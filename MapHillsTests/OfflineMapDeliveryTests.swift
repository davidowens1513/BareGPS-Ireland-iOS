import CryptoKit
import Foundation
import SQLite3
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

    @Test("Malformed manifest JSON is rejected")
    func rejectsMalformedJSON() {
        #expect(throws: (any Error).self) {
            try JSONDecoder.offlineMapManifestDecoder.decode(
                OfflineMapManifest.self,
                from: Data("{not-json".utf8)
            )
        }
    }

    @Test("Wrong pack ID and schema are rejected")
    func rejectsWrongIdentityAndSchema() {
        #expect(throws: OfflineMapManifestValidator.ValidationError.self) {
            try OfflineMapManifestValidator().validate(
                makeManifest(packID: "wrong-pack"),
                currentAppVersion: "2.0.0"
            )
        }
        #expect(throws: OfflineMapManifestValidator.ValidationError.self) {
            try OfflineMapManifestValidator().validate(
                makeManifest(schemaVersion: 2),
                currentAppVersion: "2.0.0"
            )
        }
    }

    @Test("HTTP manifest file URLs are rejected")
    func rejectsHTTPURL() {
        let manifest = replacingFirstRecord(in: makeManifest()) { record in
            fileRecord(from: record, url: URL(string: "http://downloads.appsbyonzy.dev/file")!)
        }
        #expect(throws: OfflineMapManifestValidator.ValidationError.self) {
            try OfflineMapManifestValidator().validate(manifest, currentAppVersion: "2.0.0")
        }
    }

    @Test("Unsafe relative paths are rejected")
    func rejectsUnsafePaths() {
        for path in ["../basemap.mbtiles", "/maps/basemap.mbtiles", "maps\\basemap.mbtiles", "maps//basemap.mbtiles"] {
            let manifest = replacingFirstRecord(in: makeManifest()) { record in
                fileRecord(from: record, relativePath: path)
            }
            #expect(throws: OfflineMapManifestValidator.ValidationError.self) {
                try OfflineMapManifestValidator().validate(manifest, currentAppVersion: "2.0.0")
            }
        }
    }

    @Test("Duplicate source IDs and paths are rejected")
    func rejectsDuplicates() {
        let base = makeManifest()
        var duplicateIDs = base.files
        duplicateIDs[1] = fileRecord(from: duplicateIDs[1], sourceID: duplicateIDs[0].sourceID)
        #expect(throws: OfflineMapManifestValidator.ValidationError.self) {
            try OfflineMapManifestValidator().validate(
                manifest(from: base, files: duplicateIDs),
                currentAppVersion: "2.0.0"
            )
        }

        var duplicatePaths = base.files
        duplicatePaths[1] = fileRecord(from: duplicatePaths[1], relativePath: duplicatePaths[0].relativePath)
        #expect(throws: OfflineMapManifestValidator.ValidationError.self) {
            try OfflineMapManifestValidator().validate(
                manifest(from: base, files: duplicatePaths),
                currentAppVersion: "2.0.0"
            )
        }
    }

    @Test("Wrong file count and unknown source-file pair are rejected")
    func rejectsWrongFileSet() {
        let base = makeManifest()
        #expect(throws: OfflineMapManifestValidator.ValidationError.self) {
            try OfflineMapManifestValidator().validate(
                manifest(from: base, files: Array(base.files.dropLast())),
                currentAppVersion: "2.0.0"
            )
        }
        let unknownPair = replacingFirstRecord(in: base) { record in
            fileRecord(from: record, relativePath: "maps/unknown.mbtiles")
        }
        #expect(throws: OfflineMapManifestValidator.ValidationError.self) {
            try OfflineMapManifestValidator().validate(unknownPair, currentAppVersion: "2.0.0")
        }
    }

    @Test("Invalid sizes, hashes, overflow, and excessive pack totals are rejected")
    func rejectsInvalidIntegrityMetadata() {
        for bytes in [Int64(0), Int64(-1), Int64(2_000_000_001)] {
            let manifest = replacingFirstRecord(in: makeManifest()) { record in
                fileRecord(from: record, bytes: bytes)
            }
            #expect(throws: OfflineMapManifestValidator.ValidationError.self) {
                try OfflineMapManifestValidator().validate(manifest, currentAppVersion: "2.0.0")
            }
        }

        for hash in ["abc", String(repeating: "A", count: 64), String(repeating: "g", count: 64)] {
            let manifest = replacingFirstRecord(in: makeManifest()) { record in
                fileRecord(from: record, sha256: hash)
            }
            #expect(throws: OfflineMapManifestValidator.ValidationError.self) {
                try OfflineMapManifestValidator().validate(manifest, currentAppVersion: "2.0.0")
            }
        }

        let oversized = makeManifest()
        #expect(throws: OfflineMapManifestValidator.ValidationError.self) {
            try OfflineMapManifestValidator(maximumPackBytes: 4).validate(
                oversized,
                currentAppVersion: "2.0.0"
            )
        }

        let overflowFiles = makeManifest().files.map { record in
            fileRecord(from: record, bytes: Int64.max / 4)
        }
        #expect(throws: OfflineMapManifestValidator.ValidationError.self) {
            try OfflineMapManifestValidator(maximumPackBytes: .max).validate(
                manifest(from: makeManifest(), files: overflowFiles, totalBytes: .max),
                currentAppVersion: "2.0.0"
            )
        }
    }

    @Test("Verifier rejects missing, wrongly sized, and wrongly hashed files")
    func verifierRejectsMissingSizeAndHash() throws {
        let fixture = try makeValidPackFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let target = try #require(fixture.manifest.files.first)
        let targetURL = fixture.root.appendingPathComponent(target.relativePath)

        try FileManager.default.removeItem(at: targetURL)
        #expect(throws: OfflineMapPackVerifier.VerificationError.self) {
            try OfflineMapPackVerifier().verify(manifest: fixture.manifest, at: fixture.root)
        }

        try createMBTiles(at: targetURL)
        let wrongSize = replacingFirstRecord(in: fixture.manifest) { record in
            fileRecord(from: record, bytes: record.bytes + 1)
        }
        #expect(throws: OfflineMapPackVerifier.VerificationError.self) {
            try OfflineMapPackVerifier().verify(manifest: wrongSize, at: fixture.root)
        }

        let wrongHash = replacingFirstRecord(in: fixture.manifest) { record in
            fileRecord(from: record, sha256: String(repeating: "0", count: 64))
        }
        #expect(throws: OfflineMapPackVerifier.VerificationError.self) {
            try OfflineMapPackVerifier().verify(manifest: wrongHash, at: fixture.root)
        }
    }

    @Test("Verifier rejects non-SQLite and incomplete MBTiles databases")
    func verifierRejectsInvalidDatabases() throws {
        for databaseKind in InvalidDatabaseKind.allCases {
            let fixture = try makeValidPackFixture()
            defer { try? FileManager.default.removeItem(at: fixture.root) }
            let target = try #require(fixture.manifest.files.first)
            let targetURL = fixture.root.appendingPathComponent(target.relativePath)
            try FileManager.default.removeItem(at: targetURL)

            switch databaseKind {
            case .notSQLite:
                try Data("not sqlite".utf8).write(to: targetURL)
            case .missingMetadata:
                try createMBTiles(at: targetURL, includeMetadata: false)
            case .missingTiles:
                try createMBTiles(at: targetURL, includeTiles: false)
            case .noTileRows:
                try createMBTiles(at: targetURL, includeTileRow: false)
            }

            let updatedManifest = try manifestMatchingFiles(at: fixture.root)
            #expect(throws: OfflineMapPackVerifier.VerificationError.self) {
                try OfflineMapPackVerifier().verify(manifest: updatedManifest, at: fixture.root)
            }
        }
    }

    @Test("Verifier and store reject staging path traversal")
    func rejectsStagingTraversal() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let escapedRecord = fileRecord(
            from: try #require(makeManifest().files.first),
            relativePath: "../escape.mbtiles"
        )
        let escapedManifest = manifest(from: makeManifest(), files: [escapedRecord])
        #expect(throws: OfflineMapPackVerifier.VerificationError.self) {
            try OfflineMapPackVerifier().verify(manifest: escapedManifest, at: root)
        }

        let store = try OfflineMapStore(rootURL: root.appendingPathComponent("store"))
        let staging = try store.createStagingDirectory(packVersion: "safe-pack")
        #expect(throws: OfflineMapStore.StoreError.self) {
            _ = try store.stagedFileURL(for: escapedRecord, in: staging)
        }
        #expect(throws: OfflineMapStore.StoreError.self) {
            try store.removeStagingDirectory(root)
        }
    }

    @Test("Activation rolls back when active record cannot be written")
    func activationRollsBackOnActiveRecordWriteFailure() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try OfflineMapStore(rootURL: root)
        try store.prepareDirectories()
        try FileManager.default.createDirectory(at: store.activeMapURL, withIntermediateDirectories: true)
        let manifest = makeManifest()
        let staging = try store.createStagingDirectory(packVersion: manifest.packVersion)

        #expect(throws: (any Error).self) {
            try store.activate(stagingURL: staging, manifest: manifest)
        }
        #expect(FileManager.default.fileExists(atPath: staging.path))
        #expect(!FileManager.default.fileExists(
            atPath: try store.installedPackURL(packVersion: manifest.packVersion).path
        ))
    }

    @Test("A verification failure leaves the old active map untouched")
    func verificationFailureKeepsOldMap() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try OfflineMapStore(rootURL: root)
        let oldManifest = makeManifest(packVersion: "old-pack", mapVersion: "1.0.0")
        _ = try store.activate(
            stagingURL: store.createStagingDirectory(packVersion: oldManifest.packVersion),
            manifest: oldManifest
        )
        let badFixture = try makeValidPackFixture()
        defer { try? FileManager.default.removeItem(at: badFixture.root) }
        let first = try #require(badFixture.manifest.files.first)
        try FileManager.default.removeItem(at: badFixture.root.appendingPathComponent(first.relativePath))

        #expect(throws: OfflineMapPackVerifier.VerificationError.self) {
            try OfflineMapPackVerifier().verify(manifest: badFixture.manifest, at: badFixture.root)
        }
        #expect(store.activeMap()?.packVersion == oldManifest.packVersion)
    }

    @Test("Active map and transfer identities survive a persistence round trip")
    func restoresPersistentIdentity() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try OfflineMapStore(rootURL: root)
        let manifest = makeManifest()
        let installed = try store.activate(
            stagingURL: store.createStagingDirectory(packVersion: manifest.packVersion),
            manifest: manifest,
            installedAt: Date(timeIntervalSince1970: 1_000)
        )
        var state = OfflineMapPersistentState.initial
        state.phase = .downloading
        state.activeMap = installed
        state.targetPackVersion = "next-pack"
        state.completedSourceIDs = ["basemap", "coast"]
        try store.saveState(state)

        let relaunchedStore = try OfflineMapStore(rootURL: root)
        #expect(relaunchedStore.activeMap() == installed)
        #expect(relaunchedStore.loadState() == state)
        #expect(try relaunchedStore.activeMapsRoot()?.lastPathComponent == "maps")

        let context = OfflineMapTransferContext(manifest: manifest, stagingURL: root.appendingPathComponent("stage"))
        let encoded = try JSONEncoder().encode(context)
        let restored = try JSONDecoder().decode(OfflineMapTransferContext.self, from: encoded)
        #expect(restored.manifest == context.manifest)
        #expect(restored.stagingURL == context.stagingURL)
        #expect(Set(restored.manifest.files.map(\.sourceID)) == Set(manifest.files.map(\.sourceID)))
    }

    @Test("Offline map root is excluded from backup")
    func excludesOfflineMapsFromBackup() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try OfflineMapStore(rootURL: root)
        try store.prepareDirectories()
        #expect(try root.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    }

    @Test("Space check includes margin and handles overflow")
    func checksAvailableSpaceWithSafetyMargin() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let enough = try OfflineMapStore(rootURL: root, availableCapacityProvider: { _ in 400 })
        try enough.checkAvailableSpace(requiredBytes: 100, safetyMarginBytes: 300)

        let short = try OfflineMapStore(rootURL: root, availableCapacityProvider: { _ in 399 })
        #expect(throws: OfflineMapStore.StoreError.self) {
            try short.checkAvailableSpace(requiredBytes: 100, safetyMarginBytes: 300)
        }
        #expect(throws: OfflineMapStore.StoreError.self) {
            try enough.checkAvailableSpace(requiredBytes: .max, safetyMarginBytes: 1)
        }
    }

    private enum InvalidDatabaseKind: CaseIterable {
        case notSQLite
        case missingMetadata
        case missingTiles
        case noTileRows
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func fileRecord(
        from record: OfflineMapManifest.FileRecord,
        sourceID: String? = nil,
        relativePath: String? = nil,
        url: URL? = nil,
        bytes: Int64? = nil,
        sha256: String? = nil
    ) -> OfflineMapManifest.FileRecord {
        OfflineMapManifest.FileRecord(
            sourceID: sourceID ?? record.sourceID,
            relativePath: relativePath ?? record.relativePath,
            url: url ?? record.url,
            bytes: bytes ?? record.bytes,
            sha256: sha256 ?? record.sha256
        )
    }

    private func replacingFirstRecord(
        in manifest: OfflineMapManifest,
        transform: (OfflineMapManifest.FileRecord) -> OfflineMapManifest.FileRecord
    ) -> OfflineMapManifest {
        var files = manifest.files
        files[0] = transform(files[0])
        return self.manifest(from: manifest, files: files)
    }

    private func manifest(
        from manifest: OfflineMapManifest,
        files: [OfflineMapManifest.FileRecord],
        totalBytes: Int64? = nil
    ) -> OfflineMapManifest {
        OfflineMapManifest(
            schemaVersion: manifest.schemaVersion,
            packID: manifest.packID,
            packVersion: manifest.packVersion,
            mapVersion: manifest.mapVersion,
            minimumAppVersion: manifest.minimumAppVersion,
            displayName: manifest.displayName,
            totalBytes: totalBytes ?? files.reduce(0) { partial, record in
                partial.addingReportingOverflow(record.bytes).overflow ? .max : partial + record.bytes
            },
            publishedAt: manifest.publishedAt,
            files: files
        )
    }

    private func makeValidPackFixture() throws -> (root: URL, manifest: OfflineMapManifest) {
        let root = temporaryDirectory()
        for relativePath in OfflineMapManifestValidator.expectedFiles.values {
            try createMBTiles(at: root.appendingPathComponent(relativePath))
        }
        return (root, try manifestMatchingFiles(at: root))
    }

    private func manifestMatchingFiles(at root: URL) throws -> OfflineMapManifest {
        let files = try OfflineMapManifestValidator.expectedFiles
            .sorted(by: { $0.key < $1.key })
            .map { sourceID, relativePath in
                let url = root.appendingPathComponent(relativePath)
                let data = try Data(contentsOf: url)
                return OfflineMapManifest.FileRecord(
                    sourceID: sourceID,
                    relativePath: relativePath,
                    url: URL(string: "https://downloads.appsbyonzy.dev/\(relativePath)")!,
                    bytes: Int64(data.count),
                    sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                )
            }
        return OfflineMapManifest(
            schemaVersion: 1,
            packID: OfflineMapManifestValidator.expectedPackID,
            packVersion: "verified-pack",
            mapVersion: "2.0.0",
            minimumAppVersion: "2.0.0",
            displayName: "Verified Map",
            totalBytes: files.reduce(0) { $0 + $1.bytes },
            publishedAt: nil,
            files: files
        )
    }

    private func createMBTiles(
        at url: URL,
        includeMetadata: Bool = true,
        includeTiles: Bool = true,
        includeTileRow: Bool = true
    ) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var database: OpaquePointer?
        guard sqlite3_open(url.path, &database) == SQLITE_OK, let database else {
            throw CocoaError(.fileWriteUnknown)
        }
        defer { sqlite3_close(database) }

        if includeMetadata {
            try executeSQLite("CREATE TABLE metadata (name TEXT, value TEXT);", in: database)
            try executeSQLite("INSERT INTO metadata VALUES ('name', 'test');", in: database)
        }
        if includeTiles {
            try executeSQLite(
                "CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB);",
                in: database
            )
            if includeTileRow {
                try executeSQLite("INSERT INTO tiles VALUES (0, 0, 0, X'00');", in: database)
            }
        }
    }

    private func executeSQLite(_ sql: String, in database: OpaquePointer) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    private func makeManifest(
        schemaVersion: Int = 1,
        packID: String = OfflineMapManifestValidator.expectedPackID,
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
            schemaVersion: schemaVersion,
            packID: packID,
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
