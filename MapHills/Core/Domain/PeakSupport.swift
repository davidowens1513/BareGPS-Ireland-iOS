import Foundation
import CoreLocation
import MapLibre
import UIKit

enum DisplayUnitSystem: Int, CaseIterable {
    case metric
    case imperial

    var title: String {
        switch self {
        case .metric:
            return "Metric"
        case .imperial:
            return "Imperial"
        }
    }
}

enum HillFilterMode: Int, CaseIterable {
    case simple
    case advanced

    var title: String {
        switch self {
        case .simple:
            return "Simple"
        case .advanced:
            return "Advanced"
        }
    }
}

enum HeightFilterBand: String, CaseIterable {
    case from600Up = "over600"
    case from500To600 = "500to600"
    case from400To500 = "400to500"
    case from300To400 = "300to400"
    case from200To300 = "200to300"
    case from100To200 = "100to200"
    case below100 = "below100"

    var title: String {
        switch self {
        case .from600Up:
            return "600m+"
        case .from500To600:
            return "500-600m"
        case .from400To500:
            return "400-500m"
        case .from300To400:
            return "300-400m"
        case .from200To300:
            return "200-300m"
        case .from100To200:
            return "100-200m"
        case .below100:
            return "0-100m"
        }
    }

    func includes(height: Double) -> Bool {
        switch self {
        case .from600Up:
            return height >= 600
        case .from500To600:
            return height >= 500 && height < 600
        case .from400To500:
            return height >= 400 && height < 500
        case .from300To400:
            return height >= 300 && height < 400
        case .from200To300:
            return height >= 200 && height < 300
        case .from100To200:
            return height >= 100 && height < 200
        case .below100:
            return height < 100
        }
    }
}

enum AdvancedFilterCombinationMode: Int, CaseIterable, Codable {
    case matchAll
    case matchAny

    var title: String {
        switch self {
        case .matchAll:
            return "All Conditions"
        case .matchAny:
            return "Any Condition"
        }
    }
}

struct AdvancedHillFilter: Codable, Equatable {
    var selectedClassificationCodes: [String] = []
    var minimumHeightMeters: Double?
    var maximumHeightMeters: Double?
    var combinationMode: AdvancedFilterCombinationMode = .matchAll

    var isEmpty: Bool {
        selectedClassificationCodes.isEmpty && minimumHeightMeters == nil && maximumHeightMeters == nil
    }

    var normalizedMinimumHeightMeters: Double? {
        guard let minimumHeightMeters, let maximumHeightMeters else { return minimumHeightMeters }
        return min(minimumHeightMeters, maximumHeightMeters)
    }

    var normalizedMaximumHeightMeters: Double? {
        guard let minimumHeightMeters, let maximumHeightMeters else { return maximumHeightMeters }
        return max(minimumHeightMeters, maximumHeightMeters)
    }
}

struct AdvancedHillFilterPreset: Codable, Equatable {
    var id: String
    var name: String
    var filter: AdvancedHillFilter
}

enum TrackRecordingQuality: Int, CaseIterable {
    case batterySaver
    case standard
    case highDetail

    var title: String {
        switch self {
        case .batterySaver:
            return "Saver"
        case .standard:
            return "Standard"
        case .highDetail:
            return "Detail"
        }
    }

    var descriptionText: String {
        switch self {
        case .batterySaver:
            return "Fewer track points. Best for longer battery life."
        case .standard:
            return "Balanced detail for normal walking."
        case .highDetail:
            return "Most track detail. Best for steeper or more complex ground."
        }
    }

    var trailRecordingPolicy: TrailRecordingPolicy {
        switch self {
        case .batterySaver:
            return TrailRecordingPolicy(
                minimumDistance: 12,
                maximumSamplingInterval: 10,
                minimumTimedSampleDistance: 5
            )
        case .standard:
            return TrailRecordingPolicy(
                minimumDistance: 8,
                maximumSamplingInterval: 6,
                minimumTimedSampleDistance: 3
            )
        case .highDetail:
            return TrailRecordingPolicy(
                minimumDistance: 5,
                maximumSamplingInterval: 4,
                minimumTimedSampleDistance: 2
            )
        }
    }
}

enum MapOrientationMode: Int, CaseIterable {
    case northUp
    case headsUp

    var title: String {
        switch self {
        case .northUp:
            return "North Up"
        case .headsUp:
            return "Heads Up"
        }
    }

    var descriptionText: String {
        switch self {
        case .northUp:
            return "Map stays north-up. Your position marker shows direction."
        case .headsUp:
            return "Map rotates toward your heading while follow mode is active."
        }
    }
}

enum CachedAreaDetailLevel: String, CaseIterable {
    case light
    case standard
    case deep

    var title: String {
        switch self {
        case .light:
            return "Light"
        case .standard:
            return "Standard"
        case .deep:
            return "Deep"
        }
    }

    var zoomRange: ClosedRange<Double> {
        switch self {
        case .light:
            return 8...12
        case .standard:
            return 8...14
        case .deep:
            return 8...16
        }
    }
}

final class GPXWaypointAnnotation: MLNPointAnnotation {}

final class ImportedGPXPolyline: MLNPolyline {}
final class TrailPolyline: MLNPolyline {}
final class BreadcrumbPolyline: MLNPolyline {}
final class GoToPolyline: MLNPolyline {}
final class StartPlaceSelectionAnnotation: MLNPointAnnotation {
    var markerColor: UIColor = .systemBlue
}
final class CoillteTrailPolyline: MLNPolyline {}
final class SportIrelandTrailPolyline: MLNPolyline {}
final class OutscapeTrailPolyline: MLNPolyline {}
final class CachedAreaPolygon: MLNPolygon {
    var cachedAreaID: String?
    var cachedAreaName: String?
}
final class CachedAreaBorderPolyline: MLNPolyline {
    var cachedAreaID: String?
    var cachedAreaName: String?
}

struct CachedOfflineArea {
    enum Status: String {
        case ready
        case downloading
        case partial
        case failed

        var title: String {
            switch self {
            case .ready:
                return "Ready"
            case .downloading:
                return "Downloading"
            case .partial:
                return "Partial"
            case .failed:
                return "Failed"
            }
        }
    }

    let id: String
    let name: String
    let detailLevel: CachedAreaDetailLevel
    let bounds: MLNCoordinateBounds
    let status: Status
    let byteCount: UInt64
    let statusMessage: String?
}

struct TrailRecordingPolicy {
    let minimumDistance: CLLocationDistance
    let maximumSamplingInterval: TimeInterval
    let minimumTimedSampleDistance: CLLocationDistance
}

enum TrailAppendResult {
    case ignored
    case previewOnly
    case appended
}

