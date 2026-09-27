import CoreLocation
import Foundation

enum MapDataLoader {
    // The bundled Outscape files are app-facing curated data; keep this guard so raw imports dropped in during review are filtered back to the release subset.
    private static let usesCuratedOutscapeTrailSubset = true
    private static let curatedOutscapeMinimumLengthKilometers = 2.0
    private static let curatedOutscapeNamePattern = #"\b(walk|trail|loop|way|greenway|towpath)\b"#

    private struct DataCoordinate: Codable {
        let latitude: Double
        let longitude: Double

        var locationCoordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    private struct CoillteTrailSummaryData: Codable {
        let name: String
        let lengthMeters: Double?
        let ascentMeters: Double?
        let coordinateSegments: [[DataCoordinate]]
        let startCoordinate: DataCoordinate
        let finishCoordinate: DataCoordinate

        var trailSummary: CoillteTrailSummary {
            CoillteTrailSummary(
                name: name,
                lengthMeters: lengthMeters,
                ascentMeters: ascentMeters,
                coordinateSegments: coordinateSegments.map { $0.map(\.locationCoordinate) },
                startCoordinate: startCoordinate.locationCoordinate,
                finishCoordinate: finishCoordinate.locationCoordinate
            )
        }
    }

    private struct SportIrelandTrailSummaryData: Codable {
        let name: String
        let lengthMeters: Double?
        let ascentMeters: Double?
        let coordinateSegments: [[DataCoordinate]]

        func trailSummary(trailID: String) -> SportIrelandTrailSummary {
            SportIrelandTrailSummary(
                trailID: trailID,
                name: name,
                lengthMeters: lengthMeters,
                ascentMeters: ascentMeters,
                coordinateSegments: coordinateSegments.map { $0.map(\.locationCoordinate) }
            )
        }
    }

    private struct OutscapeTrailSummaryData: Codable {
        let name: String
        let lengthMeters: Double?
        let ascentMeters: Double?
        let coordinateSegments: [[DataCoordinate]]

        func trailSummary(trailID: String) -> OutscapeTrailSummary {
            OutscapeTrailSummary(
                trailID: trailID,
                name: name,
                lengthMeters: lengthMeters,
                ascentMeters: ascentMeters,
                coordinateSegments: coordinateSegments.map { $0.map(\.locationCoordinate) }
            )
        }
    }

    static func loadPeaksFromJSON(resourceName: String) -> [Peak] {
        loadJSONResource(resourceName: resourceName, as: [Peak].self) ?? []
    }

    static func loadStartPlacesFromJSON(resourceName: String) -> [StartPlace] {
        loadJSONResource(resourceName: resourceName, as: [StartPlace].self) ?? []
    }

    static func loadCoillteTrailSummaries() -> [CoillteTrailSummary] {
        loadJSONResource(resourceName: "CoillteTrailSummaries", as: [CoillteTrailSummaryData].self)?
            .map(\.trailSummary) ?? []
    }

    static func loadSportIrelandTrailSummariesByTrailID() -> [String: SportIrelandTrailSummary] {
        guard let summaries = loadJSONResource(resourceName: "SportIrelandTrailSummaries", as: [String: SportIrelandTrailSummaryData].self) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: summaries.map { trailID, trailData in
            (trailID, trailData.trailSummary(trailID: trailID))
        })
    }

    static func loadOutscapeDerivedTrailStartPlaces() -> [StartPlace] {
        loadStartPlacesFromJSON(resourceName: "OutscapeTrailStartPoints")
    }

