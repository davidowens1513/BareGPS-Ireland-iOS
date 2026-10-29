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

    private func makeManifest(
        minimumAppVersion: String = "2.0.0",
        totalBytes: Int64? = nil,
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
            packVersion: "test-pack",
            mapVersion: "2.0.0",
            minimumAppVersion: minimumAppVersion,
            displayName: "Test Map",
            totalBytes: totalBytes ?? Int64(files.count),
            publishedAt: Date(timeIntervalSince1970: 0),
            files: files
        )
    }
}