struct OfflinePackContext {
    let id: String
    let name: String
    let detailLevel: CachedAreaDetailLevel
}

final class PeakSelectionStore {
    var selectedPeakID: String?
    var isRefreshingSelectionState = false
}

struct GoToTarget {
    let title: String
    let subtitle: String?
    let coordinate: CLLocationCoordinate2D
    let peak: Peak?

    init(peak: Peak, subtitle: String?) {
        self.title = peak.name
        self.subtitle = subtitle
        self.coordinate = peak.coordinate
        self.peak = peak
    }

    init(title: String, subtitle: String?, coordinate: CLLocationCoordinate2D) {
        self.title = title
        self.subtitle = subtitle
        self.coordinate = coordinate
        self.peak = nil
    }
}

final class GoToSessionStore {
    var activeTarget: GoToTarget?
    var pendingTarget: GoToTarget?
    var lastLineStartLocation: CLLocation?

    func activate(_ target: GoToTarget) {
        pendingTarget = nil
        activeTarget = target
    }

    func activate(_ peak: Peak, subtitle: String?) {
        activate(GoToTarget(peak: peak, subtitle: subtitle))
    }

    func clear() {
        pendingTarget = nil
        activeTarget = nil
        lastLineStartLocation = nil
    }

    func bearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> CLLocationDirection {
        let startLatitude = start.latitude * .pi / 180
        let startLongitude = start.longitude * .pi / 180
        let endLatitude = end.latitude * .pi / 180
        let endLongitude = end.longitude * .pi / 180

        let longitudeDifference = endLongitude - startLongitude
        let y = sin(longitudeDifference) * cos(endLatitude)
        let x = cos(startLatitude) * sin(endLatitude) - sin(startLatitude) * cos(endLatitude) * cos(longitudeDifference)
        let radians = atan2(y, x)
        let degrees = radians * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }

    func shouldRefreshPolyline(
        from start: CLLocationCoordinate2D,
        minimumMovementDistance: CLLocationDistance
    ) -> Bool {
        let startLocation = CLLocation(latitude: start.latitude, longitude: start.longitude)
        guard let lastLineStartLocation else {
            self.lastLineStartLocation = startLocation
            return true
        }

        guard startLocation.distance(from: lastLineStartLocation) >= minimumMovementDistance else {
            return false
        }

        self.lastLineStartLocation = startLocation
        return true
    }
}

final class MapViewportStateStore {
    var hasCompletedInitialApplicationActivation = false
    var shouldAutoRecenterOnAppActive = false
    var shouldResumeFollowModeOnAppActive = false
    var shouldResumeFollowModeAfterAuthorization = false

    func handleApplicationDidBecomeActive(
        canUseLocation: Bool,
        isTrailRecording: Bool,
        hasActiveGoTo: Bool,
        hasCurrentUserCoordinate: Bool
    ) -> Bool {
        guard hasCompletedInitialApplicationActivation else {
            hasCompletedInitialApplicationActivation = true
            shouldAutoRecenterOnAppActive = false
            shouldResumeFollowModeOnAppActive = false
            return false
        }

        let shouldRecenterOnReopen = isTrailRecording || shouldResumeFollowModeOnAppActive
        shouldAutoRecenterOnAppActive = canUseLocation && shouldRecenterOnReopen && !hasActiveGoTo
        guard shouldAutoRecenterOnAppActive, hasCurrentUserCoordinate else {
            return false
        }

        shouldAutoRecenterOnAppActive = false
        shouldResumeFollowModeOnAppActive = false
        return true
    }

    func handleApplicationDidEnterBackground(wasFollowingUser: Bool) {
        shouldAutoRecenterOnAppActive = false
        shouldResumeFollowModeOnAppActive = wasFollowingUser
    }

    func consumePendingAutoRecenter() -> Bool {
        guard shouldAutoRecenterOnAppActive else { return false }
        shouldAutoRecenterOnAppActive = false
        shouldResumeFollowModeOnAppActive = false
        return true
    }

    func requestFollowModeAfterAuthorization() {
        shouldResumeFollowModeAfterAuthorization = true
    }

    func consumeFollowModeAfterAuthorization() -> Bool {
        guard shouldResumeFollowModeAfterAuthorization else { return false }
        shouldResumeFollowModeAfterAuthorization = false
        return true
    }

    func clearLocationDependentResumeState() {
        shouldAutoRecenterOnAppActive = false
        shouldResumeFollowModeOnAppActive = false
        shouldResumeFollowModeAfterAuthorization = false
    }

    func shouldUseHeadsUp(
        mapOrientationMode: MapOrientationMode,
        isFollowingUser: Bool
    ) -> Bool {
        mapOrientationMode == .headsUp && isFollowingUser
    }

    func shouldScheduleInactivityRecenter(
        isTrailRecording: Bool,
        hasActiveGoTo: Bool
    ) -> Bool {
        !isTrailRecording && !hasActiveGoTo
    }

    func normalizedDirection(_ direction: CLLocationDirection) -> CLLocationDirection {
        let normalized = direction.truncatingRemainder(dividingBy: 360)
        return normalized >= 0 ? normalized : normalized + 360
    }

    func isNorthUp(direction: CLLocationDirection) -> Bool {
        direction < 1 || direction > 359
    }
}

struct PeakSelectionTransition {
    let selectedPeakID: String?
    let shouldReloadAnnotations: Bool
    let calloutPeakID: String?
}

final class PeakAnnotationPresentationStore {
    func makePeakAnnotations(
        from peaks: [Peak],
        subtitleProvider: (Peak) -> String
    ) -> [PeakAnnotation] {
        peaks.map { peak in
            let annotation = PeakAnnotation()
            annotation.coordinate = peak.coordinate
            annotation.title = peak.name
            annotation.subtitle = subtitleProvider(peak)
            annotation.peak = peak
            return annotation
        }
    }

    func peakAnnotations(from annotations: [MLNAnnotation]?) -> [PeakAnnotation] {
        annotations?.compactMap { $0 as? PeakAnnotation } ?? []
    }

    func peakAnnotation(for peakID: String, in annotations: [MLNAnnotation]?) -> PeakAnnotation? {
        peakAnnotations(from: annotations).first(where: { $0.peak?.id == peakID })
    }

    func selectionTransition(
        for annotation: MLNAnnotation,
        isRefreshingSelectionState: Bool
    ) -> PeakSelectionTransition? {
        guard !isRefreshingSelectionState else { return nil }
        guard let peakAnnotation = annotation as? PeakAnnotation,
              let peak = peakAnnotation.peak else {
            return nil
        }

        return PeakSelectionTransition(
            selectedPeakID: peak.id,
            shouldReloadAnnotations: true,
            calloutPeakID: peak.id
        )
    }

