import CoreLocation
import Foundation

enum MapDataLoader {
    // The bundled Outscape files are app-facing curated data; keep this guard so raw imports dropped in during review are filtered back to the release subset.
    private static let usesCuratedOutscapeTrailSubset = true
    private static let curatedOutscapeMinimumLengthKilometers = 2.0
    private static let curatedOutscapeNamePattern = #"\b(walk|trail|loop|way|greenway|towpath)\b"#

    static func loadPeaksFromCSV(resourceName: String) -> [Peak] {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "csv") else {
            print("Missing \(resourceName).csv in app bundle")
            return []
        }

        do {
            let csvString = try String(contentsOf: url, encoding: .utf8)
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
                firstHeaderIndex(["hillname", "placenameen"]) != nil,
                firstHeaderIndex(["latitude"]) != nil,
                firstHeaderIndex(["longitude"]) != nil,
                firstHeaderIndex(["metres", "height"]) != nil,
                firstHeaderIndex(["prominence", "drop"]) != nil,
                firstHeaderIndex(["classification", "province"]) != nil
            else {
                print("Unexpected CSV header: \(normalizedHeader)")
                return []
            }

            let dataLines = lines.dropFirst()

            return dataLines.compactMap { line -> Peak? in
                let parts = parseCSVColumns(from: line)

                guard parts.count == normalizedHeader.count else {
                    return nil
                }

                guard
                    let nameIndex = firstHeaderIndex(["hillname", "placenameen"]),
                    let latitudeIndex = firstHeaderIndex(["latitude"]),
                    let longitudeIndex = firstHeaderIndex(["longitude"]),
                    let heightIndex = firstHeaderIndex(["metres", "height"]),
                    let prominenceIndex = firstHeaderIndex(["prominence", "drop"]),
                    let classificationIndex = firstHeaderIndex(["classification", "province"])
                else {
                    return nil
                }

                let name = parts[nameIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                let mvIndex = firstHeaderIndex(["mvindex"]).map {
                    parts[$0].trimmingCharacters(in: .whitespacesAndNewlines)
                } ?? ""
                let latitudeString = parts[latitudeIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                let longitudeString = parts[longitudeIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                let heightString = parts[heightIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                let prominenceString = parts[prominenceIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                let classification = parts[classificationIndex]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                let administrativeAreaName = firstHeaderIndex(["countyies", "countiesin"]).map {
                    parts[$0].trimmingCharacters(in: .whitespacesAndNewlines)
                } ?? ""
                let rangeName = firstHeaderIndex(["range", "region", "subrange"]).map {
                    parts[$0].trimmingCharacters(in: .whitespacesAndNewlines)
                } ?? ""
                let regionalSubdivisionName = firstHeaderIndex(["province"]).map {
                    parts[$0].trimmingCharacters(in: .whitespacesAndNewlines)
                } ?? ""
                let alternateHillName = firstHeaderIndex(["althillname", "placenamega"]).map {
                    parts[$0].trimmingCharacters(in: .whitespacesAndNewlines)
                } ?? ""
                let highpointAreaNames = firstHeaderIndex(["chpof"]).map {
                    parts[$0].trimmingCharacters(in: .whitespacesAndNewlines)
                } ?? ""
                let projectedEastingMeters = firstHeaderIndex(["easting"]).flatMap {
                    Double(parts[$0].trimmingCharacters(in: .whitespacesAndNewlines))
                }
                let projectedNorthingMeters = firstHeaderIndex(["northing"]).flatMap {
                    Double(parts[$0].trimmingCharacters(in: .whitespacesAndNewlines))
                }

                guard
                    let latitude = Double(latitudeString),
                    let longitude = Double(longitudeString),
                    let heightM = Double(heightString),
                    let prominenceM = Double(prominenceString)
                else {
                    return nil
                }

                return Peak(
                    name: name,
                    mvIndex: mvIndex,
                    latitude: latitude,
                    longitude: longitude,
                    heightM: heightM,
                    prominenceM: prominenceM,
                    classification: classification,
                    administrativeAreaName: administrativeAreaName,
                    rangeName: rangeName,
                    regionalSubdivisionName: regionalSubdivisionName,
                    alternateHillName: alternateHillName,
                    highpointAreaNames: highpointAreaNames,
                    projectedEastingMeters: projectedEastingMeters,
                    projectedNorthingMeters: projectedNorthingMeters
                )
            }
        } catch {
            print("Failed to load CSV: \(error.localizedDescription)")
            return []
        }
    }

    static func loadStartPlacesFromCSV(resourceName: String, provider: StartPlaceProvider) -> [StartPlace] {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "csv") else {
            print("Missing \(resourceName).csv in app bundle")
            return []
        }

        do {
            let csvString = try String(contentsOf: url, encoding: .utf8)
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
                firstHeaderIndex(["startnumber"]) != nil,
                firstHeaderIndex(["nameonmap"]) != nil,
                firstHeaderIndex(["longitude"]) != nil,
                firstHeaderIndex(["latitude"])
                    != nil
            else {
                print("Unexpected start-place CSV header: \(normalizedHeader)")
                return []
            }

            let dataLines = lines.dropFirst()

            return dataLines.compactMap { line in
                let parts = parseCSVColumns(from: line)
                guard parts.count == normalizedHeader.count else { return nil }
                guard
                    let startNumberIndex = firstHeaderIndex(["startnumber"]),
                    let nameOnMapIndex = firstHeaderIndex(["nameonmap"]),
                    let latitudeIndex = firstHeaderIndex(["latitude"]),
                    let longitudeIndex = firstHeaderIndex(["longitude"])
                else {
                    return nil
                }

                let startNumber = parts[startNumberIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                let nameOnMap = parts[nameOnMapIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                let longName = firstHeaderIndex(["longname"]).map {
                    parts[$0].trimmingCharacters(in: .whitespacesAndNewlines)
                } ?? ""
                let gridReference = firstHeaderIndex(["gridref"]).map {
                    parts[$0].trimmingCharacters(in: .whitespacesAndNewlines)
                } ?? ""
                let status = firstHeaderIndex(["status"]).map {
                    parts[$0].trimmingCharacters(in: .whitespacesAndNewlines)
                } ?? ""
                let parking = firstHeaderIndex(["parking"]).map {
                    parts[$0].trimmingCharacters(in: .whitespacesAndNewlines)
                } ?? ""
                let nearbyHills = firstHeaderIndex(["nearbyhills"]).map {
                    parts[$0].trimmingCharacters(in: .whitespacesAndNewlines)
                } ?? ""

                guard
                    let latitude = Double(parts[latitudeIndex].trimmingCharacters(in: .whitespacesAndNewlines)),
                    let longitude = Double(parts[longitudeIndex].trimmingCharacters(in: .whitespacesAndNewlines))
                else {
                    return nil
                }

                let heightM = firstHeaderIndex(["heightm"]).flatMap {
                    Double(parts[$0].trimmingCharacters(in: .whitespacesAndNewlines))
                }

                return StartPlace(
                    startNumber: startNumber,
                    nameOnMap: nameOnMap,
                    longName: longName,
                    gridReference: gridReference,
                    latitude: latitude,
                    longitude: longitude,
                    heightM: heightM,
                    provider: provider,
                    status: status,
                    parking: parking,
                    nearbyHills: nearbyHills
                )
            }
        } catch {
            print("Failed to load start places CSV: \(error.localizedDescription)")
            return []
        }
    }

    static func loadCoillteTrailSummaries() -> [CoillteTrailSummary] {
        guard let url = Bundle.main.url(forResource: "CoillteTrails", withExtension: "geojson") else {
            print("Missing CoillteTrails.geojson in app bundle")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            guard
                let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let features = object["features"] as? [[String: Any]]
            else {
                print("Unexpected CoillteTrails.geojson structure")
                return []
            }

            return features.compactMap { feature in
                guard
                    let properties = feature["properties"] as? [String: Any],
                    let geometry = feature["geometry"] as? [String: Any],
                    let coordinateSegments = trailCoordinateSegments(from: geometry),
                    let firstSegment = coordinateSegments.first,
                    let lastSegment = coordinateSegments.last,
                    let startCoordinate = firstSegment.first,
                    let finishCoordinate = lastSegment.last
                else {
                    return nil
                }

                let name = stringValue(from: properties["NAME"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let lengthMeters = doubleValue(from: properties["LENGTH"]) ?? doubleValue(from: properties["Shape_STLe"])

                return CoillteTrailSummary(
                    name: name.isEmpty ? "Coillte Walk" : name,
                    lengthMeters: lengthMeters,
                    ascentMeters: nil,
                    coordinateSegments: coordinateSegments,
                    startCoordinate: startCoordinate,
                    finishCoordinate: finishCoordinate
                )
            }
        } catch {
            print("Failed to load CoillteTrails.geojson: \(error.localizedDescription)")
            return []
        }
    }

    static func loadSportIrelandTrailSummariesByTrailID() -> [String: SportIrelandTrailSummary] {
        guard let url = Bundle.main.url(forResource: "SportIrelandTrails", withExtension: "geojson") else {
            print("Missing SportIrelandTrails.geojson in app bundle")
            return [:]
        }

        do {
            let data = try Data(contentsOf: url)
            guard
                let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let features = object["features"] as? [[String: Any]]
            else {
                print("Unexpected SportIrelandTrails.geojson structure")
                return [:]
            }

            let summaries = features.compactMap { feature -> SportIrelandTrailSummary? in
                guard
                    let properties = feature["properties"] as? [String: Any],
                    let geometry = feature["geometry"] as? [String: Any],
                    let coordinateSegments = trailCoordinateSegments(from: geometry),
                    let trailIDValue = properties["TrailID"],
                    let trailID = stringValue(from: trailIDValue)?.trimmingCharacters(in: .whitespacesAndNewlines),
                    !trailID.isEmpty
                else {
                    return nil
                }

                let name = stringValue(from: properties["Name"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let lengthKilometers = doubleValue(from: properties["LengthKm"])
                let ascentMeters = doubleValue(from: properties["AscentMetres"])
                return SportIrelandTrailSummary(
                    trailID: trailID,
                    name: name.isEmpty ? "Sport Ireland Trail" : name,
                    lengthMeters: lengthKilometers.map { $0 * 1000 },
                    ascentMeters: ascentMeters,
                    coordinateSegments: coordinateSegments
                )
            }

            return Dictionary(uniqueKeysWithValues: summaries.map { ($0.trailID, $0) })
        } catch {
            print("Failed to load SportIrelandTrails.geojson: \(error.localizedDescription)")
            return [:]
        }
    }

    static func loadOutscapeDerivedTrailStartPlaces() -> [StartPlace] {
        guard let url = Bundle.main.url(forResource: "OutscapeDerivedTrailStartPoints", withExtension: "geojson") else {
            print("Missing OutscapeDerivedTrailStartPoints.geojson in app bundle")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            guard
                let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let features = object["features"] as? [[String: Any]]
            else {
                print("Unexpected OutscapeDerivedTrailStartPoints.geojson structure")
                return []
            }

            return features.compactMap { feature in
                guard
                    let properties = feature["properties"] as? [String: Any],
                    let geometry = feature["geometry"] as? [String: Any],
                    outscapeFeaturePassesCuratedSubset(properties),
                    let coordinate = pointCoordinate(from: geometry),
                    let fid = stringValue(from: properties["FID"])?.trimmingCharacters(in: .whitespacesAndNewlines),
                    !fid.isEmpty
                else {
                    return nil
                }

                let name = stringValue(from: properties["Name"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let type = stringValue(from: properties["Type"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let usage = stringValue(from: properties["Trail_Useage"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let detail = [type, usage]
                    .filter { !$0.isEmpty }
                    .joined(separator: " • ")
                let gridReference = irishGridEastingNorthing(for: coordinate).flatMap {
                    ActiveRegion.current.gridReference(easting: $0.easting, northing: $0.northing)
                } ?? ""

                return StartPlace(
                    startNumber: "outscape-\(fid)",
                    nameOnMap: name.isEmpty ? "Outscape Trail" : name,
                    longName: name.isEmpty ? "Outscape Trail" : name,
                    gridReference: gridReference,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    heightM: nil,
                    provider: .outscape,
                    status: "Derived trail start candidate",
                    parking: "",
                    nearbyHills: detail
                )
            }
        } catch {
            print("Failed to load OutscapeDerivedTrailStartPoints.geojson: \(error.localizedDescription)")
            return []
        }
    }

    static func loadOutscapeTrailSummariesByTrailID() -> [String: OutscapeTrailSummary] {
        guard let url = Bundle.main.url(forResource: "OutscapeOffRoadTrails", withExtension: "geojson") else {
            print("Missing OutscapeOffRoadTrails.geojson in app bundle")
            return [:]
        }

        do {
            let data = try Data(contentsOf: url)
            guard
                let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let features = object["features"] as? [[String: Any]]
            else {
                print("Unexpected OutscapeOffRoadTrails.geojson structure")
                return [:]
            }

            let summaries = features.compactMap { feature -> OutscapeTrailSummary? in
                guard
                    let properties = feature["properties"] as? [String: Any],
                    let geometry = feature["geometry"] as? [String: Any],
                    outscapeFeaturePassesCuratedSubset(properties),
                    let coordinateSegments = trailCoordinateSegments(from: geometry),
                    let fid = stringValue(from: properties["FID"])?.trimmingCharacters(in: .whitespacesAndNewlines),
                    !fid.isEmpty
                else {
                    return nil
                }

                let name = stringValue(from: properties["Name"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let lengthKilometers = doubleValue(from: properties["Length"])
                return OutscapeTrailSummary(
                    trailID: "outscape-\(fid)",
                    name: name.isEmpty ? "Outscape Trail" : name,
                    lengthMeters: lengthKilometers.map { $0 * 1000 },
                    ascentMeters: nil,
                    coordinateSegments: coordinateSegments
                )
            }

            return Dictionary(uniqueKeysWithValues: summaries.map { ($0.trailID, $0) })
        } catch {
            print("Failed to load OutscapeOffRoadTrails.geojson: \(error.localizedDescription)")
            return [:]
        }
    }

    static func loadSportIrelandTrailIDByStartPlaceID() -> [String: String] {
        guard let url = Bundle.main.url(forResource: "SportIrelandTrailheads", withExtension: "csv") else {
            print("Missing SportIrelandTrailheads.csv in app bundle")
            return [:]
        }

        do {
            let csvString = try String(contentsOf: url, encoding: .utf8)
            let lines = csvString
                .components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            guard let headerLine = lines.first else { return [:] }

            let normalizedHeader = parseCSVColumns(from: headerLine).map(normalizedCSVHeader)
            let headerIndexes = Dictionary(uniqueKeysWithValues: normalizedHeader.enumerated().map { ($1, $0) })
            guard
                let sourceObjectIDIndex = headerIndexes["sourceobjectid"],
                let trailIDIndex = headerIndexes["trailid"]
            else {
                print("Unexpected SportIrelandTrailheads.csv header: \(normalizedHeader)")
                return [:]
            }

            var mapping: [String: String] = [:]
            for line in lines.dropFirst() {
                let parts = parseCSVColumns(from: line)
                guard parts.count == normalizedHeader.count else { continue }
                let sourceObjectID = parts[sourceObjectIDIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                let trailID = parts[trailIDIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !sourceObjectID.isEmpty, !trailID.isEmpty else { continue }
                mapping["sportireland-\(sourceObjectID)"] = trailID
            }
            return mapping
        } catch {
            print("Failed to load SportIrelandTrailheads.csv: \(error.localizedDescription)")
            return [:]
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
