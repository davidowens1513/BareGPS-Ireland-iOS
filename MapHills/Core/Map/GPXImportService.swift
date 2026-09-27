import Foundation

enum GPXImportServiceError: LocalizedError {
    case fileOpenFailed
    case parseFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileOpenFailed:
            return "The selected file could not be opened."
        case .parseFailed(let message):
            return message
        }
    }
}

struct GPXImportService {
    func importGPX(from fileURL: URL) throws -> GPXImport {
        let parserDelegate = GPXParserDelegate()
        let needsScopedAccess = fileURL.startAccessingSecurityScopedResource()

        defer {
            if needsScopedAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let xmlParser = XMLParser(contentsOf: fileURL) else {
            throw GPXImportServiceError.fileOpenFailed
        }

        xmlParser.delegate = parserDelegate

        guard xmlParser.parse() else {
            let message = xmlParser.parserError?.localizedDescription ?? "The GPX file could not be parsed."
            throw GPXImportServiceError.parseFailed(message)
        }

        return GPXImport(
            waypoints: parserDelegate.waypoints,
            trackSegments: parserDelegate.trackSegments,
            skippedWaypointCount: parserDelegate.skippedWaypointCount,
            skippedTrackPointCount: parserDelegate.skippedTrackPointCount,
            skippedSegmentCount: parserDelegate.skippedSegmentCount,
            encounteredGPXContent: parserDelegate.encounteredGPXContent
        )
    }
}
