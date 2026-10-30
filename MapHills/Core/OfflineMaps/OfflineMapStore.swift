import Foundation

struct InstalledOfflineMap: Codable, Equatable, Sendable {
    let packVersion: String
    let mapVersion: String
    let installedAt: Date
    let publishedAt: Date?
    let totalBytes: Int64
}

struct OfflineMapPersistentState: Codable, Equatable, Sendable {
    enum Phase: String, Codable, Sendable {
        case notInstalled
        case checkingManifest
        case availableToDownload
        case waitingForNetwork
        case downloading
        case verifying
        case installing
        case ready
        case checkingForUpdate
        case updateAvailable
        case failed
    }

    var phase: Phase
    var activeMap: InstalledOfflineMap?
    var offeredPackVersion: String?
    var targetPackVersion: String?
    var completedSourceIDs: Set<String>
    var bytesReceived: Int64
    var bytesExpected: Int64
    var lastError: String?
    var lastUpdateCheck: Date?

    var isNetworkTransferActive: Bool {
        phase == .downloading || phase == .waitingForNetwork
    }

    mutating func markWaitingForNetwork() {
        guard phase == .downloading else { return }
        phase = .waitingForNetwork
    }

    mutating func markDownloadingAfterNetworkResumes() {
        guard phase == .waitingForNetwork else { return }
        phase = .downloading
    }

    mutating func cancelTransfer() {
        guard isNetworkTransferActive else { return }
        phase = activeMap == nil ? .notInstalled : .ready
        offeredPackVersion = nil
        targetPackVersion = nil
        completedSourceIDs = []
        bytesReceived = activeMap?.totalBytes ?? 0
        bytesExpected = activeMap?.totalBytes ?? 0
        lastError = nil
    }

    static let initial = OfflineMapPersistentState(
        phase: .notInstalled,
        activeMap: nil,
        offeredPackVersion: nil,
        targetPackVersion: nil,
        completedSourceIDs: [],
        bytesReceived: 0,
        bytesExpected: 0,
        lastError: nil,
        lastUpdateCheck: nil
    )
}

struct OfflineMapStore {
    enum StoreError: LocalizedError {
        case applicationSupportUnavailable
        case unsafePackVersion
        case unsafeMapRecord
        case unsafeStagingDestination
        case stagingDirectoryMissing
        case finalDirectoryAlreadyExists
        case activePackMissing
        case insufficientSpace(required: Int64, available: Int64)

        var errorDescription: String? {
            switch self {
            case .applicationSupportUnavailable:
                return "The app storage folder is not available."
            case .unsafePackVersion:
                return "The map version contains an unsafe file name."
            case .unsafeMapRecord:
                return "The map file list contains an unknown file."
            case .unsafeStagingDestination:
                return "A map file points outside the safe work folder."
            case .stagingDirectoryMissing:
                return "The map work folder is missing."
            case .finalDirectoryAlreadyExists:
                return "This map version is already installed."
            case .activePackMissing:
                return "The installed map files are missing."
            case .insufficientSpace(let required, let available):
                return "The map needs \(required) free bytes, but only \(available) are available."
            }
        }
    }

    let rootURL: URL
    let fileManager: FileManager
    private let availableCapacityProvider: (URL) throws -> Int64

    private var stagingRootURL: URL {
        rootURL.appendingPathComponent("staging", isDirectory: true)
    }

    private var packsRootURL: URL {
        rootURL.appendingPathComponent("packs", isDirectory: true)
    }

    var stateURL: URL {
        rootURL.appendingPathComponent("state.json")
    }

    var activeMapURL: URL {
        rootURL.appendingPathComponent("active.json")
    }

    init(
        rootURL: URL? = nil,
        fileManager: FileManager = .default,
        availableCapacityProvider: @escaping (URL) throws -> Int64 = { url in
            try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                .volumeAvailableCapacityForImportantUsage ?? 0
        }
    ) throws {
        self.fileManager = fileManager
        self.availableCapacityProvider = availableCapacityProvider
        if let rootURL {
            self.rootURL = rootURL
        } else {
            guard let applicationSupport = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else {
                throw StoreError.applicationSupportUnavailable
            }
            self.rootURL = applicationSupport
                .appendingPathComponent("BareGPS", isDirectory: true)
                .appendingPathComponent("OfflineMaps", isDirectory: true)
                .appendingPathComponent("Ireland", isDirectory: true)
        }
    }

