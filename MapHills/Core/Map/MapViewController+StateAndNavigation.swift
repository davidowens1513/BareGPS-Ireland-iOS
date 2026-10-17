//
//  MapViewController+StateAndNavigation.swift
//  Maphills
//
//  Created by Codex on 07/07/2026.
//

import CoreLocation
import MapLibre
import UIKit

extension ViewController {
    func focusMap(on cachedArea: CachedOfflineArea) {
        dismissActiveHillCallout(animated: false)
        dismissActiveCachedAreaCallout(animated: false)
        mapView.setVisibleCoordinateBounds(
            cachedArea.bounds,
            edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 120, right: 40),
            animated: true,
            completionHandler: nil
        )
    }

    func resumeCachedOfflineArea(
        _ area: CachedOfflineArea,
        completion: @escaping (CachedOfflineArea?) -> Void
    ) {
        if let activePack = offlinePack,
           decodedOfflineContext(from: activePack.context)?.id != area.id {
            let overlay = ActionOverlayViewController(
                title: "Download In Progress",
                message: "Wait for the current offline area to finish before retrying another cache.",
                actions: [
                    .init(title: "OK", style: .normal) {
                        completion(nil)
                    }
                ]
            )
            topmostPresentingViewController().present(overlay, animated: true)
            return
        }

        let packs = MLNOfflineStorage.shared.packs ?? []
        guard let matchingPack = packs.first(where: { decodedOfflineContext(from: $0.context)?.id == area.id }) else {
            completion(nil)
            return
        }

        var failures = offlineCacheStore.loadFailures()
        failures.removeValue(forKey: area.id)
        offlineCacheStore.saveFailures(failures)

        offlinePack = matchingPack
        matchingPack.resume()
        reloadPersistedOfflineAreas()
        setDownloadButtonTitle("Downloading \(area.name)…")
        updateCacheProgressOverlay()
        completion(cachedOfflineArea(for: area.id))
    }

    func refreshPeakAnnotationSubtitles() {
        guard shouldRefreshPeakAnnotationSubtitles() else { return }

        // Update distances when the user's location changes.
        let annotations = peakAnnotationPresentationStore.peakAnnotations(from: mapView.annotations)
        guard !annotations.isEmpty else { return }

        for annotation in annotations {
            guard let peak = annotation.peak else { continue }
            annotation.subtitle = subtitle(for: peak)
        }
    }

    func shouldRefreshPeakAnnotationSubtitles() -> Bool {
        guard showsHillMarkers else { return false }
        guard let currentLocation = mapView.userLocation?.location else { return false }

        let now = Date()
        guard let lastLocation = lastPeakSubtitleRefreshLocation,
              let lastRefreshTime = lastPeakSubtitleRefreshTime else {
            lastPeakSubtitleRefreshLocation = currentLocation
            lastPeakSubtitleRefreshTime = now
            return true
        }

        let movedEnough = currentLocation.distance(from: lastLocation) >= 100
        let waitedEnough = now.timeIntervalSince(lastRefreshTime) >= 5
        guard movedEnough || waitedEnough else { return false }

        lastPeakSubtitleRefreshLocation = currentLocation
        lastPeakSubtitleRefreshTime = now
        return true
    }

    func subtitle(for peak: Peak) -> String {
        let heightText = "Height: \(formattedElevation(peak.heightM))"
        let prominenceText = "Prom.: \(formattedProminence(peak.prominenceM))"

        if let userCoord = mapView.userLocation?.coordinate {
            let peakLocation = CLLocation(latitude: peak.latitude, longitude: peak.longitude)
            let userLocation = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
            let distanceText = "Dist.: \(formattedDistance(peakLocation.distance(from: userLocation)))"

            return "\(heightText) • \(prominenceText) • \(distanceText)"
        } else {
            return "\(heightText) • \(prominenceText) • Dist.: n/a"
        }
    }

    func hillCalloutTitle(for peak: Peak) -> String {
        return "\(peak.name) • \(formattedCompactElevation(peak.heightM))"
    }

    func alternateHillNameForDisplay(for peak: Peak) -> String? {
        let alternateName = peak.alternateHillName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !alternateName.isEmpty else { return nil }

        let normalizedTitle = duplicateNameComparisonText(peak.name)
        let normalizedAlternateName = duplicateNameComparisonText(alternateName)
        guard !normalizedAlternateName.isEmpty else { return nil }
        return normalizedTitle.contains(normalizedAlternateName) ? nil : alternateName
    }

    func duplicateNameComparisonText(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .filter { $0.isLetter || $0.isNumber }
    }

    func hillCalloutMetrics(for peak: Peak) -> String {
        let prominenceText = "Prom.: \(formattedProminence(peak.prominenceM))"

        if let userCoord = mapView.userLocation?.coordinate {
            let peakLocation = CLLocation(latitude: peak.latitude, longitude: peak.longitude)
            let userLocation = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
            let distanceText = "Dist.: \(formattedDistance(peakLocation.distance(from: userLocation)))"
            return "\(prominenceText) • \(distanceText)"
        } else {
            return "\(prominenceText) • Dist.: n/a"
        }
    }

    func hillCalloutGridReference(for peak: Peak) -> String {
        "Grid Ref: \(peak.formattedRegionGridReference ?? "n/a")"
    }

    func nonDistanceMetrics(for peak: Peak) -> String {
        let heightText = "Height: \(formattedElevation(peak.heightM))"
        let prominenceText = "Prominence: \(formattedProminence(peak.prominenceM))"
        let gridRefText = "Grid Ref: \(peak.formattedRegionGridReference ?? "n/a")"
        return "\(heightText) • \(prominenceText)\n\(gridRefText)"
    }

    func updateGoToOverlayNavigation(for target: GoToTarget) {
        guard let overlay = goToOverlayViewController else { return }

        let userCoordinate = currentValidUserCoordinate()
        let userLocation = userCoordinate.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        let targetLocation = CLLocation(latitude: target.coordinate.latitude, longitude: target.coordinate.longitude)

        let distanceMeters = userLocation.map { targetLocation.distance(from: $0) }
        let bearingDegrees = userCoordinate.map { goToSessionStore.bearing(from: $0, to: target.coordinate) }

        overlay.updateNavigation(
            distanceMeters: distanceMeters,
            bearingDegrees: bearingDegrees,
            headingDegrees: latestHeading
        )

        refreshGoToPolyline(from: userCoordinate, to: target.coordinate)
    }

    func startGoTo(for peak: Peak) {
        startGoTo(for: GoToTarget(peak: peak, subtitle: goToSubtitle(for: peak)))
    }

    func startGoTo(for target: GoToTarget) {
        dismissActiveHillCallout(animated: false)
        dismissActiveStartPlaceCallout(animated: false)
        dismissActiveCachedAreaCallout(animated: false)
        if target.peak == nil {
            selectedPeakID = nil
            mapView.selectedAnnotations = []
            isRefreshingSelectionState = true
            reloadPeakAnnotations()
            isRefreshingSelectionState = false
        }

        if isUITestBypassingLocationPrompts {
            clearGoToPolyline()
            updateGoToTargetAnnotation(for: target)
            goToOverlayViewController?.dismiss(animated: false)
            goToOverlayViewController = nil
            goToSessionStore.activate(target)
            showGoTo(for: target)
            return
        }

        switch locationAuthorizationPolicyStore.goToResolution(for: locationManager.authorizationStatus) {
        case .requestPermission:
            pendingGoToTarget = target
            locationManager.requestWhenInUseAuthorization()
        case .showAccessAlert(let title, let message):
            presentLocationAccessRequiredAlert(title: title, message: message)
        case .proceed:
            clearGoToPolyline()
            updateGoToTargetAnnotation(for: target)
            goToOverlayViewController?.dismiss(animated: false)
            goToOverlayViewController = nil
            goToSessionStore.activate(target)
            resumeLocationUpdatesIfNeeded()
            mapView.showsUserLocation = true
            showGoTo(for: target)
        case .explainTrailRecordingPermission:
            break
        }
    }

    func endGoTo() {
        dismissActiveHillCallout(animated: false)
        goToSessionStore.clear()
        goToOverlayViewController?.dismiss(animated: true)
        goToOverlayViewController = nil
        clearGoToPolyline()
        clearGoToTargetAnnotation()
        isRefreshingSelectionState = true
        reloadPeakAnnotations(selecting: selectedPeakID)
        isRefreshingSelectionState = false
    }

    func presentCancelGoToConfirmation() {
        let title = activeGoToTarget.map { "GoTo \($0.title)" } ?? "GoTo"
        var actions: [ActionOverlayViewController.Action] = [
            .init(title: "Keep GoTo", style: .normal, handler: {})
        ]
        if let activeGoToTarget {
            actions.append(.init(title: "Open Compass", style: .normal) { [weak self] in
                self?.showGoTo(for: activeGoToTarget)
            })
        }
        actions.append(.init(title: "Cancel GoTo", style: .destructive) { [weak self] in
            self?.endGoTo()
        })
        let overlay = ActionOverlayViewController(
            title: title,
            actions: actions
        )
        topmostPresentingViewController().present(overlay, animated: true)
    }

    func presentSelectedProviderTrailActions() {
        let now = CACurrentMediaTime()
        guard now - lastProviderTrailTapTimestamp >= 0.35 else { return }
        lastProviderTrailTapTimestamp = now

        let presenter = topmostPresentingViewController()
        guard !(presenter is ActionOverlayViewController) else { return }

        let overlay = ActionOverlayViewController(
            title: selectedProviderTrailName ?? "Selected Walk",
            actions: [
                .init(title: "Hide Walk", style: .normal) { [weak self] in
                    self?.clearSelectedTrailPolylines()
                },
                .init(title: "Cancel", style: .cancel, handler: {})
            ]
        )
        presenter.present(overlay, animated: true)
    }

    @objc func handleMapTapForGoToLine(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }

        let now = CACurrentMediaTime()
        if now - lastGoToLineTapTimestamp < 0.35 {
            return
        }

        let tapPoint = recognizer.location(in: view)
        guard isTapNearActiveGoToLine(at: tapPoint) else { return }

        lastGoToLineTapTimestamp = now
        presentCancelGoToConfirmation()
    }

    @objc func handleMapTapForProviderTrail(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }

        let tapPoint = recognizer.location(in: view)
        guard isTapNearSelectedProviderTrail(at: tapPoint) else { return }

        presentSelectedProviderTrailActions()
    }

    @objc func hideSelectedProviderTrailTapped() {
        clearSelectedTrailPolylines()
    }

    @objc func handleMapLongPressForGoTo(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }

        let point = recognizer.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        presentMapLongPressActions(for: coordinate, sourcePoint: point)
    }

    func openExternalDataProviderURL(_ url: URL) {
        UIApplication.shared.open(url)
    }

    func showGoTo(for target: GoToTarget) {
        let overlay = GoToHillOverlayViewController(
            target: target,
            goToLineColor: goToLineColor,
            distanceFormatter: { [weak self] in
                self?.formattedDistance($0) ?? ""
            },
            cancelGoToHandler: { [weak self] in
                self?.endGoTo()
            },
            dismissHandler: { [weak self] in
                self?.goToOverlayViewController = nil
                guard let self, self.activeGoToTarget?.peak != nil else { return }
                self.selectedPeakID = nil
                self.mapView.selectedAnnotations = []
                self.isRefreshingSelectionState = true
                self.reloadPeakAnnotations()
                self.isRefreshingSelectionState = false
            }
        )
        goToOverlayViewController = overlay
        topmostPresentingViewController().present(overlay, animated: true)

        startHeadingUpdatesIfAvailable()
        updateGoToOverlayNavigation(for: target)
    }

    func refreshGoToPolyline(from start: CLLocationCoordinate2D?, to end: CLLocationCoordinate2D, force: Bool = false) {
        guard let start else { return }

        if !force,
           !goToSessionStore.shouldRefreshPolyline(from: start, minimumMovementDistance: 4),
           goToPolylineAnnotation != nil {
            return
        }
        clearGoToPolyline()

        var coordinates = [start, end]
        let polyline = GoToPolyline(coordinates: &coordinates, count: UInt(coordinates.count))
        goToPolylineAnnotation = polyline
        UIView.performWithoutAnimation {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            mapView.addAnnotation(polyline)
            CATransaction.commit()
        }
    }

    func clearGoToPolyline() {
        if let goToPolylineAnnotation {
            UIView.performWithoutAnimation {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                mapView.removeAnnotation(goToPolylineAnnotation)
                CATransaction.commit()
            }
            self.goToPolylineAnnotation = nil
        }
    }

    func updateGoToTargetAnnotation(for target: GoToTarget) {
        if target.peak != nil {
            clearGoToTargetAnnotation()
            return
        }

        if let goToTargetAnnotation {
            goToTargetAnnotation.coordinate = target.coordinate
            goToTargetAnnotation.target = target
            goToTargetAnnotation.title = target.title
            return
        }

        let annotation = GoToTargetAnnotation()
        annotation.coordinate = target.coordinate
        annotation.target = target
        annotation.title = target.title
        goToTargetAnnotation = annotation
        mapView.addAnnotation(annotation)
    }

    func clearGoToTargetAnnotation() {
        if let goToTargetAnnotation {
            mapView.removeAnnotation(goToTargetAnnotation)
            self.goToTargetAnnotation = nil
        }
    }

    func distanceBetween(_ lhs: CGPoint, and rhs: CGPoint) -> CGFloat {
        MapFormatting.distanceBetween(lhs, and: rhs)
    }

    func distanceFrom(point: CGPoint, toSegmentStart start: CGPoint, end: CGPoint) -> CGFloat {
        MapFormatting.distanceFrom(point: point, toSegmentStart: start, end: end)
    }

    func isTapNearActiveGoToLine(at point: CGPoint) -> Bool {
        guard let activeGoToTarget, let start = currentValidUserCoordinate() else { return false }

        let startPoint = mapView.convert(start, toPointTo: view)
        let endPoint = mapView.convert(activeGoToTarget.coordinate, toPointTo: view)

        let tapThreshold: CGFloat = 18
        let endpointExclusionRadius: CGFloat = 28

        guard distanceBetween(point, and: endPoint) > endpointExclusionRadius else { return false }
        return distanceFrom(point: point, toSegmentStart: startPoint, end: endPoint) <= tapThreshold
    }

    func isTapNearSelectedProviderTrail(at point: CGPoint) -> Bool {
        guard !selectedProviderTrailCoordinateSegments.isEmpty else { return false }

        let tapThreshold: CGFloat = 24
        for segment in selectedProviderTrailCoordinateSegments where segment.count > 1 {
            var previousPoint = mapView.convert(segment[0], toPointTo: view)
            for coordinate in segment.dropFirst() {
                let nextPoint = mapView.convert(coordinate, toPointTo: view)
                if distanceFrom(point: point, toSegmentStart: previousPoint, end: nextPoint) <= tapThreshold {
                    return true
                }
                previousPoint = nextPoint
            }
        }
        return false
    }

    func goToSubtitle(for peak: Peak) -> String? {
        [
            alternateHillNameForDisplay(for: peak).map { "(\($0))" },
            peak.rangeName.isEmpty ? nil : peak.rangeName,
            expandedClassificationText(for: peak)
        ]
            .compactMap { $0 }
            .joined(separator: " • ")
    }

    func goToTarget(for coordinate: CLLocationCoordinate2D) -> GoToTarget {
        let gridReference = irishNationalGridReference(for: coordinate)
        let fallbackReference = String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
        let subtitle = "Grid Ref: \(gridReference ?? fallbackReference)"
        return GoToTarget(title: "Selected Map Point", subtitle: subtitle, coordinate: coordinate)
    }

    func expandedClassificationText(for peak: Peak) -> String? {
        let peakCodes = Set(classificationCodes(for: peak))
        let irishCodes = classificationSections(for: peakCodes)
            .first(where: { $0.title == "Irish Classifications" })?
            .codes ?? []
        let expandedNames = irishCodes.compactMap(abbreviatedHillCardClassificationName(for:))

        guard !expandedNames.isEmpty else {
            return nil
        }

        return expandedNames.joined(separator: ", ")
    }

    func abbreviatedHillCardClassificationName(for code: String) -> String? {
        switch code.uppercased() {
        case "A":
            return "Ard"
        case "AB":
            return "Ard Beg"
        case "VL":
            return "VL"
        case "HH":
            return "HH"
        case "L100":
            return "L100"
        case "RHP":
            return "RHP"
        case "4":
            return "Carn"
        case "BIN":
            return "Bin"
        case "COH":
            return "CHP"
        case "OTHER":
            return "Other"
        default:
            return nil
        }
    }

    func showHillCountOverlay(for count: Int) {
        let countChanged = count != visibleHillCountOnMap
        visibleHillCountOnMap = count

        if countChanged || (isHillCountLineVisible && hillCountLineHideTimer == nil) {
            showHillCountLineTemporarily()
        } else {
            updateMapStatusOverlay()
        }
    }

    func updateMapStatusOverlay() {
        let currentPositionText = currentPositionGridReferenceText() ?? "u/a"
        let centerPositionText = centerPositionGridReferenceText() ?? "u/a"
        let distanceToCenterText = distanceToCenterText() ?? "u/a"
        let accuracyText = MapFormatting.formattedLiveGPXAccuracy(mapView.userLocation?.location, unitSystem: .metric)
        var statusLines: [String] = []

        if isHillCountLineVisible {
            statusLines.append("  Hills shown on Map: \(visibleHillCountOnMap)  ")
        }

        statusLines.append("  Current Position: \(currentPositionText)  ")
        statusLines.append("  Centre Position: \(centerPositionText)  ")
        statusLines.append("  Distance to Centre: \(distanceToCenterText)  ")
        statusLines.append("  GPS Accuracy: \(accuracyText)  ")

        let statusText = statusLines.joined(separator: "\n")
        if hillCountOverlayLabel.text != statusText {
            hillCountOverlayLabel.text = statusText
        }
        hillCountOverlayLabel.isHidden = false
    }

    func showHillCountLineTemporarily() {
        hillCountLineHideTimer?.invalidate()
        isHillCountLineVisible = true
        updateMapStatusOverlay()

        let timer = Timer(timeInterval: 20, repeats: false) { [weak self] _ in
            self?.hideHillCountLine()
        }
        hillCountLineHideTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func hideHillCountLine() {
        hillCountLineHideTimer?.invalidate()
        hillCountLineHideTimer = nil
        isHillCountLineVisible = false
        updateMapStatusOverlay()
    }

    func distanceToCenterText() -> String? {
        guard let userCoordinate = currentValidUserCoordinate() else { return nil }
        let userLocation = CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)
        let centerCoordinate = mapView.centerCoordinate
        guard CLLocationCoordinate2DIsValid(centerCoordinate) else { return nil }
        let centerLocation = CLLocation(latitude: centerCoordinate.latitude, longitude: centerCoordinate.longitude)
        return MapFormatting.formattedDistance(userLocation.distance(from: centerLocation), unitSystem: .metric)
    }

    func presentGPXImportAlert(title: String, message: String) {
        presentInfoOverlay(title: title, message: message)
    }

    func topmostPresentingViewController() -> UIViewController {
        var topController: UIViewController = self
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }
        return topController
    }

    func presentInfoOverlay(title: String, message: String, buttonTitle: String = "OK") {
        let overlay = ActionOverlayViewController(
            title: title,
            message: message,
            actions: [
                .init(title: buttonTitle, style: .normal, handler: {})
            ]
        )
        topmostPresentingViewController().present(overlay, animated: true)
    }

    func presentLocationAccessRequiredAlert(title: String, message: String) {
        let overlay = ActionOverlayViewController(
            title: title,
            message: message,
            actions: [
                .init(title: "Cancel", style: .cancel, handler: {}),
                .init(title: "Settings", style: .normal) {
                    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(settingsURL)
                }
            ]
        )
        topmostPresentingViewController().present(overlay, animated: true)
    }

    func persistFilterState() {
        preferencesStore.saveFilterState(
            selectedFilterSchema: selectedFilterSchema,
            selectedHillFilterMode: selectedHillFilterMode,
            selectedHeightBandIDs: selectedHeightBands.map(\.rawValue),
            selectedClassificationCodes: Array(selectedClassificationCodes),
            advancedHillFilter: advancedHillFilter,
            savedAdvancedHillFilterPresets: savedAdvancedHillFilterPresets
        )
    }

    func saveDisplayUnitSystem(_ displayUnitSystem: DisplayUnitSystem) {
        selectedDisplayUnitSystem = displayUnitSystem
        preferencesStore.saveDisplayUnitSystem(displayUnitSystem)
    }

    func saveMapOrientationMode(_ mapOrientationMode: MapOrientationMode) {
        selectedMapOrientationMode = mapOrientationMode
        preferencesStore.saveMapOrientationMode(mapOrientationMode)
        if mapOrientationMode == .headsUp, mapView.userTrackingMode != .follow {
            recenterTapped()
        } else {
            applyMapOrientationMode(animated: true)
        }
    }

    func saveMapInteractionLocked(_ isLocked: Bool) {
        if isLocked, !isMapInteractionLocked, isTrailRecording {
            centerMapForTrailRecordingStart(using: mapView.userLocation?.location)
        }
        isMapInteractionLocked = isLocked
        preferencesStore.saveMapInteractionLocked(isLocked)
        applyMapInteractionLock()
        applyMapOrientationMode(animated: true)
        gpxOverlayViewController?.syncMapInteractionLockState(isLocked)
        settingsOverlayViewController?.syncMapInteractionLockState(isLocked)
    }

    func saveVisibleStartPlaceProviders(_ providers: Set<StartPlaceProvider>) {
        visibleStartPlaceProviders = providers
        preferencesStore.saveVisibleStartPlaceProviders(providers)
        dismissActiveStartPlaceCallout(animated: false)
        if let selectedProviderTrailProvider, !providers.contains(selectedProviderTrailProvider) {
            clearSelectedTrailPolylines()
        }
        reloadStartPlaceAnnotations()
    }

    func saveStartPlaceRouteLengthFilter(_ filter: StartPlaceRouteLengthFilter) {
        startPlaceRouteLengthFilter = filter
        preferencesStore.saveStartPlaceRouteLengthFilter(filter)
        dismissActiveStartPlaceCallout(animated: false)
        if selectedProviderTrailIsHiddenByRouteLengthFilter() {
            clearSelectedTrailPolylines()
        }
        reloadStartPlaceAnnotations()
    }

    func selectedProviderTrailIsHiddenByRouteLengthFilter() -> Bool {
        guard
            let minimumLengthMeters = startPlaceRouteLengthFilter.minimumLengthMeters,
            let selectedProviderTrailLengthMeters
        else {
            return false
        }
        return selectedProviderTrailLengthMeters < minimumLengthMeters
    }

    func saveTrackRecordingQuality(_ trackRecordingQuality: TrackRecordingQuality) {
        selectedTrackRecordingQuality = trackRecordingQuality
        preferencesStore.saveTrackRecordingQuality(trackRecordingQuality)
    }

    func saveShowsGridLines(_ showsGridLines: Bool) {
        self.showsGridLines = showsGridLines
        preferencesStore.saveShowsGridLines(showsGridLines)
        applyGridLineVisibility()
    }

    func saveShowsTownlands(_ showsTownlands: Bool) {
        self.showsTownlands = showsTownlands
        preferencesStore.saveShowsTownlands(showsTownlands)
        applyTownlandVisibility()
    }

    func applyGridLineVisibility() {
        guard selectedMapBaseLayer == .openBareMap, let style = mapView.style else { return }
        let gridLayerIdentifiers = [
            "irish-grid-1km",
            "irish-grid-10km",
            "irish-grid-labels"
        ]

        for layerIdentifier in gridLayerIdentifiers {
            style.layer(withIdentifier: layerIdentifier)?.isVisible = showsGridLines
        }
    }

    func applyTownlandVisibility() {
        guard selectedMapBaseLayer == .openBareMap, let style = mapView.style else { return }
        style.layer(withIdentifier: "townland-labels")?.isVisible = showsTownlands
    }

    func saveOpenBareMapDetail(_ detail: OpenBareMapDetail, isVisible: Bool) {
        if isVisible {
            visibleOpenBareMapDetails.insert(detail)
        } else {
            visibleOpenBareMapDetails.remove(detail)
        }
        preferencesStore.saveVisibleOpenBareMapDetails(visibleOpenBareMapDetails)
        applyOpenBareMapDetailVisibility()
    }

    func applyOpenBareMapDetailVisibility() {
        guard selectedMapBaseLayer == .openBareMap, let style = mapView.style else { return }

        for detail in OpenBareMapDetail.allCases {
            let isVisible = visibleOpenBareMapDetails.contains(detail)
            for layerIdentifier in detail.layerIdentifiers {
                style.layer(withIdentifier: layerIdentifier)?.isVisible = isVisible
            }
        }
    }

    func saveShowsCompactRecordingGrid(_ showsCompactRecordingGrid: Bool) {
        self.showsCompactRecordingGrid = showsCompactRecordingGrid
        preferencesStore.saveShowsCompactRecordingGrid(showsCompactRecordingGrid)
        updateLiveGPXStatsCard()
    }

    func saveMarkerColorSchema(_ schema: MenuFilterSchema) {
        selectedMarkerColorSchema = .classification
        preferencesStore.saveMarkerColorSchema(.classification)
    }

    func resolvedMarkerColor(for optionID: String, defaultColor: UIColor) -> UIColor {
        if let cachedColor = markerColors[optionID] {
            return cachedColor
        }
        guard let color = preferencesStore.loadMarkerColor(for: optionID) else {
            markerColors[optionID] = defaultColor
            return defaultColor
        }
        markerColors[optionID] = color
        return color
    }

    func saveMarkerColor(_ color: UIColor, for optionID: String) {
        markerColors[optionID] = color
        preferencesStore.saveMarkerColor(color, for: optionID)
    }

    func saveRecordedTrackColor(_ color: UIColor) {
        recordedTrackColor = color
        preferencesStore.saveRecordedTrackColor(color)
    }

    func saveGoToLineColor(_ color: UIColor) {
        goToLineColor = color
        preferencesStore.saveGoToLineColor(color)
        goToOverlayViewController?.updateGoToLineColor(color)
        if let latestLocation = locationManager.location?.coordinate, let activeGoToTarget {
            refreshGoToPolyline(from: latestLocation, to: activeGoToTarget.coordinate, force: true)
        }
    }

    func saveShowsSnailTrail(_ showsSnailTrail: Bool) {
        self.showsSnailTrail = showsSnailTrail
        preferencesStore.saveShowsSnailTrail(showsSnailTrail)
        if !showsSnailTrail {
            breadcrumbTrailPoints.removeAll()
        }
        refreshBreadcrumbTrailOverlay()
    }

    func saveSnailTrailColor(_ color: UIColor) {
        snailTrailColor = color
        preferencesStore.saveSnailTrailColor(color)
        refreshBreadcrumbTrailOverlay()
    }

    func saveImportedTrackColor(_ color: UIColor) {
        importedTrackColor = color
        preferencesStore.saveImportedTrackColor(color)
    }

    func colorCacheKey(for color: UIColor) -> String {
        MapAnnotationImages.colorCacheKey(for: color)
    }

    func heightMarkerColorCategory(for peak: Peak) -> MarkerColorCategory {
        if peak.heightM >= 600 {
            return .from600Up
        } else if peak.heightM >= 500 {
            return .from500To600
        } else if peak.heightM >= 400 {
            return .from400To500
        } else if peak.heightM >= 300 {
            return .from300To400
        } else if peak.heightM >= 200 {
            return .from200To300
        } else if peak.heightM >= 100 {
            return .from100To200
        } else {
            return .below100
        }
    }

    func markerColorOptionID(for peak: Peak, isLogged: Bool) -> String {
        if isLogged {
            return "logged"
        }
        return "hills"
    }

    func defaultMarkerColor(for optionID: String) -> UIColor {
        if optionID == "logged" {
            return MarkerColorCategory.logged.defaultColor
        }
        if optionID == "hills" {
            return .systemOrange
        }
        if optionID == "waypoints" {
            return .systemBlue
        }
        if optionID == "mvStartPoints" {
            return .systemGreen
        }
        if optionID == "sportIrelandStartPoints" {
            return .systemPurple
        }
        if optionID == "coillteStartPoints" {
            return .systemBrown
        }
        if optionID == "outscapeStartPoints" {
            return .systemOrange
        }
        return .systemOrange
    }

    func markerColor(for peak: Peak, isLogged: Bool) -> UIColor {
        let optionID = markerColorOptionID(for: peak, isLogged: isLogged)
        return resolvedMarkerColor(for: optionID, defaultColor: defaultMarkerColor(for: optionID))
    }

    func markerColorOptionID(for provider: StartPlaceProvider) -> String {
        switch provider {
        case .mountainViews:
            return "mvStartPoints"
        case .sportIreland:
            return "sportIrelandStartPoints"
        case .coillte:
            return "coillteStartPoints"
        case .outscape:
            return "outscapeStartPoints"
        }
    }

    func markerColor(for provider: StartPlaceProvider) -> UIColor {
        let optionID = markerColorOptionID(for: provider)
        return resolvedMarkerColor(for: optionID, defaultColor: defaultMarkerColor(for: optionID))
    }

    func markerColor(for startPlace: StartPlace) -> UIColor {
        markerColor(for: startPlace.provider)
    }

    func markerColorOptions() -> [MarkerColorOption] {
        let hillsOption = MarkerColorOption(
            id: "hills",
            title: "Hills",
            color: resolvedMarkerColor(for: "hills", defaultColor: .systemOrange)
        )
        let loggedOption = MarkerColorOption(
            id: "logged",
            title: "Logged Hills",
            color: resolvedMarkerColor(for: "logged", defaultColor: MarkerColorCategory.logged.defaultColor)
        )
        let waypointsOption = MarkerColorOption(
            id: "waypoints",
            title: "Waypoints",
            color: resolvedMarkerColor(for: "waypoints", defaultColor: .systemBlue)
        )
        let mvStartPointsOption = MarkerColorOption(
            id: "mvStartPoints",
            title: "MountainViews",
            color: resolvedMarkerColor(for: "mvStartPoints", defaultColor: .systemGreen)
        )
        let sportIrelandStartPointsOption = MarkerColorOption(
            id: "sportIrelandStartPoints",
            title: "Sport Ireland",
            color: resolvedMarkerColor(for: "sportIrelandStartPoints", defaultColor: .systemPurple)
        )
        let coillteStartPointsOption = MarkerColorOption(
            id: "coillteStartPoints",
            title: "Coillte",
            color: resolvedMarkerColor(for: "coillteStartPoints", defaultColor: .systemBrown)
        )
        let outscapeStartPointsOption = MarkerColorOption(
            id: "outscapeStartPoints",
            title: "Outscape NI",
            color: resolvedMarkerColor(for: "outscapeStartPoints", defaultColor: .systemOrange)
        )
        return [
            hillsOption,
            loggedOption,
            mvStartPointsOption,
            sportIrelandStartPointsOption,
            coillteStartPointsOption,
            outscapeStartPointsOption,
            waypointsOption
        ]
    }

    func migrateLoggedPeakIDsIfNeeded() {
        loggedPeakController.migrateIfNeeded(using: peaks)
    }

    func isPeakLogged(_ peak: Peak) -> Bool {
        loggedPeakController.contains(peak)
    }

    func toggleLoggedState(for peak: Peak, completion: ((Bool) -> Void)? = nil) {
        dismissActiveHillCallout(animated: false)
        if isPeakLogged(peak) {
            presentUnlogConfirmation(for: peak, completion: completion)
        } else {
            presentLogConfirmation(for: peak, completion: completion)
        }
    }

    func presentLogConfirmation(for peak: Peak, completion: ((Bool) -> Void)? = nil) {
        let overlay = ConfirmationOverlayViewController(
            title: "Log Hill",
            message: "Add \(peak.name) to your logged hills?",
            confirmTitle: "Log",
            confirmHandler: { [weak self] in
                self?.dismissActiveHillCallout(animated: false)
                self?.selectedPeakID = nil
                self?.mapView.selectedAnnotations = []
                self?.loggedPeakController.log(peak)
                self?.reloadPeakAnnotations()
                completion?(true)
            },
            cancelHandler: {
                completion?(false)
            }
        )
        topmostPresentingViewController().present(overlay, animated: true)
    }

    func presentUnlogConfirmation(for peak: Peak, completion: ((Bool) -> Void)? = nil) {
        let overlay = ConfirmationOverlayViewController(
            title: "Unlog Hill",
            message: "Remove \(peak.name) from your logged hills?",
            confirmTitle: "Unlog",
            confirmTintColor: .systemRed,
            confirmHandler: { [weak self] in
                self?.dismissActiveHillCallout(animated: false)
                self?.selectedPeakID = nil
                self?.mapView.selectedAnnotations = []
                self?.loggedPeakController.unlog(peak)
                self?.reloadPeakAnnotations()
                completion?(true)
            },
            cancelHandler: {
                completion?(false)
            }
        )
        topmostPresentingViewController().present(overlay, animated: true)
    }

    func annotationImage(for peak: Peak, isLogged: Bool, isSelected: Bool) -> UIImage {
        MapAnnotationImages.hillMarkerImage(
            markerColor: markerColor(for: peak, isLogged: isLogged),
            isLogged: isLogged,
            isSelected: isSelected
        )
    }

    func startPlaceAnnotationImage(for startPlace: StartPlace, isSelected: Bool) -> UIImage {
        let markerColor = markerColor(for: startPlace)
        let selectionStateKey = isSelected ? "selected" : "normal"
        let cacheKey = "\(startPlace.provider.rawValue)-\(colorCacheKey(for: markerColor))-\(selectionStateKey)"
        if let cachedImage = startPlaceMarkerImageCache[cacheKey] {
            return cachedImage
        }

        let image = MapAnnotationImages.startPlaceMarkerImage(
            markerColor: markerColor,
            title: "",
            isSelected: isSelected
        )
        startPlaceMarkerImageCache[cacheKey] = image
        return image
    }

    func goToTargetAnnotationImage() -> UIImage {
        MapAnnotationImages.goToTargetMarkerImage(color: goToLineColor)
    }

    func savedWaypointAnnotationImage() -> UIImage {
        MapAnnotationImages.savedWaypointMarkerImage(
            color: resolvedMarkerColor(for: "waypoints", defaultColor: .systemBlue)
        )
    }

    // MARK: - Offline Pack Helpers

    func encodedOfflineContext(for cachedArea: CachedOfflineArea) -> Data {
        offlineCacheStore.encodedOfflineContext(for: cachedArea)
    }

    func decodedOfflineContext(from data: Data) -> OfflinePackContext? {
        offlineCacheStore.decodedOfflineContext(from: data)
    }

    func isOfflinePackComplete(_ pack: MLNOfflinePack) -> Bool {
        offlineCacheStore.isOfflinePackComplete(pack)
    }

    func isOfflinePackActive(_ pack: MLNOfflinePack) -> Bool {
        offlineCacheStore.isOfflinePackActive(pack)
    }

    func reloadPersistedOfflineAreas() {
        let packs = MLNOfflineStorage.shared.packs ?? []
        let rebuiltInventory = offlineCacheStore.rebuildCachedOfflineAreas(from: packs)
        cachedOfflineAreas = rebuiltInventory.areas
        hasLoadedOfflineArea = !cachedOfflineAreas.isEmpty

        if let activelyDownloadingPack = rebuiltInventory.activePack {
            offlinePack = activelyDownloadingPack
        } else {
            offlinePack = nil
        }

        refreshCachedAreaOverlays()
    }

    func refreshOfflinePackInventory() {
        MLNOfflineStorage.shared.reloadPacks()

        DispatchQueue.main.async { [weak self] in
            self?.reloadPersistedOfflineAreas()
            self?.updateDownloadButtonForExistingPack()
        }
    }

    func refreshCachedAreaOverlays() {
        if !cachedAreaPolygons.isEmpty {
            mapView.removeAnnotations(cachedAreaPolygons)
            cachedAreaPolygons.removeAll()
        }
        if !cachedAreaBorders.isEmpty {
            mapView.removeAnnotations(cachedAreaBorders)
            cachedAreaBorders.removeAll()
        }

        let readyAreas = cachedOfflineAreas.filter { $0.status == .ready }
        let polygons = readyAreas.compactMap { polygonAnnotation(for: $0) }
        let borders = readyAreas.compactMap { borderAnnotation(for: $0) }
        cachedAreaPolygons = polygons
        cachedAreaBorders = borders

        if !polygons.isEmpty {
            mapView.addAnnotations(polygons)
        }
        if !borders.isEmpty {
            mapView.addAnnotations(borders)
        }
    }

    func polygonAnnotation(for cachedArea: CachedOfflineArea) -> CachedAreaPolygon? {
        let sw = cachedArea.bounds.sw
        let ne = cachedArea.bounds.ne
        let nw = CLLocationCoordinate2D(latitude: ne.latitude, longitude: sw.longitude)
        let se = CLLocationCoordinate2D(latitude: sw.latitude, longitude: ne.longitude)

        guard
            CLLocationCoordinate2DIsValid(sw),
            CLLocationCoordinate2DIsValid(ne),
            CLLocationCoordinate2DIsValid(nw),
            CLLocationCoordinate2DIsValid(se)
        else {
            return nil
        }

        var coordinates = [sw, nw, ne, se]
        let polygon = CachedAreaPolygon(coordinates: &coordinates, count: UInt(coordinates.count))
        polygon.cachedAreaID = cachedArea.id
        polygon.cachedAreaName = cachedArea.name
        return polygon
    }

    func borderAnnotation(for cachedArea: CachedOfflineArea) -> CachedAreaBorderPolyline? {
        let sw = cachedArea.bounds.sw
        let ne = cachedArea.bounds.ne
        let nw = CLLocationCoordinate2D(latitude: ne.latitude, longitude: sw.longitude)
        let se = CLLocationCoordinate2D(latitude: sw.latitude, longitude: ne.longitude)

        guard
            CLLocationCoordinate2DIsValid(sw),
            CLLocationCoordinate2DIsValid(ne),
            CLLocationCoordinate2DIsValid(nw),
            CLLocationCoordinate2DIsValid(se)
        else {
            return nil
        }

        var coordinates = [sw, nw, ne, se, sw]
        let polyline = CachedAreaBorderPolyline(coordinates: &coordinates, count: UInt(coordinates.count))
        polyline.cachedAreaID = cachedArea.id
        polyline.cachedAreaName = cachedArea.name
        return polyline
    }

    func resolvedOfflineAreaName(from proposedName: String) -> String {
        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = trimmedName.isEmpty ? "Offline Area" : trimmedName
        let existingNames = Set(cachedOfflineAreas.map { $0.name.lowercased() })

        guard existingNames.contains(fallbackName.lowercased()) else {
            return fallbackName
        }

        var suffix = 2
        while existingNames.contains("\(fallbackName) \(suffix)".lowercased()) {
            suffix += 1
        }

        return "\(fallbackName) \(suffix)"
    }

    func cachedAreaNames() -> [String] {
        cachedOfflineAreas.map(\.name)
    }

    func renameCachedOfflineArea(id: String, proposedName: String) {
        guard !proposedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let currentArea = cachedOfflineAreas.first(where: { $0.id == id })
        let existingNames = Set(
            cachedOfflineAreas
                .filter { $0.id != id }
                .map { $0.name.lowercased() }
        )

        let trimmed = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmed.isEmpty ? (currentArea?.name ?? "Offline Area") : trimmed
        var resolvedName = baseName
        var suffix = 2
        while existingNames.contains(resolvedName.lowercased()) {
            resolvedName = "\(baseName) \(suffix)"
            suffix += 1
        }

        var overrides = offlineCacheStore.loadNameOverrides()
        overrides[id] = resolvedName
        offlineCacheStore.saveNameOverrides(overrides)
        reloadPersistedOfflineAreas()
        updateDownloadButtonForExistingPack()
    }

    func deleteCachedOfflineArea(id: String, completion: @escaping (Bool) -> Void) {
        let packs = MLNOfflineStorage.shared.packs ?? []
        guard let matchingPack = packs.first(where: { decodedOfflineContext(from: $0.context)?.id == id }) else {
            completion(false)
            return
        }

        MLNOfflineStorage.shared.removePack(matchingPack) { [weak self] error in
            guard let self = self else {
                completion(false)
                return
            }

            if let error = error {
                print("Failed to remove offline pack: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            if self.offlinePack == matchingPack {
                self.offlinePack = nil
            }

            self.offlineCacheStore.removeAreaMetadata(for: id)

            DispatchQueue.main.async {
                self.reloadPersistedOfflineAreas()
                self.updateDownloadButtonForExistingPack()
                completion(true)
            }
        }
    }

    func promptToRenameCachedOfflineArea(
        _ area: CachedOfflineArea,
        completion: @escaping (CachedOfflineArea?) -> Void
    ) {
        let overlay = TextInputOverlayViewController(
            title: "Rename Cached Area",
            placeholder: "Offline Area",
            initialText: area.name,
            confirmTitle: "Rename",
            confirmHandler: { [weak self] proposedName in
                guard let self else {
                    completion(nil)
                    return
                }
                self.renameCachedOfflineArea(id: area.id, proposedName: proposedName.isEmpty ? area.name : proposedName)
                completion(self.cachedOfflineAreas.first(where: { $0.id == area.id }))
            },
            cancelHandler: {
                completion(nil)
            }
        )
        topmostPresentingViewController().present(overlay, animated: true)
    }

    func deleteAllCachedOfflineAreas(completion: @escaping (Bool) -> Void) {
        let packs = MLNOfflineStorage.shared.packs ?? []
        guard !packs.isEmpty else {
            completion(false)
            return
        }

        let group = DispatchGroup()
        var deletedAny = false

        for pack in packs {
            group.enter()
            MLNOfflineStorage.shared.removePack(pack) { error in
                if error == nil {
                    deletedAny = true
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.offlinePack = nil
            self.offlineCacheStore.clearAllMetadata()
            self.reloadPersistedOfflineAreas()
            self.updateDownloadButtonForExistingPack()
            completion(deletedAny)
        }
    }

    func confirmDeleteAllCachedOfflineAreas(completion: @escaping (Bool) -> Void) {
        let overlay = ActionOverlayViewController(
            title: "Delete All Cached Areas?",
            message: "Remove all offline cached areas from this device?",
            actions: [
                .init(title: "Cancel", style: .cancel) {
                    completion(false)
                },
                .init(title: "Delete All", style: .destructive) { [weak self] in
                    self?.deleteAllCachedOfflineAreas(completion: completion)
                }
            ]
        )
        topmostPresentingViewController().present(overlay, animated: true)
    }

    func confirmDeleteCachedOfflineArea(
        _ area: CachedOfflineArea,
        completion: @escaping (Bool) -> Void
    ) {
        let overlay = ActionOverlayViewController(
            title: "Delete Cached Area?",
            message: "Remove \"\(area.name)\" from offline storage?",
            actions: [
                .init(title: "Cancel", style: .cancel) {
                    completion(false)
                },
                .init(title: "Delete", style: .destructive) { [weak self] in
                    self?.deleteCachedOfflineArea(id: area.id, completion: completion)
                }
            ]
        )
        topmostPresentingViewController().present(overlay, animated: true)
    }

    func updateDownloadButtonForExistingPack() {
        let title: String
        if (MLNOfflineStorage.shared.packs ?? []).contains(where: isOfflinePackActive(_:)) {
            title = "Downloading…"
        } else if hasLoadedOfflineArea {
            title = "Save Another Visible Area for Offline Use"
        } else {
            title = "Download Visible Area for Offline Use"
        }
        setDownloadButtonTitle(title)
    }

    func currentOfflineProgressText() -> String? {
        let activePack = offlinePack ?? (MLNOfflineStorage.shared.packs ?? []).first(where: isOfflinePackActive(_:))
        guard let activePack else { return nil }

        let progress = activePack.progress
        let completed = progress.countOfResourcesCompleted
        let expected = progress.countOfResourcesExpected

        guard expected > 0 else { return "Preparing offline cache…" }

        let percentage = Int((Double(completed) / Double(expected)) * 100)
        return "\(completed) of \(expected) tiles cached (\(percentage)%)"
    }

    func updateCacheProgressOverlay() {
        guard let progressText = currentOfflineProgressText() else {
            cacheProgressOverlayLabel.isHidden = true
            return
        }

        cacheProgressOverlayLabel.text = "  \(progressText)  "
        cacheProgressOverlayLabel.isHidden = false
    }

    func currentLocationGridReferenceText() -> String? {
        currentPositionGridReferenceText().map { "Grid Ref: \($0)" }
    }

    func currentPositionGridReferenceText() -> String? {
        let authorizationStatus = locationManager.authorizationStatus
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return nil
        }
        guard let coordinate = currentValidUserCoordinate() else { return nil }
        return irishNationalGridReference(for: coordinate)
    }

    func centerPositionGridReferenceText() -> String? {
        irishNationalGridReference(for: mapView.centerCoordinate)
    }

    func updateCurrentGridRefOverlay() {
        currentGridRefOverlayLabel.isHidden = true
        cacheProgressOverlayBottomConstraint?.constant = -6
        updateMapStatusOverlay()
    }

    func updatePositionIndicator() {
        let canUseLocation = locationAuthorizationPolicyStore.canUseLocation(locationManager.authorizationStatus)
        guard canUseLocation, let coordinate = currentValidUserCoordinate() else {
            positionIndicatorView.isHidden = true
            positionIndicatorAccuracyRingView.isHidden = true
            positionIndicatorHeadingGlyphView.isHidden = true
            recenterHeadingIndicatorView.isHidden = true
            return
        }

        let point = mapView.convert(coordinate, toPointTo: view)
        let isVisible = view.bounds.insetBy(dx: -20, dy: -20).contains(point)
        positionIndicatorView.isHidden = !isVisible
        positionIndicatorAccuracyRingView.isHidden = !isVisible

        guard isVisible else { return }

        positionIndicatorView.center = point
        positionIndicatorAccuracyRingView.center = point

        let headingDegrees = latestHeading ?? {
            let course = mapView.userLocation?.location?.course ?? -1
            return course >= 0 ? course : nil
        }()

        if let headingDegrees {
            positionIndicatorHeadingGlyphView.isHidden = false
            let relativeHeadingDegrees = headingDegrees - normalizedMapDirection
            positionIndicatorHeadingGlyphView.transform = CGAffineTransform(rotationAngle: CGFloat(relativeHeadingDegrees * .pi / 180))
            recenterHeadingIndicatorView.isHidden = false
            recenterHeadingIndicatorView.transform = CGAffineTransform(rotationAngle: CGFloat(relativeHeadingDegrees * .pi / 180))
        } else {
            positionIndicatorHeadingGlyphView.isHidden = true
            recenterHeadingIndicatorView.isHidden = true
        }
    }

    // MARK: - UI State

    func updateRecenterButtonAppearance() {
        recenterButton.tintColor = .systemBlue
    }

    func updateOrientationButtonAppearance() {
        let rotationAngle = CGFloat(-normalizedMapDirection * .pi / 180)
        orientationButton.imageView?.transform = CGAffineTransform(rotationAngle: rotationAngle)
        orientationButton.tintColor = selectedMapOrientationMode == .headsUp ? .systemGreen : .systemBlue
    }

    func updateZoomSliderFromMap() {
        let clampedZoomLevel = max(minimumMapZoomLevel, min(mapView.zoomLevel, maximumMapZoomLevel))
        if mapView.zoomLevel != clampedZoomLevel {
            mapView.setZoomLevel(clampedZoomLevel, animated: false)
        }
        zoomSlider.setValue(Float(clampedZoomLevel), animated: false)
    }

    func scheduleMapInactivityRecenter() {
        guard mapViewportStateStore.shouldScheduleInactivityRecenter(
            isTrailRecording: isTrailRecording,
            hasActiveGoTo: activeGoToTarget != nil
        ) else { return }
        mapInactivityRecenterTimer?.invalidate()
        mapInactivityRecenterTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            self?.recenterTapped()
        }
    }

    func cancelMapInactivityRecenter() {
        mapInactivityRecenterTimer?.invalidate()
        mapInactivityRecenterTimer = nil
    }

    func currentValidUserCoordinate() -> CLLocationCoordinate2D? {
        guard let coordinate = mapView.userLocation?.location?.coordinate else { return nil }
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        return coordinate
    }

    func resumeLocationUpdatesIfNeeded() {
        guard !isUITestBypassingLocationPrompts else { return }
        guard locationAuthorizationPolicyStore.canUseLocation(locationManager.authorizationStatus) else {
            return
        }

        mapView.showsUserLocation = true
        locationManager.startUpdatingLocation()
        locationManager.requestLocation()
    }

    var isNorthUp: Bool {
        mapViewportStateStore.isNorthUp(direction: normalizedMapDirection)
    }

    var normalizedMapDirection: CLLocationDirection {
        mapViewportStateStore.normalizedDirection(mapView.direction)
    }
}