    func deselectionTransition(
        for annotation: MLNAnnotation,
        selectedPeakID: String?,
        isRefreshingSelectionState: Bool
    ) -> PeakSelectionTransition? {
        guard !isRefreshingSelectionState else { return nil }
        guard let peakAnnotation = annotation as? PeakAnnotation,
              let peak = peakAnnotation.peak,
              selectedPeakID == peak.id else {
            return nil
        }

        return PeakSelectionTransition(
            selectedPeakID: nil,
            shouldReloadAnnotations: true,
            calloutPeakID: nil
        )
    }

    func isSelectedPeak(_ peak: Peak, selectedPeakID: String?) -> Bool {
        selectedPeakID == peak.id
    }
}

enum LocationAuthorizationResolution: Equatable {
    case proceed
    case requestPermission
    case explainTrailRecordingPermission
    case showAccessAlert(title: String, message: String)
}

final class LocationAuthorizationPolicyStore {
    func canUseLocation(_ status: CLAuthorizationStatus) -> Bool {
        status == .authorizedWhenInUse || status == .authorizedAlways
    }

    func shouldAllowBackgroundRecording(
        authorizationStatus: CLAuthorizationStatus,
        isTrailRecording: Bool
    ) -> Bool {
        canUseLocation(authorizationStatus) && isTrailRecording
    }

    func goToResolution(for status: CLAuthorizationStatus) -> LocationAuthorizationResolution {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            return .proceed
        case .notDetermined:
            return .requestPermission
        case .denied, .restricted:
            return .showAccessAlert(
                title: "Location Access Needed",
                message: "Allow location access to show your position and draw the live Go To line to the selected destination."
            )
        @unknown default:
            return .showAccessAlert(
                title: "Location Access Needed",
                message: "Allow location access to show your position and draw the live Go To line to the selected destination."
            )
        }
    }

    func trailRecordingResolution(for status: CLAuthorizationStatus) -> LocationAuthorizationResolution {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            return .proceed
        case .notDetermined:
            return .explainTrailRecordingPermission
        case .denied, .restricted:
            return .showAccessAlert(
                title: "Location Access Needed",
                message: "Allow location access to record a GPX track and keep it updating while you are on the move."
            )
        @unknown default:
            return .showAccessAlert(
                title: "Location Access Needed",
                message: "Allow location access to record a GPX track and keep it updating while you are on the move."
            )
        }
    }

    func recenterResolution(for status: CLAuthorizationStatus) -> LocationAuthorizationResolution {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            return .proceed
        case .notDetermined:
            return .requestPermission
        case .denied, .restricted:
            return .showAccessAlert(
                title: "Location Access Needed",
                message: "Allow location access to show your position on the map and re-centre on where you are."
            )
        @unknown default:
            return .showAccessAlert(
                title: "Location Access Needed",
                message: "Allow location access to show your position on the map and re-centre on where you are."
            )
        }
    }
}

final class HillFilterEngine {
    func filteredPeaks(
        from peaks: [Peak],
        mode: HillFilterMode,
        schema: MenuFilterSchema,
        selectedHeightBands: Set<HeightFilterBand>,
        selectedClassificationCodes: Set<String>,
        advancedHillFilter: AdvancedHillFilter
    ) -> [Peak] {
        switch mode {
        case .simple:
            switch schema {
            case .height:
                guard !selectedHeightBands.isEmpty else { return peaks }
                return peaks.filter { peak in
                    selectedHeightBands.contains { $0.includes(height: peak.heightM) }
                }
            case .classification:
                guard !selectedClassificationCodes.isEmpty else { return peaks }
                return peaks.filter { peak in
                    let peakCodes = Set(classificationCodes(for: peak))
                    return !peakCodes.isDisjoint(with: selectedClassificationCodes)
                }
            }
        case .advanced:
            guard !advancedHillFilter.isEmpty else { return peaks }

            let selectedCodes = Set(advancedHillFilter.selectedClassificationCodes)
            let minimumHeight = advancedHillFilter.normalizedMinimumHeightMeters
            let maximumHeight = advancedHillFilter.normalizedMaximumHeightMeters

            return peaks.filter { peak in
                let classificationMatches: Bool? = {
                    guard !selectedCodes.isEmpty else { return nil }
                    let peakCodes = Set(classificationCodes(for: peak))
                    switch advancedHillFilter.combinationMode {
                    case .matchAll:
                        return selectedCodes.isSubset(of: peakCodes)
                    case .matchAny:
                        return !peakCodes.isDisjoint(with: selectedCodes)
                    }
                }()

                let heightMatches: Bool? = (minimumHeight == nil && maximumHeight == nil)
                    ? nil
                    : {
                        if let minimumHeight, peak.heightM < minimumHeight { return false }
                        if let maximumHeight, peak.heightM > maximumHeight { return false }
                        return true
                    }()

                let activeMatches = [classificationMatches, heightMatches].compactMap { $0 }
                guard !activeMatches.isEmpty else { return true }

                switch advancedHillFilter.combinationMode {
                case .matchAll:
                    return activeMatches.allSatisfy { $0 }
                case .matchAny:
                    return activeMatches.contains(true)
                }
            }
        }
    }

    func advancedFilterSummaryText(_ filter: AdvancedHillFilter) -> String {
        guard !filter.isEmpty else {
            return "No advanced conditions set. All hills are shown."
        }

        var parts: [String] = []
        if !filter.selectedClassificationCodes.isEmpty {
            let names = filter.selectedClassificationCodes
                .map { displayNameForClassificationCode($0) ?? $0 }
                .sorted()
            parts.append(names.joined(separator: ", "))
        }

        let minimumHeight = filter.normalizedMinimumHeightMeters
        let maximumHeight = filter.normalizedMaximumHeightMeters
        switch (minimumHeight, maximumHeight) {
        case let (.some(minimumHeight), .some(maximumHeight)):
            parts.append("\(formattedMeters(minimumHeight))-\(formattedMeters(maximumHeight))")
        case let (.some(minimumHeight), nil):
            parts.append("\(formattedMeters(minimumHeight)) and up")
        case let (nil, .some(maximumHeight)):
            parts.append("up to \(formattedMeters(maximumHeight))")
        case (nil, nil):
            break
        }

        let logicPrefix = filter.combinationMode == .matchAll ? "Match all" : "Match any"
        return "\(logicPrefix): \(parts.joined(separator: " • "))"
    }

    private func formattedMeters(_ value: Double) -> String {
        "\(Int(value.rounded()))m"
    }
}

