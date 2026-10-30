//
//  MapHillsTests.swift
//  MapHillsTests
//
//  Created by David Owens on 26/03/2026.
//

import CoreLocation
import Foundation
import Testing
@testable import BareGPS_Ireland

@Suite(.serialized)
struct MapHillsTests {

    private func makeUserDefaults(suiteName: String = UUID().uuidString) -> UserDefaults {
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return userDefaults
    }

    @Test
    func gridCoordinateFormatterRoundTripsLatitudeLongitude() {
        let coordinate = CLLocationCoordinate2D(latitude: 53.3498, longitude: -6.2603)

        let formatted = GridCoordinateFormatter.format(
            coordinate: coordinate,
            system: .latitudeLongitude
        )
        let parsed = formatted.flatMap { GridCoordinateFormatter.parse(input: $0, system: .latitudeLongitude) }

        #expect(formatted == "53.34980, -6.26030")
        #expect(parsed?.displayString == "53.34980, -6.26030")
        #expect(parsed?.coordinate.latitude == coordinate.latitude)
        #expect(parsed?.coordinate.longitude == coordinate.longitude)
    }

    @Test
    func peakCompatibilityAliasesExposeLegacyFieldNames() {
        let peak = Peak(
            name: "Croagh Patrick",
            mvIndex: "MV-001",
            latitude: 53.7593,
            longitude: -9.6720,
            heightM: 764,
            prominenceM: 764,
            classification: "Furth",
            administrativeAreaName: "Mayo",
            rangeName: "Mweelrea",
            regionalSubdivisionName: "Connacht",
            alternateHillName: "Cruach Phádraig",
            highpointAreaNames: "Mayo",
            projectedEastingMeters: 200_000,
            projectedNorthingMeters: 250_000
        )

        #expect(peak.legacyID == "MV-001")
        #expect(peak.administrativeArea == "Mayo")
        #expect(peak.regionGroup == "Connacht")
        #expect(peak.province == "Mayo")
        #expect(peak.highpointAreas == "Mayo")
        #expect(peak.formattedRegionGridReference == irishGridReference(easting: 200_000, northing: 250_000))
    }

    @Test
    func savedWaypointControllerSupportsReplaceSaveUpdateDeleteAndSort() {
        let controller = SavedWaypointController()
        let a = SavedWaypoint(name: "Zephyr", coordinate: CLLocationCoordinate2D(latitude: 53.1, longitude: -8.2))
        let b = SavedWaypoint(name: "Alpha", coordinate: CLLocationCoordinate2D(latitude: 53.2, longitude: -8.3))

        controller.replaceWaypoints([a, b])
        #expect(controller.sortedWaypoints().map(\.name) == ["Alpha", "Zephyr"])

        let saved = controller.saveWaypoint(
            named: "Middle",
            coordinate: CLLocationCoordinate2D(latitude: 53.3, longitude: -8.4)
        )
        #expect(controller.waypoints.contains(where: { $0.id == saved.id }))

        let updated = controller.updateWaypoint(saved, withName: "Updated")
        #expect(updated?.name == "Updated")
        #expect(controller.deleteWaypoint(a))
        #expect(!controller.deleteWaypoint(a))
    }

    @Test
    func sanitizedGPXFileBaseNameReplacesInvalidCharacters() {
        let result = sanitizedGPXFileBaseName(
            from: "Tryfan / Bristly\\Gully:*?",
            defaultBaseName: "Track"
        )

        #expect(result == "Tryfan - Bristly-Gully---")
    }

    @Test
    func gpxRecordingSummaryCalculatesDistanceDurationAndElevationTotals() {
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        let points = [
            RecordedTrackPoint(latitude: 53.0, longitude: -4.0, altitude: 100, timestamp: start),
            RecordedTrackPoint(latitude: 53.0, longitude: -3.999, altitude: 106, timestamp: start.addingTimeInterval(60)),
            RecordedTrackPoint(latitude: 53.0005, longitude: -3.999, altitude: 103, timestamp: start.addingTimeInterval(120))
        ]

        let summary = gpxRecordingSummary(
            for: points,
            durationEndDate: start.addingTimeInterval(180),
            currentElevationMeters: 103,
            noiseThreshold: 1.5,
            smoothingWindow: 1
        )

        #expect(summary != nil)
        #expect((summary?.duration ?? 0) == 180)
        #expect((summary?.distanceMeters ?? 0) > 0)
        #expect((summary?.ascentMeters ?? 0) == 6)
        #expect((summary?.descentMeters ?? 0) == 3)
        #expect(summary?.currentElevationMeters == 103)
    }

    @Test
    func gpxParserDelegateCollectsWaypointsAndTrackSegments() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="MapHills">
            <wpt lat="53.1" lon="-8.2">
                <name>Start Point</name>
            </wpt>
            <wpt lat="invalid" lon="-8.3">
                <name>Ignored</name>
            </wpt>
            <trk>
                <trkseg>
                    <trkpt lat="53.1" lon="-8.2"><ele>120</ele></trkpt>
                    <trkpt lat="53.1005" lon="-8.1995"><ele>121</ele></trkpt>
                </trkseg>
                <trkseg>
                    <trkpt lat="53.2" lon="-8.1" />
                </trkseg>
            </trk>
        </gpx>
        """

        let delegate = GPXParserDelegate()
        let parser = XMLParser(data: Data(xml.utf8))
        parser.delegate = delegate

        #expect(parser.parse())
        #expect(delegate.encounteredGPXContent)
        #expect(delegate.waypoints.count == 1)
        #expect(delegate.waypoints.first?.name == "Start Point")
        #expect(delegate.waypoints.first?.coordinate.latitude == 53.1)
        #expect(delegate.trackSegments.count == 1)
        #expect(delegate.trackSegments.first?.count == 2)
        #expect(delegate.skippedWaypointCount == 1)
        #expect(delegate.skippedTrackPointCount == 0)
        #expect(delegate.skippedSegmentCount == 1)
    }

    @Test
    func gpxImportServiceParsesFileURL() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="MapHills">
            <wpt lat="53.1" lon="-8.2">
                <name>Start Point</name>
            </wpt>
            <trk>
                <trkseg>
                    <trkpt lat="53.1" lon="-8.2" />
                    <trkpt lat="53.1005" lon="-8.1995" />
                </trkseg>
            </trk>
        </gpx>
        """
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("gpx")
        try xml.write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let importedGPX = try GPXImportService().importGPX(from: fileURL)

