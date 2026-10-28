//
//  PeakModels.swift
//  MapHills
//
//  Created by Codex on 07/07/2026.
//

import Foundation
import CoreLocation
import MapLibre
import UIKit

struct Peak: Codable {
    let name: String
    let mvIndex: String
    let latitude: Double
    let longitude: Double
    let heightM: Double
    let prominenceM: Double
    let classification: String
    let administrativeAreaName: String
    let rangeName: String
    let regionalSubdivisionName: String
    let alternateHillName: String
    let highpointAreaNames: String
    let projectedEastingMeters: Double?
    let projectedNorthingMeters: Double?

    init(
        name: String,
        mvIndex: String = "",
        latitude: Double,
        longitude: Double,
        heightM: Double,
        prominenceM: Double,
        classification: String,
        administrativeAreaName: String,
        rangeName: String,
        regionalSubdivisionName: String = "",
        alternateHillName: String,
        highpointAreaNames: String = "",
        projectedEastingMeters: Double? = nil,
        projectedNorthingMeters: Double? = nil
    ) {
        self.name = name
        self.mvIndex = mvIndex
        self.latitude = latitude
        self.longitude = longitude
        self.heightM = heightM
        self.prominenceM = prominenceM
        self.classification = classification
        self.administrativeAreaName = administrativeAreaName
        self.rangeName = rangeName
        self.regionalSubdivisionName = regionalSubdivisionName
        self.alternateHillName = alternateHillName
        self.highpointAreaNames = highpointAreaNames
        self.projectedEastingMeters = projectedEastingMeters
        self.projectedNorthingMeters = projectedNorthingMeters
    }

    var id: String {
        mvIndex.isEmpty ? name : mvIndex
    }

    var legacyID: String {
        id
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var countyHighpointOf: String {
        highpointAreaNames
    }

    var administrativeArea: String {
        administrativeAreaName
    }

    var regionGroup: String {
        regionalSubdivisionName
    }

    var province: String {
        administrativeAreaName
    }

    var highpointAreas: String {
        highpointAreaNames
    }

    var formattedRegionGridReference: String? {
        GridCoordinateFormatter.format(
            coordinate: coordinate,
            projectedEastingMeters: projectedEastingMeters,
            projectedNorthingMeters: projectedNorthingMeters,
            system: .irishGrid
        )
    }

    var eastingM: Double? {
        projectedEastingMeters
    }

    var northingM: Double? {
        projectedNorthingMeters
    }
}

enum StartPlaceProvider: String, CaseIterable, Codable {
    case mountainViews
    case sportIreland
    case coillte
    case outscape

    var title: String {
        switch self {
        case .mountainViews:
            return "MountainViews"
        case .sportIreland:
            return "Sport Ireland"
        case .coillte:
            return "Coillte"
        case .outscape:
            return "Outscape NI"
        }
    }
}

enum StartPlaceRouteLengthFilter: Int, CaseIterable {
    case off
    case minimum1000
    case minimum2000
    case minimum3000
    case minimum5000

    var title: String {
        switch self {
        case .off:
            return "Off"
        case .minimum1000:
            return "1 km"
        case .minimum2000:
            return "2 km"
        case .minimum3000:
            return "3 km"
        case .minimum5000:
            return "5 km"
        }
    }

    var minimumLengthMeters: Double? {
        switch self {
        case .off:
            return nil
        case .minimum1000:
            return 1_000
        case .minimum2000:
            return 2_000
        case .minimum3000:
            return 3_000
        case .minimum5000:
            return 5_000
        }
    }
}

struct StartPlace: Codable {
    let startNumber: String
    let nameOnMap: String
    let longName: String
    let gridReference: String
    let latitude: Double
    let longitude: Double
    let heightM: Double?
    let provider: StartPlaceProvider
    let status: String
    let parking: String
    let nearbyHills: String