struct PersistedFilterState {
    let selectedFilterSchema: MenuFilterSchema
    let selectedHillFilterMode: HillFilterMode
    let displayUnitSystem: DisplayUnitSystem
    let mapOrientationMode: MapOrientationMode
    let isMapInteractionLocked: Bool
    let trackRecordingQuality: TrackRecordingQuality
    let showsCompactRecordingGrid: Bool
    let showsSnailTrail: Bool
    let snailTrailColor: UIColor
    let goToLineColor: UIColor
    let recordedTrackColor: UIColor
    let importedTrackColor: UIColor
    let selectedHeightBandIDs: [String]
    let selectedClassificationCodes: [String]
    let advancedHillFilter: AdvancedHillFilter
    let savedAdvancedHillFilterPresets: [AdvancedHillFilterPreset]
}

final class AppPreferencesStore {
    private enum Key {
        static let loggedPeaks = "loggedPeakIDs"
        static let filterSchema = "selectedFilterSchema"
        static let hillFilterMode = "selectedHillFilterMode"
        static let displayUnitSystem = "displayUnitSystem"
        static let mapOrientationMode = "mapOrientationMode"
        static let isMapInteractionLocked = "isMapInteractionLocked"
        static let trackRecordingQuality = "trackRecordingQuality"
        static let showsCompactRecordingGrid = "showsCompactRecordingGrid"
        static let showsSnailTrail = "showsSnailTrail"
        static let snailTrailColor = "snailTrailColor"
        static let goToLineColor = "goToLineColor"
        static let recordedTrackColor = "recordedTrackColor"
        static let importedTrackColor = "importedTrackColor"
        static let selectedHeightBands = "selectedHeightBands"
        static let selectedClassificationCodes = "selectedClassificationCodes"
        static let advancedHillFilter = "advancedHillFilter"
        static let advancedHillFilterPresets = "advancedHillFilterPresets"
        static let markerColorSchema = "markerColorSchema"
        static let showsHillMarkers = "showsHillMarkers"
        static let visibleStartPlaceProviders = "visibleStartPlaceProviders"
        static let startPlaceRouteLengthFilter = "startPlaceRouteLengthFilter"
        static let localHundredConfiguration = "localHundredConfiguration"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadLoggedPeakIDs() -> Set<String> {
        Set(userDefaults.stringArray(forKey: Key.loggedPeaks) ?? [])
    }

    func saveLoggedPeakIDs(_ ids: Set<String>) {
        userDefaults.set(Array(ids).sorted(), forKey: Key.loggedPeaks)
    }

    func loadFilterState() -> PersistedFilterState {
        let selectedFilterSchema = MenuFilterSchema(rawValue: userDefaults.integer(forKey: Key.filterSchema)) ?? .classification
        let selectedHillFilterMode: HillFilterMode = .simple
        let displayUnitSystem = DisplayUnitSystem(rawValue: userDefaults.integer(forKey: Key.displayUnitSystem)) ?? .metric
        let mapOrientationMode = MapOrientationMode(rawValue: userDefaults.integer(forKey: Key.mapOrientationMode)) ?? .northUp
        userDefaults.removeObject(forKey: Key.isMapInteractionLocked)
        let isMapInteractionLocked = false
        let trackRecordingQuality = TrackRecordingQuality(rawValue: userDefaults.integer(forKey: Key.trackRecordingQuality)) ?? .standard
        let showsCompactRecordingGrid = userDefaults.object(forKey: Key.showsCompactRecordingGrid) as? Bool ?? true
        let showsSnailTrail = userDefaults.object(forKey: Key.showsSnailTrail) as? Bool ?? true
        let snailTrailColor = loadColor(forKey: Key.snailTrailColor) ?? UIColor.systemRed.withAlphaComponent(0.75)
        let goToLineColor = loadColor(forKey: Key.goToLineColor) ?? .systemTeal
        let recordedTrackColor = loadColor(forKey: Key.recordedTrackColor) ?? .systemRed
        let importedTrackColor = loadColor(forKey: Key.importedTrackColor) ?? .systemTeal
        let selectedHeightBandIDs = userDefaults.stringArray(forKey: Key.selectedHeightBands) ?? []
        let selectedClassificationCodes = userDefaults.stringArray(forKey: Key.selectedClassificationCodes) ?? []
        let advancedHillFilter: AdvancedHillFilter = loadCodableValue(forKey: Key.advancedHillFilter) ?? AdvancedHillFilter()
        let savedAdvancedHillFilterPresets: [AdvancedHillFilterPreset] = loadCodableValue(forKey: Key.advancedHillFilterPresets) ?? []

        return PersistedFilterState(
            selectedFilterSchema: selectedFilterSchema,
            selectedHillFilterMode: selectedHillFilterMode,
            displayUnitSystem: displayUnitSystem,
            mapOrientationMode: mapOrientationMode,
            isMapInteractionLocked: isMapInteractionLocked,
            trackRecordingQuality: trackRecordingQuality,
            showsCompactRecordingGrid: showsCompactRecordingGrid,
            showsSnailTrail: showsSnailTrail,
            snailTrailColor: snailTrailColor,
            goToLineColor: goToLineColor,
            recordedTrackColor: recordedTrackColor,
            importedTrackColor: importedTrackColor,
            selectedHeightBandIDs: selectedHeightBandIDs,
            selectedClassificationCodes: selectedClassificationCodes,
            advancedHillFilter: advancedHillFilter,
            savedAdvancedHillFilterPresets: savedAdvancedHillFilterPresets
        )
    }

    func saveFilterState(
        selectedFilterSchema: MenuFilterSchema,
        selectedHillFilterMode: HillFilterMode,
        selectedHeightBandIDs: [String],
        selectedClassificationCodes: [String],
        advancedHillFilter: AdvancedHillFilter,
        savedAdvancedHillFilterPresets: [AdvancedHillFilterPreset]
    ) {
        userDefaults.set(selectedFilterSchema.rawValue, forKey: Key.filterSchema)
        userDefaults.set(HillFilterMode.simple.rawValue, forKey: Key.hillFilterMode)
        userDefaults.set(selectedHeightBandIDs.sorted(), forKey: Key.selectedHeightBands)
        userDefaults.set(selectedClassificationCodes.sorted(), forKey: Key.selectedClassificationCodes)
        saveCodableValue(advancedHillFilter, forKey: Key.advancedHillFilter)
        saveCodableValue(savedAdvancedHillFilterPresets, forKey: Key.advancedHillFilterPresets)
    }

    func saveDisplayUnitSystem(_ displayUnitSystem: DisplayUnitSystem) {
        userDefaults.set(displayUnitSystem.rawValue, forKey: Key.displayUnitSystem)
    }

