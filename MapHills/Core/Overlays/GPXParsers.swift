import CoreLocation
import Foundation

final class GPXParserDelegate: NSObject, XMLParserDelegate {
    private(set) var waypoints: [GPXWaypoint] = []
    private(set) var trackSegments: [[CLLocationCoordinate2D]] = []
    private(set) var skippedWaypointCount = 0
    private(set) var skippedTrackPointCount = 0
    private(set) var skippedSegmentCount = 0
    private(set) var encounteredGPXContent = false

    private var currentWaypointCoordinate: CLLocationCoordinate2D?
    private var currentWaypointName: String?
    private var currentTrackSegment: [CLLocationCoordinate2D] = []
    private var currentTrackSegmentHadPoints = false
    private var currentElementText = ""
    private var isReadingWaypointName = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String : String] = [:]
    ) {
        switch elementName {
        case "wpt":
            encounteredGPXContent = true
            currentWaypointCoordinate = coordinate(from: attributeDict)
            currentWaypointName = nil
        case "trkseg", "rte":
            encounteredGPXContent = true
            currentTrackSegment = []
            currentTrackSegmentHadPoints = false
        case "trkpt", "rtept":
            encounteredGPXContent = true
            currentTrackSegmentHadPoints = true
            if let coordinate = coordinate(from: attributeDict) {
                currentTrackSegment.append(coordinate)
            } else {
                skippedTrackPointCount += 1
            }
        case "name":
            if currentWaypointCoordinate != nil {
                isReadingWaypointName = true
                currentElementText = ""
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isReadingWaypointName else { return }
        currentElementText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        // GPX files may contain waypoints and multiple track segments. We collect only
        // complete waypoint records and polyline-worthy segments here, leaving styling to the map layer.
        switch elementName {
        case "name":
            guard isReadingWaypointName else { return }
            let trimmed = currentElementText.trimmingCharacters(in: .whitespacesAndNewlines)
            currentWaypointName = trimmed.isEmpty ? nil : trimmed
            isReadingWaypointName = false
            currentElementText = ""
        case "wpt":
            guard let coordinate = currentWaypointCoordinate else {
                skippedWaypointCount += 1
                currentWaypointName = nil
                return
            }
            let waypoint = GPXWaypoint(
                name: currentWaypointName ?? "Waypoint",
                coordinate: coordinate
            )
            waypoints.append(waypoint)
            currentWaypointCoordinate = nil
            currentWaypointName = nil
        case "trkseg", "rte":
            if currentTrackSegment.count > 1 {
                trackSegments.append(currentTrackSegment)
            } else if currentTrackSegmentHadPoints {
                skippedSegmentCount += 1
            }
            currentTrackSegment = []
            currentTrackSegmentHadPoints = false
        default:
            break
        }
    }

    private func coordinate(from attributes: [String: String]) -> CLLocationCoordinate2D? {
        guard
            let latitudeString = attributes["lat"],
            let longitudeString = attributes["lon"],
            let latitude = Double(latitudeString),
            let longitude = Double(longitudeString)
        else {
            return nil
        }

        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
    }
}

final class GPXTrackSummaryParserDelegate: NSObject, XMLParserDelegate {
    private(set) var trackPoints: [RecordedTrackPoint] = []

    private var currentCoordinate: CLLocationCoordinate2D?
    private var currentAltitude: Double?
    private var currentTimestamp: Date?
    private var currentElementText = ""
    private var isReadingElevation = false
    private var isReadingTime = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String : String] = [:]
    ) {
        switch elementName {
        case "trkpt", "rtept":
            currentCoordinate = coordinate(from: attributeDict)
            currentAltitude = nil
            currentTimestamp = nil
        case "ele":
            isReadingElevation = true
            currentElementText = ""
        case "time":
            isReadingTime = true
            currentElementText = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isReadingElevation || isReadingTime else { return }
        currentElementText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        // Saved GPX summaries are rebuilt from the file itself so saved-track metadata
        // stays correct even if the app is relaunched or files are renamed externally.
        switch elementName {
        case "ele":
            if isReadingElevation {
                currentAltitude = Double(currentElementText.trimmingCharacters(in: .whitespacesAndNewlines))
                isReadingElevation = false
                currentElementText = ""
            }
        case "time":
            if isReadingTime {
                currentTimestamp = ISO8601DateFormatter().date(from: currentElementText.trimmingCharacters(in: .whitespacesAndNewlines))
                isReadingTime = false
                currentElementText = ""
            }
        case "trkpt", "rtept":
            guard let currentCoordinate else { return }
            trackPoints.append(
                RecordedTrackPoint(
                    latitude: currentCoordinate.latitude,
                    longitude: currentCoordinate.longitude,
                    altitude: currentAltitude,
                    timestamp: currentTimestamp ?? Date.distantPast
                )
            )
            self.currentCoordinate = nil
            currentAltitude = nil
            currentTimestamp = nil
        default:
            break
        }
    }

    private func coordinate(from attributes: [String: String]) -> CLLocationCoordinate2D? {
        guard
            let latitudeString = attributes["lat"],
            let longitudeString = attributes["lon"],
            let latitude = Double(latitudeString),
            let longitude = Double(longitudeString)
        else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