        #expect(importedGPX.waypoints.count == 1)
        #expect(importedGPX.waypoints.first?.name == "Start Point")
        #expect(importedGPX.trackSegments.count == 1)
        #expect(importedGPX.trackSegments.first?.count == 2)
    }

    @Test
    func gpxTrackSummaryParserDelegateCapturesPointsWithElevationAndTime() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="MapHills">
            <trk>
                <trkseg>
                    <trkpt lat="53.1" lon="-8.2">
                        <ele>120</ele>
                        <time>2026-07-07T08:00:00Z</time>
                    </trkpt>
                    <trkpt lat="53.1005" lon="-8.1995">
                        <ele>123.5</ele>
                        <time>2026-07-07T08:01:30Z</time>
                    </trkpt>
                </trkseg>
            </trk>
        </gpx>
        """

        let delegate = GPXTrackSummaryParserDelegate()
        let parser = XMLParser(data: Data(xml.utf8))
        parser.delegate = delegate

        #expect(parser.parse())
        #expect(delegate.trackPoints.count == 2)
        #expect(delegate.trackPoints[0].latitude == 53.1)
        #expect(delegate.trackPoints[0].altitude == 120)
        #expect(delegate.trackPoints[0].timestamp == ISO8601DateFormatter().date(from: "2026-07-07T08:00:00Z"))
        #expect(delegate.trackPoints[1].altitude == 123.5)
    }

    @Test
    func trailRecordingStoreAppendsPreviewAndCommittedPointsByPolicy() {
        let store = TrailRecordingStore()
        let start = Date(timeIntervalSinceReferenceDate: 2000)
        let initialLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 53.0, longitude: -4.0),
            altitude: 100,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: -1,
            speed: 1,
            timestamp: start
        )
        let previewLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 53.0, longitude: -3.99998),
            altitude: 100.4,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: -1,
            speed: 1,
            timestamp: start.addingTimeInterval(2)
        )
        let committedLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 53.0, longitude: -3.9997),
            altitude: 104,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: -1,
            speed: 1,
            timestamp: start.addingTimeInterval(8)
        )

        store.startRecording(initialLocation: initialLocation, maximumVerticalAccuracy: 12)

        let previewResult = store.appendTrailLocationIfNeeded(
            previewLocation,
            policy: TrackRecordingQuality.standard.trailRecordingPolicy,
            maximumHorizontalAccuracy: 35,
            maximumVerticalAccuracy: 12,
            minimumAscentIncrement: 1.5
        )
        let committedResult = store.appendTrailLocationIfNeeded(
            committedLocation,
            policy: TrackRecordingQuality.standard.trailRecordingPolicy,
            maximumHorizontalAccuracy: 35,
            maximumVerticalAccuracy: 12,
            minimumAscentIncrement: 1.5
        )

        #expect(previewResult == .previewOnly)
        #expect(committedResult == .appended)
        #expect(store.recordedTrailPoints.count == 2)
    }

    @Test
    func goToSessionStoreRefreshesPolylineOnlyAfterMeaningfulMovement() {
        let store = GoToSessionStore()
        let start = CLLocationCoordinate2D(latitude: 53.0, longitude: -4.0)
        let nearby = CLLocationCoordinate2D(latitude: 53.0, longitude: -3.99999)
        let moved = CLLocationCoordinate2D(latitude: 53.0, longitude: -3.9998)

        #expect(store.shouldRefreshPolyline(from: start, minimumMovementDistance: 4))
        #expect(!store.shouldRefreshPolyline(from: nearby, minimumMovementDistance: 4))
        #expect(store.shouldRefreshPolyline(from: moved, minimumMovementDistance: 4))
    }

    @Test
    func mapViewportStateStoreRecenterPolicyHonorsLifecycleAndActiveGoTo() {
        let store = MapViewportStateStore()

        #expect(!store.handleApplicationDidBecomeActive(
            canUseLocation: true,
            isTrailRecording: false,
            hasActiveGoTo: false,
            hasCurrentUserCoordinate: true
        ))

        store.handleApplicationDidEnterBackground(wasFollowingUser: true)
        let shouldRecenter = store.handleApplicationDidBecomeActive(
            canUseLocation: true,
            isTrailRecording: false,
            hasActiveGoTo: false,
            hasCurrentUserCoordinate: true
        )

        #expect(shouldRecenter)
        #expect(!store.shouldAutoRecenterOnAppActive)
        #expect(!store.shouldResumeFollowModeOnAppActive)

        store.handleApplicationDidEnterBackground(wasFollowingUser: true)
        let blockedByGoTo = store.handleApplicationDidBecomeActive(
            canUseLocation: true,
            isTrailRecording: false,
            hasActiveGoTo: true,
            hasCurrentUserCoordinate: true
        )

        #expect(!blockedByGoTo)
    }

    @Test
    func classificationCodesDeriveProminenceBasedLists() {
        let peak = Peak(
            name: "Test Peak",
            latitude: 53.1,
            longitude: -4.1,
            heightM: 650,
            prominenceM: 610,
            classification: "N",
            administrativeAreaName: "",
            rangeName: "",
            alternateHillName: ""
        )

        let codes = classificationCodes(for: peak)

        #expect(codes.contains("N"))
        #expect(codes.contains("HU"))
        #expect(codes.contains("TU"))
        #expect(codes.contains("A"))
        #expect(!codes.contains("AB"))
        #expect(!codes.contains("BIN"))
        #expect(codes.contains("P500"))
        #expect(codes.contains("P600"))
        #expect(displayNameForClassificationCode("HEW") == "Hewitt")
        #expect(displayNameForClassificationCode("TU") == "Tump")
        #expect(displayNameForClassificationCode("SIB") == "Island")
        #expect(displayNameForClassificationCode("COH") == "County Highpoint")
        #expect(displayNameForClassificationCode("DIL") == "Dillon")
        #expect(displayNameForClassificationCode("A") == "Arderin")
        #expect(displayNameForClassificationCode("AB") == "Arderin Beg")
        #expect(displayNameForClassificationCode("BIN") == "Binnion")
        #expect(displayNameForClassificationCode("VL") == "Vandeleur-Lynam")
    }

    @Test
    func hewittRequiresTwoThousandFeetAndThirtyMetersProminence() {
        let validPeak = Peak(
            name: "Valid Hewitt",
            latitude: 53.1,
            longitude: -4.1,
            heightM: 609.6,
            prominenceM: 30,
            classification: "",
            administrativeAreaName: "",
            rangeName: "",
            alternateHillName: ""
        )
        let tooLowPeak = Peak(
            name: "Too Low Hewitt",
            latitude: 53.2,
            longitude: -4.2,
            heightM: 609.5,
            prominenceM: 30,
            classification: "",
            administrativeAreaName: "",
            rangeName: "",
            alternateHillName: ""
        )

        let validCodes = classificationCodes(for: validPeak)
        let tooLowCodes = classificationCodes(for: tooLowPeak)

        #expect(validCodes.contains("HEW"))
        #expect(!tooLowCodes.contains("HEW"))
    }

    @Test
    func furthRequiresThreeThousandFeet() {
        let validPeak = Peak(
            name: "Valid Furth",
            latitude: 53.1,
            longitude: -4.1,
            heightM: 914.4,
            prominenceM: 0,
            classification: "",
            administrativeAreaName: "",
            rangeName: "",
            alternateHillName: ""
        )
        let tooLowPeak = Peak(
            name: "Too Low Furth",
            latitude: 53.2,
            longitude: -4.2,
            heightM: 914.3,
            prominenceM: 100,
            classification: "",
            administrativeAreaName: "",
            rangeName: "",
            alternateHillName: ""
        )

        let validCodes = classificationCodes(for: validPeak)
        let tooLowCodes = classificationCodes(for: tooLowPeak)

        #expect(validCodes.contains("F"))
        #expect(!tooLowCodes.contains("F"))
    }

    @Test
    func marilynRequiresOneHundredAndFiftyMetersProminence() {
        let validPeak = Peak(
            name: "Valid Marilyn",
            latitude: 53.1,
            longitude: -4.1,
            heightM: 300,
            prominenceM: 150,
            classification: "",
            administrativeAreaName: "",
            rangeName: "",
            alternateHillName: ""
        )
        let tooLowPeak = Peak(
            name: "Too Low Marilyn",
            latitude: 53.2,
            longitude: -4.2,
            heightM: 900,
            prominenceM: 149.9,
            classification: "",
            administrativeAreaName: "",
            rangeName: "",
            alternateHillName: ""
        )

        let validCodes = classificationCodes(for: validPeak)
        let tooLowCodes = classificationCodes(for: tooLowPeak)

        #expect(validCodes.contains("MA"))
        #expect(!tooLowCodes.contains("MA"))
    }

    @Test
    func highestHundredUsesTopHundredHeightsAmongProminentPeaks() {
        let peaks = (0..<101).map { index in
            Peak(
                name: "Peak \(index)",
                latitude: 53.0 + Double(index) * 0.001,
                longitude: -4.0,
                heightM: 1000 - Double(index),
                prominenceM: 100,
                classification: "",
                administrativeAreaName: "",
                rangeName: "",
                alternateHillName: ""
            )
        }

        DerivedClassificationMembershipStore.shared.update(peaks: peaks)

        let topPeakCodes = classificationCodes(for: peaks[0])
        let excludedPeakCodes = classificationCodes(for: peaks[100])

        #expect(topPeakCodes.contains("HH"))
        #expect(!excludedPeakCodes.contains("HH"))
        #expect(displayNameForClassificationCode("HH") == "Highest Hundred")
    }

    @Test
    func localHundredUsesNearestHundredPeaksToConfiguredReference() {
        let peaks = (0..<101).map { index in
            Peak(
                name: "Peak \(index)",
                latitude: 53.0,
                longitude: -4.0,
                heightM: 400 + Double(index),
                prominenceM: 50,
                classification: "",
                administrativeAreaName: "",
                rangeName: "",
                alternateHillName: "",
                projectedEastingMeters: 100_000 + Double(index * 100),
                projectedNorthingMeters: 200_000
            )
        }
        let configuration = LocalHundredConfiguration(
            source: .gridReference,
            gridReference: "A 00000 00000",
            easting: 100_000,
            northing: 200_000
        )

        DerivedClassificationMembershipStore.shared.update(peaks: peaks, localHundredConfiguration: configuration)

        let nearestPeakCodes = classificationCodes(for: peaks[0])
        let furthestPeakCodes = classificationCodes(for: peaks[100])

        #expect(nearestPeakCodes.contains("L100"))
        #expect(!furthestPeakCodes.contains("L100"))
        #expect(displayNameForClassificationCode("L100") == "Nearest 100")
    }

    @Test
    func parsedIrishGridReferenceNormalizesManualInput() {
        let parsed = parsedIrishGridReference("a1234567890")

        #expect(parsed?.gridReference == "A 12345 67890")
        #expect(parsed?.easting == 12_345)
        #expect(parsed?.northing == 467_890)
    }

    @Test
    func irishGridReferenceFormatsProjectedCoordinates() {
        #expect(irishGridReference(easting: 12_345, northing: 467_890) == "A 12345 67890")
    }

    @Test
    func irishGridReferenceRoundTripsThroughParser() {
        let reference = irishGridReference(easting: 200_000, northing: 250_000)
        let parsed = reference.flatMap(parsedIrishGridReference)

        #expect(reference != nil)
        #expect(parsed?.gridReference == reference)
        #expect(parsed?.easting == 200_000)
        #expect(parsed?.northing == 250_000)
    }

    @Test
    func rangeHighpointUsesTallestPeakPerRange() {
        let peaks = [
            Peak(
                name: "Range A High",
                latitude: 53.1,
                longitude: -4.1,
                heightM: 700,
                prominenceM: 100,
                classification: "",
                administrativeAreaName: "",
                rangeName: "Range A",
                alternateHillName: ""
            ),
            Peak(
                name: "Range A Low",
                latitude: 53.2,
                longitude: -4.2,
                heightM: 650,
                prominenceM: 120,
                classification: "",
                administrativeAreaName: "",
                rangeName: "Range A",
                alternateHillName: ""
            ),
            Peak(
                name: "Range B High",
                latitude: 53.3,
                longitude: -4.3,
                heightM: 800,
                prominenceM: 150,
                classification: "",
                administrativeAreaName: "",
                rangeName: "Range B",
                alternateHillName: ""
            )
        ]

        DerivedClassificationMembershipStore.shared.update(peaks: peaks)

        let rangeAHighCodes = classificationCodes(for: peaks[0])
        let rangeALowCodes = classificationCodes(for: peaks[1])
        let rangeBHighCodes = classificationCodes(for: peaks[2])

        #expect(rangeAHighCodes.contains("RHP"))
        #expect(!rangeALowCodes.contains("RHP"))
        #expect(rangeBHighCodes.contains("RHP"))
        #expect(displayNameForClassificationCode("RHP") == "Range Highpoint")
    }

    @Test
    func appPreferencesStorePersistsLocalHundredConfiguration() {
        let userDefaults = makeUserDefaults()
        let store = AppPreferencesStore(userDefaults: userDefaults)
        let configuration = LocalHundredConfiguration(
            source: .currentPosition,
            gridReference: "V 83643 84450",
            easting: 283_643,
            northing: 284_450
        )

        store.saveLocalHundredConfiguration(configuration)

        #expect(store.loadLocalHundredConfiguration() == configuration)
    }

    @Test
    func provinceTopFiftyUsesHighestProminentHillsPerProvince() {
        let connachtPeaks = (0..<51).map { index in
            Peak(
                name: "Connacht Peak \(index)",
                latitude: 53.0 + Double(index) * 0.001,
                longitude: -9.0,
                heightM: 1000 - Double(index),
                prominenceM: 100,
                classification: "",
                administrativeAreaName: "",
                rangeName: "",
                regionalSubdivisionName: "Connacht",
                alternateHillName: ""
            )
        }
        let leinsterPeak = Peak(
            name: "Leinster Peak",
            latitude: 53.8,
            longitude: -6.5,
            heightM: 800,
            prominenceM: 100,
            classification: "",
            administrativeAreaName: "",
            rangeName: "",
            regionalSubdivisionName: "Leinster",
            alternateHillName: ""
        )

        let peaks = connachtPeaks + [leinsterPeak]
        DerivedClassificationMembershipStore.shared.update(peaks: peaks)

        let includedCodes = classificationCodes(for: connachtPeaks[0])
        let excludedCodes = classificationCodes(for: connachtPeaks[50])
        let leinsterCodes = classificationCodes(for: leinsterPeak)

        #expect(includedCodes.contains("PT50_CONNACHT"))
        #expect(!excludedCodes.contains("PT50_CONNACHT"))
        #expect(leinsterCodes.contains("PT50_LEINSTER"))
        #expect(displayNameForClassificationCode("PT50_CONNACHT") == "Connacht Top 50")
    }

    @Test
    func countyHighpointComesFromCHPField() {
        let countyHighpointPeak = Peak(
            name: "County Highpoint",
            latitude: 53.1,
            longitude: -4.1,
            heightM: 800,
            prominenceM: 300,
            classification: "",
            administrativeAreaName: "",
            rangeName: "",
            alternateHillName: "",
            highpointAreaNames: "Kerry"
        )
        let ordinaryPeak = Peak(
            name: "Ordinary Peak",
            latitude: 53.2,
            longitude: -4.2,
            heightM: 800,
            prominenceM: 300,
            classification: "",
            administrativeAreaName: "",
            rangeName: "",
            alternateHillName: "",
            highpointAreaNames: ""
        )

        let countyHighpointCodes = classificationCodes(for: countyHighpointPeak)
        let ordinaryCodes = classificationCodes(for: ordinaryPeak)

        #expect(countyHighpointCodes.contains("COH"))
        #expect(!ordinaryCodes.contains("COH"))
    }

    @Test
    func otherCategoryCatchesUnclassifiedHills() {
        let uncategorizedPeak = Peak(
            name: "Uncategorized Peak",
            latitude: 53.1,
            longitude: -4.1,
            heightM: 450,
            prominenceM: 10,
            classification: "",
            administrativeAreaName: "",
            rangeName: "",
            alternateHillName: ""
        )
        let categorizedPeak = Peak(
            name: "Categorized Peak",
            latitude: 53.2,
            longitude: -4.2,
            heightM: 650,
            prominenceM: 100,
            classification: "",
            administrativeAreaName: "",
            rangeName: "",
            alternateHillName: ""
        )

        let uncategorizedCodes = classificationCodes(for: uncategorizedPeak)
        let categorizedCodes = classificationCodes(for: categorizedPeak)

        #expect(uncategorizedCodes.contains("OTHER"))
        #expect(!categorizedCodes.contains("OTHER"))
        #expect(displayNameForClassificationCode("OTHER") == "Other")
    }

    @Test
    func arderinBegRequiresProminenceBelowArderinThreshold() {
        let arderinBegPeak = Peak(
            name: "Arderin Beg Peak",
            latitude: 53.1,
            longitude: -4.1,
            heightM: 550,
            prominenceM: 20,
            classification: "",
            administrativeAreaName: "",
            rangeName: "",
            alternateHillName: ""
        )
        let arderinPeak = Peak(
            name: "Arderin Peak",
            latitude: 53.2,
            longitude: -4.2,
            heightM: 550,
            prominenceM: 35,
            classification: "",
            administrativeAreaName: "",
            rangeName: "",
            alternateHillName: ""
        )

        let arderinBegCodes = classificationCodes(for: arderinBegPeak)
        let arderinCodes = classificationCodes(for: arderinPeak)

        #expect(arderinBegCodes.contains("AB"))
        #expect(!arderinBegCodes.contains("A"))
        #expect(!arderinBegCodes.contains("BIN"))
        #expect(arderinCodes.contains("A"))
        #expect(!arderinCodes.contains("AB"))
    }

    @Test
    func binnionRequiresHundredToFourHundredMetersAndHundredMetersProminence() {
        let binnionPeak = Peak(
            name: "Binnion Peak",
            latitude: 53.1,
            longitude: -4.1,
            heightM: 100,
            prominenceM: 120,
            classification: "",
            administrativeAreaName: "",
            rangeName: "",
            alternateHillName: ""
        )
        let midRangePeak = Peak(
            name: "Mid Range Binnion Peak",
            latitude: 53.12,
            longitude: -4.12,
            heightM: 350,
            prominenceM: 120,
            classification: "",
            administrativeAreaName: "",
            rangeName: "",
            alternateHillName: ""
        )
        let upperBoundPeak = Peak(
            name: "Upper Bound Excluded Peak",
            latitude: 53.15,
            longitude: -4.15,
            heightM: 400,
            prominenceM: 120,
            classification: "",
            administrativeAreaName: "",
            rangeName: "",
            alternateHillName: ""
        )
        let tooTallPeak = Peak(
            name: "Too Tall Peak",
            latitude: 53.2,
            longitude: -4.2,
            heightM: 450,
            prominenceM: 120,
            classification: "",
            administrativeAreaName: "",
            rangeName: "",
            alternateHillName: ""
        )

        let binnionCodes = classificationCodes(for: binnionPeak)
        let midRangeCodes = classificationCodes(for: midRangePeak)
        let upperBoundCodes = classificationCodes(for: upperBoundPeak)
        let tooTallCodes = classificationCodes(for: tooTallPeak)

        #expect(binnionCodes.contains("BIN"))
        #expect(midRangeCodes.contains("BIN"))
        #expect(!upperBoundCodes.contains("BIN"))
        #expect(!binnionCodes.contains("AB"))
        #expect(!tooTallCodes.contains("BIN"))
    }

    @Test
    func vandeleurLynamIncludesSixHundredMetersAndRequiresFifteenMetersProminence() {
        let validPeak = Peak(
            name: "VL Peak",
            latitude: 53.1,
            longitude: -4.1,
            heightM: 600,
            prominenceM: 15,
            classification: "",
            administrativeAreaName: "",
            rangeName: "",
            alternateHillName: ""
        )
        let tooLowPeak = Peak(
            name: "Too Low VL Peak",
            latitude: 53.2,
            longitude: -4.2,
            heightM: 599.9,
            prominenceM: 15,
            classification: "",
            administrativeAreaName: "",
            rangeName: "",
            alternateHillName: ""
        )

        let validCodes = classificationCodes(for: validPeak)
        let tooLowCodes = classificationCodes(for: tooLowPeak)

        #expect(validCodes.contains("VL"))
        #expect(!tooLowCodes.contains("VL"))
    }

    @Test
    func trailRecordingStoreRetainsTrackPointButDropsAltitudeWhenVerticalAccuracyIsPoor() {
        let store = TrailRecordingStore()
        let start = Date(timeIntervalSinceReferenceDate: 5_000)
        let initialLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 53.0, longitude: -4.0),
            altitude: 100,
            horizontalAccuracy: 5,
            verticalAccuracy: 30,
            course: -1,
            speed: 0,
            timestamp: start
        )
        let appendedLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 53.0, longitude: -3.9997),
            altitude: 140,
            horizontalAccuracy: 5,
            verticalAccuracy: 30,
            course: -1,
            speed: 1,
            timestamp: start.addingTimeInterval(10)
        )

        store.startRecording(initialLocation: initialLocation, maximumVerticalAccuracy: 12)
        let result = store.appendTrailLocationIfNeeded(
            appendedLocation,
            policy: TrackRecordingQuality.standard.trailRecordingPolicy,
            maximumHorizontalAccuracy: 35,
            maximumVerticalAccuracy: 12,
            minimumAscentIncrement: 1.5
        )

        #expect(result == .appended)
        #expect(store.recordedTrailPoints.count == 2)
        #expect(store.recordedTrailPoints.allSatisfy { $0.altitude == nil })
    }

    @Test
    func gpxRecordingSummaryUsesObservedAltitudeAnchorsAsMinimumTotals() {
        let start = Date(timeIntervalSinceReferenceDate: 6_000)
        let points = [
            RecordedTrackPoint(latitude: 53.0, longitude: -4.0, altitude: 100, timestamp: start),
            RecordedTrackPoint(latitude: 53.0001, longitude: -3.9999, altitude: nil, timestamp: start.addingTimeInterval(60)),
            RecordedTrackPoint(latitude: 53.0002, longitude: -3.9998, altitude: 500, timestamp: start.addingTimeInterval(120)),
            RecordedTrackPoint(latitude: 53.0003, longitude: -3.9997, altitude: nil, timestamp: start.addingTimeInterval(180)),
            RecordedTrackPoint(latitude: 53.0004, longitude: -3.9996, altitude: 250, timestamp: start.addingTimeInterval(240))
        ]

        let summary = gpxRecordingSummary(
            for: points,
            noiseThreshold: 1.5,
            smoothingWindow: 3
        )

        #expect(summary != nil)
        #expect(summary?.ascentMeters == 400)
        #expect(summary?.descentMeters == 250)
    }

    @Test
    func parsedIrishGridReferenceRejectsOddDigitsAndDisallowedLetter() {
        #expect(parsedIrishGridReference("0123456") == nil)
        #expect(parsedIrishGridReference("I123456") == nil)
    }

    @Test
    func appPreferencesStoreClearsLocalHundredConfiguration() {
        let userDefaults = makeUserDefaults()
        let store = AppPreferencesStore(userDefaults: userDefaults)
        let configuration = LocalHundredConfiguration(
            source: .gridReference,
            gridReference: "A 12345 67890",
            easting: 12_345,
            northing: 467_890
        )

        store.saveLocalHundredConfiguration(configuration)
        store.clearLocalHundredConfiguration()

        #expect(store.loadLocalHundredConfiguration() == nil)
    }

    @Test
    func carnRequiresOverFourHundredUnderFiveHundredMetersAndThirtyMetersProminence() {
        let validPeak = Peak(
            name: "Carn Peak",
            latitude: 53.1,
            longitude: -4.1,
            heightM: 450,
            prominenceM: 30,
            classification: "",
            administrativeAreaName: "",
            rangeName: "",
            alternateHillName: ""
        )
        let lowerBoundPeak = Peak(
            name: "Lower Bound Carn Peak",
            latitude: 53.2,
            longitude: -4.2,
            heightM: 400,
            prominenceM: 30,
            classification: "",
            administrativeAreaName: "",
            rangeName: "",
            alternateHillName: ""
        )
        let tooHighPeak = Peak(
            name: "Too High Carn Peak",
            latitude: 53.3,
            longitude: -4.3,
            heightM: 500,
            prominenceM: 30,
            classification: "",
            administrativeAreaName: "",
            rangeName: "",
            alternateHillName: ""
        )

        let validCodes = classificationCodes(for: validPeak)
        let lowerBoundCodes = classificationCodes(for: lowerBoundPeak)
        let tooHighCodes = classificationCodes(for: tooHighPeak)

        #expect(validCodes.contains("4"))
        #expect(lowerBoundCodes.contains("4"))
        #expect(!tooHighCodes.contains("4"))
    }

    @Test
    func advancedHillFilterNormalizesSwappedHeightBounds() {
        let filter = AdvancedHillFilter(
            selectedClassificationCodes: ["N"],
            minimumHeightMeters: 700,
            maximumHeightMeters: 500,
            combinationMode: .matchAll
        )

        #expect(filter.normalizedMinimumHeightMeters == 500)
        #expect(filter.normalizedMaximumHeightMeters == 700)
        #expect(!filter.isEmpty)
    }

    @Test
    func gpxRecordingSummarySuppressesSmallAltitudeNoise() {
        let start = Date(timeIntervalSinceReferenceDate: 3000)
        let points = [
            RecordedTrackPoint(latitude: 53.0, longitude: -4.0, altitude: 100.0, timestamp: start),
            RecordedTrackPoint(latitude: 53.0, longitude: -3.9999, altitude: 100.6, timestamp: start.addingTimeInterval(30)),
            RecordedTrackPoint(latitude: 53.0, longitude: -3.9998, altitude: 99.9, timestamp: start.addingTimeInterval(60)),
            RecordedTrackPoint(latitude: 53.0, longitude: -3.9997, altitude: 100.7, timestamp: start.addingTimeInterval(90))
        ]

        let summary = gpxRecordingSummary(
            for: points,
            noiseThreshold: 1.5,
            smoothingWindow: 1
        )

        #expect(summary != nil)
        #expect(abs((summary?.ascentMeters ?? -1) - 0.8) < 0.0001)
        #expect(abs((summary?.descentMeters ?? -1) - 0.7) < 0.0001)
    }

    @Test
    func breadcrumbPruningRemovesExpiredPoints() {
        let store = TrailRecordingStore()
        let start = Date(timeIntervalSinceReferenceDate: 4000)
        store.breadcrumbTrailPoints = [
            RecordedTrackPoint(latitude: 53.0, longitude: -4.0, altitude: nil, timestamp: start),
            RecordedTrackPoint(latitude: 53.0, longitude: -3.9999, altitude: nil, timestamp: start.addingTimeInterval(100)),
            RecordedTrackPoint(latitude: 53.0, longitude: -3.9998, altitude: nil, timestamp: start.addingTimeInterval(200))
        ]

        store.pruneBreadcrumbTrail(relativeTo: start.addingTimeInterval(250), duration: 120)

        #expect(store.breadcrumbTrailPoints.count == 1)
        #expect(store.breadcrumbTrailPoints.first?.timestamp == start.addingTimeInterval(200))
    }

    @Test
    func breadcrumbAppendBreaksStaleDistantTrail() {
        let store = TrailRecordingStore()
        let start = Date(timeIntervalSinceReferenceDate: 5000)
        store.breadcrumbTrailPoints = [
            RecordedTrackPoint(latitude: 53.0, longitude: -4.0, altitude: nil, timestamp: start)
        ]
        let laterLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 53.01, longitude: -4.0),
            altitude: 100,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: start.addingTimeInterval(90)
        )

        let didAppend = store.appendBreadcrumbLocationIfNeeded(
            laterLocation,
            minimumDistance: 2,
            maximumHorizontalAccuracy: 35,
            trailDuration: 5 * 60,
            maximumStaleSampleInterval: 60,
            maximumStaleSampleDistance: 75
        )

        #expect(didAppend)
        #expect(store.breadcrumbTrailPoints.count == 1)
        #expect(store.breadcrumbTrailPoints.first?.timestamp == laterLocation.timestamp)
    }

    @Test
    func offlineCacheStoreTransitionsFailureAndCompletionState() {
        let userDefaults = makeUserDefaults()
        let store = OfflineCacheStore(userDefaults: userDefaults)

        store.markFailed(id: "area-1", message: "The Internet connection appears to be offline.")
        #expect(store.loadFailures()["area-1"] == "The Internet connection appears to be offline.")
        #expect(!store.loadCompletedIDs().contains("area-1"))
        #expect(store.loadByteCounts()["area-1"] == nil)
        #expect(store.normalizedFailureMessage(store.loadFailures()["area-1"] ?? "") == "No network connection.")

        store.markCompleted(id: "area-1", byteCount: 2048)
        #expect(store.loadFailures()["area-1"] == nil)
        #expect(store.loadCompletedIDs().contains("area-1"))
        #expect(store.loadByteCounts()["area-1"] == 2048)
    }

    @Test
    func offlineCacheStoreClearsTransientMetadataWithoutTouchingNameOverride() {
        let userDefaults = makeUserDefaults()
        let store = OfflineCacheStore(userDefaults: userDefaults)

        store.saveNameOverrides(["area-1": "Snowdon Range"])
        store.markFailed(id: "area-1", message: "disk full")
        store.clearTransientMetadata(for: "area-1")

        #expect(store.loadNameOverrides()["area-1"] == "Snowdon Range")
        #expect(store.loadFailures()["area-1"] == nil)
        #expect(!store.loadCompletedIDs().contains("area-1"))
        #expect(store.loadByteCounts()["area-1"] == nil)
    }

    @Test
    func appPreferencesStoreDefaultsToHillMarkersAndMountainViewsOnlyStartPlaces() {
        let userDefaults = makeUserDefaults()
        let store = AppPreferencesStore(userDefaults: userDefaults)

        #expect(store.loadShowsHillMarkers())
        #expect(store.loadVisibleStartPlaceProviders() == [.mountainViews])
        #expect(store.loadStartPlaceRouteLengthFilter() == .off)
    }

    @Test
    func appPreferencesStorePersistsHillMarkerVisibility() {
        let userDefaults = makeUserDefaults()
        let store = AppPreferencesStore(userDefaults: userDefaults)

        store.saveShowsHillMarkers(false)
        #expect(!store.loadShowsHillMarkers())

        store.saveShowsHillMarkers(true)
        #expect(store.loadShowsHillMarkers())
    }

    @Test
    func appPreferencesStorePersistsVisibleStartPlaceProviders() {
        let userDefaults = makeUserDefaults()
        let store = AppPreferencesStore(userDefaults: userDefaults)
        let providers: Set<StartPlaceProvider> = [.coillte, .sportIreland]

        store.saveVisibleStartPlaceProviders(providers)

        #expect(store.loadVisibleStartPlaceProviders() == providers)
    }

    @Test
    func appPreferencesStorePersistsStartPlaceRouteLengthFilter() {
        let userDefaults = makeUserDefaults()
        let store = AppPreferencesStore(userDefaults: userDefaults)

        store.saveStartPlaceRouteLengthFilter(.minimum3000)

        #expect(store.loadStartPlaceRouteLengthFilter() == .minimum3000)
    }

    @Test
    func startPlaceProviderRawValuesAndTitlesAreStable() throws {
        #expect(StartPlaceProvider.mountainViews.rawValue == "mountainViews")
        #expect(StartPlaceProvider.sportIreland.rawValue == "sportIreland")
        #expect(StartPlaceProvider.coillte.rawValue == "coillte")
        #expect(StartPlaceProvider.outscape.rawValue == "outscape")
        #expect(StartPlaceProvider.mountainViews.title == "MountainViews")
        #expect(StartPlaceProvider.sportIreland.title == "Sport Ireland")
        #expect(StartPlaceProvider.coillte.title == "Coillte")
        #expect(StartPlaceProvider.outscape.title == "Outscape NI")

        let encoded = try JSONEncoder().encode([StartPlaceProvider.mountainViews, .coillte, .sportIreland, .outscape])
        let decoded = try JSONDecoder().decode([StartPlaceProvider].self, from: encoded)
        #expect(decoded == [.mountainViews, .coillte, .sportIreland, .outscape])
    }

    @Test
    func coillteStartPlaceDisplayNameUsesFullTrailNameWithoutEndpointRole() {
        let coillteStartPlace = StartPlace(
            startNumber: "coillte-0-S",
            nameOnMap: "Kanturk / Agreed A",
            longName: "Kanturk / Agreed Access (Start)",
            gridReference: "O 14846 03129",
            latitude: 52.0,
            longitude: -8.0,
            heightM: nil,
            provider: .coillte,
            status: "Coillte",
            parking: "",
            nearbyHills: ""
        )
        let sportIrelandStartPlace = StartPlace(
            startNumber: "sportireland-1",
            nameOnMap: "Short Sport Name",
            longName: "Long Sport Name (Start)",
            gridReference: "O 14846 03129",
            latitude: 52.0,
            longitude: -8.0,
            heightM: nil,
            provider: .sportIreland,
            status: "Easy",
            parking: "",
            nearbyHills: ""
        )

        #expect(coillteStartPlace.shortDisplayName == "Kanturk / Agreed Access")
        #expect(sportIrelandStartPlace.shortDisplayName == "Short Sport Name")
    }

    @Test
    func csvParserHandlesBOMAndQuotedCommas() {
        let csv = "\u{FEFF}StartNumber,NameOnMap,Latitude,Longitude\n1,\"Car park, west\",53.1,-8.1\n"
        let rows = parsedCSVRows(from: csv)

        #expect(rows.count == 1)
        #expect(rows[0]["startnumber"] == "1")
        #expect(rows[0]["nameonmap"] == "Car park, west")
        #expect(rows[0]["latitude"] == "53.1")
        #expect(rows[0]["longitude"] == "-8.1")
    }

    @Test
    func bundledStartPlaceCSVsHaveRequiredHeadersAndValidCoordinates() throws {
        for resourceName in ["MountainViewsStartPoints", "CoillteStartPoints", "SportIrelandStartPoints"] {
            let rows = try bundledCSVRows(resourceName: resourceName, subdirectory: "ReferenceData")
            #expect(!rows.isEmpty)

            for header in ["startnumber", "nameonmap", "latitude", "longitude"] {
                #expect(rows[0].keys.contains(header), "Missing \\(header) in \\(resourceName).csv")
            }

            for row in rows {
                let latitude = try #require(Double(row["latitude"] ?? ""), "Invalid latitude in \\(resourceName): \\(row)")
                let longitude = try #require(Double(row["longitude"] ?? ""), "Invalid longitude in \\(resourceName): \\(row)")
                #expect((51.0...56.0).contains(latitude), "Latitude outside Ireland bounds in \\(resourceName): \\(latitude)")
                #expect((-11.0 ... -5.0).contains(longitude), "Longitude outside Ireland bounds in \\(resourceName): \\(longitude)")
            }
        }
    }

    @Test
    func bundledProviderTrailGeoJSONContainsUsableFeatures() throws {
        let coillteFeatures = try bundledGeoJSONFeatures(resourceName: "CoillteTrails")
        let sportIrelandFeatures = try bundledGeoJSONFeatures(resourceName: "SportIrelandTrails")
        let outscapeFeatures = try bundledGeoJSONFeatures(resourceName: "OutscapeOffRoadTrails")

        #expect(!coillteFeatures.isEmpty)
        #expect(!sportIrelandFeatures.isEmpty)
        #expect(!outscapeFeatures.isEmpty)
        #expect(coillteFeatures.contains { featureHasUsableLineGeometry($0) && stringProperty("NAME", in: $0) != nil })
        #expect(sportIrelandFeatures.contains { featureHasUsableLineGeometry($0) && stringProperty("TrailID", in: $0) != nil })
        #expect(outscapeFeatures.contains { featureHasUsableLineGeometry($0) && stringProperty("FID", in: $0) != nil })
    }

    @Test
    func outscapeDerivedStartPointsResolveToTrailGeometries() {
        let starts = MapDataLoader.loadOutscapeDerivedTrailStartPlaces()
        let trailsByID = MapDataLoader.loadOutscapeTrailSummariesByTrailID()
        let unresolvedStarts = starts.filter { trailsByID[$0.id] == nil }

        #expect(!starts.isEmpty)
        #expect(!trailsByID.isEmpty)
        #expect(unresolvedStarts.isEmpty)
        #expect(starts.allSatisfy { !$0.gridReference.isEmpty })
    }

    @Test
    func sportIrelandTrailheadLinksMostlyResolveToTrailGeometries() throws {
        let trailheadRows = try bundledCSVRows(resourceName: "SportIrelandTrailheads", subdirectory: "ReferenceData")
        let routeFeatures = try bundledGeoJSONFeatures(resourceName: "SportIrelandTrails")
        let routeTrailIDs = Set(routeFeatures.compactMap { stringProperty("TrailID", in: $0) })
        let linkedTrailIDs = trailheadRows.compactMap { $0["trailid"] }.filter { !$0.isEmpty }
        let resolvedLinkCount = linkedTrailIDs.filter { routeTrailIDs.contains($0) }.count
        let resolvedRatio = Double(resolvedLinkCount) / Double(max(linkedTrailIDs.count, 1))

        #expect(!linkedTrailIDs.isEmpty)
        #expect(!routeTrailIDs.isEmpty)
        #expect(resolvedRatio >= 0.95)
    }

    @Test
    func coillteStartPointsHaveNearbyRouteEndpoints() throws {
        let startRows = try bundledCSVRows(resourceName: "CoillteStartPoints", subdirectory: "ReferenceData")
        let routeFeatures = try bundledGeoJSONFeatures(resourceName: "CoillteTrails")
        let endpoints = routeFeatures.flatMap(routeEndpoints)

        #expect(!startRows.isEmpty)
        #expect(!endpoints.isEmpty)

        let startsWithoutRouteEndpoint = startRows.filter { row in
            guard
                let latitude = Double(row["latitude"] ?? ""),
                let longitude = Double(row["longitude"] ?? "")
            else {
                return true
            }

            return !endpoints.contains { endpoint in
                distanceMeters(
                    from: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    to: endpoint
                ) <= 20
            }
        }

        #expect(startsWithoutRouteEndpoint.isEmpty)
    }

    private func bundledCSVRows(resourceName: String, subdirectory: String) throws -> [[String: String]] {
        let url = try bundledResourceURL(resourceName: resourceName, extension: "csv", subdirectory: subdirectory)
        let csv = try String(contentsOf: url, encoding: .utf8)
        return parsedCSVRows(from: csv)
    }

    private func parsedCSVRows(from csv: String) -> [[String: String]] {
        let lines = csv
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard let headerLine = lines.first else { return [] }

        let headers = parseCSVColumns(headerLine).map(normalizedHeader)
        return lines.dropFirst().compactMap { line in
            let columns = parseCSVColumns(line)
            guard columns.count == headers.count else { return nil }
            return Dictionary(uniqueKeysWithValues: zip(headers, columns))
        }
    }

    private func parseCSVColumns(_ line: String) -> [String] {
        var columns: [String] = []
        var current = ""
        var isInsideQuotes = false
        var index = line.startIndex

        while index < line.endIndex {
            let character = line[index]
            if character == "\"" {
                let nextIndex = line.index(after: index)
                if isInsideQuotes, nextIndex < line.endIndex, line[nextIndex] == "\"" {
                    current.append("\"")
                    index = line.index(after: nextIndex)
                    continue
                }
                isInsideQuotes.toggle()
            } else if character == ",", !isInsideQuotes {
                columns.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current.removeAll()
            } else {
                current.append(character)
            }
            index = line.index(after: index)
        }

        columns.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        return columns
    }

    private func normalizedHeader(_ header: String) -> String {
        header
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{FEFF}")))
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private func bundledGeoJSONFeatures(resourceName: String) throws -> [[String: Any]] {
        let url = try bundledResourceURL(resourceName: resourceName, extension: "geojson", subdirectory: "ReferenceData")
        let data = try Data(contentsOf: url)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try #require(object["features"] as? [[String: Any]])
    }

    private func bundledResourceURL(resourceName: String, extension pathExtension: String, subdirectory: String) throws -> URL {
        let bundles = [Bundle.main, Bundle(for: MapHillsTestBundleToken.self)] + Bundle.allBundles
        for bundle in bundles {
            if let url = bundle.url(forResource: resourceName, withExtension: pathExtension, subdirectory: subdirectory) {
                return url
            }
            if let url = bundle.url(forResource: resourceName, withExtension: pathExtension) {
                return url
            }
        }
        throw TestResourceError.missingResource("\(resourceName).\(pathExtension)")
    }

    private func stringProperty(_ key: String, in feature: [String: Any]) -> String? {
        guard
            let properties = feature["properties"] as? [String: Any],
            let value = properties[key]
        else {
            return nil
        }
        let string = String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
        return string.isEmpty ? nil : string
    }

    private func featureHasUsableLineGeometry(_ feature: [String: Any]) -> Bool {
        guard let geometry = feature["geometry"] as? [String: Any] else { return false }
        return !coordinateSegments(from: geometry).isEmpty
    }

    private func routeEndpoints(from feature: [String: Any]) -> [CLLocationCoordinate2D] {
        guard let geometry = feature["geometry"] as? [String: Any] else { return [] }
        return coordinateSegments(from: geometry).flatMap { segment in
            [segment.first, segment.last].compactMap { $0 }
        }
    }

    private func coordinateSegments(from geometry: [String: Any]) -> [[CLLocationCoordinate2D]] {
        guard let type = geometry["type"] as? String else { return [] }
        switch type {
        case "LineString":
            guard let coordinates = geometry["coordinates"] as? [[Double]] else { return [] }
            let segment = coordinates.compactMap(coordinate)
            return segment.count > 1 ? [segment] : []
        case "MultiLineString":
            guard let coordinateGroups = geometry["coordinates"] as? [[[Double]]] else { return [] }
            return coordinateGroups
                .map { $0.compactMap(coordinate) }
                .filter { $0.count > 1 }
        default:
            return []
        }
    }

    private func coordinate(from position: [Double]) -> CLLocationCoordinate2D? {
        guard position.count >= 2 else { return nil }
        return CLLocationCoordinate2D(latitude: position[1], longitude: position[0])
    }

    private func distanceMeters(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: start.latitude, longitude: start.longitude)
            .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
    }
}

private final class MapHillsTestBundleToken {}

private enum TestResourceError: Error {
    case missingResource(String)
}