    func saveMapOrientationMode(_ mapOrientationMode: MapOrientationMode) {
        userDefaults.set(mapOrientationMode.rawValue, forKey: Key.mapOrientationMode)
    }

    func saveMapInteractionLocked(_ isLocked: Bool) {
        userDefaults.set(isLocked, forKey: Key.isMapInteractionLocked)
    }

    func loadMarkerColorSchema() -> MenuFilterSchema {
        .classification
    }

    func saveMarkerColorSchema(_ schema: MenuFilterSchema) {
        userDefaults.set(MenuFilterSchema.classification.rawValue, forKey: Key.markerColorSchema)
    }

    func loadMarkerColor(for optionID: String) -> UIColor? {
        guard let encodedColor = userDefaults.string(forKey: markerColorDefaultsKey(for: optionID)) else { return nil }
        return color(from: encodedColor)
    }

    func saveMarkerColor(_ color: UIColor, for optionID: String) {
        userDefaults.set(encodedString(for: color), forKey: markerColorDefaultsKey(for: optionID))
    }

    func loadShowsHillMarkers() -> Bool {
        userDefaults.object(forKey: Key.showsHillMarkers) as? Bool ?? true
    }

    func saveShowsHillMarkers(_ showsHillMarkers: Bool) {
        userDefaults.set(showsHillMarkers, forKey: Key.showsHillMarkers)
    }

    func loadVisibleStartPlaceProviders() -> Set<StartPlaceProvider> {
        guard let rawValues = userDefaults.stringArray(forKey: Key.visibleStartPlaceProviders) else {
            return [.mountainViews]
        }
        return Set(rawValues.compactMap(StartPlaceProvider.init(rawValue:)))
    }

    func saveVisibleStartPlaceProviders(_ providers: Set<StartPlaceProvider>) {
        userDefaults.set(providers.map(\.rawValue).sorted(), forKey: Key.visibleStartPlaceProviders)
    }

    func loadStartPlaceRouteLengthFilter() -> StartPlaceRouteLengthFilter {
        StartPlaceRouteLengthFilter(rawValue: userDefaults.integer(forKey: Key.startPlaceRouteLengthFilter)) ?? .off
    }

    func saveStartPlaceRouteLengthFilter(_ filter: StartPlaceRouteLengthFilter) {
        userDefaults.set(filter.rawValue, forKey: Key.startPlaceRouteLengthFilter)
    }

    func saveTrackRecordingQuality(_ trackRecordingQuality: TrackRecordingQuality) {
        userDefaults.set(trackRecordingQuality.rawValue, forKey: Key.trackRecordingQuality)
    }

    func loadShowsCompactRecordingGrid() -> Bool {
        userDefaults.object(forKey: Key.showsCompactRecordingGrid) as? Bool ?? true
    }

    func saveShowsCompactRecordingGrid(_ showsCompactRecordingGrid: Bool) {
        userDefaults.set(showsCompactRecordingGrid, forKey: Key.showsCompactRecordingGrid)
    }

    func saveShowsSnailTrail(_ showsSnailTrail: Bool) {
        userDefaults.set(showsSnailTrail, forKey: Key.showsSnailTrail)
    }

    func saveSnailTrailColor(_ color: UIColor) {
        userDefaults.set(encodedString(for: color), forKey: Key.snailTrailColor)
    }

    func saveRecordedTrackColor(_ color: UIColor) {
        userDefaults.set(encodedString(for: color), forKey: Key.recordedTrackColor)
    }

    func saveGoToLineColor(_ color: UIColor) {
        userDefaults.set(encodedString(for: color), forKey: Key.goToLineColor)
    }

    func saveImportedTrackColor(_ color: UIColor) {
        userDefaults.set(encodedString(for: color), forKey: Key.importedTrackColor)
    }

    func loadNearestHundredConfiguration() -> NearestHundredConfiguration? {
        loadCodableValue(forKey: Key.localHundredConfiguration)
    }

    func saveNearestHundredConfiguration(_ configuration: NearestHundredConfiguration) {
        saveCodableValue(configuration, forKey: Key.localHundredConfiguration)
    }

    func clearNearestHundredConfiguration() {
        userDefaults.removeObject(forKey: Key.localHundredConfiguration)
    }

    func loadLocalHundredConfiguration() -> LocalHundredConfiguration? {
        loadNearestHundredConfiguration()
    }

    func saveLocalHundredConfiguration(_ configuration: LocalHundredConfiguration) {
        saveNearestHundredConfiguration(configuration)
    }

    func clearLocalHundredConfiguration() {
        clearNearestHundredConfiguration()
    }

    private func markerColorDefaultsKey(for optionID: String) -> String {
        "markerColor.\(optionID)"
    }

    private func saveCodableValue<T: Codable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        userDefaults.set(data, forKey: key)
    }

    private func loadCodableValue<T: Codable>(forKey key: String) -> T? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func loadColor(forKey key: String) -> UIColor? {
        guard let encodedColor = userDefaults.string(forKey: key) else { return nil }
        return color(from: encodedColor)
    }

    private func encodedString(for color: UIColor) -> String {
        guard let components = color.cgColor.components else { return "" }
        let normalizedComponents: [CGFloat]
        if components.count >= 4 {
            normalizedComponents = Array(components.prefix(4))
        } else if components.count == 2 {
            normalizedComponents = [components[0], components[0], components[0], components[1]]
        } else {
            normalizedComponents = [0, 0, 0, 1]
        }
        return normalizedComponents
            .map { String(format: "%.4f", $0) }
            .joined(separator: ",")
    }

    private func color(from encodedString: String) -> UIColor? {
        let values = encodedString.split(separator: ",").compactMap { Double($0) }
        guard values.count == 4 else { return nil }
        return UIColor(
            red: values[0],
            green: values[1],
            blue: values[2],
            alpha: values[3]
        )
    }
}

final class LoggedPeakController {
    private let preferencesStore: AppPreferencesStore
    private(set) var loggedPeakIDs: Set<String>

    init(preferencesStore: AppPreferencesStore = AppPreferencesStore()) {
        self.preferencesStore = preferencesStore
        self.loggedPeakIDs = preferencesStore.loadLoggedPeakIDs()
    }

    func migrateIfNeeded(using peaks: [Peak]) {
        guard !loggedPeakIDs.isEmpty, !peaks.isEmpty else { return }

        let migratedLoggedPeakIDs = Set(loggedPeakIDs.compactMap { storedID -> String? in
            if peaks.contains(where: { $0.id == storedID }) {
                return storedID
            }

            if let matchingPeak = peaks.first(where: { $0.legacyID == storedID }) {
                return matchingPeak.id
            }

            return nil
        })

        guard migratedLoggedPeakIDs != loggedPeakIDs else { return }
        loggedPeakIDs = migratedLoggedPeakIDs
        persist()
    }