    var id: String {
        startNumber
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var shortDisplayName: String {
        if provider == .coillte {
            let coillteTrailName = longNameWithoutEndpointRole
            if !coillteTrailName.isEmpty {
                return coillteTrailName
            }
        }
        return nameOnMap.isEmpty ? longName : nameOnMap
    }

    var fullDisplayName: String {
        longName.isEmpty ? shortDisplayName : longName
    }

    private var longNameWithoutEndpointRole: String {
        let trimmedLongName = longName.trimmingCharacters(in: .whitespacesAndNewlines)
        for suffix in [" (Start)", " (Finish)"] where trimmedLongName.hasSuffix(suffix) {
            return String(trimmedLongName.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmedLongName
    }
}

struct ClassificationSection {
    let title: String
    let codes: [String]
}

enum NearestHundredSource: String, Codable, CaseIterable {
    case currentPosition
    case gridReference

    var title: String {
        switch self {
        case .currentPosition:
            return "Current Position"
        case .gridReference:
            return "Grid Ref"
        }
    }
}

struct NearestHundredConfiguration: Codable, Equatable {
    let source: NearestHundredSource
    let gridReference: String
    let easting: Double
    let northing: Double
}

enum NearestHundredSetupResult {
    case success(NearestHundredConfiguration)
    case failure(String)
}

typealias LocalHundredSource = NearestHundredSource
typealias LocalHundredConfiguration = NearestHundredConfiguration
typealias LocalHundredSetupResult = NearestHundredSetupResult

final class DerivedClassificationMembershipStore {
    static let shared = DerivedClassificationMembershipStore()

    private var highestHundredPeakIDs = Set<String>()
    private var rangeHighpointPeakIDs = Set<String>()
    private var provinceTopFiftyPeakIDsByCode: [String: Set<String>] = [:]
    private var localHundredPeakIDs = Set<String>()

    private init() {}

    func update(peaks: [Peak], localHundredConfiguration: LocalHundredConfiguration? = nil) {
        apply(
            ActiveRegion.current.derivedClassificationMemberships(
                for: peaks,
                localHundredConfiguration: localHundredConfiguration
            )
        )
    }

    func isHighestHundred(_ peak: Peak) -> Bool {
        highestHundredPeakIDs.contains(peak.id)
    }

    func isRangeHighpoint(_ peak: Peak) -> Bool {
        rangeHighpointPeakIDs.contains(peak.id)
    }

    func provinceTopFiftyMembershipCode(for peak: Peak) -> String? {
        provinceTopFiftyPeakIDsByCode.first { $0.value.contains(peak.id) }?.key
    }

    func isLocalHundred(_ peak: Peak) -> Bool {
        localHundredPeakIDs.contains(peak.id)
    }

    private func apply(_ memberships: DerivedClassificationMemberships) {
        highestHundredPeakIDs = memberships.highestHundredPeakIDs
        rangeHighpointPeakIDs = memberships.rangeHighpointPeakIDs
        provinceTopFiftyPeakIDsByCode = memberships.provinceTopFiftyPeakIDsByCode
        localHundredPeakIDs = memberships.localHundredPeakIDs
    }
}

private func squaredGridDistance(
    easting: Double,
    northing: Double,
    referenceEasting: Double,
    referenceNorthing: Double
) -> Double {
    let dEasting = easting - referenceEasting
    let dNorthing = northing - referenceNorthing
    return (dEasting * dEasting) + (dNorthing * dNorthing)
}

func alwaysVisibleClassificationCodes() -> Set<String> {
    ActiveRegion.current.alwaysVisibleClassificationCodes
}

func parsedRegionGridReference(_ input: String) -> (gridReference: String, easting: Double, northing: Double)? {
    ActiveRegion.current.parseGridReference(input)
}

func regionGridReference(easting: Double, northing: Double) -> String? {
    ActiveRegion.current.gridReference(easting: easting, northing: northing)
}

func parsedIrishGridReference(_ input: String) -> (gridReference: String, easting: Double, northing: Double)? {
    parsedRegionGridReference(input)
}

func irishGridReference(easting: Double, northing: Double) -> String? {
    regionGridReference(easting: easting, northing: northing)
}

func irishGridReference(for coordinate: CLLocationCoordinate2D) -> String? {
    GridCoordinateFormatter.format(coordinate: coordinate, system: .irishGrid)
}

func irishGridEastingNorthing(for coordinate: CLLocationCoordinate2D) -> (easting: Double, northing: Double)? {
    GridCoordinateFormatter.tm65IrishGridEastingNorthing(for: coordinate)
}

final class PeakAnnotation: MLNPointAnnotation {
    var peak: Peak?
    var zoomPresentationRawValue: String?
}

final class StartPlaceAnnotation: MLNPointAnnotation {
    var startPlace: StartPlace?
    var zoomPresentationRawValue: String?
}

final class IrelandPlaceSelectionAnnotation: MLNPointAnnotation {
    var place: IrelandPlacename?
}

final class GoToTargetAnnotation: MLNPointAnnotation {
    var target: GoToTarget?
}

struct SavedWaypoint: Codable, Equatable {
    let id: String
    var name: String
    let latitude: Double
    let longitude: Double
    let createdAt: Date

    init(id: String = UUID().uuidString, name: String, coordinate: CLLocationCoordinate2D, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.createdAt = createdAt
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

final class SavedWaypointAnnotation: MLNPointAnnotation {
    var waypoint: SavedWaypoint?
}

final class SavedWaypointController {
    private(set) var waypoints: [SavedWaypoint] = []

    func replaceWaypoints(_ waypoints: [SavedWaypoint]) {
        self.waypoints = waypoints
    }

    @discardableResult
    func saveWaypoint(named name: String, coordinate: CLLocationCoordinate2D) -> SavedWaypoint {
        let waypoint = SavedWaypoint(name: name, coordinate: coordinate)
        waypoints.append(waypoint)
        return waypoint
    }

    func updateWaypoint(_ waypoint: SavedWaypoint, withName name: String) -> SavedWaypoint? {
        guard let index = waypoints.firstIndex(where: { $0.id == waypoint.id }) else { return nil }
        var updatedWaypoint = waypoint
        updatedWaypoint.name = name
        waypoints[index] = updatedWaypoint
        return updatedWaypoint
    }

    func deleteWaypoint(_ waypoint: SavedWaypoint) -> Bool {
        guard let index = waypoints.firstIndex(where: { $0.id == waypoint.id }) else { return false }
        waypoints.remove(at: index)
        return true
    }

    func sortedWaypoints() -> [SavedWaypoint] {
        waypoints.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

struct GPXWaypoint {
    let name: String
    let coordinate: CLLocationCoordinate2D
}

struct GPXImport {
    let waypoints: [GPXWaypoint]
    let trackSegments: [[CLLocationCoordinate2D]]
    let skippedWaypointCount: Int
    let skippedTrackPointCount: Int
    let skippedSegmentCount: Int
    let encounteredGPXContent: Bool
}

struct RecordedTrackPoint: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let timestamp: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct ActiveGPXRecordingState: Codable {
    let isRecording: Bool
    let points: [RecordedTrackPoint]
}

struct GPXRecordingSummary {
    let distanceMeters: CLLocationDistance
    let duration: TimeInterval
    let ascentMeters: Double
    let descentMeters: Double
    let currentElevationMeters: Double?
}

struct SavedGPXRecordingItem {
    let fileURL: URL
    let subtitleText: String
}