    static func loadOutscapeTrailSummariesByTrailID() -> [String: OutscapeTrailSummary] {
        guard let summaries = loadJSONResource(resourceName: "OutscapeTrailSummaries", as: [String: OutscapeTrailSummaryData].self) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: summaries.map { trailID, trailData in
            (trailID, trailData.trailSummary(trailID: trailID))
        })
    }

    static func loadSportIrelandTrailIDByStartPlaceID() -> [String: String] {
        loadJSONResource(resourceName: "SportIrelandTrailIDByStartPlaceID", as: [String: String].self) ?? [:]
    }

    private static func loadJSONResource<T: Decodable>(resourceName: String, as type: T.Type) -> T? {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json") else {
            print("Missing \(resourceName).json in app bundle")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("Failed to load \(resourceName).json: \(error.localizedDescription)")
            return nil
        }
    }

    static func loadIrelandPlacenames() -> [IrelandPlacename] {
        let populationCentresURL = Bundle.main.url(forResource: "CentresOfPopulationPlacenames", withExtension: "csv")

        let populationCentres = loadIrelandPlacenames(from: populationCentresURL, kind: .populationCentre)

        return deduplicatedIrelandPlacenames(populationCentres)
    }

    private static func loadIrelandPlacenames(from url: URL?, kind: IrelandPlacename.Kind) -> [IrelandPlacename] {
        guard let url else { return [] }

        do {
            let csvData = try Data(contentsOf: url)
            guard let csvString = String(data: csvData, encoding: .utf8) else {
                print("Failed to decode Ireland placenames CSV for \(kind.title)")
                return []
            }

            let lines = csvString
                .components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

            guard let headerLine = lines.first else {
                return []
            }

            let normalizedHeader = parseCSVColumns(from: headerLine).map(normalizedCSVHeader)
            let headerIndexes = Dictionary(uniqueKeysWithValues: normalizedHeader.enumerated().map { ($1, $0) })

            func firstHeaderIndex(_ names: [String]) -> Int? {
                names.compactMap { headerIndexes[$0] }.first
            }

            guard
                let countyIndex = firstHeaderIndex(["county"]) ?? firstHeaderIndex(["contae"]),
                let englishNameIndex = firstHeaderIndex(["englishna"]) ?? firstHeaderIndex(["english_name"]) ?? firstHeaderIndex(["englishname"]),
                let irishNameIndex = firstHeaderIndex(["irishname"]) ?? firstHeaderIndex(["irish_name"])
            else {
                print("Unexpected Ireland placenames CSV header for \(kind.title): \(normalizedHeader)")
                return []
            }

            let classificationIndex = firstHeaderIndex(["classifica"]) ?? firstHeaderIndex(["classification"]) ?? firstHeaderIndex(["town_class"])
            let latitudeIndex = firstHeaderIndex(["latitude"])
            let longitudeIndex = firstHeaderIndex(["longitude"])
            let itmEastingIndex = firstHeaderIndex(["x"])
            let itmNorthingIndex = firstHeaderIndex(["y"])

            return lines.dropFirst().compactMap { line in
                let parts = parseCSVColumns(from: line)
                guard parts.count == normalizedHeader.count else { return nil }

                let county = parts[countyIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                let englishName = parts[englishNameIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                let irishName = parts[irishNameIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                let classification = classificationIndex.map {
                    parts[$0].trimmingCharacters(in: .whitespacesAndNewlines)
                } ?? ""
                let latitude = latitudeIndex.flatMap { Double(parts[$0].trimmingCharacters(in: .whitespacesAndNewlines)) }
                let longitude = longitudeIndex.flatMap { Double(parts[$0].trimmingCharacters(in: .whitespacesAndNewlines)) }
                let itmEasting = itmEastingIndex.flatMap { Double(parts[$0].trimmingCharacters(in: .whitespacesAndNewlines)) }
                let itmNorthing = itmNorthingIndex.flatMap { Double(parts[$0].trimmingCharacters(in: .whitespacesAndNewlines)) }
                return IrelandPlacename(
                    name: englishName.isEmpty ? irishName : englishName,
                    irishName: irishName,
                    county: county,
                    classification: classification,
                    kind: kind,
                    latitude: latitude,
                    longitude: longitude,
                    itmEasting: itmEasting,
                    itmNorthing: itmNorthing,
                    searchableText: [
                        englishName.isEmpty ? irishName : englishName,
                        irishName,
                        county,
                        classification,
                        kind.title
                    ]
                    .joined(separator: " ")
                    .localizedLowercase
                )
            }
        } catch {
            print("Failed to load Ireland placenames CSV for \(kind.title): \(error.localizedDescription)")
            return []
        }
    }

    private static func deduplicatedIrelandPlacenames(_ placenames: [IrelandPlacename]) -> [IrelandPlacename] {
        var seenKeys = Set<String>()
        return placenames.filter { placename in
            let key = [
                placename.name.localizedLowercase,
                placename.county.localizedLowercase,
                placename.kind.title.localizedLowercase
            ].joined(separator: "|")
            if seenKeys.contains(key) {
                return false
            }
            seenKeys.insert(key)
            return true
        }
    }

    private static func outscapeFeaturePassesCuratedSubset(_ properties: [String: Any]) -> Bool {
        guard usesCuratedOutscapeTrailSubset else { return true }

        guard
            let lengthKilometers = doubleValue(from: properties["Length"]),
            lengthKilometers >= curatedOutscapeMinimumLengthKilometers
        else {
            return false
        }

        let name = stringValue(from: properties["Name"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.range(
            of: curatedOutscapeNamePattern,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static func trailCoordinateSegments(from geometry: [String: Any]) -> [[CLLocationCoordinate2D]]? {
        guard let type = geometry["type"] as? String else { return nil }

        switch type {
        case "LineString":
            guard let coordinates = geometry["coordinates"] as? [[Double]] else { return nil }
            let segment = coordinates.compactMap(coordinate(fromGeoJSONPosition:))
            return segment.count > 1 ? [segment] : nil

        case "MultiLineString":
            guard let coordinateGroups = geometry["coordinates"] as? [[[Double]]] else { return nil }
            let segments = coordinateGroups
                .map { $0.compactMap(coordinate(fromGeoJSONPosition:)) }
                .filter { $0.count > 1 }
            return segments.isEmpty ? nil : segments

        default:
            return nil
        }
    }

    private static func pointCoordinate(from geometry: [String: Any]) -> CLLocationCoordinate2D? {
        guard
            let type = geometry["type"] as? String,
            type == "Point",
            let position = geometry["coordinates"] as? [Double]
        else {
            return nil
        }
        return coordinate(fromGeoJSONPosition: position)
    }

    private static func coordinate(fromGeoJSONPosition position: [Double]) -> CLLocationCoordinate2D? {
        guard position.count >= 2 else { return nil }
        let coordinate = CLLocationCoordinate2D(latitude: position[1], longitude: position[0])
        return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
    }

    private static func stringValue(from value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    private static func doubleValue(from value: Any?) -> Double? {
        switch value {
        case let double as Double:
            return double
        case let int as Int:
            return Double(int)
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }

    private static func parseCSVColumns(from line: String) -> [String] {
        var columns: [String] = []
        var currentColumn = ""
        var isInsideQuotes = false

        let characters = Array(line)
        var index = 0

        while index < characters.count {
            let character = characters[index]

            if character == "\"" {
                if isInsideQuotes, index + 1 < characters.count, characters[index + 1] == "\"" {
                    currentColumn.append("\"")
                    index += 1
                } else {
                    isInsideQuotes.toggle()
                }
            } else if character == "," && !isInsideQuotes {
                columns.append(currentColumn)
                currentColumn = ""
            } else {
                currentColumn.append(character)
            }

            index += 1
        }

        columns.append(currentColumn)
        return columns
    }

    private static func normalizedCSVHeader(_ header: String) -> String {
        let trimmedHeader = header
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\u{feff}"))
            .lowercased()

        return trimmedHeader.filter { $0.isLetter || $0.isNumber }
    }
}
