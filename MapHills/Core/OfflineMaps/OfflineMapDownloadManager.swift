import Foundation
import UIKit

struct OfflineMapTransferContext: Codable, Sendable {
    let manifest: OfflineMapManifest
    let stagingURL: URL
}

extension Notification.Name {
    static let offlineMapStateDidChange = Notification.Name("OfflineMapStateDidChange")
}

final class OfflineMapDownloadManager: NSObject, URLSessionDownloadDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    static let shared: OfflineMapDownloadManager? = try? OfflineMapDownloadManager()

    private enum DownloadError: LocalizedError {
        case noHTTPResponse
        case badStatus(Int)
        case redirectedToUnapprovedLocation
        case missingTaskIdentity
        case noSavedTransfer
        case wrongContentType

        var errorDescription: String? {
            switch self {
            case .noHTTPResponse:
                return "The map server did not give a valid web response."
            case .badStatus(let status):
                return "The map server returned error \(status)."
            case .redirectedToUnapprovedLocation:
                return "The map server sent the download to an unapproved address."
            case .missingTaskIdentity:
                return "The app could not match a download to its map file."
            case .noSavedTransfer:
                return "The saved map download could not be found."
            case .wrongContentType:
                return "The map server returned a web page instead of a map file."
            }
        }
    }

    private let store: OfflineMapStore
    private let verifier: OfflineMapPackVerifier
    private let validator = OfflineMapManifestValidator()
    private let fileManager: FileManager
    private let defaults: UserDefaults
    private let contextURL: URL
    private let logURL: URL
    private let lock = NSLock()
    private var backgroundCompletionHandler: (() -> Void)?
    private var _state: OfflineMapPersistentState
    private var sessionStorage: URLSession?

    var state: OfflineMapPersistentState {
        lock.withLock { _state }
    }

    var wiFiOnly: Bool {
        get { defaults.object(forKey: "offlineMapWiFiOnly") as? Bool ?? true }
        set {
            defaults.set(newValue, forKey: "offlineMapWiFiOnly")
            sessionStorage?.invalidateAndCancel()
            sessionStorage = nil
            reconnectToBackgroundTasks()
        }
    }

    private var session: URLSession {
        if let sessionStorage {
            return sessionStorage
        }
        let configuration = URLSessionConfiguration.background(
            withIdentifier: OfflineMapConfiguration.backgroundSessionIdentifier
        )
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.allowsCellularAccess = !wiFiOnly
        configuration.allowsExpensiveNetworkAccess = !wiFiOnly
        configuration.allowsConstrainedNetworkAccess = false

        let queue = OperationQueue()
        queue.name = "ie.appsbyonzy.baregps.offline-map-delegate"
        queue.maxConcurrentOperationCount = 1
        let created = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
        sessionStorage = created
        return created
    }

    init(
        store: OfflineMapStore = try! OfflineMapStore(),
        verifier: OfflineMapPackVerifier = OfflineMapPackVerifier(),
        fileManager: FileManager = .default,
        defaults: UserDefaults = .standard
    ) throws {
        self.store = store
        self.verifier = verifier
        self.fileManager = fileManager
        self.defaults = defaults
        self.contextURL = store.rootURL.appendingPathComponent("transfer.json")
        self.logURL = store.rootURL.appendingPathComponent("download.log")
        self._state = store.loadState()
        super.init()
        try store.prepareDirectories()
        reconcileStoredState()
        reconnectToBackgroundTasks()
    }

    func checkForUpdate() {
        mutateState { state in
            state.phase = state.activeMap == nil ? .checkingManifest : .checkingForUpdate
            state.lastError = nil
        }

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(
                    from: OfflineMapConfiguration.manifestURL
                )
                try validateManifestResponse(response, data: data)
                let manifest = try JSONDecoder.offlineMapManifestDecoder.decode(
                    OfflineMapManifest.self,
                    from: data
                )
                try validator.validate(manifest, currentAppVersion: Self.appVersion)

                if let active = store.activeMap(), active.packVersion == manifest.packVersion {
                    mutateState { state in
                        state.phase = .ready
                        state.activeMap = active
                        state.offeredPackVersion = nil
                        state.lastUpdateCheck = Date()
                    }
                } else {
                    try saveContext(OfflineMapTransferContext(manifest: manifest, stagingURL: URL(fileURLWithPath: "/")))
                    mutateState { state in
                        state.phase = state.activeMap == nil ? .availableToDownload : .updateAvailable
                        state.offeredPackVersion = manifest.packVersion
                        state.lastUpdateCheck = Date()
                    }
                }
            } catch {
                recordFailure(error)
            }
        }
    }

    func downloadOfferedMap() {
        Task {
            do {
                let offeredContext = try loadContext()
                let manifest = offeredContext.manifest
                try store.checkAvailableSpace(requiredBytes: manifest.totalBytes)
                let stagingURL = try store.createStagingDirectory(packVersion: manifest.packVersion)
                try saveContext(OfflineMapTransferContext(manifest: manifest, stagingURL: stagingURL))

                mutateState { state in
                    state.phase = .downloading
                    state.targetPackVersion = manifest.packVersion
                    state.completedSourceIDs = []
                    state.bytesReceived = 0
                    state.bytesExpected = manifest.totalBytes
                    state.lastError = nil
                }

                for record in manifest.files {
                    let request = URLRequest(
                        url: record.url,
                        cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                        timeoutInterval: 300
                    )
                    let task = session.downloadTask(with: request)
                    task.taskDescription = record.sourceID
                    task.resume()
                }
                appendLog("Started pack \(manifest.packVersion).")
            } catch {
                recordFailure(error)
            }
        }
    }

    func retry() {
        if state.phase == .failed {
            checkForUpdate()
        }
    }

    func removeMap() throws {
        session.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }
        if let context = try? loadContext(), context.stagingURL.path != "/" {
            try? store.removeStagingDirectory(context.stagingURL)
        }
        try store.removeActiveMap()
        try? fileManager.removeItem(at: contextURL)
        setState(store.loadState())
        appendLog("Removed installed map.")
    }

    func reconnectToBackgroundTasks() {
        _ = session
        session.getAllTasks { [weak self] tasks in
            guard let self else { return }
            let activeIDs = Set(tasks.compactMap(\.taskDescription))
            let savedIDs = Set(self.state.completedSourceIDs)
            if self.state.phase == .downloading && activeIDs.isEmpty && savedIDs.count < 5 {
                self.recordFailure(DownloadError.noSavedTransfer)
            }
        }
    }

    func handleBackgroundEvents(completionHandler: @escaping () -> Void) {
        lock.withLock {
            backgroundCompletionHandler = completionHandler
        }
        reconnectToBackgroundTasks()
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            guard let response = downloadTask.response as? HTTPURLResponse else {
                throw DownloadError.noHTTPResponse
            }
            guard response.statusCode == 200 else {
                throw DownloadError.badStatus(response.statusCode)
            }
            guard let finalURL = response.url,
                  finalURL.scheme?.lowercased() == "https",
                  finalURL.host?.lowercased() == OfflineMapConfiguration.approvedDownloadHost else {
                throw DownloadError.redirectedToUnapprovedLocation
            }
            if response.mimeType?.lowercased() == "text/html" {
                throw DownloadError.wrongContentType
            }
            guard let sourceID = downloadTask.taskDescription else {
                throw DownloadError.missingTaskIdentity
            }

            let context = try loadContext()
            guard let record = context.manifest.files.first(where: { $0.sourceID == sourceID }) else {
                throw DownloadError.missingTaskIdentity
            }
            let destination = try store.stagedFileURL(for: record, in: context.stagingURL)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: location, to: destination)

            mutateState { state in
                if !state.completedSourceIDs.contains(sourceID) {
                    state.completedSourceIDs.insert(sourceID)
                }
            }
            appendLog("Saved \(sourceID).")
            finishInstallIfComplete(context: context)
        } catch {
            recordFailure(error)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        session.getAllTasks { [weak self] tasks in
            guard let self else { return }
            let received = tasks.reduce(Int64(0)) { $0 + max($1.countOfBytesReceived, 0) }
            let finishedBytes = self.completedByteCount()
            self.mutateState { state in
                state.bytesReceived = min(finishedBytes + received, state.bytesExpected)
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled { return }
        recordFailure(error)
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        let completion = lock.withLock { () -> (() -> Void)? in
            defer { backgroundCompletionHandler = nil }
            return backgroundCompletionHandler
        }
        DispatchQueue.main.async {
            completion?()
        }
    }

    private func finishInstallIfComplete(context: OfflineMapTransferContext) {
        guard state.completedSourceIDs.count == context.manifest.files.count else { return }
        mutateState { $0.phase = .verifying }

        Task {
            do {
                try verifier.verify(manifest: context.manifest, at: context.stagingURL)
                mutateState { $0.phase = .installing }
                let installed = try store.activate(
                    stagingURL: context.stagingURL,
                    manifest: context.manifest
                )
                try? fileManager.removeItem(at: contextURL)
                mutateState { state in
                    state.phase = .ready
                    state.activeMap = installed
                    state.targetPackVersion = nil
                    state.offeredPackVersion = nil
                    state.bytesReceived = installed.totalBytes
                    state.bytesExpected = installed.totalBytes
                    state.lastError = nil
                }
                appendLog("Activated pack \(installed.packVersion).")
            } catch {
                try? store.removeStagingDirectory(context.stagingURL)
                recordFailure(error)
            }
        }
    }

    private func validateManifestResponse(_ response: URLResponse, data: Data) throws {
        guard let response = response as? HTTPURLResponse else {
            throw DownloadError.noHTTPResponse
        }
        guard response.statusCode == 200 else {
            throw DownloadError.badStatus(response.statusCode)
        }
        guard response.url?.scheme?.lowercased() == "https",
              response.url?.host?.lowercased() == OfflineMapConfiguration.approvedDownloadHost else {
            throw DownloadError.redirectedToUnapprovedLocation
        }
        if response.mimeType?.lowercased() == "text/html" ||
            data.prefix(32).contains(Data("<html".utf8)) {
            throw DownloadError.wrongContentType
        }
    }

    private func reconcileStoredState() {
        let active = store.activeMap()
        mutateState { state in
            state.activeMap = active
            if active != nil && state.phase != .downloading && state.phase != .verifying {
                state.phase = .ready
            }
        }
    }

    private func completedByteCount() -> Int64 {
        guard let context = try? loadContext() else { return 0 }
        let completed = Set(state.completedSourceIDs)
        return context.manifest.files
            .filter { completed.contains($0.sourceID) }
            .reduce(0) { $0 + $1.bytes }
    }

    private func mutateState(_ mutation: (inout OfflineMapPersistentState) -> Void) {
        let newState = lock.withLock { () -> OfflineMapPersistentState in
            mutation(&_state)
            return _state
        }
        try? store.saveState(newState)
        NotificationCenter.default.post(name: .offlineMapStateDidChange, object: self)
    }

    private func setState(_ state: OfflineMapPersistentState) {
        lock.withLock {
            _state = state
        }
        NotificationCenter.default.post(name: .offlineMapStateDidChange, object: self)
    }

    private func recordFailure(_ error: Error) {
        session.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }
        if let context = try? loadContext(), context.stagingURL.path != "/" {
            try? store.removeStagingDirectory(context.stagingURL)
            try? fileManager.removeItem(at: contextURL)
        }
        appendLog("Failed: \(error.localizedDescription)")
        mutateState { state in
            state.completedSourceIDs = []
            state.bytesReceived = 0
            state.targetPackVersion = nil
            state.phase = .failed
            state.lastError = error.localizedDescription
        }
    }

    private func saveContext(_ context: OfflineMapTransferContext) throws {
        try store.prepareDirectories()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(context)
        try data.write(to: contextURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private func loadContext() throws -> OfflineMapTransferContext {
        guard let data = try? Data(contentsOf: contextURL) else {
            throw DownloadError.noSavedTransfer
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(OfflineMapTransferContext.self, from: data)
    }

    private func appendLog(_ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        try? store.prepareDirectories()
        if fileManager.fileExists(atPath: logURL.path),
           let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: logURL, options: .completeFileProtectionUntilFirstUserAuthentication)
        }
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }
}

private extension OfflineMapConfiguration {
    static let approvedDownloadHost = "downloads.appsbyonzy.dev"
}

extension JSONDecoder {
    static var offlineMapManifestDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