    func contains(_ peak: Peak) -> Bool {
        loggedPeakIDs.contains(peak.id)
    }

    @discardableResult
    func log(_ peak: Peak) -> Bool {
        let (inserted, _) = loggedPeakIDs.insert(peak.id)
        if inserted {
            persist()
        }
        return inserted
    }

    @discardableResult
    func unlog(_ peak: Peak) -> Bool {
        let removed = loggedPeakIDs.remove(peak.id) != nil
        if removed {
            persist()
        }
        return removed
    }

    private func persist() {
        preferencesStore.saveLoggedPeakIDs(loggedPeakIDs)
    }
}

final class OfflineCacheStore {
    private enum Key {
        static let names = "cachedOfflineAreaNames"
        static let failures = "cachedOfflineAreaFailures"
        static let completedIDs = "cachedOfflineAreaCompletedIDs"
        static let byteCounts = "cachedOfflineAreaByteCounts"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func encodedOfflineContext(for cachedArea: CachedOfflineArea) -> Data {
        let context: [String: String] = [
            "id": cachedArea.id,
            "name": cachedArea.name,
            "detailLevel": cachedArea.detailLevel.rawValue
        ]
        return (try? JSONSerialization.data(withJSONObject: context, options: [])) ?? Data()
    }

    func decodedOfflineContext(from data: Data) -> OfflinePackContext? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data, options: []),
            let dictionary = object as? [String: Any],
            let name = dictionary["name"] as? String
        else {
            return nil
        }

