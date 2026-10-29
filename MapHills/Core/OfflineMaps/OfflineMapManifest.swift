import Foundation

struct OfflineMapManifest: Codable, Equatable, Sendable {
    struct FileRecord: Codable, Equatable, Sendable, Identifiable {
        let sourceID: String
        let relativePath: String
        let url: URL
        let bytes: Int64
        let sha256: String

        var id: String { sourceID }
    }

    let schemaVersion: Int
    let packID: String
    let packVersion: String
    let mapVersion: String
    let minimumAppVersion: String
    let displayName: String
    let totalBytes: Int64
    let publishedAt: Date?
    let files: [FileRecord]
}

struct OfflineMapManifestValidator: Sendable {
    enum ValidationError: LocalizedError, Equatable {
        case unsupportedSchema(Int)
        case wrongPackID
        case incompatibleApp(required: String)
        case wrongFileSet
        case duplicateSourceID(String)
        case duplicatePath(String)
        case invalidPath(String)
        case invalidURL(String)
        case unapprovedHost(String)
        case invalidByteCount(String)
        case invalidHash(String)
        case totalByteMismatch
        case packTooLarge

        var errorDescription: String? {
            switch self {
            case .unsupportedSchema:
                return "This map list uses a format this app cannot read."
            case .wrongPackID:
                return "The map list is for a different map."
            case .incompatibleApp(let required):
                return "This map needs BareGPS Ireland \(required) or later."
            case .wrongFileSet:
                return "The map list does not contain the five files this app expects."
            case .duplicateSourceID(let sourceID):
                return "The map list repeats source \(sourceID)."
            case .duplicatePath(let path):
                return "The map list repeats file \(path)."
            case .invalidPath(let path):
                return "The map list contains an unsafe file path: \(path)."
            case .invalidURL(let path):
                return "The download link for \(path) is not secure."
            case .unapprovedHost(let host):
                return "The map list uses an unapproved download host: \(host)."
            case .invalidByteCount(let path):
                return "The map list has an invalid size for \(path)."
            case .invalidHash(let path):
                return "The map list has an invalid check code for \(path)."
            case .totalByteMismatch:
                return "The map list total does not match its files."
            case .packTooLarge:
                return "The map list is larger than this app allows."
            }
        }
    }

    static let expectedPackID = "ie.appsbyonzy.baregps.ireland.openbaremap"
    static let expectedFiles: [String: String] = [
        "basemap": "maps/basemap.mbtiles",
        "topography": "maps/topography.mbtiles",
        "hillshade": "maps/hillshade.mbtiles",
        "irish-grid": "maps/grid.mbtiles",
        "coast": "maps/coast.mbtiles"
    ]

    let approvedHosts: Set<String>
    let maximumPackBytes: Int64

    init(
        approvedHosts: Set<String> = ["downloads.appsbyonzy.dev"],
        maximumPackBytes: Int64 = 2_000_000_000
    ) {
        self.approvedHosts = approvedHosts
        self.maximumPackBytes = maximumPackBytes
    }

    func validate(_ manifest: OfflineMapManifest, currentAppVersion: String) throws {
        guard manifest.schemaVersion == 1 else {
            throw ValidationError.unsupportedSchema(manifest.schemaVersion)
        }
        guard manifest.packID == Self.expectedPackID else {
            throw ValidationError.wrongPackID
        }
        guard compareVersions(currentAppVersion, manifest.minimumAppVersion) != .orderedAscending else {
            throw ValidationError.incompatibleApp(required: manifest.minimumAppVersion)
        }
        guard manifest.files.count == Self.expectedFiles.count else {
            throw ValidationError.wrongFileSet
        }

        var sourceIDs = Set<String>()
        var paths = Set<String>()
        var totalBytes: Int64 = 0

        for file in manifest.files {
            guard sourceIDs.insert(file.sourceID).inserted else {
                throw ValidationError.duplicateSourceID(file.sourceID)
            }
            guard paths.insert(file.relativePath).inserted else {
                throw ValidationError.duplicatePath(file.relativePath)
            }
            guard Self.expectedFiles[file.sourceID] == file.relativePath else {
                throw ValidationError.wrongFileSet
            }
            guard isSafeRelativePath(file.relativePath) else {
                throw ValidationError.invalidPath(file.relativePath)
            }
            guard file.url.scheme?.lowercased() == "https", let host = file.url.host?.lowercased() else {
                throw ValidationError.invalidURL(file.relativePath)
            }
            guard approvedHosts.contains(host) else {
                throw ValidationError.unapprovedHost(host)
            }
            guard file.bytes > 0, file.bytes <= maximumPackBytes else {
                throw ValidationError.invalidByteCount(file.relativePath)
            }
            guard file.sha256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
                throw ValidationError.invalidHash(file.relativePath)
            }
            let (sum, overflow) = totalBytes.addingReportingOverflow(file.bytes)
            guard !overflow else {
                throw ValidationError.packTooLarge
            }
            totalBytes = sum
        }

        guard Set(sourceIDs) == Set(Self.expectedFiles.keys) else {
            throw ValidationError.wrongFileSet
        }
        guard totalBytes == manifest.totalBytes else {
            throw ValidationError.totalByteMismatch
        }
        guard totalBytes <= maximumPackBytes else {
            throw ValidationError.packTooLarge
        }
    }

    private func isSafeRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !path.hasPrefix("~"),
              !path.contains("\\"),
              URL(fileURLWithPath: path).pathComponents.allSatisfy({ $0 != ".." && $0 != "." }) else {
            return false
        }
        return path.split(separator: "/").allSatisfy { !$0.isEmpty }
    }

    private func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(left.count, right.count)

        for index in 0..<count {
            let leftValue = index < left.count ? left[index] : 0
            let rightValue = index < right.count ? right[index] : 0
            if leftValue < rightValue { return .orderedAscending }
            if leftValue > rightValue { return .orderedDescending }
        }
        return .orderedSame
    }
}

enum OfflineMapConfiguration {
    static let manifestURL = URL(
        string: "https://downloads.appsbyonzy.dev/baregps-ireland/manifest-v1.json"
    )!
    static let backgroundSessionIdentifier = "com.DavidOwens1513.BareGPSIreland.offline-map-download"
}
