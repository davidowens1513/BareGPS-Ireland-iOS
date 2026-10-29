import CryptoKit
import Foundation
import SQLite3

struct OfflineMapPackVerifier {
    enum VerificationError: LocalizedError, Equatable {
        case fileMissing(String)
        case fileSizeMismatch(path: String, expected: Int64, actual: Int64)
        case checksumMismatch(path: String)
        case invalidSQLite(path: String, message: String)

        var errorDescription: String? {
            switch self {
            case .fileMissing(let path):
                return "A map file is missing: \(path)."
            case .fileSizeMismatch(let path, let expected, let actual):
                return "The map file \(path) has \(actual) bytes; \(expected) were expected."
            case .checksumMismatch(let path):
                return "The map file \(path) did not pass its security check."
            case .invalidSQLite(let path, let message):
                return "The map file \(path) cannot be opened as a map database: \(message)"
            }
        }
    }

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func verify(manifest: OfflineMapManifest, at packRootURL: URL) throws {
        for file in manifest.files {
            let fileURL = try verifiedFileURL(relativePath: file.relativePath, under: packRootURL)

            guard fileManager.fileExists(atPath: fileURL.path) else {
                throw VerificationError.fileMissing(file.relativePath)
            }

            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            let actualSize = (attributes[.size] as? NSNumber)?.int64Value ?? -1
            guard actualSize == file.bytes else {
                throw VerificationError.fileSizeMismatch(
                    path: file.relativePath,
                    expected: file.bytes,
                    actual: actualSize
                )
            }

            let actualHash = try sha256(of: fileURL)
            guard actualHash == file.sha256.lowercased() else {
                throw VerificationError.checksumMismatch(path: file.relativePath)
            }

            try verifySQLiteDatabase(at: fileURL, relativePath: file.relativePath)
        }
    }

    private func verifiedFileURL(relativePath: String, under rootURL: URL) throws -> URL {
        let candidateURL = rootURL
            .appendingPathComponent(relativePath)
            .standardizedFileURL
        let standardizedRoot = rootURL.standardizedFileURL
        let rootPath = standardizedRoot.path.hasSuffix("/")
            ? standardizedRoot.path
            : standardizedRoot.path + "/"

        guard candidateURL.path.hasPrefix(rootPath) else {
            throw VerificationError.fileMissing(relativePath)
        }
        return candidateURL
    }

    private func sha256(of fileURL: URL) throws -> String {
        let file = try FileHandle(forReadingFrom: fileURL)
        defer {
            try? file.close()
        }

        var hasher = SHA256()
        while true {
            let data = try file.read(upToCount: 1_048_576) ?? Data()
            guard !data.isEmpty else { break }
            hasher.update(data: data)
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func verifySQLiteDatabase(at fileURL: URL, relativePath: String) throws {
        var database: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        let openResult = sqlite3_open_v2(fileURL.path, &database, flags, nil)
        guard openResult == SQLITE_OK, let database else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Open failed."
            if let database {
                sqlite3_close(database)
            }
            throw VerificationError.invalidSQLite(path: relativePath, message: message)
        }
        defer {
            sqlite3_close(database)
        }

        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(
            database,
            "PRAGMA quick_check(1);",
            -1,
            &statement,
            nil
        )
        guard prepareResult == SQLITE_OK, let quickStatement = statement else {
            let message = String(cString: sqlite3_errmsg(database))
            throw VerificationError.invalidSQLite(path: relativePath, message: message)
        }
        guard sqlite3_step(quickStatement) == SQLITE_ROW,
              let result = sqlite3_column_text(quickStatement, 0),
              String(cString: result) == "ok" else {
            let message = String(cString: sqlite3_errmsg(database))
            sqlite3_finalize(quickStatement)
            throw VerificationError.invalidSQLite(path: relativePath, message: message)
        }
        sqlite3_finalize(quickStatement)
        statement = nil

        let schemaSQL = """
        SELECT count(*) FROM sqlite_master
        WHERE type IN ('table', 'view') AND name IN ('metadata', 'tiles');
        """
        guard sqlite3_prepare_v2(database, schemaSQL, -1, &statement, nil) == SQLITE_OK,
              let schemaStatement = statement,
              sqlite3_step(schemaStatement) == SQLITE_ROW,
              sqlite3_column_int(schemaStatement, 0) == 2 else {
            sqlite3_finalize(statement)
            throw VerificationError.invalidSQLite(
                path: relativePath,
                message: "Required MBTiles tables are missing."
            )
        }
        sqlite3_finalize(schemaStatement)
        try verifyAtLeastOneTile(in: database, relativePath: relativePath)
    }

    private func verifyAtLeastOneTile(in database: OpaquePointer, relativePath: String) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT 1 FROM tiles LIMIT 1;", -1, &statement, nil) == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_ROW else {
            sqlite3_finalize(statement)
            throw VerificationError.invalidSQLite(
                path: relativePath,
                message: "The MBTiles file contains no tiles."
            )
        }
        sqlite3_finalize(statement)
    }
}