        let id = (dictionary["id"] as? String) ?? name
        let detailLevel = CachedAreaDetailLevel(rawValue: dictionary["detailLevel"] as? String ?? "") ?? .standard
        return OfflinePackContext(id: id, name: name, detailLevel: detailLevel)
    }

    func loadNameOverrides() -> [String: String] {
        userDefaults.dictionary(forKey: Key.names) as? [String: String] ?? [:]
    }

    func saveNameOverrides(_ overrides: [String: String]) {
        userDefaults.set(overrides, forKey: Key.names)
    }

    func loadFailures() -> [String: String] {
        userDefaults.dictionary(forKey: Key.failures) as? [String: String] ?? [:]
    }

    func saveFailures(_ failures: [String: String]) {
        userDefaults.set(failures, forKey: Key.failures)
    }

    func loadCompletedIDs() -> Set<String> {
        Set(userDefaults.stringArray(forKey: Key.completedIDs) ?? [])
    }

    func saveCompletedIDs(_ ids: Set<String>) {
        userDefaults.set(Array(ids).sorted(), forKey: Key.completedIDs)
    }

    func loadByteCounts() -> [String: UInt64] {
        let rawDictionary = userDefaults.dictionary(forKey: Key.byteCounts) as? [String: NSNumber] ?? [:]
        return rawDictionary.reduce(into: [:]) { result, entry in
            result[entry.key] = entry.value.uint64Value
        }
    }

    func saveByteCounts(_ byteCounts: [String: UInt64]) {
        let rawDictionary = byteCounts.reduce(into: [String: NSNumber]()) { result, entry in
            result[entry.key] = NSNumber(value: entry.value)
        }
        userDefaults.set(rawDictionary, forKey: Key.byteCounts)
    }

    func clearTransientMetadata(for id: String) {
        var failures = loadFailures()
        failures.removeValue(forKey: id)
        saveFailures(failures)

        var completedIDs = loadCompletedIDs()
        completedIDs.remove(id)
        saveCompletedIDs(completedIDs)

        var byteCounts = loadByteCounts()
        byteCounts.removeValue(forKey: id)
        saveByteCounts(byteCounts)
    }

    func removeAreaMetadata(for id: String) {
        var overrides = loadNameOverrides()
        overrides.removeValue(forKey: id)
        saveNameOverrides(overrides)
        clearTransientMetadata(for: id)
    }

    func clearAllMetadata() {
        saveNameOverrides([:])
        saveFailures([:])
        saveCompletedIDs(Set<String>())
        saveByteCounts([:])
    }

    func markCompleted(id: String, byteCount: UInt64) {
        var failures = loadFailures()
        failures.removeValue(forKey: id)
        saveFailures(failures)

        var completedIDs = loadCompletedIDs()
        completedIDs.insert(id)
        saveCompletedIDs(completedIDs)

        var byteCounts = loadByteCounts()
        byteCounts[id] = byteCount
        saveByteCounts(byteCounts)
    }

    func markFailed(id: String, message: String) {
        var failures = loadFailures()
        failures[id] = message
        saveFailures(failures)

        var completedIDs = loadCompletedIDs()
        completedIDs.remove(id)
        saveCompletedIDs(completedIDs)

        var byteCounts = loadByteCounts()
        byteCounts.removeValue(forKey: id)
        saveByteCounts(byteCounts)
    }

    func normalizedFailureMessage(_ message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercase = trimmed.lowercased()

        if lowercase.contains("not connected") || lowercase.contains("offline") {
            return "No network connection."
        }

        if lowercase.contains("timed out") {
            return "Download timed out."
        }

        if lowercase.contains("storage") || lowercase.contains("space") || lowercase.contains("disk") || lowercase.contains("full") {
            return "Not enough storage space."
        }

        if lowercase.contains("cancel") {
            return "Download was cancelled."
        }

        return trimmed.isEmpty ? "Offline download failed." : trimmed
    }

    func isOfflinePackComplete(_ pack: MLNOfflinePack) -> Bool {
        let progress = pack.progress
        guard progress.countOfResourcesExpected > 0 else { return false }
        return progress.countOfResourcesCompleted >= progress.countOfResourcesExpected
    }

    func isOfflinePackActive(_ pack: MLNOfflinePack) -> Bool {
        if isOfflinePackComplete(pack) {
            return false
        }

        if let id = decodedOfflineContext(from: pack.context)?.id,
           loadCompletedIDs().contains(id) {
            return false
        }

        let progress = pack.progress
        return progress.countOfResourcesExpected == 0 ||
            progress.countOfResourcesCompleted < progress.countOfResourcesExpected
    }

    func cachedOfflineArea(
        from pack: MLNOfflinePack,
        activeDownloadID: String?
    ) -> CachedOfflineArea? {
        guard let region = pack.region as? MLNTilePyramidOfflineRegion else { return nil }
        let decodedContext = decodedOfflineContext(from: pack.context)
        let storedName = decodedContext?.name ?? "Offline Area"
        let id = decodedContext?.id ?? storedName
        let detailLevel = decodedContext?.detailLevel ?? .standard
        let overrides = loadNameOverrides()
        let name = overrides[id] ?? storedName
        let progress = pack.progress
        let liveByteCount = UInt64(max(0, progress.countOfBytesCompleted))
        let storedByteCounts = loadByteCounts()
        let failures = loadFailures()
        let completedIDs = loadCompletedIDs()
        let byteCount = max(liveByteCount, storedByteCounts[id] ?? 0)
        let failureMessage = failures[id].map(normalizedFailureMessage(_:))
        let status: CachedOfflineArea.Status

        if isOfflinePackComplete(pack) || completedIDs.contains(id) {
            status = .ready
        } else if failures[id] != nil {
            status = .failed
        } else if activeDownloadID == id {
            status = .downloading
        } else {
            status = .partial
        }

        return CachedOfflineArea(
            id: id,
            name: name,
            detailLevel: detailLevel,
            bounds: region.bounds,
            status: status,
            byteCount: byteCount,
            statusMessage: failureMessage
        )
    }

    func rebuildCachedOfflineAreas(from packs: [MLNOfflinePack]) -> (areas: [CachedOfflineArea], activePack: MLNOfflinePack?) {
        let activePack = packs.first(where: isOfflinePackActive(_:))
        let activeDownloadID = activePack.flatMap { decodedOfflineContext(from: $0.context)?.id }

        let areas = packs
            .compactMap { cachedOfflineArea(from: $0, activeDownloadID: activeDownloadID) }
            .sorted {
                if $0.status != $1.status {
                    let order: [CachedOfflineArea.Status: Int] = [
                        .downloading: 0,
                        .failed: 1,
                        .partial: 2,
                        .ready: 3
                    ]
                    return (order[$0.status] ?? 99) < (order[$1.status] ?? 99)
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

        return (areas, activePack)
    }
}

final class TrailRecordingStore {
    var isRecording = false
    var recordedTrailPoints: [RecordedTrackPoint] = []
    var breadcrumbTrailPoints: [RecordedTrackPoint] = []

    func restoreRecordedTrailPoints(_ points: [RecordedTrackPoint]) {
        recordedTrailPoints = points
        isRecording = false
    }

    func startRecording(initialLocation: CLLocation?, maximumVerticalAccuracy: CLLocationAccuracy) {
        isRecording = true

        if recordedTrailPoints.isEmpty, let initialLocation {
            recordedTrailPoints = [RecordedTrackPoint(
                latitude: initialLocation.coordinate.latitude,
                longitude: initialLocation.coordinate.longitude,
                altitude: initialLocation.verticalAccuracy >= 0 && initialLocation.verticalAccuracy <= maximumVerticalAccuracy ? initialLocation.altitude : nil,
                timestamp: initialLocation.timestamp
            )]
        }
    }

    func stopRecording() {
        isRecording = false
    }

    func discardRecording() {
        isRecording = false
        recordedTrailPoints.removeAll()
    }

    func appendTrailLocationIfNeeded(
        _ location: CLLocation,
        policy: TrailRecordingPolicy,
        maximumHorizontalAccuracy: CLLocationAccuracy,
        maximumVerticalAccuracy: CLLocationAccuracy,
        minimumAscentIncrement: Double
    ) -> TrailAppendResult {
        guard isRecording else { return .ignored }
        guard location.horizontalAccuracy >= 0 else { return .ignored }
        guard location.horizontalAccuracy <= maximumHorizontalAccuracy else { return .ignored }

        let trackPoint = RecordedTrackPoint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.verticalAccuracy >= 0 && location.verticalAccuracy <= maximumVerticalAccuracy ? location.altitude : nil,
            timestamp: location.timestamp
        )

        if let lastPoint = recordedTrailPoints.last {
            let lastLocation = CLLocation(latitude: lastPoint.latitude, longitude: lastPoint.longitude)
            let distanceFromLastPoint = location.distance(from: lastLocation)
            let timeSinceLastPoint = location.timestamp.timeIntervalSince(lastPoint.timestamp)
            let hasMeaningfulAltitudeChange: Bool

            if let lastAltitude = lastPoint.altitude, let newAltitude = trackPoint.altitude {
                hasMeaningfulAltitudeChange = abs(newAltitude - lastAltitude) >= minimumAscentIncrement
            } else {
                hasMeaningfulAltitudeChange = false
            }

            guard distanceFromLastPoint >= policy.minimumDistance
                || (
                    timeSinceLastPoint >= policy.maximumSamplingInterval
                    && (
                        distanceFromLastPoint >= policy.minimumTimedSampleDistance
                        || hasMeaningfulAltitudeChange
                    )
                )
            else {
                return .previewOnly
            }
        }

        recordedTrailPoints.append(trackPoint)
        return .appended
    }

    func appendBreadcrumbLocationIfNeeded(
        _ location: CLLocation,
        minimumDistance: CLLocationDistance,
        maximumHorizontalAccuracy: CLLocationAccuracy,
        trailDuration: TimeInterval
    ) -> Bool {
        guard !isRecording else { return false }
        guard location.horizontalAccuracy >= 0 else { return false }
        guard location.horizontalAccuracy <= maximumHorizontalAccuracy else { return false }

        let trackPoint = RecordedTrackPoint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.verticalAccuracy >= 0 ? location.altitude : nil,
            timestamp: location.timestamp
        )

        pruneBreadcrumbTrail(relativeTo: location.timestamp, duration: trailDuration)

        if let lastCoordinate = breadcrumbTrailPoints.last?.coordinate {
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let distanceFromLastPoint = location.distance(from: lastLocation)
            guard distanceFromLastPoint >= minimumDistance else { return false }
        }

        breadcrumbTrailPoints.append(trackPoint)
        return true
    }

    func pruneBreadcrumbTrail(relativeTo referenceDate: Date = Date(), duration: TimeInterval) {
        let cutoffDate = referenceDate.addingTimeInterval(-duration)
        breadcrumbTrailPoints.removeAll { $0.timestamp < cutoffDate }
    }
}

func sanitizedGPXFileBaseName(from text: String, defaultBaseName: String) -> String {
    let invalidCharacters = CharacterSet(charactersIn: "/\\\\?%*|\"<>:")
    let cleaned = text
        .components(separatedBy: invalidCharacters)
        .joined(separator: "-")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    return cleaned.isEmpty ? defaultBaseName : cleaned
}

