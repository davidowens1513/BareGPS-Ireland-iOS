//
//  ViewController.swift
//  MapHills
//
//  Created by David Owens on 26/03/2026.
//

import UIKit
import MapLibre
import MapKit
import CoreLocation
import UniformTypeIdentifiers

enum CalloutInvocationSource {
    case search
    case other
}

// MARK: - View Controller

final class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    // MARK: - UI Elements

    // Main map view shown on screen.
    var mapView: MLNMapView!

    // Button to re-center the map on the user's current location.
    let recenterButton = UIButton(type: .system)

    // Button to show map orientation and restore the map to north-up.
    let orientationButton = UIButton(type: .system)

    // Attribution label required for OpenStreetMap / OpenTopoMap usage.
    let attributionLabel = UILabel()
    let zoomSliderGuideView = DashedSliderGuideView()
    let zoomSlider = UISlider()
    let minimumMapZoomLevel = 6.0
    let maximumMapZoomLevel = 17.0

    // Button to show app information.
    let aboutButton = UIButton(type: .system)
    let settingsButton = UIButton(type: .system)
    let weatherButton = UIButton(type: .system)
    let hillSearchButton = UIButton(type: .system)
    let hillSearchField = UISearchTextField()
    let hillSearchInfoView = UIView()
    let hillSearchInfoLabel = UILabel()
    let hillSearchSuggestionsTableView = UITableView(frame: .zero, style: .plain)
    lazy var hillSearchDismissTapRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleHillSearchDismissTap(_:)))
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        return recognizer
    }()
    var hillSearchFieldWidthConstraint: NSLayoutConstraint?
    var hillSearchSuggestionsHeightConstraint: NSLayoutConstraint?
    var hillSearchSuggestions: [SearchSuggestionItem] = []

    // Button to show logged hill records.
    let recordsButton = UIButton(type: .system)

    // Button to show GPX actions and recording controls.
    let trailButton = UIButton(type: .system)
    let trailStatusIndicatorView = UIView()
    let mapLogoImageView = UIImageView()
    let mapLogoTitleLabel = UILabel()
    let selectedProviderTrailPillView = UIView()
    let selectedProviderTrailNameLabel = UILabel()
    let selectedProviderTrailCloseButton = UIButton(type: .system)
    let positionIndicatorView = UIView()
    let positionIndicatorAccuracyRingView = UIView()
    let positionIndicatorHeadingGlyphView = UIImageView()
    let recenterHeadingIndicatorView = UIImageView()
    let liveGPXStatsCardView = UIView()
    let liveGPXStatsStack = UIStackView()
    let liveDistanceValueLabel = UILabel()
    let liveTimeValueLabel = UILabel()
    let liveAscentValueLabel = UILabel()
    let liveDescentValueLabel = UILabel()
    let liveElevationValueLabel = UILabel()
    let liveGridRefValueLabel = UILabel()
    let liveAccuracyValueLabel = UILabel()
    let liveRecordingValueLabel = UILabel()
    let liveRecordingLockBannerView = UIView()
    let liveRecordingLockLabel = UILabel()
    let liveRecordingButtonRow = UIStackView()
    let livePrimaryRecordingButton = UIButton(type: .system)
    let liveStopRecordingButton = UIButton(type: .system)
    let liveSaveRecordingButton = UIButton(type: .system)
    let liveDiscardRecordingButton = UIButton(type: .system)
    let compactRecordingStripView = UIView()
    let compactRecordingStripStack = UIStackView()
    let compactTimeValueLabel = UILabel()
    let compactDistanceValueLabel = UILabel()
    let compactAscentValueLabel = UILabel()
    let compactElevationValueLabel = UILabel()
    let compactStatusBoxView = UIView()
    let compactStatusDotView = UIView()
    var liveRecordingUnlockTimer: Timer?
    var liveRecordingUnlockRemainingSeconds = 0
    var isLiveRecordingControlsUnlocked = false
    let hillCountOverlayLabel = UILabel()
    let centerCrosshairLeftView = UIView()
    let centerCrosshairRightView = UIView()
    let centerCrosshairTopView = UIView()
    let centerCrosshairBottomView = UIView()
    let centerCrosshairCircleView = UIView()
    let cacheProgressOverlayLabel = UILabel()
    let currentGridRefOverlayLabel = UILabel()
    var visibleHillCountOnMap = 0
    var cacheProgressOverlayBottomConstraint: NSLayoutConstraint?
    var currentGridRefOverlayBottomConstraint: NSLayoutConstraint?
    weak var goToOverlayViewController: GoToHillOverlayViewController?
    weak var gpxOverlayViewController: GPXOverlayViewController?
    weak var settingsOverlayViewController: SettingsOverlayViewController?

    // Button to show caching controls.
    let cachingButton = UIButton(type: .system)
    let cachingStatusIndicatorView = UIView()

    // Button to show the app menu.
    let menuButton = UIButton(type: .system)
    let menuFilterStatusIndicatorView = UIView()
    let layerButton = UIButton(type: .system)
    let gpxImportTitle = "Import GPX File"

    // MARK: - Services

    // Apple's location manager for permission and location updates.
    let locationManager = CLLocationManager()
    let preferencesStore = AppPreferencesStore()
    let offlineCacheStore = OfflineCacheStore()
    let trailRecordingStore = TrailRecordingStore()
    let goToSessionStore = GoToSessionStore()
    let peakSelectionStore = PeakSelectionStore()
    let mapViewportStateStore = MapViewportStateStore()
    let peakAnnotationPresentationStore = PeakAnnotationPresentationStore()
    let locationAuthorizationPolicyStore = LocationAuthorizationPolicyStore()
    let hillFilterEngine = HillFilterEngine()
    let weatherForecastService = WeatherForecastService()
    var isUITestBypassingLocationPrompts: Bool {
        ProcessInfo.processInfo.environment["UITEST_BYPASS_LOCATION_PROMPTS"] == "1"
    }

    // Reference to the pack currently downloading, if one exists.
    var offlinePack: MLNOfflinePack?
    var hasLoadedOfflineArea = false
    var cachedOfflineAreas: [CachedOfflineArea] = []
    var cachedAreaPolygons: [CachedAreaPolygon] = []
    var cachedAreaBorders: [CachedAreaBorderPolyline] = []
    var selectedCacheDetailLevel: CachedAreaDetailLevel = .standard
    var selectedMapBaseLayer: MapBaseLayer = .openBareMap
    var selectedFilterSchema: MenuFilterSchema = .classification
    var selectedHillFilterMode: HillFilterMode = .simple
    var selectedDisplayUnitSystem: DisplayUnitSystem = .metric
    var selectedMapOrientationMode: MapOrientationMode = .northUp
    var isMapInteractionLocked = false
    var selectedTrackRecordingQuality: TrackRecordingQuality = .standard
    var showsCompactRecordingGrid = true
    var showsSnailTrail = true
    var snailTrailColor = UIColor.systemRed.withAlphaComponent(0.75)
    var goToLineColor: UIColor = .systemTeal
    var recordedTrackColor: UIColor = .systemRed
    var importedTrackColor: UIColor = .systemTeal
    var showsGridLines = true
    var localHundredConfiguration: LocalHundredConfiguration?
    var selectedHeightBands: Set<HeightFilterBand> = []
    var selectedClassificationCodes: Set<String> = []
    var advancedHillFilter = AdvancedHillFilter()
    var savedAdvancedHillFilterPresets: [AdvancedHillFilterPreset] = []
    var gpxWaypointAnnotations: [GPXWaypointAnnotation] = []
    var gpxTrackAnnotations: [MLNPolyline] = []
    let savedWaypointController = SavedWaypointController()
    var savedWaypointAnnotations: [SavedWaypointAnnotation] = []
    var isTrailRecording: Bool {
        get { trailRecordingStore.isRecording }
        set { trailRecordingStore.isRecording = newValue }
    }
    var recordedTrailPoints: [RecordedTrackPoint] {
        get { trailRecordingStore.recordedTrailPoints }
        set { trailRecordingStore.recordedTrailPoints = newValue }
    }
    var trailPolylineAnnotation: TrailPolyline?
    var breadcrumbTrailPoints: [RecordedTrackPoint] {
        get { trailRecordingStore.breadcrumbTrailPoints }
        set { trailRecordingStore.breadcrumbTrailPoints = newValue }
    }
    var breadcrumbPolylineAnnotation: BreadcrumbPolyline?
    var goToPolylineAnnotation: GoToPolyline?
    var goToTargetAnnotation: GoToTargetAnnotation?
    var activeGoToTarget: GoToTarget? {
        get { goToSessionStore.activeTarget }
        set { goToSessionStore.activeTarget = newValue }
    }
    var activeGoToPeak: Peak? {
        activeGoToTarget?.peak
    }
    var pendingTrailStartMode: PendingTrailStartMode?
    var pendingGoToTarget: GoToTarget? {
        get { goToSessionStore.pendingTarget }
        set { goToSessionStore.pendingTarget = newValue }
    }
    var hasCompletedInitialApplicationActivation: Bool {
        get { mapViewportStateStore.hasCompletedInitialApplicationActivation }
        set { mapViewportStateStore.hasCompletedInitialApplicationActivation = newValue }
    }
    var shouldAutoRecenterOnAppActive: Bool {
        get { mapViewportStateStore.shouldAutoRecenterOnAppActive }
        set { mapViewportStateStore.shouldAutoRecenterOnAppActive = newValue }
    }
    var shouldResumeFollowModeOnAppActive: Bool {
        get { mapViewportStateStore.shouldResumeFollowModeOnAppActive }
        set { mapViewportStateStore.shouldResumeFollowModeOnAppActive = newValue }
    }
    var shouldResumeFollowModeAfterAuthorization: Bool {
        get { mapViewportStateStore.shouldResumeFollowModeAfterAuthorization }
        set { mapViewportStateStore.shouldResumeFollowModeAfterAuthorization = newValue }
    }
    var mapInactivityRecenterTimer: Timer?
    var latestHeading: CLLocationDirection?
    var selectedPeakID: String? {
        get { peakSelectionStore.selectedPeakID }
        set { peakSelectionStore.selectedPeakID = newValue }
    }
    var pendingPeakCalloutSelectionToken = 0
    var selectedStartPlaceKey: String?
    var pendingStartPlaceCalloutPlacementMode: StartPlaceCalloutView.PlacementMode?
    var pendingStartPlaceCalloutSelectionToken = 0
    var pendingIrelandPlaceHaloRemovalToken = 0
    var selectedStartPlaceHaloAnnotation: StartPlaceSelectionAnnotation?
    var selectedIrelandPlaceHaloAnnotation: IrelandPlaceSelectionAnnotation?
    var isRefreshingStartPlaceSelectionState = false
    var isRefreshingSelectionState: Bool {
        get { peakSelectionStore.isRefreshingSelectionState }
        set { peakSelectionStore.isRefreshingSelectionState = newValue }
    }
    weak var activeHillCalloutView: HillCalloutView?
    weak var activeStartPlaceCalloutView: StartPlaceCalloutView?
    weak var activeCachedAreaCalloutView: CachedAreaCalloutView?
    var activeCachedAreaID: String?
    var currentImportedGPXSourceURL: URL?
    var currentImportedGPXDisplayName: String?
    var hasRunUITestGPXImport = false
    var hasSeededUITestSavedGPX = false
    var hasSeededUITestSavedWaypoints = false
    var lastPeakSubtitleRefreshLocation: CLLocation?
    var lastPeakSubtitleRefreshTime: Date?
    var lastGoToLineTapTimestamp: TimeInterval = 0
    var lastProviderTrailTapTimestamp: TimeInterval = 0
    var selectedProviderTrailName: String?
    var selectedProviderTrailProvider: StartPlaceProvider?
    var selectedProviderTrailLengthMeters: Double?
    var selectedProviderTrailColor: UIColor?
    var selectedProviderTrailCoordinateSegments: [[CLLocationCoordinate2D]] = []
    var hasPresentedStartupGridSystemPrompt = false
    var hasScheduledInitialBootstrap = false
    var hasCompletedInitialBootstrap = false
    lazy var goToLineTapRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleMapTapForGoToLine(_:)))
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        return recognizer
    }()
    lazy var providerTrailTapRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleMapTapForProviderTrail(_:)))
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        return recognizer
    }()
    lazy var goToLongPressRecognizer: UILongPressGestureRecognizer = {
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleMapLongPressForGoTo(_:)))
        recognizer.minimumPressDuration = 0.55
        recognizer.delegate = self
        return recognizer
    }()

    // MARK: - Peak Data

    // This will hold all peaks loaded from the CSV file.
    var peaks: [Peak] = []
    var startPlaces: [StartPlace] = []
    var irelandPlacenames: [IrelandPlacename] = []
    var coillteTrailSummaries: [CoillteTrailSummary] = []
    var sportIrelandTrailSummariesByTrailID: [String: SportIrelandTrailSummary] = [:]
    var outscapeTrailSummariesByTrailID: [String: OutscapeTrailSummary] = [:]
    var sportIrelandTrailIDByStartPlaceID: [String: String] = [:]
    var startPlaceWalkSummaryProvider: StartPlaceWalkSummaryProvider {
        StartPlaceWalkSummaryProvider(
            coillteTrailSummaries: coillteTrailSummaries,
            sportIrelandTrailSummariesByTrailID: sportIrelandTrailSummariesByTrailID,
            outscapeTrailSummariesByTrailID: outscapeTrailSummariesByTrailID,
            sportIrelandTrailIDByStartPlaceID: sportIrelandTrailIDByStartPlaceID
        )
    }
    var selectedCoillteTrailPolylines: [CoillteTrailPolyline] = []
    var selectedSportIrelandTrailPolylines: [SportIrelandTrailPolyline] = []
    var selectedOutscapeTrailPolylines: [OutscapeTrailPolyline] = []
    var hasStartedInitialMapDataLoad = false
    var showsHillMarkers = true
    var visibleStartPlaceProviders: Set<StartPlaceProvider> = [.mountainViews]
    var startPlaceRouteLengthFilter: StartPlaceRouteLengthFilter = .off

    // Local on-device record of hills the user has logged as climbed.
    let loggedPeakController = LoggedPeakController()
    var selectedMarkerColorSchema: MenuFilterSchema = .classification
    var markerColors: [String: UIColor] = [:]
    var startPlaceMarkerImageCache: [String: UIImage] = [:]

    // MARK: - Constants

    // Default starting point = Carrauntoohil
    let defaultCenter = CLLocationCoordinate2D(
        latitude: 51.999471,
        longitude: -9.742687
    )

    // Starting zoom level when app opens.
    let defaultZoomLevel: Double = 12

    // Zoom level used when following the user.
    let followZoomLevel: Double = 14
    let breadcrumbTrailDuration: TimeInterval = 5 * 60

    // Ignore poor GPS fixes for the trail.
    let trailMaximumHorizontalAccuracy: CLLocationAccuracy = 35

    // Ignore tiny elevation noise so ascent totals are more realistic without
    // erasing genuine short climbs on steep ground.
    let trailMinimumAscentIncrement: Double = 2.0

    // Ignore altitude readings when Core Location reports poor vertical confidence.
    let trailMaximumVerticalAccuracy: CLLocationAccuracy = 12

    // Smooth altitude readings before summing ascent, but keep the window small enough
    // that stop/start climbing still registers as real gain.
    let trailElevationSmoothingWindow = 3

    // File prefix used when saving recorded tracks to Documents.
    let recordedGPXFilePrefix = "GPX-Recording"
    let activeRecordingStateFileName = "ActiveGPXRecording.json"
    let savedGPXActionTitle = "Saved GPX Files"

    let regionDefinition = ActiveRegion.current

    lazy var mapStyleURLProvider = MapStyleURLProvider(regionDefinition: regionDefinition)
    lazy var topographicStyleURL = mapStyleURLProvider.topographicStyleURL()
    lazy var openBareMapStyleURL = mapStyleURLProvider.openBareMapStyleURL()
    lazy var satelliteStyleURL = mapStyleURLProvider.satelliteStyleURL()
    lazy var standardStyleURL = mapStyleURLProvider.standardStyleURL()

    var currentMapStyleURL: URL? {
        selectedMapBaseLayer.styleURL(
            topographicStyleURL: topographicStyleURL,
            openBareMapStyleURL: openBareMapStyleURL,
            standardStyleURL: standardStyleURL,
            satelliteStyleURL: satelliteStyleURL
        )
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scheduleInitialBootstrapIfNeeded()
    }

    func scheduleInitialBootstrapIfNeeded() {
        guard !hasScheduledInitialBootstrap else { return }
        hasScheduledInitialBootstrap = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.bootstrapInitialInterfaceIfNeeded()
        }
    }

    func bootstrapInitialInterfaceIfNeeded() {
        guard !hasCompletedInitialBootstrap else { return }
        hasCompletedInitialBootstrap = true

        setupMap()
        setupPositionIndicator()
        setupCenterCrosshair()
        setupMapLogo()
        setupZoomSlider()
        setupCompactRecordingStrip()
        setupRecenterButton()
        setupOrientationButton()
        setupAttributionLabel()
        setupTrailButton()
        setupRecordsButton()
        setupCachingButton()
        setupMenuButton()
        setupLayerButton()
        setupWeatherButton()
        setupAboutButton()
        setupSettingsButton()
        setupHillSearchControl()
        setupSelectedProviderTrailPill()
        view.addGestureRecognizer(hillSearchDismissTapRecognizer)
        applyRightRailButtonLayout()
        setupHillCountOverlay()
        setupCacheProgressOverlay()
        setupCurrentGridRefOverlay()
        restoreActiveRecordingState()
        setupLocationManager()
        observeApplicationLifecycle()
        observeOfflineProgress()
        refreshOfflinePackInventory()
        updateCurrentGridRefOverlay()
        updateZoomSliderFromMap()
        seedUITestSavedWaypointsIfRequested()
        seedUITestSavedGPXIfRequested()
        runUITestGPXImportIfRequested()

        let persistedFilterState = preferencesStore.loadFilterState()
        selectedFilterSchema = persistedFilterState.selectedFilterSchema
        selectedHillFilterMode = persistedFilterState.selectedHillFilterMode
        selectedDisplayUnitSystem = persistedFilterState.displayUnitSystem
        selectedMapOrientationMode = persistedFilterState.mapOrientationMode
        isMapInteractionLocked = false
        selectedTrackRecordingQuality = persistedFilterState.trackRecordingQuality
        showsCompactRecordingGrid = preferencesStore.loadShowsCompactRecordingGrid()
        showsSnailTrail = persistedFilterState.showsSnailTrail
        snailTrailColor = persistedFilterState.snailTrailColor
        goToLineColor = persistedFilterState.goToLineColor
        recordedTrackColor = persistedFilterState.recordedTrackColor
        importedTrackColor = persistedFilterState.importedTrackColor
        showsGridLines = persistedFilterState.showsGridLines
        selectedHeightBands = Set(persistedFilterState.selectedHeightBandIDs.compactMap(HeightFilterBand.init(rawValue:)))
        selectedClassificationCodes = Set(persistedFilterState.selectedClassificationCodes)
        advancedHillFilter = persistedFilterState.advancedHillFilter
        savedAdvancedHillFilterPresets = persistedFilterState.savedAdvancedHillFilterPresets
        localHundredConfiguration = preferencesStore.loadLocalHundredConfiguration()
        selectedMarkerColorSchema = preferencesStore.loadMarkerColorSchema()
        showsHillMarkers = preferencesStore.loadShowsHillMarkers()
        visibleStartPlaceProviders = preferencesStore.loadVisibleStartPlaceProviders()
        startPlaceRouteLengthFilter = preferencesStore.loadStartPlaceRouteLengthFilter()
        markerColors = [:]
        applyMapInteractionLock()
        updateLiveGPXStatsCard()

        if localHundredConfiguration == nil {
            selectedClassificationCodes.remove("L100")
        }
        updateMenuFilterIndicatorAppearance()

        reloadSavedWaypointAnnotations()
        startInitialMapDataLoadIfNeeded()
    }

    func runUITestGPXImportIfRequested() {
        guard !hasRunUITestGPXImport else { return }
        hasRunUITestGPXImport = true

        let environment = ProcessInfo.processInfo.environment
        guard let xml = environment["UITEST_GPX_IMPORT_XML"], !xml.isEmpty else { return }

        let fileName = environment["UITEST_GPX_IMPORT_FILE_NAME"] ?? "UITestImportedTrack.gpx"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        guard let data = xml.data(using: .utf8) else {
            presentGPXImportAlert(title: "GPX Import Failed", message: "The UI test GPX fixture could not be encoded.")
            return
        }

        do {
            try data.write(to: fileURL, options: .atomic)
            importGPX(from: fileURL)
        } catch {
            presentGPXImportAlert(title: "GPX Import Failed", message: error.localizedDescription)
        }
    }

    func seedUITestSavedGPXIfRequested() {
        guard !hasSeededUITestSavedGPX else { return }
        hasSeededUITestSavedGPX = true

        let environment = ProcessInfo.processInfo.environment
        guard let xml = environment["UITEST_SAVED_GPX_XML"], !xml.isEmpty else { return }

        let fileName = environment["UITEST_SAVED_GPX_FILE_NAME"] ?? "UITestSavedTrack.gpx"
        let fileURL = try? documentsDirectoryURL().appendingPathComponent(fileName)
        guard let fileURL, let data = xml.data(using: .utf8) else { return }

        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to seed UI test saved GPX: \(error.localizedDescription)")
        }
    }

    func seedUITestSavedWaypointsIfRequested() {
        guard !hasSeededUITestSavedWaypoints else { return }
        hasSeededUITestSavedWaypoints = true

        let environment = ProcessInfo.processInfo.environment
        let shouldClearSavedWaypoints = environment["UITEST_CLEAR_SAVED_WAYPOINTS"] == "1"
        let json = environment["UITEST_SAVED_WAYPOINTS_JSON"]

        if shouldClearSavedWaypoints {
            savedWaypointController.replaceWaypoints([])
            reloadSavedWaypointAnnotations()
        }

        guard let json, !json.isEmpty else { return }

        guard let data = json.data(using: .utf8) else {
            print("Failed to seed UI test saved waypoints: payload could not be encoded.")
            return
        }

        do {
            let waypoints = try JSONDecoder().decode([SavedWaypoint].self, from: data)
            savedWaypointController.replaceWaypoints(waypoints)
            reloadSavedWaypointAnnotations()
        } catch {
            print("Failed to seed UI test saved waypoints: \(error.localizedDescription)")
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard hasCompletedInitialBootstrap, mapView != nil else { return }
        updateScaleBarLayout()
        updateAttributionButtonLayout()
        updatePositionIndicator()
    }

    deinit {
        liveRecordingUnlockTimer?.invalidate()
        liveRecordingUnlockTimer = nil
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    func setupMap() {
        // Create the map using the local bundled JSON style.
        mapView = MLNMapView(frame: view.bounds, styleURL: currentMapStyleURL)
        mapView.accessibilityIdentifier = "mainMapView"
        mapView.accessibilityLabel = "Map"

        // Allow the map to resize with the screen.
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Set delegate to respond to map events.
        mapView.delegate = self
        mapView.showsScale = true
        mapView.scaleBarPosition = .bottomLeft
        mapView.attributionButtonPosition = .bottomRight
        mapView.compassView.isHidden = true
        mapView.allowsTilting = false
        mapView.minimumZoomLevel = minimumMapZoomLevel
        mapView.maximumZoomLevel = maximumMapZoomLevel
        applyMapInteractionLock()

        // Add map to the view hierarchy.
        view.addSubview(mapView)
        mapView.addGestureRecognizer(goToLineTapRecognizer)
        mapView.addGestureRecognizer(providerTrailTapRecognizer)
        mapView.addGestureRecognizer(goToLongPressRecognizer)

        // Start centered on Wales.
        mapView.setCenter(defaultCenter, zoomLevel: defaultZoomLevel, animated: false)
    }

    func setupPositionIndicator() {
        positionIndicatorView.frame = CGRect(x: 0, y: 0, width: 14, height: 14)
        positionIndicatorView.backgroundColor = .systemBlue
        positionIndicatorView.layer.cornerRadius = 7
        positionIndicatorView.layer.borderWidth = 2
        positionIndicatorView.layer.borderColor = UIColor.white.cgColor
        positionIndicatorView.layer.shadowColor = UIColor.black.cgColor
        positionIndicatorView.layer.shadowOpacity = 0.18
        positionIndicatorView.layer.shadowRadius = 4
        positionIndicatorView.layer.shadowOffset = .zero
        positionIndicatorView.isUserInteractionEnabled = false
        positionIndicatorView.isHidden = true

        positionIndicatorHeadingGlyphView.frame = CGRect(x: 0, y: 0, width: 12, height: 12)
        positionIndicatorHeadingGlyphView.image = UIImage(
            systemName: "location.north.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
        )
        positionIndicatorHeadingGlyphView.tintColor = .white
        positionIndicatorHeadingGlyphView.contentMode = .center
        positionIndicatorHeadingGlyphView.isUserInteractionEnabled = false
        positionIndicatorHeadingGlyphView.isHidden = true
        positionIndicatorHeadingGlyphView.center = CGPoint(x: 7, y: 7)
        positionIndicatorView.addSubview(positionIndicatorHeadingGlyphView)

        positionIndicatorAccuracyRingView.frame = CGRect(x: 0, y: 0, width: 28, height: 28)
        positionIndicatorAccuracyRingView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.18)
        positionIndicatorAccuracyRingView.layer.cornerRadius = 14
        positionIndicatorAccuracyRingView.layer.borderWidth = 1
        positionIndicatorAccuracyRingView.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.35).cgColor
        positionIndicatorAccuracyRingView.isUserInteractionEnabled = false
        positionIndicatorAccuracyRingView.isHidden = true

        view.addSubview(positionIndicatorAccuracyRingView)
        view.addSubview(positionIndicatorView)
    }

    func setupCenterCrosshair() {
        let crosshairColor = UIColor.label.withAlphaComponent(0.6)
        for crosshairView in [
            centerCrosshairLeftView,
            centerCrosshairRightView,
            centerCrosshairTopView,
            centerCrosshairBottomView
        ] {
            crosshairView.translatesAutoresizingMaskIntoConstraints = false
            crosshairView.backgroundColor = crosshairColor
            crosshairView.isUserInteractionEnabled = false
            crosshairView.accessibilityElementsHidden = true
            view.addSubview(crosshairView)
        }

        centerCrosshairCircleView.translatesAutoresizingMaskIntoConstraints = false
        centerCrosshairCircleView.backgroundColor = .clear
        centerCrosshairCircleView.layer.borderColor = crosshairColor.cgColor
        centerCrosshairCircleView.layer.borderWidth = 1
        centerCrosshairCircleView.layer.cornerRadius = 3
        centerCrosshairCircleView.isUserInteractionEnabled = false
        centerCrosshairCircleView.accessibilityElementsHidden = true
        view.addSubview(centerCrosshairCircleView)

        NSLayoutConstraint.activate([
            centerCrosshairLeftView.trailingAnchor.constraint(equalTo: centerCrosshairCircleView.leadingAnchor, constant: -2),
            centerCrosshairLeftView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            centerCrosshairLeftView.widthAnchor.constraint(equalToConstant: 12),
            centerCrosshairLeftView.heightAnchor.constraint(equalToConstant: 1),
            centerCrosshairRightView.leadingAnchor.constraint(equalTo: centerCrosshairCircleView.trailingAnchor, constant: 2),
            centerCrosshairRightView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            centerCrosshairRightView.widthAnchor.constraint(equalToConstant: 12),
            centerCrosshairRightView.heightAnchor.constraint(equalToConstant: 1),
            centerCrosshairTopView.bottomAnchor.constraint(equalTo: centerCrosshairCircleView.topAnchor, constant: -2),
            centerCrosshairTopView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            centerCrosshairTopView.widthAnchor.constraint(equalToConstant: 1),
            centerCrosshairTopView.heightAnchor.constraint(equalToConstant: 12),
            centerCrosshairBottomView.topAnchor.constraint(equalTo: centerCrosshairCircleView.bottomAnchor, constant: 2),
            centerCrosshairBottomView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            centerCrosshairBottomView.widthAnchor.constraint(equalToConstant: 1),
            centerCrosshairBottomView.heightAnchor.constraint(equalToConstant: 12),
            centerCrosshairCircleView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            centerCrosshairCircleView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            centerCrosshairCircleView.widthAnchor.constraint(equalToConstant: 6),
            centerCrosshairCircleView.heightAnchor.constraint(equalTo: centerCrosshairCircleView.widthAnchor)
        ])
    }

    func setupMapLogo() {
        guard let logoImage = overlayLogoImage() else { return }

        mapLogoImageView.translatesAutoresizingMaskIntoConstraints = false
        mapLogoImageView.image = logoImage
        mapLogoImageView.contentMode = .scaleAspectFill
        mapLogoImageView.clipsToBounds = true
        mapLogoImageView.layer.cornerRadius = 5
        mapLogoImageView.layer.borderWidth = 0.8
        mapLogoImageView.layer.borderColor = UIColor.white.withAlphaComponent(0.38).cgColor
        mapLogoImageView.backgroundColor = UIColor.black.withAlphaComponent(0.48)

        mapLogoTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        mapLogoTitleLabel.textAlignment = .left
        mapLogoTitleLabel.numberOfLines = 0
        mapLogoTitleLabel.attributedText = outlinedMapLogoTitleText()

        view.addSubview(mapLogoImageView)
        view.addSubview(mapLogoTitleLabel)

        NSLayoutConstraint.activate([
            mapLogoImageView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 14),
            mapLogoImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            mapLogoImageView.widthAnchor.constraint(equalToConstant: 24),
            mapLogoImageView.heightAnchor.constraint(equalToConstant: 24),
            mapLogoTitleLabel.leadingAnchor.constraint(equalTo: mapLogoImageView.leadingAnchor),
            mapLogoTitleLabel.topAnchor.constraint(equalTo: mapLogoImageView.bottomAnchor, constant: 6),
            mapLogoTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12)
        ])
    }

    func setupHillSearchControl() {
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 17, weight: .bold)
        let searchImage = UIImage(systemName: "magnifyingglass", withConfiguration: symbolConfiguration)
        hillSearchButton.setImage(searchImage, for: .normal)
        applyRightRailButtonStyle(hillSearchButton, tintColor: .systemBlue)
        hillSearchButton.layer.cornerRadius = 20
        hillSearchButton.accessibilityIdentifier = "hillSearchButton"
        hillSearchButton.accessibilityLabel = "Search"
        hillSearchButton.addTarget(self, action: #selector(toggleHillSearch), for: .touchUpInside)

        hillSearchField.translatesAutoresizingMaskIntoConstraints = false
        hillSearchField.placeholder = "Search hills, starts, places"
        hillSearchField.returnKeyType = .search
        hillSearchField.autocapitalizationType = .words
        hillSearchField.autocorrectionType = .no
        hillSearchField.spellCheckingType = .no
        hillSearchField.clearButtonMode = .whileEditing
        hillSearchField.borderStyle = .none
        hillSearchField.background = UIImage()
        hillSearchField.backgroundColor = .systemBackground
        hillSearchField.accessibilityIdentifier = "hillSearchField"
        hillSearchField.layer.shadowColor = UIColor.black.cgColor
        hillSearchField.layer.shadowOpacity = 0.10
        hillSearchField.layer.shadowRadius = 5
        hillSearchField.layer.shadowOffset = CGSize(width: 0, height: 2)
        hillSearchField.layer.borderWidth = 0.75
        hillSearchField.layer.borderColor = UIColor.separator.withAlphaComponent(0.55).cgColor
        hillSearchField.clipsToBounds = false
        hillSearchField.alpha = 0
        hillSearchField.isHidden = true
        hillSearchField.addTarget(self, action: #selector(hillSearchSubmitted), for: .editingDidEndOnExit)
        hillSearchField.addTarget(self, action: #selector(hillSearchEditingDidEnd), for: .editingDidEnd)
        hillSearchField.addTarget(self, action: #selector(hillSearchTextDidChange), for: .editingChanged)

        hillSearchInfoView.translatesAutoresizingMaskIntoConstraints = false
        hillSearchInfoView.backgroundColor = .systemBackground
        hillSearchInfoView.layer.shadowColor = UIColor.black.cgColor
        hillSearchInfoView.layer.shadowOpacity = 0.10
        hillSearchInfoView.layer.shadowRadius = 5
        hillSearchInfoView.layer.shadowOffset = CGSize(width: 0, height: 2)
        hillSearchInfoView.layer.borderWidth = 0.75
        hillSearchInfoView.layer.borderColor = UIColor.separator.withAlphaComponent(0.55).cgColor
        hillSearchInfoView.clipsToBounds = false
        hillSearchInfoView.alpha = 0
        hillSearchInfoView.isHidden = true

        hillSearchInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        hillSearchInfoLabel.text = "Only filtered Hills and Starts will be shown"
        hillSearchInfoLabel.font = .systemFont(ofSize: 10, weight: .medium)
        hillSearchInfoLabel.textColor = .secondaryLabel
        hillSearchInfoLabel.textAlignment = .center
        hillSearchInfoLabel.numberOfLines = 1
        hillSearchInfoLabel.adjustsFontSizeToFitWidth = true
        hillSearchInfoLabel.minimumScaleFactor = 0.7
        hillSearchInfoLabel.lineBreakMode = .byTruncatingTail

        hillSearchInfoView.addSubview(hillSearchInfoLabel)

        hillSearchSuggestionsTableView.translatesAutoresizingMaskIntoConstraints = false
        hillSearchSuggestionsTableView.dataSource = self
        hillSearchSuggestionsTableView.delegate = self
        hillSearchSuggestionsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "HillSearchSuggestionCell")
        hillSearchSuggestionsTableView.rowHeight = 50
        hillSearchSuggestionsTableView.separatorInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        hillSearchSuggestionsTableView.layer.shadowColor = UIColor.black.cgColor
        hillSearchSuggestionsTableView.layer.shadowOpacity = 0.10
        hillSearchSuggestionsTableView.layer.shadowRadius = 5
        hillSearchSuggestionsTableView.layer.shadowOffset = CGSize(width: 0, height: 2)
        hillSearchSuggestionsTableView.layer.borderWidth = 0.75
        hillSearchSuggestionsTableView.layer.borderColor = UIColor.separator.withAlphaComponent(0.55).cgColor
        hillSearchSuggestionsTableView.clipsToBounds = false
        hillSearchSuggestionsTableView.isScrollEnabled = true
        hillSearchSuggestionsTableView.accessibilityIdentifier = "hillSearchSuggestionsTableView"
        hillSearchSuggestionsTableView.alpha = 0
        hillSearchSuggestionsTableView.isHidden = true

        view.addSubview(hillSearchButton)
        view.addSubview(hillSearchField)
        view.addSubview(hillSearchInfoView)
        view.addSubview(hillSearchSuggestionsTableView)

        let widthConstraint = hillSearchField.widthAnchor.constraint(equalToConstant: 0)
        hillSearchFieldWidthConstraint = widthConstraint
        let infoHeightConstraint = hillSearchInfoView.heightAnchor.constraint(equalToConstant: 20)
        let suggestionsHeightConstraint = hillSearchSuggestionsTableView.heightAnchor.constraint(equalToConstant: 0)
        let infoLabelLeadingConstraint = hillSearchInfoLabel.leadingAnchor.constraint(equalTo: hillSearchInfoView.leadingAnchor, constant: 8)
        let infoLabelTrailingConstraint = hillSearchInfoLabel.trailingAnchor.constraint(equalTo: hillSearchInfoView.trailingAnchor, constant: -8)
        infoLabelLeadingConstraint.priority = .defaultHigh
        infoLabelTrailingConstraint.priority = .defaultHigh
        hillSearchSuggestionsHeightConstraint = suggestionsHeightConstraint
        NSLayoutConstraint.activate([
            hillSearchButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            hillSearchButton.centerYAnchor.constraint(equalTo: mapLogoImageView.centerYAnchor),
            hillSearchButton.widthAnchor.constraint(equalToConstant: 40),
            hillSearchButton.heightAnchor.constraint(equalToConstant: 40),

            hillSearchField.trailingAnchor.constraint(equalTo: hillSearchButton.leadingAnchor, constant: -8),
            hillSearchField.centerYAnchor.constraint(equalTo: hillSearchButton.centerYAnchor),
            hillSearchField.heightAnchor.constraint(equalToConstant: 40),
            hillSearchField.leadingAnchor.constraint(greaterThanOrEqualTo: mapLogoImageView.trailingAnchor, constant: 16),
            widthConstraint,

            hillSearchInfoView.topAnchor.constraint(equalTo: hillSearchField.bottomAnchor, constant: 0),
            hillSearchInfoView.leadingAnchor.constraint(equalTo: hillSearchField.leadingAnchor),
            hillSearchInfoView.trailingAnchor.constraint(equalTo: hillSearchField.trailingAnchor),
            infoHeightConstraint,

            infoLabelLeadingConstraint,
            infoLabelTrailingConstraint,
            hillSearchInfoLabel.centerYAnchor.constraint(equalTo: hillSearchInfoView.centerYAnchor),

            hillSearchSuggestionsTableView.topAnchor.constraint(equalTo: hillSearchInfoView.bottomAnchor, constant: 0),
            hillSearchSuggestionsTableView.leadingAnchor.constraint(equalTo: hillSearchField.leadingAnchor),
            hillSearchSuggestionsTableView.trailingAnchor.constraint(equalTo: hillSearchField.trailingAnchor),
            suggestionsHeightConstraint
        ])
    }

    func setupSelectedProviderTrailPill() {
        selectedProviderTrailPillView.translatesAutoresizingMaskIntoConstraints = false
        selectedProviderTrailPillView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.94)
        selectedProviderTrailPillView.layer.cornerRadius = 17
        selectedProviderTrailPillView.layer.borderWidth = 0.75
        selectedProviderTrailPillView.layer.borderColor = UIColor.separator.withAlphaComponent(0.55).cgColor
        selectedProviderTrailPillView.layer.shadowColor = UIColor.black.cgColor
        selectedProviderTrailPillView.layer.shadowOpacity = 0.14
        selectedProviderTrailPillView.layer.shadowRadius = 6
        selectedProviderTrailPillView.layer.shadowOffset = CGSize(width: 0, height: 2)
        selectedProviderTrailPillView.alpha = 0
        selectedProviderTrailPillView.isHidden = true

        selectedProviderTrailNameLabel.translatesAutoresizingMaskIntoConstraints = false
        selectedProviderTrailNameLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        selectedProviderTrailNameLabel.textColor = .label
        selectedProviderTrailNameLabel.lineBreakMode = .byTruncatingTail
        selectedProviderTrailNameLabel.numberOfLines = 1

        selectedProviderTrailCloseButton.translatesAutoresizingMaskIntoConstraints = false
        selectedProviderTrailCloseButton.setImage(
            UIImage(systemName: "xmark.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)),
            for: .normal
        )
        selectedProviderTrailCloseButton.tintColor = .secondaryLabel
        selectedProviderTrailCloseButton.accessibilityLabel = "Hide selected walk"
        selectedProviderTrailCloseButton.addTarget(self, action: #selector(hideSelectedProviderTrailTapped), for: .touchUpInside)

        selectedProviderTrailPillView.addSubview(selectedProviderTrailNameLabel)
        selectedProviderTrailPillView.addSubview(selectedProviderTrailCloseButton)
        view.addSubview(selectedProviderTrailPillView)

        NSLayoutConstraint.activate([
            selectedProviderTrailPillView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 56),
            selectedProviderTrailPillView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            selectedProviderTrailPillView.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            selectedProviderTrailPillView.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            selectedProviderTrailPillView.heightAnchor.constraint(equalToConstant: 34),

            selectedProviderTrailNameLabel.leadingAnchor.constraint(equalTo: selectedProviderTrailPillView.leadingAnchor, constant: 14),
            selectedProviderTrailNameLabel.centerYAnchor.constraint(equalTo: selectedProviderTrailPillView.centerYAnchor),
            selectedProviderTrailNameLabel.trailingAnchor.constraint(equalTo: selectedProviderTrailCloseButton.leadingAnchor, constant: -8),

            selectedProviderTrailCloseButton.trailingAnchor.constraint(equalTo: selectedProviderTrailPillView.trailingAnchor, constant: -10),
            selectedProviderTrailCloseButton.centerYAnchor.constraint(equalTo: selectedProviderTrailPillView.centerYAnchor),
            selectedProviderTrailCloseButton.widthAnchor.constraint(equalToConstant: 24),
            selectedProviderTrailCloseButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    func outlinedMapLogoTitleText() -> NSAttributedString {
        NSAttributedString(
            string: AppBranding.displayName,
            attributes: [
                .font: UIFont.systemFont(ofSize: 16, weight: .bold),
                .foregroundColor: UIColor.systemGreen,
                .strokeColor: UIColor.black.withAlphaComponent(0.55),
                .strokeWidth: -2.5
            ]
        )
    }

    func setupRecenterButton() {
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)
        let locationImage = UIImage(systemName: "scope", withConfiguration: symbolConfiguration)
        recenterButton.setImage(locationImage, for: .normal)
        applyRightRailButtonStyle(recenterButton, tintColor: .systemBlue)

        recenterButton.addTarget(self, action: #selector(recenterTapped), for: .touchUpInside)

        view.addSubview(recenterButton)

        NSLayoutConstraint.activate([
            recenterButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            recenterButton.widthAnchor.constraint(equalToConstant: 44),
            recenterButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    func setupOrientationButton() {
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        let compassImage = UIImage(systemName: "location.north.line.fill", withConfiguration: symbolConfiguration)
        orientationButton.setImage(compassImage, for: .normal)
        applyRightRailButtonStyle(orientationButton, tintColor: .systemBlue)

        orientationButton.addTarget(self, action: #selector(resetMapToNorthTapped), for: .touchUpInside)

        view.addSubview(orientationButton)

        NSLayoutConstraint.activate([
            orientationButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            orientationButton.widthAnchor.constraint(equalToConstant: 44),
            orientationButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        updateOrientationButtonAppearance()
    }

    func setupAttributionLabel() {
        updateAttributionLabel()
        attributionLabel.font = .systemFont(ofSize: 9)
        attributionLabel.textColor = .secondaryLabel
        attributionLabel.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.7)
        attributionLabel.translatesAutoresizingMaskIntoConstraints = false
        attributionLabel.numberOfLines = 2
        attributionLabel.lineBreakMode = .byWordWrapping

        attributionLabel.layer.cornerRadius = 4
        attributionLabel.clipsToBounds = true

        view.addSubview(attributionLabel)

        NSLayoutConstraint.activate([
            attributionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            attributionLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -18),
            attributionLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -72)
        ])
    }

    func setupZoomSlider() {
        zoomSliderGuideView.translatesAutoresizingMaskIntoConstraints = false
        zoomSliderGuideView.backgroundColor = UIColor.black.withAlphaComponent(0.16)
        zoomSliderGuideView.layer.cornerRadius = 9
        view.addSubview(zoomSliderGuideView)

        zoomSlider.translatesAutoresizingMaskIntoConstraints = false
        zoomSlider.minimumValue = Float(minimumMapZoomLevel)
        zoomSlider.maximumValue = Float(maximumMapZoomLevel)
        zoomSlider.value = Float(defaultZoomLevel)
        zoomSlider.minimumTrackTintColor = UIColor.systemBlue.withAlphaComponent(0.85)
        zoomSlider.maximumTrackTintColor = UIColor.clear
        zoomSlider.thumbTintColor = .white
        zoomSlider.transform = CGAffineTransform(rotationAngle: -.pi / 2)
        zoomSlider.backgroundColor = .clear
        zoomSlider.layer.cornerRadius = 12
        zoomSlider.addTarget(self, action: #selector(zoomSliderChanged(_:)), for: .valueChanged)

        view.addSubview(zoomSlider)

        NSLayoutConstraint.activate([
            zoomSliderGuideView.centerXAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            zoomSliderGuideView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            zoomSliderGuideView.widthAnchor.constraint(equalToConstant: 18),
            zoomSliderGuideView.heightAnchor.constraint(equalToConstant: 228),

            zoomSlider.centerXAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            zoomSlider.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            zoomSlider.widthAnchor.constraint(equalToConstant: 220),
            zoomSlider.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    func setupTrailButton() {
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        let trailImage = UIImage(systemName: "play.fill", withConfiguration: symbolConfiguration)
        trailButton.setImage(trailImage, for: .normal)
        applyRightRailButtonStyle(trailButton, tintColor: .systemBlue)
        trailButton.accessibilityIdentifier = "trailButton"
        trailButton.addTarget(self, action: #selector(showGPXMenu), for: .touchUpInside)

        view.addSubview(trailButton)
        trailStatusIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        trailStatusIndicatorView.layer.cornerRadius = 6
        trailStatusIndicatorView.layer.borderWidth = 2
        trailStatusIndicatorView.layer.borderColor = UIColor.systemBackground.cgColor
        trailStatusIndicatorView.isHidden = true
        view.addSubview(trailStatusIndicatorView)

        NSLayoutConstraint.activate([
            trailButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            trailButton.widthAnchor.constraint(equalToConstant: 44),
            trailButton.heightAnchor.constraint(equalToConstant: 44),
            trailStatusIndicatorView.widthAnchor.constraint(equalToConstant: 12),
            trailStatusIndicatorView.heightAnchor.constraint(equalToConstant: 12),
            trailStatusIndicatorView.topAnchor.constraint(equalTo: trailButton.topAnchor, constant: 2),
            trailStatusIndicatorView.trailingAnchor.constraint(equalTo: trailButton.trailingAnchor, constant: -2)
        ])

        updateTrailStatusIndicator()
    }

    func setupLiveGPXStatsCard() {
        liveGPXStatsCardView.translatesAutoresizingMaskIntoConstraints = false
        liveGPXStatsCardView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.42)
        liveGPXStatsCardView.layer.cornerRadius = 12
        liveGPXStatsCardView.layer.borderWidth = 1
        liveGPXStatsCardView.layer.borderColor = UIColor.systemGray3.withAlphaComponent(0.65).cgColor
        liveGPXStatsCardView.layer.shadowColor = UIColor.black.cgColor
        liveGPXStatsCardView.layer.shadowOpacity = 0.12
        liveGPXStatsCardView.layer.shadowRadius = 8
        liveGPXStatsCardView.layer.shadowOffset = CGSize(width: 0, height: 3)
        liveGPXStatsCardView.isHidden = false
        liveGPXStatsCardView.isUserInteractionEnabled = true
        liveGPXStatsCardView.accessibilityIdentifier = "liveGPXStatsCard"
        liveGPXStatsCardView.accessibilityLabel = "GPX recording controls"
        liveGPXStatsCardView.accessibilityTraits = [.allowsDirectInteraction]

        let recordingTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleLiveRecordingControlsTap(_:)))
        recordingTapRecognizer.cancelsTouchesInView = false
        liveGPXStatsCardView.addGestureRecognizer(recordingTapRecognizer)
        let recordingLongPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLiveRecordingControlsLongPress(_:)))
        recordingLongPressRecognizer.minimumPressDuration = 0.55
        liveGPXStatsCardView.addGestureRecognizer(recordingLongPressRecognizer)

        liveGridRefValueLabel.adjustsFontSizeToFitWidth = true
        liveGridRefValueLabel.minimumScaleFactor = 0.65

        liveGPXStatsStack.axis = .vertical
        liveGPXStatsStack.spacing = 1
        liveGPXStatsStack.translatesAutoresizingMaskIntoConstraints = false
        liveGPXStatsStack.addArrangedSubview(
            RecordingHUDViewFactory.liveMetricsRow(
                leftTitle: "Distance",
                leftValueLabel: liveDistanceValueLabel,
                rightTitle: "Time",
                rightValueLabel: liveTimeValueLabel
            )
        )
        liveGPXStatsStack.addArrangedSubview(
            RecordingHUDViewFactory.liveMetricsRow(
                leftTitle: "Ascent",
                leftValueLabel: liveAscentValueLabel,
                rightTitle: "Descent",
                rightValueLabel: liveDescentValueLabel
            )
        )
        liveGPXStatsStack.addArrangedSubview(
            RecordingHUDViewFactory.liveMetricsRow(
                leftTitle: "Elevation",
                leftValueLabel: liveElevationValueLabel,
                rightTitle: "Grid Ref",
                rightValueLabel: liveGridRefValueLabel
            )
        )
        liveGPXStatsStack.addArrangedSubview(
            RecordingHUDViewFactory.liveMetricsRow(
                leftTitle: "Accuracy",
                leftValueLabel: liveAccuracyValueLabel,
                rightTitle: "Status",
                rightValueLabel: liveRecordingValueLabel
            )
        )

        liveRecordingLockBannerView.translatesAutoresizingMaskIntoConstraints = false
        liveRecordingLockBannerView.backgroundColor = .clear
        liveRecordingLockBannerView.layer.cornerRadius = 0
        liveRecordingLockBannerView.layer.borderWidth = 0
        liveRecordingLockBannerView.layer.borderColor = UIColor.clear.cgColor
        liveRecordingLockBannerView.addSubview(liveRecordingLockLabel)

        liveRecordingLockLabel.translatesAutoresizingMaskIntoConstraints = false
        liveRecordingLockLabel.font = .systemFont(ofSize: 12.5, weight: .bold)
        liveRecordingLockLabel.textColor = .black
        liveRecordingLockLabel.textAlignment = .center
        liveRecordingLockLabel.numberOfLines = 1

        liveRecordingButtonRow.axis = .horizontal
        liveRecordingButtonRow.alignment = .fill
        liveRecordingButtonRow.distribution = .fillEqually
        liveRecordingButtonRow.spacing = 0
        liveRecordingButtonRow.translatesAutoresizingMaskIntoConstraints = false

        livePrimaryRecordingButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            guard !self.isTrailRecording else { return }
            self.beginTrailRecordingFlow(startMode: .standard)
            self.updateLiveGPXStatsCard()
        }, for: .touchUpInside)

        liveStopRecordingButton.addAction(UIAction { [weak self] _ in
            self?.stopTrailRecording()
            self?.updateLiveGPXStatsCard()
        }, for: .touchUpInside)

        liveSaveRecordingButton.addAction(UIAction { [weak self] _ in
            self?.promptForGPXRecordingNameAndSave()
            self?.updateLiveGPXStatsCard()
        }, for: .touchUpInside)

        liveDiscardRecordingButton.addAction(UIAction { [weak self] _ in
            self?.discardTrailRecording()
            self?.updateLiveGPXStatsCard()
        }, for: .touchUpInside)

        for button in [livePrimaryRecordingButton, liveStopRecordingButton, liveSaveRecordingButton, liveDiscardRecordingButton] {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.heightAnchor.constraint(equalTo: button.widthAnchor).isActive = true
            liveRecordingButtonRow.addArrangedSubview(button)
        }

        liveGPXStatsCardView.addSubview(liveRecordingLockBannerView)
        liveGPXStatsCardView.addSubview(liveGPXStatsStack)
        liveGPXStatsCardView.addSubview(liveRecordingButtonRow)
        view.addSubview(liveGPXStatsCardView)

        NSLayoutConstraint.activate([
            liveGPXStatsCardView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            liveGPXStatsCardView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -72),
            liveGPXStatsCardView.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            liveGPXStatsCardView.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),

            liveRecordingLockBannerView.leadingAnchor.constraint(equalTo: liveGPXStatsCardView.leadingAnchor, constant: 8),
            liveRecordingLockBannerView.trailingAnchor.constraint(equalTo: liveGPXStatsCardView.trailingAnchor, constant: -8),
            liveRecordingLockBannerView.topAnchor.constraint(equalTo: liveGPXStatsCardView.topAnchor, constant: 5),

            liveRecordingLockLabel.leadingAnchor.constraint(equalTo: liveRecordingLockBannerView.leadingAnchor, constant: 10),
            liveRecordingLockLabel.trailingAnchor.constraint(equalTo: liveRecordingLockBannerView.trailingAnchor, constant: -10),
            liveRecordingLockLabel.topAnchor.constraint(equalTo: liveRecordingLockBannerView.topAnchor, constant: 8),
            liveRecordingLockLabel.bottomAnchor.constraint(equalTo: liveRecordingLockBannerView.bottomAnchor, constant: -8),

            liveGPXStatsStack.leadingAnchor.constraint(equalTo: liveGPXStatsCardView.leadingAnchor, constant: 8),
            liveGPXStatsStack.trailingAnchor.constraint(equalTo: liveGPXStatsCardView.trailingAnchor, constant: -8),
            liveGPXStatsStack.topAnchor.constraint(equalTo: liveRecordingLockBannerView.bottomAnchor, constant: 8),
            liveGPXStatsStack.widthAnchor.constraint(equalToConstant: 236),

            liveRecordingButtonRow.leadingAnchor.constraint(equalTo: liveGPXStatsCardView.leadingAnchor, constant: 8),
            liveRecordingButtonRow.trailingAnchor.constraint(equalTo: liveGPXStatsCardView.trailingAnchor, constant: -8),
            liveRecordingButtonRow.topAnchor.constraint(equalTo: liveGPXStatsStack.bottomAnchor, constant: 8),
            liveRecordingButtonRow.bottomAnchor.constraint(equalTo: liveGPXStatsCardView.bottomAnchor, constant: -5)
        ])

        updateLiveGPXStatsCard()
    }

    func setupCompactRecordingStrip() {
        compactRecordingStripView.translatesAutoresizingMaskIntoConstraints = false
        compactRecordingStripView.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        compactRecordingStripView.layer.cornerRadius = 0
        compactRecordingStripView.layer.borderWidth = 1
        compactRecordingStripView.layer.borderColor = UIColor.black.cgColor
        compactRecordingStripView.clipsToBounds = true
        compactRecordingStripView.isUserInteractionEnabled = false
        compactRecordingStripView.accessibilityIdentifier = "compactRecordingStrip"
        compactRecordingStripView.isHidden = true

        compactRecordingStripStack.axis = .horizontal
        compactRecordingStripStack.alignment = .fill
        compactRecordingStripStack.distribution = .fill
        compactRecordingStripStack.spacing = 0
        compactRecordingStripStack.translatesAutoresizingMaskIntoConstraints = false

        let timeBox = RecordingHUDViewFactory.compactRecordingMetricBox(title: "Time", valueLabel: compactTimeValueLabel)
        let distanceBox = RecordingHUDViewFactory.compactRecordingMetricBox(title: "Distance", valueLabel: compactDistanceValueLabel)
        let ascentBox = RecordingHUDViewFactory.compactRecordingMetricBox(title: "Ascent", valueLabel: compactAscentValueLabel)
        let elevationBox = RecordingHUDViewFactory.compactRecordingMetricBox(title: "Elevation", valueLabel: compactElevationValueLabel)
        let statusBox = RecordingHUDViewFactory.compactRecordingStatusBox(boxView: compactStatusBoxView, dotView: compactStatusDotView)

        compactRecordingStripStack.addArrangedSubview(timeBox)
        compactRecordingStripStack.addArrangedSubview(distanceBox)
        compactRecordingStripStack.addArrangedSubview(ascentBox)
        compactRecordingStripStack.addArrangedSubview(elevationBox)
        compactRecordingStripStack.addArrangedSubview(statusBox)

        compactRecordingStripView.addSubview(compactRecordingStripStack)
        view.addSubview(compactRecordingStripView)

        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            compactRecordingStripView.centerXAnchor.constraint(equalTo: safeArea.centerXAnchor),
            compactRecordingStripView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -134),
            compactRecordingStripView.widthAnchor.constraint(equalTo: safeArea.widthAnchor, multiplier: 0.6),
            compactRecordingStripStack.leadingAnchor.constraint(equalTo: compactRecordingStripView.leadingAnchor),
            compactRecordingStripStack.trailingAnchor.constraint(equalTo: compactRecordingStripView.trailingAnchor),
            compactRecordingStripStack.topAnchor.constraint(equalTo: compactRecordingStripView.topAnchor),
            compactRecordingStripStack.bottomAnchor.constraint(equalTo: compactRecordingStripView.bottomAnchor),
            timeBox.widthAnchor.constraint(equalTo: distanceBox.widthAnchor),
            distanceBox.widthAnchor.constraint(equalTo: ascentBox.widthAnchor),
            ascentBox.widthAnchor.constraint(equalTo: elevationBox.widthAnchor),
            statusBox.widthAnchor.constraint(equalToConstant: 34),
            statusBox.heightAnchor.constraint(equalToConstant: 34)
        ])

        updateCompactRecordingStrip()
    }

    func setupAboutButton() {
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        let questionImage = UIImage(systemName: "questionmark", withConfiguration: symbolConfiguration)
        aboutButton.setImage(questionImage, for: .normal)
        applyRightRailButtonStyle(aboutButton, tintColor: .systemBlue)
        aboutButton.accessibilityIdentifier = "aboutButton"
        aboutButton.accessibilityLabel = "About"

        aboutButton.addTarget(self, action: #selector(showAbout), for: .touchUpInside)

        view.addSubview(aboutButton)

        NSLayoutConstraint.activate([
            aboutButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            aboutButton.widthAnchor.constraint(equalToConstant: 44),
            aboutButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    func setupSettingsButton() {
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        let gearImage = UIImage(systemName: "gearshape.fill", withConfiguration: symbolConfiguration)
        settingsButton.setImage(gearImage, for: .normal)
        applyRightRailButtonStyle(settingsButton, tintColor: .systemBlue)
        settingsButton.accessibilityIdentifier = "settingsButton"
        settingsButton.accessibilityLabel = "Settings"

        settingsButton.addTarget(self, action: #selector(showSettings), for: .touchUpInside)

        view.addSubview(settingsButton)

        NSLayoutConstraint.activate([
            settingsButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            settingsButton.widthAnchor.constraint(equalToConstant: 44),
            settingsButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    func setupCachingButton() {
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let cachingImage = UIImage(systemName: "internaldrive.fill", withConfiguration: symbolConfiguration)
        cachingButton.setImage(cachingImage, for: .normal)
        applyRightRailButtonStyle(cachingButton, tintColor: .systemBlue)
        cachingButton.accessibilityIdentifier = "cachingButton"
        cachingButton.accessibilityLabel = "Caching"

        cachingButton.addTarget(self, action: #selector(showCaching), for: .touchUpInside)
        updateCachingButtonAppearance()

        view.addSubview(cachingButton)
        cachingStatusIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        cachingStatusIndicatorView.backgroundColor = .systemGreen
        cachingStatusIndicatorView.layer.cornerRadius = 6
        cachingStatusIndicatorView.layer.borderWidth = 2
        cachingStatusIndicatorView.layer.borderColor = UIColor.systemBackground.cgColor
        cachingStatusIndicatorView.isHidden = true
        view.addSubview(cachingStatusIndicatorView)

        NSLayoutConstraint.activate([
            cachingButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            cachingButton.widthAnchor.constraint(equalToConstant: 44),
            cachingButton.heightAnchor.constraint(equalToConstant: 44),
            cachingStatusIndicatorView.widthAnchor.constraint(equalToConstant: 12),
            cachingStatusIndicatorView.heightAnchor.constraint(equalToConstant: 12),
            cachingStatusIndicatorView.topAnchor.constraint(equalTo: cachingButton.topAnchor, constant: 2),
            cachingStatusIndicatorView.trailingAnchor.constraint(equalTo: cachingButton.trailingAnchor, constant: -2)
        ])
    }

    func setupHillCountOverlay() {
        hillCountOverlayLabel.translatesAutoresizingMaskIntoConstraints = false
        hillCountOverlayLabel.font = .systemFont(ofSize: 9.6, weight: .semibold)
        hillCountOverlayLabel.textColor = UIColor.secondaryLabel.withAlphaComponent(0.78)
        hillCountOverlayLabel.textAlignment = .center
        hillCountOverlayLabel.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.32)
        hillCountOverlayLabel.layer.cornerRadius = 8
        hillCountOverlayLabel.clipsToBounds = true
        hillCountOverlayLabel.numberOfLines = 4
        hillCountOverlayLabel.adjustsFontSizeToFitWidth = true
        hillCountOverlayLabel.minimumScaleFactor = 0.8
        hillCountOverlayLabel.alpha = 1
        hillCountOverlayLabel.isHidden = false

        view.addSubview(hillCountOverlayLabel)

        NSLayoutConstraint.activate([
            hillCountOverlayLabel.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            hillCountOverlayLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -36),
            hillCountOverlayLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 14),
            hillCountOverlayLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -74)
        ])
    }

    func setupCacheProgressOverlay() {
        cacheProgressOverlayLabel.translatesAutoresizingMaskIntoConstraints = false
        cacheProgressOverlayLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        cacheProgressOverlayLabel.textColor = .label
        cacheProgressOverlayLabel.textAlignment = .center
        cacheProgressOverlayLabel.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.5)
        cacheProgressOverlayLabel.layer.cornerRadius = 10
        cacheProgressOverlayLabel.clipsToBounds = true
        cacheProgressOverlayLabel.numberOfLines = 1
        cacheProgressOverlayLabel.isHidden = true

        view.addSubview(cacheProgressOverlayLabel)

        let bottomConstraint = cacheProgressOverlayLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        cacheProgressOverlayBottomConstraint = bottomConstraint

        NSLayoutConstraint.activate([
            cacheProgressOverlayLabel.centerXAnchor.constraint(equalTo: mapView.scaleBar.centerXAnchor),
            bottomConstraint,
            cacheProgressOverlayLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            cacheProgressOverlayLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -72)
        ])
    }

    func setupCurrentGridRefOverlay() {
        currentGridRefOverlayLabel.translatesAutoresizingMaskIntoConstraints = false
        currentGridRefOverlayLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        currentGridRefOverlayLabel.textColor = .label
        currentGridRefOverlayLabel.textAlignment = .center
        currentGridRefOverlayLabel.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.5)
        currentGridRefOverlayLabel.layer.cornerRadius = 10
        currentGridRefOverlayLabel.clipsToBounds = true
        currentGridRefOverlayLabel.numberOfLines = 1
        currentGridRefOverlayLabel.adjustsFontSizeToFitWidth = true
        currentGridRefOverlayLabel.minimumScaleFactor = 0.8
        currentGridRefOverlayLabel.isHidden = true

        view.addSubview(currentGridRefOverlayLabel)

        let bottomConstraint = currentGridRefOverlayLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        currentGridRefOverlayBottomConstraint = bottomConstraint

        NSLayoutConstraint.activate([
            currentGridRefOverlayLabel.centerXAnchor.constraint(equalTo: mapView.scaleBar.centerXAnchor),
            bottomConstraint,
            currentGridRefOverlayLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            currentGridRefOverlayLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -88)
        ])
    }

    func setupRecordsButton() {
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let recordsImage = UIImage(systemName: "list.bullet.clipboard", withConfiguration: symbolConfiguration)
        recordsButton.setImage(recordsImage, for: .normal)
        applyRightRailButtonStyle(recordsButton, tintColor: .systemBlue)
        recordsButton.accessibilityIdentifier = "recordsButton"
        recordsButton.accessibilityLabel = "Records"

        recordsButton.addTarget(self, action: #selector(showRecords), for: .touchUpInside)

        view.addSubview(recordsButton)

        NSLayoutConstraint.activate([
            recordsButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            recordsButton.widthAnchor.constraint(equalToConstant: 44),
            recordsButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    func setupMenuButton() {
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let menuImage = UIImage(systemName: "line.3.horizontal.decrease.circle", withConfiguration: symbolConfiguration)
        menuButton.setImage(menuImage, for: .normal)
        applyRightRailButtonStyle(menuButton, tintColor: .systemBlue)
        menuButton.accessibilityIdentifier = "menuButton"
        menuButton.accessibilityLabel = "Filter"

        menuButton.addTarget(self, action: #selector(showMenu), for: .touchUpInside)

        view.addSubview(menuButton)
        menuFilterStatusIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        menuFilterStatusIndicatorView.backgroundColor = .systemGreen
        menuFilterStatusIndicatorView.layer.cornerRadius = 6
        menuFilterStatusIndicatorView.layer.borderWidth = 2
        menuFilterStatusIndicatorView.layer.borderColor = UIColor.systemBackground.cgColor
        menuFilterStatusIndicatorView.isHidden = true
        view.addSubview(menuFilterStatusIndicatorView)

        NSLayoutConstraint.activate([
            menuButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            menuButton.widthAnchor.constraint(equalToConstant: 44),
            menuButton.heightAnchor.constraint(equalToConstant: 44),
            menuFilterStatusIndicatorView.widthAnchor.constraint(equalToConstant: 12),
            menuFilterStatusIndicatorView.heightAnchor.constraint(equalToConstant: 12),
            menuFilterStatusIndicatorView.topAnchor.constraint(equalTo: menuButton.topAnchor, constant: 2),
            menuFilterStatusIndicatorView.trailingAnchor.constraint(equalTo: menuButton.trailingAnchor, constant: -2)
        ])
    }

    func setupLayerButton() {
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let layerImage = UIImage(systemName: "square.2.layers.3d.top.filled", withConfiguration: symbolConfiguration)
        layerButton.setImage(layerImage, for: .normal)
        applyRightRailButtonStyle(layerButton, tintColor: .systemBlue)
        layerButton.addTarget(self, action: #selector(showMapLayerChooser), for: .touchUpInside)

        view.addSubview(layerButton)

        NSLayoutConstraint.activate([
            layerButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            layerButton.widthAnchor.constraint(equalToConstant: 44),
            layerButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        updateLayerButtonAppearance()
    }

    func setupWeatherButton() {
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let weatherImage = UIImage(systemName: "cloud.sun.fill", withConfiguration: symbolConfiguration)
        weatherButton.setImage(weatherImage, for: .normal)
        applyRightRailButtonStyle(weatherButton, tintColor: .systemBlue)
        weatherButton.accessibilityIdentifier = "weatherButton"
        weatherButton.accessibilityLabel = "Weather"
        weatherButton.addTarget(self, action: #selector(showWeather), for: .touchUpInside)

        view.addSubview(weatherButton)

        NSLayoutConstraint.activate([
            weatherButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            weatherButton.widthAnchor.constraint(equalToConstant: 44),
            weatherButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    func applyRightRailButtonLayout() {
        let buttonsFromBottom: [(button: UIButton, bottomSpacing: CGFloat)] = [
            (recenterButton, -44),
            (orientationButton, -10),
            (layerButton, -10),
            (weatherButton, -10),
            (trailButton, -24),
            (cachingButton, -10),
            (recordsButton, -10),
            (menuButton, -24),
            (settingsButton, -10),
            (aboutButton, -10)
        ]

        guard let firstButton = buttonsFromBottom.first else { return }

        var constraints = [
            firstButton.button.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: firstButton.bottomSpacing
            )
        ]

        for index in 1..<buttonsFromBottom.count {
            let current = buttonsFromBottom[index]
            let buttonBelow = buttonsFromBottom[index - 1]
            constraints.append(
                current.button.bottomAnchor.constraint(
                    equalTo: buttonBelow.button.topAnchor,
                    constant: current.bottomSpacing
                )
            )
        }

        NSLayoutConstraint.activate(constraints)
    }

    func applyRightRailButtonStyle(_ button: UIButton, tintColor: UIColor) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .systemBackground
        button.tintColor = tintColor
        button.layer.cornerRadius = 22
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.16
        button.layer.shadowRadius = 6
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.borderWidth = 0.75
        button.layer.borderColor = UIColor.separator.withAlphaComponent(0.55).cgColor
        button.clipsToBounds = false
    }

    func canCacheCurrentMapLayer() -> Bool {
        selectedMapBaseLayer.supportsOfflineCaching
    }

    func updateCachingButtonAppearance() {
        let canCache = canCacheCurrentMapLayer()
        cachingButton.isEnabled = canCache
        cachingButton.alpha = canCache ? 1.0 : 0.38
        cachingButton.tintColor = canCache ? .systemBlue : .secondaryLabel
        cachingButton.accessibilityLabel = canCache ? "Caching" : "Caching unavailable for this map layer"
    }

    func updateAttributionLabel() {
        attributionLabel.text = selectedMapBaseLayer.attributionText
    }

    func updateLayerButtonAppearance() {
        switch selectedMapBaseLayer {
        case .topographic:
            layerButton.tintColor = .systemBlue
        case .openBareMap:
            layerButton.tintColor = .systemOrange
        case .standard:
            layerButton.tintColor = .systemTeal
        case .satellite:
            layerButton.tintColor = .systemIndigo
        }
    }

    func updateMenuFilterIndicatorAppearance() {
        menuFilterStatusIndicatorView.isHidden = !isHillFilterActive()
    }

    func isHillFilterActive() -> Bool {
        !selectedHeightBands.isEmpty ||
            !selectedClassificationCodes.isEmpty ||
            !advancedHillFilter.isEmpty
    }

    func setHillSearchVisible(_ visible: Bool, animated: Bool) {
        let targetWidth: CGFloat = visible ? min(260, view.safeAreaLayoutGuide.layoutFrame.width - 150) : 0
        hillSearchFieldWidthConstraint?.constant = max(0, targetWidth)

        if visible {
            hillSearchField.isHidden = false
            hillSearchInfoView.isHidden = false
        } else {
            updateHillSearchSuggestions(for: nil, animated: animated)
        }

        let animations = {
            self.hillSearchField.alpha = visible ? 1 : 0
            self.view.layoutIfNeeded()
        }

        let completion: (Bool) -> Void = { _ in
            if visible {
                self.hillSearchField.becomeFirstResponder()
                self.hillSearchInfoView.alpha = 1
            } else {
                self.hillSearchField.resignFirstResponder()
                self.hillSearchField.text = nil
                self.hillSearchField.isHidden = true
                self.hillSearchInfoView.alpha = 0
                self.hillSearchInfoView.isHidden = true
            }
        }

        if animated {
            UIView.animate(withDuration: 0.2, animations: animations, completion: completion)
        } else {
            animations()
            completion(true)
        }
    }

    func updateHillSearchSuggestions(for query: String?, animated: Bool) {
        let trimmedQuery = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let suggestions = trimmedQuery.isEmpty ? [] : mixedSearchSuggestions(for: trimmedQuery, limit: 12)
        hillSearchSuggestions = suggestions
        hillSearchSuggestionsTableView.reloadData()

        let maxVisibleRows = min(6, suggestions.count)
        let targetHeight = min(
            CGFloat(suggestions.count) * hillSearchSuggestionsTableView.rowHeight,
            CGFloat(maxVisibleRows) * hillSearchSuggestionsTableView.rowHeight
        )
        hillSearchSuggestionsHeightConstraint?.constant = targetHeight
        let shouldShow = !suggestions.isEmpty && !hillSearchField.isHidden

        if shouldShow {
            hillSearchSuggestionsTableView.isHidden = false
        }

        let animations = {
            self.hillSearchSuggestionsTableView.alpha = shouldShow ? 1 : 0
            self.view.layoutIfNeeded()
        }

        let completion: (Bool) -> Void = { _ in
            if !shouldShow {
                self.hillSearchSuggestionsTableView.isHidden = true
            }
        }

        if animated {
            UIView.animate(withDuration: 0.15, animations: animations, completion: completion)
        } else {
            animations()
            completion(true)
        }
    }

    func clearHillSearchPulldownImmediately() {
        hillSearchField.resignFirstResponder()
        hillSearchField.text = nil
        hillSearchSuggestions = []
        hillSearchSuggestionsHeightConstraint?.constant = 0
        hillSearchSuggestionsTableView.reloadData()
        hillSearchSuggestionsTableView.alpha = 0
        hillSearchSuggestionsTableView.isHidden = true
        hillSearchInfoView.isHidden = true
    }

    func mixedSearchSuggestions(for query: String, limit: Int? = nil) -> [SearchSuggestionItem] {
        let lowercasedQuery = query.localizedLowercase
        let hills = matchedPeaks(for: query, limit: nil).map(SearchSuggestionItem.hill)

        let startPlaceMatches = displayedStartPlaces()
            .filter { startPlace in
                [
                    startPlace.shortDisplayName,
                    startPlace.fullDisplayName,
                    startPlace.provider.title,
                    startPlace.gridReference,
                    startPlace.status,
                    startPlace.parking,
                    startPlace.nearbyHills
                ].contains { $0.localizedLowercase.contains(lowercasedQuery) }
            }
            .sorted { lhs, rhs in
                lhs.shortDisplayName.localizedCaseInsensitiveCompare(rhs.shortDisplayName) == .orderedAscending
            }
            .map(SearchSuggestionItem.startPlace)

        let placeMatches = irelandPlacenames
            .filter { $0.searchableText.contains(lowercasedQuery) }
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            .map(SearchSuggestionItem.irelandPlace)

        let combined = (hills + startPlaceMatches + placeMatches).sorted { lhs, rhs in
            let titleOrder = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
            if titleOrder != .orderedSame {
                return titleOrder == .orderedAscending
            }

            let lhsKindOrder = lhs.kind.sortOrder
            let rhsKindOrder = rhs.kind.sortOrder
            if lhsKindOrder != rhsKindOrder {
                return lhsKindOrder < rhsKindOrder
            }

            return lhs.subtitle.localizedCaseInsensitiveCompare(rhs.subtitle) == .orderedAscending
        }
        if let limit {
            return Array(combined.prefix(limit))
        }
        return combined
    }

    func displayedStartPlaces() -> [StartPlace] {
        startPlaces.filter { startPlace in
            visibleStartPlaceProviders.contains(startPlace.provider)
                && startPlacePassesRouteLengthFilter(startPlace)
        }
    }

    func focusOnPeak(
        _ peak: Peak,
        placementMode: HillCalloutView.PlacementMode = .belowAnchor,
        positionsPeakForCallout: Bool,
        invocationSource: CalloutInvocationSource = .other,
        animated: Bool = true
    ) {
        dismissActiveHillCallout(animated: false)
        dismissActiveStartPlaceCallout(animated: false)
        dismissActiveCachedAreaCallout(animated: false)
        removeSelectedIrelandPlaceHalo()

        if let selectedAnnotation = mapView.selectedAnnotations.first {
            mapView.deselectAnnotation(selectedAnnotation, animated: false)
        }

        selectedPeakID = peak.id
        reloadPeakAnnotations(selecting: peak.id)
        let targetZoomLevel: Double = invocationSource == .search ? 14.0 : 16.0
        if invocationSource == .search {
            mapView.setCenter(peak.coordinate, zoomLevel: targetZoomLevel, animated: animated)
        } else {
            mapView.setCenter(peak.coordinate, zoomLevel: mapView.zoomLevel, animated: animated)
        }
        positionCoordinateForCallout(peak.coordinate)

        pendingPeakCalloutSelectionToken += 1
        let selectionToken = pendingPeakCalloutSelectionToken

        let fallbackAnnotation = PeakAnnotation()
        fallbackAnnotation.coordinate = peak.coordinate
        fallbackAnnotation.title = peak.name
        fallbackAnnotation.subtitle = subtitle(for: peak)
        fallbackAnnotation.peak = peak

        presentHillCalloutWhenReady(
            forPeakID: peak.id,
            delay: 0.3,
            remainingAttempts: 8,
            placementMode: placementMode,
            selectionToken: selectionToken,
            fallbackAnnotation: fallbackAnnotation
        )
    }

    func positionPeakForCallout(_ coordinate: CLLocationCoordinate2D) {
        positionCoordinateForCallout(coordinate)
    }

    func positionCoordinateForCallout(_ coordinate: CLLocationCoordinate2D) {
        let currentPoint = mapView.convert(coordinate, toPointTo: mapView)
        let targetPoint = CGPoint(
            x: mapView.bounds.midX,
            y: mapView.bounds.minY + (mapView.bounds.height / 3.0)
        )
        let deltaX = targetPoint.x - currentPoint.x
        let deltaY = targetPoint.y - currentPoint.y

        guard abs(deltaX) > 1 || abs(deltaY) > 1 else { return }

        let currentCenterPoint = CGPoint(x: mapView.bounds.midX, y: mapView.bounds.midY)
        let adjustedCenterPoint = CGPoint(
            x: currentCenterPoint.x - deltaX,
            y: currentCenterPoint.y - deltaY
        )
        let adjustedCenterCoordinate = mapView.convert(adjustedCenterPoint, toCoordinateFrom: mapView)
        mapView.setCenter(adjustedCenterCoordinate, animated: true)
    }

    func clampedCalloutAnchorRect(
        from rect: CGRect,
        constrainedTo constrainedRect: CGRect
    ) -> CGRect {
        let insetRect = constrainedRect.insetBy(dx: 12, dy: 12)
        let maxX = max(insetRect.minX, insetRect.maxX - rect.width)
        let maxY = max(insetRect.minY, insetRect.maxY - rect.height)
        let clampedX = min(max(rect.minX, insetRect.minX), maxX)
        let clampedY = min(max(rect.minY, insetRect.minY), maxY)
        return CGRect(origin: CGPoint(x: clampedX, y: clampedY), size: rect.size)
    }

    func presentHillCalloutWhenReady(
        forPeakID peakID: String,
        delay: TimeInterval = 0,
        remainingAttempts: Int = 4,
        placementMode: HillCalloutView.PlacementMode = .belowAnchor,
        selectionToken: Int? = nil,
        fallbackAnnotation: PeakAnnotation? = nil
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            if let selectionToken, selectionToken != self.pendingPeakCalloutSelectionToken {
                return
            }
            guard let annotation = self.peakAnnotation(for: peakID) else {
                if remainingAttempts > 0 {
                    self.presentHillCalloutWhenReady(
                        forPeakID: peakID,
                        delay: 0.12,
                        remainingAttempts: remainingAttempts - 1,
                        placementMode: placementMode,
                        selectionToken: selectionToken,
                        fallbackAnnotation: fallbackAnnotation
                    )
                    return
                }

                guard let fallbackAnnotation else { return }
                self.showHillCallout(for: fallbackAnnotation, placementMode: placementMode)
                return
            }

            self.mapView.selectAnnotation(annotation, animated: false, completionHandler: nil)
            self.showHillCallout(for: annotation, placementMode: placementMode)
        }
    }

    func presentHillCalloutWhenReady(
        for peak: Peak,
        placementMode: HillCalloutView.PlacementMode = .belowAnchor,
        selectionToken: Int? = nil
    ) {
        let fallbackAnnotation = PeakAnnotation()
        fallbackAnnotation.coordinate = peak.coordinate
        fallbackAnnotation.title = peak.name
        fallbackAnnotation.subtitle = subtitle(for: peak)
        fallbackAnnotation.peak = peak

        presentHillCalloutWhenReady(
            forPeakID: peak.id,
            delay: 0,
            remainingAttempts: 4,
            placementMode: placementMode,
            selectionToken: selectionToken,
            fallbackAnnotation: fallbackAnnotation
        )
    }

    func matchedPeaks(for query: String, limit: Int? = nil) -> [Peak] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        let visiblePeaks = filteredPeaks()
        let normalizedQuery = trimmedQuery.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        func normalized(_ text: String) -> String {
            text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        }

        let matches = visiblePeaks
            .compactMap { peak -> (peak: Peak, rank: Int, sortName: String)? in
                let primaryName = normalized(peak.name)
                let alternateName = normalized(peak.alternateHillName)

                let rank: Int?
                if primaryName == normalizedQuery {
                    rank = 0
                } else if !alternateName.isEmpty, alternateName == normalizedQuery {
                    rank = 1
                } else if primaryName.hasPrefix(normalizedQuery) {
                    rank = 2
                } else if !alternateName.isEmpty, alternateName.hasPrefix(normalizedQuery) {
                    rank = 3
                } else if primaryName.contains(normalizedQuery) {
                    rank = 4
                } else if !alternateName.isEmpty, alternateName.contains(normalizedQuery) {
                    rank = 5
                } else {
                    rank = nil
                }

                guard let rank else { return nil }
                return (peak, rank, peak.name)
            }
            .sorted { lhs, rhs in
                if lhs.rank != rhs.rank {
                    return lhs.rank < rhs.rank
                }
                return lhs.sortName.localizedCaseInsensitiveCompare(rhs.sortName) == .orderedAscending
            }
            .map(\.peak)

        if let limit {
            return Array(matches.prefix(limit))
        }
        return matches
    }

    func matchedPeak(for query: String) -> Peak? {
        matchedPeaks(for: query, limit: 1).first
    }

    func performHillSearch(using query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            setHillSearchVisible(false, animated: true)
            return
        }

        guard let peak = matchedPeak(for: trimmedQuery) else {
            presentInfoOverlay(
                title: "Not Found",
                message: "Nothing matches \"\(trimmedQuery)\"."
            )
            return
        }

        setHillSearchVisible(false, animated: true)
        focusOnPeak(
            peak,
            placementMode: .belowAnchor,
            positionsPeakForCallout: true,
            invocationSource: .search,
            animated: false
        )
    }

    func topButtonConfiguration(title: String, fontSize: CGFloat = 17) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.baseForegroundColor = .systemBlue
        configuration.background.backgroundColor = .systemBackground
        configuration.background.cornerRadius = 10
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: fontSize, weight: .regular)
            return outgoing
        }
        return configuration
    }

    func setDownloadButtonTitle(_ title: String) {
        updateCachingIndicatorAppearance()
        updateCacheProgressOverlay()
    }

    func updateCachingIndicatorAppearance() {
        cachingStatusIndicatorView.isHidden = !canCacheCurrentMapLayer() || !isVisibleAreaCoveredByCachedOfflineArea()
    }

    func isVisibleAreaCoveredByCachedOfflineArea() -> Bool {
        let visibleBounds = mapView.visibleCoordinateBounds
        return cachedOfflineAreas.contains { cachedArea in
            cachedArea.status == .ready &&
            cachedAreaContainsVisibleBounds(cachedArea.bounds, visibleBounds: visibleBounds)
        }
    }

    func cachedAreaContainsVisibleBounds(
        _ cachedBounds: MLNCoordinateBounds,
        visibleBounds: MLNCoordinateBounds
    ) -> Bool {
        visibleBounds.sw.latitude >= cachedBounds.sw.latitude &&
        visibleBounds.sw.longitude >= cachedBounds.sw.longitude &&
        visibleBounds.ne.latitude <= cachedBounds.ne.latitude &&
        visibleBounds.ne.longitude <= cachedBounds.ne.longitude
    }

    func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .fitness
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.headingFilter = 5
        locationManager.allowsBackgroundLocationUpdates = false
    }

    func updateBackgroundLocationMode() {
        locationManager.allowsBackgroundLocationUpdates = locationAuthorizationPolicyStore.shouldAllowBackgroundRecording(
            authorizationStatus: locationManager.authorizationStatus,
            isTrailRecording: isTrailRecording
        )
    }

    func startHeadingUpdatesIfAvailable() {
        guard CLLocationManager.headingAvailable() else { return }
        locationManager.startUpdatingHeading()
    }

    var isUserTrackingActive: Bool {
        mapView.userTrackingMode != .none
    }

    func applyMapOrientationMode(animated: Bool) {
        switch selectedMapOrientationMode {
        case .northUp:
            if mapView.userTrackingMode == .followWithHeading {
                mapView.userTrackingMode = .follow
            }
            if !isNorthUp {
                mapView.setDirection(0, animated: animated)
            }
        case .headsUp:
            if isUserTrackingActive, mapView.userTrackingMode != .followWithHeading {
                mapView.userTrackingMode = .followWithHeading
            }
        }
        updateOrientationButtonAppearance()
    }

    func applyMapInteractionLock() {
        let gesturesEnabled = !isMapInteractionLocked
        mapView.isScrollEnabled = gesturesEnabled
        mapView.isZoomEnabled = gesturesEnabled
        mapView.isRotateEnabled = gesturesEnabled
    }

    func resetMapInteractionLockForCompletedRecording() {
        guard isMapInteractionLocked else { return }
        isMapInteractionLocked = false
        applyMapInteractionLock()
        applyMapOrientationMode(animated: true)
    }

    func smallestAngleDifference(from current: CLLocationDirection, to target: CLLocationDirection) -> CLLocationDirection {
        let normalizedCurrent = current.truncatingRemainder(dividingBy: 360)
        let normalizedTarget = target.truncatingRemainder(dividingBy: 360)
        let delta = (normalizedTarget - normalizedCurrent + 540).truncatingRemainder(dividingBy: 360) - 180
        return delta
    }

    func observeApplicationLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    func updateScaleBarLayout() {
        let fallbackScaleBarWidth: CGFloat = 110
        let actualScaleBarWidth = mapView.scaleBar.bounds.width
        let scaleBarWidth = actualScaleBarWidth > 0 ? actualScaleBarWidth : fallbackScaleBarWidth
        let centeredX = (view.bounds.width - scaleBarWidth) / 2
        let bottomMargin = max(74, view.safeAreaInsets.bottom + 78)

        mapView.scaleBarMargins = CGPoint(
            x: max(12, centeredX),
            y: bottomMargin
        )
    }

    func updateAttributionButtonLayout() {
        let bottomMargin = max(-36, view.safeAreaInsets.bottom - 36)
        mapView.attributionButtonMargins = CGPoint(x: 24, y: bottomMargin)
    }

    // MARK: - Data Loading

    func loadPeaksFromJSON() -> [Peak] {
        MapDataLoader.loadPeaksFromJSON(resourceName: regionDefinition.hillDatasetResourceName)
    }

    func loadStartPlacesFromJSON(resourceName: String) -> [StartPlace] {
        MapDataLoader.loadStartPlacesFromJSON(resourceName: resourceName)
    }

    func loadOutscapeDerivedTrailStartPlaces() -> [StartPlace] {
        MapDataLoader.loadOutscapeDerivedTrailStartPlaces()
    }

    func loadCoillteTrailSummaries() -> [CoillteTrailSummary] {
        MapDataLoader.loadCoillteTrailSummaries()
    }

    func loadSportIrelandTrailSummariesByTrailID() -> [String: SportIrelandTrailSummary] {
        MapDataLoader.loadSportIrelandTrailSummariesByTrailID()
    }

    func loadOutscapeTrailSummariesByTrailID() -> [String: OutscapeTrailSummary] {
        MapDataLoader.loadOutscapeTrailSummariesByTrailID()
    }

    func loadSportIrelandTrailIDByStartPlaceID() -> [String: String] {
        MapDataLoader.loadSportIrelandTrailIDByStartPlaceID()
    }

    func mountainViewsStartPlaceURL(for startPlace: StartPlace) -> URL? {
        guard startPlace.provider == .mountainViews else { return nil }
        let startNumber = startPlace.startNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !startNumber.isEmpty else { return nil }
        return URL(string: "https://mountainviews.ie/start/\(startNumber)")
    }

    func startInitialMapDataLoadIfNeeded() {
        guard !hasStartedInitialMapDataLoad else { return }
        hasStartedInitialMapDataLoad = true

        let dataLoader = InitialMapDataLoader(regionDefinition: regionDefinition)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let loadedData = dataLoader.load()

            DispatchQueue.main.async {
                self?.applyInitialMapData(loadedData)
            }
        }
    }

    func applyInitialMapData(_ loadedData: InitialMapData) {
        peaks = loadedData.peaks
        migrateLoggedPeakIDsIfNeeded()
        startPlaces = loadedData.startPlaces
        irelandPlacenames = loadedData.irelandPlacenames
        coillteTrailSummaries = loadedData.coillteTrailSummaries
        sportIrelandTrailSummariesByTrailID = loadedData.sportIrelandTrailSummariesByTrailID
        outscapeTrailSummariesByTrailID = loadedData.outscapeTrailSummariesByTrailID
        sportIrelandTrailIDByStartPlaceID = loadedData.sportIrelandTrailIDByStartPlaceID
        refreshDerivedClassificationMemberships()

        addPeakAnnotations()
        addStartPlaceAnnotations()
    }

    func allClassificationCodes() -> [String] {
        var seenCodes = Set<String>()

        for peak in peaks {
            for code in classificationCodes(for: peak) {
                if displayNameForClassificationCode(code) != nil {
                    seenCodes.insert(code)
                }
            }
        }

        seenCodes.formUnion(alwaysVisibleClassificationCodes())
        return orderedClassificationCodes(from: seenCodes)
    }

    func classificationDisplayName(for code: String) -> String {
        displayNameForClassificationCode(code) ?? code
    }

    func refreshDerivedClassificationMemberships() {
        DerivedClassificationMembershipStore.shared.update(
            peaks: peaks,
            localHundredConfiguration: localHundredConfiguration
        )
    }

    func currentLocalHundredPositionGridReference() -> String? {
        guard let coordinate = currentValidUserCoordinate() else { return nil }
        return irishNationalGridReference(for: coordinate)
    }

    func saveLocalHundredConfiguration(_ configuration: LocalHundredConfiguration) {
        localHundredConfiguration = configuration
        preferencesStore.saveLocalHundredConfiguration(configuration)
        refreshDerivedClassificationMemberships()
        reloadPeakAnnotations()
    }

    func clearLocalHundredConfiguration() {
        localHundredConfiguration = nil
        preferencesStore.clearLocalHundredConfiguration()
        refreshDerivedClassificationMemberships()
        reloadPeakAnnotations()
    }

    func configureLocalHundred(fromGridReference input: String) -> LocalHundredSetupResult {
        guard let parsedReference = parsedRegionGridReference(input) else {
            return .failure("Enter a valid grid reference, for example V 83643 84450.")
        }

        let configuration = LocalHundredConfiguration(
            source: .gridReference,
            gridReference: parsedReference.gridReference,
            easting: parsedReference.easting,
            northing: parsedReference.northing
        )
        saveLocalHundredConfiguration(configuration)
        return .success(configuration)
    }

    func configureLocalHundredFromCurrentPosition() -> LocalHundredSetupResult {
        guard locationAuthorizationPolicyStore.canUseLocation(locationManager.authorizationStatus) else {
            return .failure("Allow location access first, then choose Use Current Position again.")
        }
        guard let coordinate = currentValidUserCoordinate() else {
            return .failure("Current position is not available yet.")
        }
        guard let gridReference = irishNationalGridReference(for: coordinate) else {
            return .failure("Could not convert the current position into a grid reference.")
        }
        guard let projected = irishGridEastingNorthing(for: coordinate) else {
            return .failure("Could not project the current position into planar coordinates.")
        }

        let configuration = LocalHundredConfiguration(
            source: .currentPosition,
            gridReference: gridReference,
            easting: projected.easting,
            northing: projected.northing
        )
        saveLocalHundredConfiguration(configuration)
        return .success(configuration)
    }

    func recordsTableText() -> String {
        RecordsTableFormatter(
            peaks: peaks,
            classificationCodes: allClassificationCodes(),
            classificationDisplayName: { [weak self] code in
                self?.classificationDisplayName(for: code) ?? code
            },
            peakClassificationCodes: { peak in
                classificationCodes(for: peak)
            },
            isPeakLogged: { [weak self] peak in
                self?.isPeakLogged(peak) ?? false
            }
        ).tableText()
    }

    func showHillCallout(
        for peakAnnotation: PeakAnnotation,
        placementMode: HillCalloutView.PlacementMode = .belowAnchor
    ) {
        // Hills use a custom overlay view instead of MapLibre's callout cycle so we
        // can control placement and avoid the framework re-centering over the marker.
        dismissActiveHillCallout(animated: false)
        dismissActiveStartPlaceCallout(animated: false)
        dismissActiveCachedAreaCallout(animated: false)
        removeSelectedIrelandPlaceHalo()

        guard let peak = peakAnnotation.peak else { return }

        let isActiveGoToDestination = activeGoToPeak?.id == peak.id
        let primaryActionTitle = isActiveGoToDestination ? "End Go To" : (isPeakLogged(peak) ? "Unlog" : "Log it")
        let primaryActionHandler: () -> Void = { [weak self] in
            if isActiveGoToDestination {
                self?.endGoTo()
            } else {
                self?.toggleLoggedState(for: peak)
            }
        }
        let secondaryActionTitle = isActiveGoToDestination ? "Compass" : "Go To"
        let secondaryActionHandler: (() -> Void) = { [weak self] in
            if isActiveGoToDestination {
                guard let self, let activeGoToTarget = self.activeGoToTarget else { return }
                self.showGoTo(for: activeGoToTarget)
            } else {
                self?.startGoTo(for: peak)
            }
        }
        let tertiaryActionHandler: (() -> Void)? = isActiveGoToDestination
            ? nil
            : regionDefinition.externalDataProviderURL(forPeakIndex: peak.mvIndex).map { url in
                { [weak self] in
                    self?.openExternalDataProviderURL(url)
                }
            }
        let calloutView = HillCalloutView(
            annotation: peakAnnotation,
            title: hillCalloutTitle(for: peak),
            alternateName: alternateHillNameForDisplay(for: peak),
            rangeName: peak.rangeName.isEmpty ? nil : peak.rangeName,
            classification: isPeakLogged(peak) ? nil : expandedClassificationText(for: peak),
            metrics: hillCalloutMetrics(for: peak),
            gridReference: hillCalloutGridReference(for: peak),
            primaryActionTitle: primaryActionTitle,
            primaryActionHandler: primaryActionHandler,
            secondaryActionTitle: secondaryActionTitle,
            secondaryActionHandler: secondaryActionHandler,
            tertiaryActionTitle: isActiveGoToDestination ? nil : "Open MV",
            tertiaryActionHandler: tertiaryActionHandler,
            startPlaceActions: nearestStartPlaceActions(for: peak),
            placementMode: placementMode
        )

        let anchorRectInMapView: CGRect
        if let annotationView = mapView.view(for: peakAnnotation) {
            anchorRectInMapView = annotationView.frame
        } else {
            let anchorPoint = mapView.convert(peak.coordinate, toPointTo: mapView)
            anchorRectInMapView = CGRect(x: anchorPoint.x - 22, y: anchorPoint.y - 22, width: 44, height: 44)
        }

        let constrainedRect = view.safeAreaLayoutGuide.layoutFrame.insetBy(dx: 0, dy: 8)
        let anchorRect = clampedCalloutAnchorRect(
            from: mapView.convert(anchorRectInMapView, to: view),
            constrainedTo: constrainedRect
        )

        calloutView.presentCallout(
            from: anchorRect,
            in: view,
            constrainedTo: constrainedRect,
            animated: true
        )
        activeHillCalloutView = calloutView
    }

    func setMapVisibleArea(for coordinates: [CLLocationCoordinate2D], animated: Bool) {
        MapVisibleAreaFitter(
            mapView: mapView,
            maximumMapZoomLevel: maximumMapZoomLevel
        ).setVisibleArea(for: coordinates, animated: animated)
    }

    func nearestStartPlaceActions(for peak: Peak) -> [CalloutButtonAction] {
        NearbyStartPlaceSelector(
            startPlaces: startPlaces,
            visibleProviders: visibleStartPlaceProviders,
            routeLengthFilter: startPlaceRouteLengthFilter,
            walkSummaryProvider: startPlaceWalkSummaryProvider
        )
            .candidates(near: peak)
            .map { candidate in
                CalloutButtonAction(
                    title: candidate.startPlace.fullDisplayName,
                    tintColor: markerColor(for: candidate.startPlace),
                    handler: { [weak self] in
                        self?.focusOnStartPlace(candidate.startPlace, invocationSource: .other)
                    }
                )
            }
    }

    func openDirections(to startPlace: StartPlace) {
        let coordinate = CLLocationCoordinate2D(latitude: startPlace.latitude, longitude: startPlace.longitude)
        let destinationPlacemark = MKPlacemark(coordinate: coordinate)
        let destination = MKMapItem(placemark: destinationPlacemark)
        destination.name = startPlace.fullDisplayName

        MKMapItem.openMaps(
            with: [MKMapItem.forCurrentLocation(), destination],
            launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        )
    }

    func openGoogleMapsDirections(to startPlace: StartPlace) {
        let latitude = startPlace.latitude
        let longitude = startPlace.longitude
        let encodedName = startPlace.fullDisplayName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? startPlace.fullDisplayName
        let appURLString = "comgooglemaps://?daddr=\(latitude),\(longitude)&directionsmode=driving&q=\(encodedName)"
        let webURLString = "https://www.google.com/maps/dir/?api=1&destination=\(latitude),\(longitude)&travelmode=driving"

        guard let appURL = URL(string: appURLString), let webURL = URL(string: webURLString) else { return }

        UIApplication.shared.open(appURL, options: [:]) { success in
            guard !success else { return }
            UIApplication.shared.open(webURL, options: [:], completionHandler: nil)
        }
    }

    func nearbyHillActions(for startPlace: StartPlace) -> [StartPlaceNearbyHillAction] {
        NearbyHillActionBuilder(
            peaks: peaks,
            displayUnitSystem: selectedDisplayUnitSystem,
            bearing: { [goToSessionStore] start, end in
                goToSessionStore.bearing(from: start, to: end)
            },
            focusOnPeak: { [weak self] peak in
                self?.focusOnPeak(
                    peak,
                    placementMode: .belowAnchor,
                    positionsPeakForCallout: true,
                    invocationSource: .other
                )
            }
        ).actions(for: startPlace)
    }

}
