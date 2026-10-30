import Foundation
import Testing
@testable import BareGPS_Ireland

@Suite("Offline map delivery")
struct OfflineMapDeliveryTests {
    @Test("Valid five-file manifest is accepted")
    func validManifest() throws {
        try OfflineMapManifestValidator().validate(makeManifest(), currentAppVersion: "2.0.0")
    }

    @Test("Manifest from an unapproved host is rejected")
    func rejectsWrongHost() {
        let manifest = makeManifest(transform: { record in
            OfflineMapManifest.FileRecord(
                sourceID: record.sourceID,
                relativePath: record.relativePath,
                url: URL(string: "https://example.com/\(record.relativePath)")!,
                bytes: record.bytes,
                sha256: record.sha256
            )
        })
        #expect(throws: OfflineMapManifestValidator.ValidationError.self) {
            try OfflineMapManifestValidator().validate(manifest, currentAppVersion: "2.0.0")
        }
    }

    @Test("Manifest requiring a newer app is rejected")
    func rejectsNewerAppRequirement() {
        let manifest = makeManifest(minimumAppVersion: "3.0.0")
        #expect(throws: OfflineMapManifestValidator.ValidationError.self) {
            try OfflineMapManifestValidator().validate(manifest, currentAppVersion: "2.0.0")
        }
    }

    @Test("Manifest total must equal all file sizes")
    func rejectsWrongTotal() {
        let manifest = makeManifest(totalBytes: 999)
        #expect(throws: OfflineMapManifestValidator.ValidationError.self) {
            try OfflineMapManifestValidator().validate(manifest, currentAppVersion: "2.0.0")
        }
    }

    @Test("Map store activates a complete staged pack atomically")
    func activatesStagedPack() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try OfflineMapStore(rootURL: root)
        let manifest = makeManifest()
        let staging = try store.createStagingDirectory(packVersion: manifest.packVersion)
        for record in manifest.files {
            let url = try store.stagedFileURL(for: record, in: staging)
            try Data([0]).write(to: url)
        }

        let installed = try store.activate(stagingURL: staging, manifest: manifest)
        #expect(installed.packVersion == manifest.packVersion)
        #expect(store.activeMap()?.packVersion == installed.packVersion)
        #expect(store.activeMap()?.mapVersion == installed.mapVersion)
        #expect(store.activeMap()?.totalBytes == installed.totalBytes)
        #expect(try store.activeMapsRoot()?.lastPathComponent == "maps")
        #expect(!FileManager.default.fileExists(atPath: staging.path))
    }

    @Test("Removing a map does not remove the offline-map root")
    func removesOnlyPackData() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try OfflineMapStore(rootURL: root)
        let manifest = makeManifest()
        let staging = try store.createStagingDirectory(packVersion: manifest.packVersion)
        _ = try store.activate(stagingURL: staging, manifest: manifest)
        try store.removeActiveMap()

        #expect(store.activeMap() == nil)
        #expect(FileManager.default.fileExists(atPath: root.path))
        #expect(store.loadState().phase == .notInstalled)
    }

    @Test("A download moves into and out of the waiting-for-network state")
    func tracksWaitingForNetwork() {
        var state = OfflineMapPersistentState.initial
        state.phase = .downloading

        state.markWaitingForNetwork()
        #expect(state.phase == .waitingForNetwork)
        #expect(state.isNetworkTransferActive)

        state.markDownloadingAfterNetworkResumes()
        #expect(state.phase == .downloading)
        #expect(state.isNetworkTransferActive)
    }

    @Test("Unrelated phases ignore network-transfer callbacks")
    func ignoresNetworkCallbacksOutsideDownload() {
        var state = OfflineMapPersistentState.initial

        state.markWaitingForNetwork()
        #expect(state.phase == .notInstalled)
        #expect(!state.isNetworkTransferActive)

        state.phase = .ready
        state.markDownloadingAfterNetworkResumes()
        #expect(state.phase == .ready)
        #expect(!state.isNetworkTransferActive)
    }

    @Test("Cancelling without an installed map returns to Not Installed")
    func cancellationWithoutInstalledMap() {
        var state = OfflineMapPersistentState.initial
        state.phase = .downloading
        state.targetPackVersion = "new-pack"
        state.completedSourceIDs = ["base"]
        state.bytesReceived = 100
        state.bytesExpected = 1_000

        state.cancelTransfer()

        #expect(state.phase == .notInstalled)
        #expect(state.targetPackVersion == nil)
        #expect(state.completedSourceIDs.isEmpty)
        #expect(state.bytesReceived == 0)
        #expect(state.lastError == nil)
    }

    @Test("Cancelling an update keeps the installed map ready")
    func cancellationWithInstalledMap() {
        let installed = InstalledOfflineMap(
            packVersion: "old-pack",
            mapVersion: "1.0.0",
            installedAt: .distantPast,
            publishedAt: nil,
            totalBytes: 500
        )
        var state = OfflineMapPersistentState.initial
        state.activeMap = installed
        state.phase = .waitingForNetwork
        state.bytesExpected = 1_000

        state.cancelTransfer()
        state.cancelTransfer()

        #expect(state.phase == .ready)
        #expect(state.activeMap == installed)
        #expect(state.bytesReceived == installed.totalBytes)
        #expect(state.lastError == nil)
    }

    @Test("A failed new-style validation rolls back to the previous map")
    func failedActivationRollsBack() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try OfflineMapStore(rootURL: root)
        let oldManifest = makeManifest(packVersion: "old-pack", mapVersion: "1.0.0")
        let oldStaging = try store.createStagingDirectory(packVersion: oldManifest.packVersion)
        _ = try store.activate(stagingURL: oldStaging, manifest: oldManifest)

        let newManifest = makeManifest(packVersion: "new-pack", mapVersion: "2.0.0")
        let newStaging = try store.createStagingDirectory(packVersion: newManifest.packVersion)
        struct RejectedStyle: Error {}

        #expect(throws: RejectedStyle.self) {
            try store.activate(stagingURL: newStaging, manifest: newManifest) { _ in
                throw RejectedStyle()
            }
        }
        #expect(store.activeMap()?.packVersion == oldManifest.packVersion)
        #expect(FileManager.default.fileExists(
            atPath: try store.installedPackURL(packVersion: oldManifest.packVersion).path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: try store.installedPackURL(packVersion: newManifest.packVersion).path
        ))
    }

    @Test("A successful update removes the obsolete pack only after activation")
    func successfulActivationCleansOldPack() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try OfflineMapStore(rootURL: root)
        let oldManifest = makeManifest(packVersion: "old-pack", mapVersion: "1.0.0")
        _ = try store.activate(
            stagingURL: store.createStagingDirectory(packVersion: oldManifest.packVersion),
            manifest: oldManifest
        )
        let newManifest = makeManifest(packVersion: "new-pack", mapVersion: "2.0.0")
        var validatedWhileOldMapWasActive = false
        _ = try store.activate(
            stagingURL: store.createStagingDirectory(packVersion: newManifest.packVersion),
            manifest: newManifest
        ) { _ in
            validatedWhileOldMapWasActive = store.activeMap()?.packVersion == oldManifest.packVersion
        }

        #expect(validatedWhileOldMapWasActive)
        #expect(store.activeMap()?.packVersion == newManifest.packVersion)
        #expect(!FileManager.default.fileExists(
            atPath: try store.installedPackURL(packVersion: oldManifest.packVersion).path
        ))
    }

    @Test("Wi-Fi policy blocks cellular, costly, and constrained networks")
    func wiFiNetworkPolicy() {
        let configuration = URLSessionConfiguration.ephemeral
        OfflineMapNetworkPolicy(wiFiOnly: true).apply(to: configuration)
        #expect(!configuration.allowsCellularAccess)
        #expect(!configuration.allowsExpensiveNetworkAccess)
        #expect(!configuration.allowsConstrainedNetworkAccess)

        OfflineMapNetworkPolicy(wiFiOnly: false).apply(to: configuration)
        #expect(configuration.allowsCellularAccess)
        #expect(configuration.allowsExpensiveNetworkAccess)
        #expect(!configuration.allowsConstrainedNetworkAccess)
    }

    @Test("First-launch map offer appears no more than twice")
    func firstLaunchOfferLimit() throws {
        let suiteName = "OfflineMapLaunchOfferPolicyTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let policy = OfflineMapLaunchOfferPolicy(defaults: defaults)

        #expect(policy.shouldOffer(isMapInstalled: false, hasOfferedThisLaunch: false))
        policy.recordOffer()
        #expect(policy.shouldOffer(isMapInstalled: false, hasOfferedThisLaunch: false))
        policy.recordOffer()
        #expect(!policy.shouldOffer(isMapInstalled: false, hasOfferedThisLaunch: false))
    }

    @Test("First-launch map offer never appears with an installed map")
    func noFirstLaunchOfferForInstalledMap() throws {
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        let policy = OfflineMapLaunchOfferPolicy(defaults: defaults)
        #expect(!policy.shouldOffer(isMapInstalled: true, hasOfferedThisLaunch: false))
    }

    @Test("Choosing Later starts neither a first download nor an update")
    func laterIsPassive() {
        var requestCount = 0
        OfflineMapLaunchOfferDecision.later.performNetworkRequest { requestCount += 1 }
        OfflineMapUpdateOfferDecision.later.performDownload { requestCount += 1 }
        #expect(requestCount == 0)
    }

    private func makeManifest(
        minimumAppVersion: String = "2.0.0",
        totalBytes: Int64? = nil,
        packVersion: String = "test-pack",
        mapVersion: String = "2.0.0",
        transform: (OfflineMapManifest.FileRecord) -> OfflineMapManifest.FileRecord = { $0 }
    ) -> OfflineMapManifest {
        let files = OfflineMapManifestValidator.expectedFiles
            .sorted(by: { $0.key < $1.key })
            .map { sourceID, relativePath in
                transform(
                    OfflineMapManifest.FileRecord(
                        sourceID: sourceID,
                        relativePath: relativePath,
                        url: URL(
                            string: "https://downloads.appsbyonzy.dev/baregps-ireland/test/\(relativePath)"
                        )!,
                        bytes: 1,
                        sha256: String(repeating: "a", count: 64)
                    )
                )
            }

        return OfflineMapManifest(
            schemaVersion: 1,
            packID: OfflineMapManifestValidator.expectedPackID,
            packVersion: packVersion,
            mapVersion: mapVersion,
            minimumAppVersion: minimumAppVersion,
            displayName: "Test Map",
            totalBytes: totalBytes ?? Int64(files.count),
            publishedAt: Date(timeIntervalSince1970: 0),
            files: files
        )
    }
}