func makeGPXString(from points: [RecordedTrackPoint], trackName: String, creatorName: String) -> String {
    let formatter = ISO8601DateFormatter()
    let trackPointsXML = points.map { point in
        var lines = [
            "      <trkpt lat=\"\(point.latitude)\" lon=\"\(point.longitude)\">"
        ]

        if let altitude = point.altitude {
            lines.append("        <ele>\(altitude)</ele>")
        }

        lines.append("        <time>\(formatter.string(from: point.timestamp))</time>")
        lines.append("      </trkpt>")
        return lines.joined(separator: "\n")
    }.joined(separator: "\n")

    return """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="\(escapedXMLText(creatorName))" xmlns="http://www.topografix.com/GPX/1/1">
      <metadata>
        <desc>Recorded with BareGPS Ireland</desc>
      </metadata>
      <trk>
        <name>\(escapedXMLText(trackName))</name>
        <trkseg>
    \(trackPointsXML)
        </trkseg>
      </trk>
    </gpx>
    """
}

func gpxRecordingSummary(
    for points: [RecordedTrackPoint],
    durationEndDate: Date? = nil,
    currentElevationMeters: Double? = nil,
    noiseThreshold: Double,
    smoothingWindow: Int
) -> GPXRecordingSummary? {
    guard let firstPoint = points.first else { return nil }

    let endDate = durationEndDate ?? points.last?.timestamp ?? firstPoint.timestamp
    let duration = max(0, endDate.timeIntervalSince(firstPoint.timestamp))

    let coordinates = points.map(\.coordinate)
    let distanceMeters = zip(coordinates, coordinates.dropFirst()).reduce(0.0) { total, pair in
        let start = CLLocation(latitude: pair.0.latitude, longitude: pair.0.longitude)
        let end = CLLocation(latitude: pair.1.latitude, longitude: pair.1.longitude)
        return total + end.distance(from: start)
    }

    let smoothedAltitudes = smoothedAltitudes(for: points, smoothingWindow: smoothingWindow)
    let elevationTotals = accumulatedElevationTotals(for: smoothedAltitudes, noiseThreshold: noiseThreshold)
    let altitudeAnchorBounds = altitudeAnchorBounds(for: points.map(\.altitude))

    return GPXRecordingSummary(
        distanceMeters: distanceMeters,
        duration: duration,
        ascentMeters: max(elevationTotals.ascentMeters, altitudeAnchorBounds.minimumAscentMeters),
        descentMeters: max(elevationTotals.descentMeters, altitudeAnchorBounds.minimumDescentMeters),
        currentElevationMeters: currentElevationMeters ?? points.last?.altitude
    )
}

private func escapedXMLText(_ text: String) -> String {
    text
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&apos;")
}

private func accumulatedElevationTotals(
    for altitudes: [Double?],
    noiseThreshold: Double
) -> (ascentMeters: Double, descentMeters: Double) {
    var ascentMeters = 0.0
    var descentMeters = 0.0
    var previousAltitude: Double?
    var pendingRise = 0.0
    var pendingFall = 0.0

    for altitude in altitudes {
        guard let altitude else { continue }

        guard let lastAltitude = previousAltitude else {
            previousAltitude = altitude
            continue
        }

        let delta = altitude - lastAltitude
        previousAltitude = altitude
        guard abs(delta) > 0 else { continue }

        if delta > 0 {
            pendingRise += delta

            if pendingFall > 0 {
                if pendingFall >= noiseThreshold {
                    descentMeters += pendingFall
                }
                pendingFall = 0
            }

            if pendingRise >= noiseThreshold {
                ascentMeters += pendingRise
                pendingRise = 0
            }
        } else {
            pendingFall += -delta

            if pendingRise > 0 {
                if pendingRise >= noiseThreshold {
                    ascentMeters += pendingRise
                }
                pendingRise = 0
            }

            if pendingFall >= noiseThreshold {
                descentMeters += pendingFall
                pendingFall = 0
            }
        }
    }

    if pendingRise >= noiseThreshold {
        ascentMeters += pendingRise
    }

    if pendingFall >= noiseThreshold {
        descentMeters += pendingFall
    }

    return (ascentMeters, descentMeters)
}

private func smoothedAltitudes(for points: [RecordedTrackPoint], smoothingWindow: Int) -> [Double?] {
    let rawAltitudes = points.map(\.altitude)
    let radius = max(0, smoothingWindow / 2)

    return rawAltitudes.enumerated().map { index, altitude in
        guard altitude != nil else { return nil }

        let lowerBound = max(0, index - radius)
        let upperBound = min(rawAltitudes.count - 1, index + radius)
        let windowValues = rawAltitudes[lowerBound...upperBound].compactMap { $0 }.sorted()

        guard !windowValues.isEmpty else { return nil }

        let middleIndex = windowValues.count / 2
        if windowValues.count.isMultiple(of: 2) {
            return (windowValues[middleIndex - 1] + windowValues[middleIndex]) / 2
        }

        return windowValues[middleIndex]
    }
}

private func altitudeAnchorBounds(for altitudes: [Double?]) -> (minimumAscentMeters: Double, minimumDescentMeters: Double) {
    var runningLow: Double?
    var runningHigh: Double?
    var minimumAscentMeters = 0.0
    var minimumDescentMeters = 0.0

    for altitude in altitudes {
        guard let altitude else { continue }

        if let low = runningLow {
            minimumAscentMeters = max(minimumAscentMeters, altitude - low)
            runningLow = min(low, altitude)
        } else {
            runningLow = altitude
        }

        if let high = runningHigh {
            minimumDescentMeters = max(minimumDescentMeters, high - altitude)
            runningHigh = max(high, altitude)
        } else {
            runningHigh = altitude
        }
    }

    return (
        minimumAscentMeters: max(0, minimumAscentMeters),
        minimumDescentMeters: max(0, minimumDescentMeters)
    )
}

func normalizedClassificationCodes(from rawValue: String) -> [String] {
    rawValue
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
        .filter { !$0.isEmpty }
}

func classificationCodes(for peak: Peak) -> [String] {
    ActiveRegion.current.classificationCodes(
        for: peak,
        derivedMemberships: DerivedClassificationMembershipStore.shared
    )
}

func displayNameForClassificationCode(_ code: String) -> String? {
    ActiveRegion.current.displayNameForClassificationCode(code)
}

func classificationSections(for availableCodes: Set<String>) -> [ClassificationSection] {
    ActiveRegion.current.classificationSections(for: availableCodes)
}

func orderedClassificationCodes(from availableCodes: Set<String>) -> [String] {
    classificationSections(for: availableCodes).flatMap(\.codes)
}
struct DerivedClassificationMemberships {
    let highestHundredPeakIDs: Set<String>
    let rangeHighpointPeakIDs: Set<String>
    let provinceTopFiftyPeakIDsByCode: [String: Set<String>]
    let localHundredPeakIDs: Set<String>
}