    func prepareDirectories() throws {
        try fileManager.createDirectory(at: stagingRootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: packsRootURL, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableRootURL = rootURL
        try mutableRootURL.setResourceValues(values)
    }

    func loadState() -> OfflineMapPersistentState {
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder.offlineMapDecoder.decode(
                OfflineMapPersistentState.self,
                from: data
              ) else {
            return .initial
        }
        return state
    }

    func saveState(_ state: OfflineMapPersistentState) throws {
        try prepareDirectories()
        let data = try JSONEncoder.offlineMapEncoder.encode(state)
        try data.write(to: stateURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func createStagingDirectory(packVersion: String) throws -> URL {
        guard isSafeComponent(packVersion) else {
            throw StoreError.unsafePackVersion
        }
        try prepareDirectories()
        let directory = stagingRootURL
            .appendingPathComponent("\(packVersion)-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(
            at: directory.appendingPathComponent("maps", isDirectory: true),
            withIntermediateDirectories: true
        )
        return directory
    }

    func stagedFileURL(for record: OfflineMapManifest.FileRecord, in stagingURL: URL) throws -> URL {
        guard OfflineMapManifestValidator.expectedFiles[record.sourceID] == record.relativePath else {
            throw StoreError.unsafeMapRecord
        }
        let destination = stagingURL.appendingPathComponent(record.relativePath)
        let stagingComponents = stagingURL.pathComponents
        let destinationComponents = destination.pathComponents
        guard destinationComponents.count > stagingComponents.count,
              destinationComponents.starts(with: stagingComponents) else {
            throw StoreError.unsafeStagingDestination
        }
        return destination
    }

    func installedPackURL(packVersion: String) throws -> URL {
        guard isSafeComponent(packVersion) else {
            throw StoreError.unsafePackVersion
        }
        return packsRootURL.appendingPathComponent(packVersion, isDirectory: true)
    }

    func activate(
        stagingURL: URL,
        manifest: OfflineMapManifest,
        installedAt: Date = Date(),
        validate: (URL) throws -> Void = { _ in }
    ) throws -> InstalledOfflineMap {
        try prepareDirectories()
        guard fileManager.fileExists(atPath: stagingURL.path) else {
            throw StoreError.stagingDirectoryMissing
        }

        let finalURL = try installedPackURL(packVersion: manifest.packVersion)
        guard !fileManager.fileExists(atPath: finalURL.path) else {
            throw StoreError.finalDirectoryAlreadyExists
        }

        try fileManager.moveItem(at: stagingURL, to: finalURL)
        let installedMap = InstalledOfflineMap(
            packVersion: manifest.packVersion,
            mapVersion: manifest.mapVersion,
            installedAt: installedAt,
            publishedAt: manifest.publishedAt,
            totalBytes: manifest.totalBytes
        )

        do {
            try validate(finalURL.appendingPathComponent("maps", isDirectory: true))
            let data = try JSONEncoder.offlineMapEncoder.encode(installedMap)
            try data.write(
                to: activeMapURL,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
        } catch {
            if fileManager.fileExists(atPath: finalURL.path) {
                try? fileManager.moveItem(at: finalURL, to: stagingURL)
            }
            throw error
        }
        try? removeObsoletePacks(keeping: manifest.packVersion)
        return installedMap
    }

    func removeObsoletePacks(keeping packVersion: String) throws {
        let entries = try fileManager.contentsOfDirectory(
            at: packsRootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        for entry in entries where entry.lastPathComponent != packVersion {
            guard (try entry.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true else {
                continue
            }
            try fileManager.removeItem(at: entry)
        }
    }

    func activeMap() -> InstalledOfflineMap? {
        guard let data = try? Data(contentsOf: activeMapURL) else { return nil }
        return try? JSONDecoder.offlineMapDecoder.decode(InstalledOfflineMap.self, from: data)
    }

    func activeMapsRoot() throws -> URL? {
        guard let activeMap = activeMap() else { return nil }
        let packURL = try installedPackURL(packVersion: activeMap.packVersion)
        guard fileManager.fileExists(atPath: packURL.path) else {
            throw StoreError.activePackMissing
        }
        return packURL.appendingPathComponent("maps", isDirectory: true)
    }

    func removeActiveMap() throws {
        if let activeMap = activeMap() {
            let packURL = try installedPackURL(packVersion: activeMap.packVersion)
            if fileManager.fileExists(atPath: packURL.path) {
                try fileManager.removeItem(at: packURL)
            }
        }
        if fileManager.fileExists(atPath: activeMapURL.path) {
            try fileManager.removeItem(at: activeMapURL)
        }

        var state = loadState()
        state.phase = .notInstalled
        state.activeMap = nil
        state.targetPackVersion = nil
        state.completedSourceIDs = []
        state.lastError = nil
        try saveState(state)
    }

    func removeStagingDirectory(_ url: URL) throws {
        let rootPath = stagingRootURL.standardizedFileURL.path
        let standardizedRoot = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard url.standardizedFileURL.path.hasPrefix(standardizedRoot) else {
            throw StoreError.unsafePackVersion
        }
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    func checkAvailableSpace(requiredBytes: Int64, safetyMarginBytes: Int64 = 300_000_000) throws {
        try prepareDirectories()
        let available = try availableCapacityProvider(rootURL)
        let (required, overflow) = requiredBytes.addingReportingOverflow(safetyMarginBytes)
        guard !overflow, available >= required else {
            throw StoreError.insufficientSpace(
                required: overflow ? Int64.max : required,
                available: available
            )
        }
    }

    private func isSafeComponent(_ value: String) -> Bool {
        !value.isEmpty &&
        value != "." &&
        value != ".." &&
        !value.contains("/") &&
        !value.contains("\\") &&
        value.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil
    }
}

private extension JSONEncoder {
    static var offlineMapEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var offlineMapDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
