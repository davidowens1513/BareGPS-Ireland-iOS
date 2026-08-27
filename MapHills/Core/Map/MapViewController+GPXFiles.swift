import CoreLocation
import MapLibre
import UIKit

extension ViewController {
    func clearImportedGPX() {
        if !gpxWaypointAnnotations.isEmpty {
            mapView.removeAnnotations(gpxWaypointAnnotations)
            gpxWaypointAnnotations.removeAll()
        }

        if !gpxTrackAnnotations.isEmpty {
            mapView.removeAnnotations(gpxTrackAnnotations)
            gpxTrackAnnotations.removeAll()
        }

        currentImportedGPXSourceURL = nil
        currentImportedGPXDisplayName = nil
    }

    func refreshImportedGPXTrackAnnotations() {
        guard !gpxTrackAnnotations.isEmpty else { return }
        mapView.removeAnnotations(gpxTrackAnnotations)
        mapView.addAnnotations(gpxTrackAnnotations)
    }

    func hasImportedGPX() -> Bool {
        !gpxWaypointAnnotations.isEmpty || !gpxTrackAnnotations.isEmpty
    }

    func importGPX(from fileURL: URL) {
        let parserDelegate = GPXParserDelegate()
        let needsScopedAccess = fileURL.startAccessingSecurityScopedResource()

        defer {
            if needsScopedAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let xmlParser = XMLParser(contentsOf: fileURL) else {
            presentGPXImportAlert(
                title: "GPX Import Failed",
                message: "The selected file could not be opened."
            )
            return
        }

        xmlParser.delegate = parserDelegate

        guard xmlParser.parse() else {
            let message = xmlParser.parserError?.localizedDescription ?? "The GPX file could not be parsed."
            presentGPXImportAlert(title: "GPX Import Failed", message: message)
            return
        }

        let importedGPX = GPXImport(
            waypoints: parserDelegate.waypoints,
            trackSegments: parserDelegate.trackSegments,
            skippedWaypointCount: parserDelegate.skippedWaypointCount,
            skippedTrackPointCount: parserDelegate.skippedTrackPointCount,
            skippedSegmentCount: parserDelegate.skippedSegmentCount,
            encounteredGPXContent: parserDelegate.encounteredGPXContent
        )

        guard !importedGPX.waypoints.isEmpty || !importedGPX.trackSegments.isEmpty else {
            let detail = gpxImportIssueSummary(for: importedGPX)
            let message: String
            if importedGPX.encounteredGPXContent {
                message = detail.isEmpty
                    ? "The selected file contained GPX data, but none of it could be imported."
                    : "The selected file contained GPX data, but none of it could be imported. \(detail)"
            } else {
                message = "The selected file did not contain any GPX waypoints, routes, or tracks."
            }
            presentGPXImportAlert(
                title: "No Usable GPX Data Found",
                message: message
            )
            return
        }

        showImportedGPX(
            importedGPX,
            fileName: fileURL.deletingPathExtension().lastPathComponent,
            sourceURL: fileURL
        )
    }

    func showImportedGPX(_ importedGPX: GPXImport, fileName: String, sourceURL: URL? = nil) {
        clearImportedGPX()

        let waypointAnnotations = importedGPX.waypoints.map { waypoint -> GPXWaypointAnnotation in
            let annotation = GPXWaypointAnnotation()
            annotation.coordinate = waypoint.coordinate
            annotation.title = waypoint.name
            annotation.subtitle = fileName
            return annotation
        }

        let trackAnnotations = importedGPX.trackSegments.compactMap { segment -> MLNPolyline? in
            guard segment.count > 1 else { return nil }
            var coordinates = segment
            return ImportedGPXPolyline(coordinates: &coordinates, count: UInt(coordinates.count))
        }

        gpxWaypointAnnotations = waypointAnnotations
        gpxTrackAnnotations = trackAnnotations

        if !waypointAnnotations.isEmpty {
            mapView.addAnnotations(waypointAnnotations)
        }

        if !trackAnnotations.isEmpty {
            mapView.addAnnotations(trackAnnotations)
        }

        currentImportedGPXSourceURL = sourceURL
        currentImportedGPXDisplayName = fileName
        fitMapToImportedGPX(importedGPX)

        let importedSummary = "\(waypointAnnotations.count) waypoint(s), \(trackAnnotations.count) track segment(s)"
        let skippedSummary = gpxImportIssueSummary(for: importedGPX)
        let message = skippedSummary.isEmpty
            ? importedSummary
            : "\(importedSummary). Skipped \(skippedSummary.lowercased())"
        presentGPXImportAlert(title: "GPX Imported", message: message)
    }

    func canSaveCurrentImportedGPX() -> Bool {
        guard let fileURL = currentImportedGPXSourceURL else { return false }
        return !isSavedGPXFileURL(fileURL)
    }

    func isSavedGPXFileURL(_ fileURL: URL) -> Bool {
        guard let documentsDirectory = try? documentsDirectoryURL() else { return false }
        return fileURL.standardizedFileURL.deletingLastPathComponent() == documentsDirectory.standardizedFileURL
    }

    func promptForImportedGPXNameAndSave() {
        guard canSaveCurrentImportedGPX() else { return }

        let overlay = TextInputOverlayViewController(
            title: "Save Imported GPX",
            message: "Choose a name for this GPX file.",
            placeholder: "GPX file name",
            initialText: currentImportedGPXDisplayName ?? "Imported-GPX",
            confirmTitle: "Save"
        ) { [weak self] enteredName in
            guard let self else { return }
            let fileBaseName = sanitizedGPXFileBaseName(
                from: enteredName,
                defaultBaseName: self.defaultRecordedGPXFileBaseName()
            )
            self.saveImportedGPX(named: fileBaseName)
        }
        topmostPresentingViewController().present(overlay, animated: true)
    }

    func saveImportedGPX(named fileBaseName: String) {
        guard let sourceURL = currentImportedGPXSourceURL else { return }

        do {
            let destinationURL = try nextImportedGPXFileURL(fileBaseName: fileBaseName)
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            currentImportedGPXSourceURL = destinationURL
            currentImportedGPXDisplayName = destinationURL.deletingPathExtension().lastPathComponent
            presentGPXImportAlert(
                title: "Imported GPX Saved",
                message: "Saved GPX to \(destinationURL.lastPathComponent)"
            )
        } catch {
            presentGPXImportAlert(
                title: "Save Failed",
                message: error.localizedDescription
            )
        }
    }

    func gpxImportIssueSummary(for importedGPX: GPXImport) -> String {
        var issues: [String] = []

        if importedGPX.skippedWaypointCount > 0 {
            issues.append("\(importedGPX.skippedWaypointCount) invalid waypoint(s)")
        }

        if importedGPX.skippedTrackPointCount > 0 {
            issues.append("\(importedGPX.skippedTrackPointCount) invalid track point(s)")
        }

        if importedGPX.skippedSegmentCount > 0 {
            issues.append("\(importedGPX.skippedSegmentCount) incomplete segment(s)")
        }

        return issues.joined(separator: ", ")
    }

    func fitMapToImportedGPX(_ importedGPX: GPXImport) {
        let allCoordinates = importedGPX.waypoints.map(\.coordinate) + importedGPX.trackSegments.flatMap { $0 }
        guard let firstCoordinate = allCoordinates.first else { return }

        var minLatitude = firstCoordinate.latitude
        var maxLatitude = firstCoordinate.latitude
        var minLongitude = firstCoordinate.longitude
        var maxLongitude = firstCoordinate.longitude

        for coordinate in allCoordinates.dropFirst() {
            minLatitude = min(minLatitude, coordinate.latitude)
            maxLatitude = max(maxLatitude, coordinate.latitude)
            minLongitude = min(minLongitude, coordinate.longitude)
            maxLongitude = max(maxLongitude, coordinate.longitude)
        }

        let bounds = MLNCoordinateBounds(
            sw: CLLocationCoordinate2D(latitude: minLatitude, longitude: minLongitude),
            ne: CLLocationCoordinate2D(latitude: maxLatitude, longitude: maxLongitude)
        )

        mapView.setVisibleCoordinateBounds(
            bounds,
            edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 120, right: 40),
            animated: true,
            completionHandler: nil
        )
    }

    func beginTrailRecordingFlow(startMode: PendingTrailStartMode = .standard) {
        if startMode == .fresh {
            discardTrailRecording()
        }

        let initialLocation = mapView.userLocation?.location
        centerMapForTrailRecordingStart(using: initialLocation)
        trailRecordingStore.startRecording(
            initialLocation: initialLocation,
            maximumVerticalAccuracy: trailMaximumVerticalAccuracy
        )
        refreshTrailOverlay()
        updateTrailStatusIndicator()
        updateBackgroundLocationMode()
        persistActiveRecordingState()
    }

    func startTrailRecording() {
        beginTrailRecordingFlow(startMode: .standard)
    }

    func stopTrailRecording() {
        trailRecordingStore.stopRecording()
        refreshTrailOverlay()
        updateTrailStatusIndicator()
        updateBackgroundLocationMode()
        persistActiveRecordingState()
    }

    func discardTrailRecording() {
        trailRecordingStore.discardRecording()
        recordedTrailPoints.removeAll()
        breadcrumbTrailPoints.removeAll()
        refreshTrailOverlay()
        updateTrailStatusIndicator()
        updateBackgroundLocationMode()
        clearPersistedActiveRecordingState()
    }

    func centerMapForTrailRecordingStart(using location: CLLocation?) {
        guard let location else { return }
        mapView.setCenter(location.coordinate, zoomLevel: followZoomLevel, animated: true)
    }

    func appendTrailCoordinateIfNeeded(_ location: CLLocation) {
        let policy = selectedTrackRecordingQuality.trailRecordingPolicy
        let appendResult = trailRecordingStore.appendTrailLocationIfNeeded(
            location,
            policy: policy,
            maximumHorizontalAccuracy: trailMaximumHorizontalAccuracy,
            maximumVerticalAccuracy: trailMaximumVerticalAccuracy,
            minimumAscentIncrement: trailMinimumAscentIncrement
        )

        guard appendResult == .appended else { return }
        refreshTrailOverlay()
        persistActiveRecordingState()
    }

    func appendBreadcrumbCoordinateIfNeeded(_ location: CLLocation) {
        let didAppend = trailRecordingStore.appendBreadcrumbLocationIfNeeded(
            location,
            minimumDistance: 5,
            maximumHorizontalAccuracy: trailMaximumHorizontalAccuracy,
            trailDuration: breadcrumbTrailDuration
        )

        guard didAppend else { return }
        refreshBreadcrumbTrailOverlay()
    }

    func refreshTrailOverlay() {
        if let trailPolylineAnnotation {
            mapView.removeAnnotation(trailPolylineAnnotation)
            self.trailPolylineAnnotation = nil
        }

        if recordedTrailPoints.count > 1 {
            var coordinates = recordedTrailPoints.map(\.coordinate)
            let polyline = TrailPolyline(coordinates: &coordinates, count: UInt(coordinates.count))
            trailPolylineAnnotation = polyline
            mapView.addAnnotation(polyline)
        }

        if let breadcrumbPolylineAnnotation {
            mapView.removeAnnotation(breadcrumbPolylineAnnotation)
            self.breadcrumbPolylineAnnotation = nil
        }

        if breadcrumbTrailPoints.count > 1 {
            var coordinates = breadcrumbTrailPoints.map(\.coordinate)
            let polyline = BreadcrumbPolyline(coordinates: &coordinates, count: UInt(coordinates.count))
            breadcrumbPolylineAnnotation = polyline
            mapView.addAnnotation(polyline)
        }
    }

    func activeRecordingStateFileURL() throws -> URL {
        let documentsDirectory = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return documentsDirectory.appendingPathComponent(activeRecordingStateFileName)
    }

    func persistActiveRecordingState() {
        let state = ActiveGPXRecordingState(
            isRecording: isTrailRecording,
            points: recordedTrailPoints
        )

        if state.points.isEmpty {
            clearPersistedActiveRecordingState()
            return
        }

        do {
            let fileURL = try activeRecordingStateFileURL()
            let encodedState = try JSONEncoder().encode(state)
            try encodedState.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to persist active GPX recording: \(error.localizedDescription)")
        }
    }

    func restoreActiveRecordingState() {
        do {
            let fileURL = try activeRecordingStateFileURL()
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

            let data = try Data(contentsOf: fileURL)
            let state = try JSONDecoder().decode(ActiveGPXRecordingState.self, from: data)
            trailRecordingStore.restoreRecordedTrailPoints(state.points)
            refreshTrailOverlay()
            updateBackgroundLocationMode()
            updateTrailStatusIndicator()
        } catch {
            print("Failed to restore active GPX recording: \(error.localizedDescription)")
        }
    }

    func clearPersistedActiveRecordingState() {
        do {
            let fileURL = try activeRecordingStateFileURL()
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            print("Failed to clear active GPX recording: \(error.localizedDescription)")
        }
    }

    func updateTrailStatusIndicator() {
        if isTrailRecording {
            trailStatusIndicatorView.isHidden = false
            trailStatusIndicatorView.backgroundColor = .systemRed
        } else if !recordedTrailPoints.isEmpty {
            trailStatusIndicatorView.isHidden = false
            trailStatusIndicatorView.backgroundColor = .systemBlue
        } else {
            trailStatusIndicatorView.isHidden = true
        }

        updateLiveGPXStatsCard()
        updateLiveGPXStatsTimer()
    }

    func updateLiveGPXStatsCard() {
        liveGPXStatsCardView.isHidden = showsCompactRecordingGrid
        compactRecordingStripView.isHidden = !showsCompactRecordingGrid
        liveGPXStatsCardView.layer.borderWidth = isTrailRecording ? 3 : 1
        liveGPXStatsCardView.layer.borderColor = (isTrailRecording
            ? UIColor.systemGray2.withAlphaComponent(0.8)
            : UIColor.systemGray3.withAlphaComponent(0.65)
        ).cgColor

        if let summary = currentGPXRecordingSummary() {
            liveDistanceValueLabel.text = formattedLiveGPXDistance(summary.distanceMeters)
            liveTimeValueLabel.text = formattedLiveGPXDuration(summary.duration)
            liveAscentValueLabel.text = formattedLiveGPXElevation(summary.ascentMeters)
            liveDescentValueLabel.text = formattedLiveGPXElevation(summary.descentMeters)
            liveElevationValueLabel.text = summary.currentElevationMeters.map(formattedLiveGPXElevation) ?? "u/a"
        } else {
            liveDistanceValueLabel.text = formattedLiveGPXDistance(0)
            liveTimeValueLabel.text = "00:00"
            liveAscentValueLabel.text = formattedLiveGPXElevation(0)
            liveDescentValueLabel.text = formattedLiveGPXElevation(0)
            liveElevationValueLabel.text = "u/a"
        }

        if let coordinate = mapView.userLocation?.coordinate {
            liveGridRefValueLabel.text = irishNationalGridReference(for: coordinate) ?? "u/a"
        } else {
            liveGridRefValueLabel.text = "u/a"
        }
        liveAccuracyValueLabel.text = formattedLiveGPXAccuracy(mapView.userLocation?.location)
        liveRecordingValueLabel.attributedText = liveRecordingStatusText()

        let hasRecording = !recordedTrailPoints.isEmpty
        livePrimaryRecordingButton.configuration = liveRecordingButtonConfiguration(
            title: hasRecording ? "Resume" : "Start",
            systemImageName: "play.circle.fill",
            tintColor: .systemBlue
        )
        liveStopRecordingButton.configuration = liveRecordingButtonConfiguration(
            title: "Stop",
            systemImageName: "stop.fill",
            tintColor: .systemRed
        )
        liveSaveRecordingButton.configuration = liveRecordingButtonConfiguration(
            title: "Save",
            systemImageName: "square.and.arrow.down.fill",
            tintColor: .systemGreen
        )
        liveDiscardRecordingButton.configuration = liveRecordingButtonConfiguration(
            title: "Discard",
            systemImageName: "trash.fill",
            tintColor: .systemOrange
        )

        updateLiveRecordingLockBanner(
            isRecording: isTrailRecording,
            hasRecording: hasRecording,
            hasSavableRecording: recordedTrailPoints.count > 1
        )
        updateCompactRecordingStrip()
    }

    func updateLiveGPXStatsTimer() {
        guard liveGPXStatsTimer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateLiveGPXStatsCard()
        }
        RunLoop.main.add(timer, forMode: .common)
        liveGPXStatsTimer = timer
    }

    func liveRecordingStatusText() -> NSAttributedString {
        let statusColor: UIColor = isTrailRecording ? .systemRed : .systemGray
        let statusText = isTrailRecording ? " REC" : " Ready"

        let attachment = NSTextAttachment()
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        attachment.image = UIImage(systemName: "play.circle.fill", withConfiguration: symbolConfiguration)?
            .withTintColor(statusColor, renderingMode: .alwaysOriginal)
        attachment.bounds = CGRect(x: 0, y: -1, width: 13, height: 13)

        let text = NSMutableAttributedString(attachment: attachment)
        text.append(NSAttributedString(
            string: statusText,
            attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .heavy),
                .foregroundColor: statusColor
            ]
        ))
        return text
    }

    func updateCompactRecordingStrip() {
        if let summary = currentGPXRecordingSummary() {
            compactTimeValueLabel.text = formattedLiveGPXDuration(summary.duration)
            compactDistanceValueLabel.text = formattedLiveGPXDistance(summary.distanceMeters)
            compactAscentValueLabel.text = formattedLiveGPXElevation(summary.ascentMeters)
            compactElevationValueLabel.text = summary.currentElevationMeters.map(formattedLiveGPXElevation) ?? "u/a"
        } else {
            compactTimeValueLabel.text = "00:00"
            compactDistanceValueLabel.text = formattedLiveGPXDistance(0)
            compactAscentValueLabel.text = formattedLiveGPXElevation(0)
            compactElevationValueLabel.text = "u/a"
        }

        if isTrailRecording {
            compactStatusDotView.backgroundColor = .systemRed
            compactStatusDotView.layer.borderColor = UIColor.systemRed.cgColor
        } else {
            compactStatusDotView.backgroundColor = .clear
            compactStatusDotView.layer.borderColor = UIColor.systemGray.cgColor
        }
    }

    @objc func handleLiveRecordingControlsTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended, isLiveRecordingControlsUnlocked else { return }
        liveRecordingUnlockRemainingSeconds = 20
        startLiveRecordingUnlockTimer()
        updateLiveRecordingLockBanner(
            isRecording: isTrailRecording,
            hasRecording: !recordedTrailPoints.isEmpty,
            hasSavableRecording: recordedTrailPoints.count > 1
        )
    }

    @objc func handleLiveRecordingControlsLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        unlockLiveRecordingControls()
    }

    func unlockLiveRecordingControls() {
        isLiveRecordingControlsUnlocked = true
        liveRecordingUnlockRemainingSeconds = 20
        startLiveRecordingUnlockTimer()
        updateLiveRecordingLockBanner(
            isRecording: isTrailRecording,
            hasRecording: !recordedTrailPoints.isEmpty,
            hasSavableRecording: recordedTrailPoints.count > 1
        )
    }

    func startLiveRecordingUnlockTimer() {
        liveRecordingUnlockTimer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.advanceLiveRecordingUnlockTimer()
        }
        RunLoop.main.add(timer, forMode: .common)
        liveRecordingUnlockTimer = timer
    }

    func stopLiveRecordingUnlockTimer() {
        liveRecordingUnlockTimer?.invalidate()
        liveRecordingUnlockTimer = nil
    }

    func advanceLiveRecordingUnlockTimer() {
        guard isLiveRecordingControlsUnlocked else { return }
        liveRecordingUnlockRemainingSeconds -= 1
        if liveRecordingUnlockRemainingSeconds <= 0 {
            isLiveRecordingControlsUnlocked = false
            liveRecordingUnlockRemainingSeconds = 0
            stopLiveRecordingUnlockTimer()
        }
        updateLiveRecordingLockBanner(
            isRecording: isTrailRecording,
            hasRecording: !recordedTrailPoints.isEmpty,
            hasSavableRecording: recordedTrailPoints.count > 1
        )
    }

    func updateLiveRecordingLockBanner(
        isRecording: Bool,
        hasRecording: Bool,
        hasSavableRecording: Bool
    ) {
        liveRecordingLockLabel.text = isLiveRecordingControlsUnlocked
            ? "Unlocked... \(liveRecordingUnlockRemainingSeconds)s"
            : "Long press grid to activate..."
        liveRecordingLockBannerView.alpha = isLiveRecordingControlsUnlocked ? 1.0 : 0.55

        livePrimaryRecordingButton.isEnabled = isLiveRecordingControlsUnlocked && !isRecording
        liveStopRecordingButton.isEnabled = isLiveRecordingControlsUnlocked && isRecording
        liveSaveRecordingButton.isEnabled = isLiveRecordingControlsUnlocked && hasRecording && !isRecording && hasSavableRecording
        liveDiscardRecordingButton.isEnabled = isLiveRecordingControlsUnlocked && hasRecording && !isRecording

        setLiveRecordingButtonAlpha(livePrimaryRecordingButton)
        setLiveRecordingButtonAlpha(liveStopRecordingButton)
        setLiveRecordingButtonAlpha(liveSaveRecordingButton)
        setLiveRecordingButtonAlpha(liveDiscardRecordingButton)
    }

    func setLiveRecordingButtonAlpha(_ button: UIButton) {
        button.alpha = button.isEnabled ? 1.0 : 0.45
    }

    func liveRecordingButtonConfiguration(
        title: String,
        systemImageName: String,
        tintColor: UIColor
    ) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = tintColor.withAlphaComponent(0.12)
        configuration.baseForegroundColor = tintColor
        configuration.cornerStyle = .medium
        configuration.image = UIImage(systemName: systemImageName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold))
        configuration.imagePlacement = .top
        configuration.imagePadding = 3
        configuration.titleAlignment = .center
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4)
        configuration.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: tintColor
            ])
        )
        return configuration
    }

    func irishNationalGridReference(for coordinate: CLLocationCoordinate2D) -> String? {
        irishGridReference(for: coordinate)
    }

    func formattedDistance(_ distanceMeters: CLLocationDistance) -> String {
        MapFormatting.formattedDistance(distanceMeters, unitSystem: selectedDisplayUnitSystem)
    }

    func formattedElevation(_ elevationMeters: Double) -> String {
        MapFormatting.formattedElevation(elevationMeters, unitSystem: selectedDisplayUnitSystem)
    }

    func formattedProminence(_ prominenceMeters: Double) -> String {
        MapFormatting.formattedProminence(prominenceMeters, unitSystem: selectedDisplayUnitSystem)
    }

    func formattedCompactElevation(_ elevationMeters: Double) -> String {
        MapFormatting.formattedCompactElevation(elevationMeters, unitSystem: selectedDisplayUnitSystem)
    }

    func presentGPXRecordingPermissionExplainer() {
        let overlay = ActionOverlayViewController(
            title: "Allow Location for GPX Recording",
            message: "\(AppBranding.displayName) uses your location to draw your live GPX track, calculate recording stats, and keep recording going while the app is in the background during an active GPX recording.",
            actions: [
                .init(title: "Not Now", style: .cancel) { [weak self] in
                    self?.pendingTrailStartMode = nil
                },
                .init(title: "Continue", style: .normal) { [weak self] in
                    self?.locationManager.requestWhenInUseAuthorization()
                }
            ]
        )
        topmostPresentingViewController().present(overlay, animated: true)
    }

    func saveTrailAsGPX(named fileBaseName: String) {
        guard recordedTrailPoints.count > 1 else {
            presentGPXImportAlert(
                title: "GPX Recording Not Saved",
                message: "Record at least two trail points before saving a GPX file."
            )
            return
        }

        do {
            let destinationURL = try nextRecordedGPXFileURL(fileBaseName: fileBaseName)
            let gpxString = makeGPXString(
                from: recordedTrailPoints,
                trackName: destinationURL.deletingPathExtension().lastPathComponent,
                creatorName: AppBranding.displayName
            )
            try gpxString.write(to: destinationURL, atomically: true, encoding: .utf8)

            discardTrailRecording()
            presentGPXImportAlert(
                title: "GPX Recording Saved",
                message: "Saved GPX to \(destinationURL.lastPathComponent)"
            )
        } catch {
            presentGPXImportAlert(
                title: "Save Failed",
                message: error.localizedDescription
            )
        }
    }

    func promptForGPXRecordingNameAndSave() {
        guard recordedTrailPoints.count > 1 else {
            presentGPXImportAlert(
                title: "GPX Recording Not Saved",
                message: "Record at least two trail points before saving a GPX file."
            )
            return
        }

        let overlay = TextInputOverlayViewController(
            title: "Save GPX Recording",
            message: "Choose a name for this GPX file.",
            placeholder: "Recording name",
            initialText: defaultRecordedGPXFileBaseName(),
            confirmTitle: "Save"
        ) { [weak self] enteredName in
            guard let self else { return }
            let fileBaseName = sanitizedGPXFileBaseName(
                from: enteredName,
                defaultBaseName: self.defaultRecordedGPXFileBaseName()
            )
            self.saveTrailAsGPX(named: fileBaseName)
        }
        topmostPresentingViewController().present(overlay, animated: true)
    }

    func nextRecordedGPXFileURL(fileBaseName: String) throws -> URL {
        let documentsDirectory = try documentsDirectoryURL()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss-SSS"
        let timestamp = formatter.string(from: Date())
        let baseFileName = "\(fileBaseName)-\(timestamp)"
        var candidateURL = documentsDirectory.appendingPathComponent("\(baseFileName).gpx")
        var suffix = 2

        while FileManager.default.fileExists(atPath: candidateURL.path) {
            candidateURL = documentsDirectory.appendingPathComponent("\(baseFileName)-\(suffix).gpx")
            suffix += 1
        }

        return candidateURL
    }

    func nextImportedGPXFileURL(fileBaseName: String) throws -> URL {
        let documentsDirectory = try documentsDirectoryURL()
        var candidateURL = documentsDirectory.appendingPathComponent("\(fileBaseName).gpx")
        var suffix = 2

        while FileManager.default.fileExists(atPath: candidateURL.path) {
            candidateURL = documentsDirectory.appendingPathComponent("\(fileBaseName)-\(suffix).gpx")
            suffix += 1
        }

        return candidateURL
    }

    func documentsDirectoryURL() throws -> URL {
        try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }

    func defaultRecordedGPXFileBaseName() -> String {
        recordedGPXFilePrefix
    }

    func savedGPXFileURLs() -> [URL] {
        do {
            let documentsDirectory = try documentsDirectoryURL()
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: documentsDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            return fileURLs
                .filter { $0.pathExtension.lowercased() == "gpx" }
                .sorted { lhs, rhs in
                    let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                    let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                    return lhsDate > rhsDate
                }
        } catch {
            print("Failed to list saved GPX files: \(error.localizedDescription)")
            return []
        }
    }

    func savedGPXRecordingItems() -> [SavedGPXRecordingItem] {
        savedGPXFileURLs().map { fileURL in
            let metadataText = savedGPXMetadataText(for: fileURL)
            return SavedGPXRecordingItem(fileURL: fileURL, subtitleText: metadataText)
        }
    }

    func currentGPXRecordingSummary() -> GPXRecordingSummary? {
        let currentElevationMeters: Double?
        if let liveLocation = mapView.userLocation?.location,
           liveLocation.verticalAccuracy >= 0,
           liveLocation.verticalAccuracy <= trailMaximumVerticalAccuracy {
            currentElevationMeters = liveLocation.altitude
        } else {
            currentElevationMeters = recordedTrailPoints.last?.altitude
        }

        return gpxRecordingSummary(
            for: recordedTrailPoints,
            durationEndDate: isTrailRecording ? Date() : nil,
            currentElevationMeters: currentElevationMeters,
            noiseThreshold: trailMinimumAscentIncrement,
            smoothingWindow: trailElevationSmoothingWindow
        )
    }

    func formattedLiveGPXDistance(_ distanceMeters: CLLocationDistance) -> String {
        formattedDistance(distanceMeters)
    }

    func formattedLiveGPXDuration(_ duration: TimeInterval) -> String {
        MapFormatting.formattedLiveGPXDuration(duration)
    }

    func formattedLiveGPXElevation(_ elevationMeters: Double) -> String {
        formattedElevation(elevationMeters)
    }

    func formattedLiveGPXAccuracy(_ location: CLLocation?) -> String {
        MapFormatting.formattedLiveGPXAccuracy(location, unitSystem: selectedDisplayUnitSystem)
    }

    func savedGPXMetadataText(for fileURL: URL) -> String {
        let summaryText = parsedSavedGPXSummary(for: fileURL).map {
            "\(formattedSavedGPXDistance($0.distanceMeters)) • \(formattedSavedGPXDuration($0.duration)) • Ascent \(formattedSavedGPXElevation($0.ascentMeters))"
        }
        let dateText = formattedSavedGPXDate(for: fileURL)
        return [summaryText, dateText]
            .compactMap { $0 }
            .joined(separator: "\n")
    }

    func parsedSavedGPXSummary(for fileURL: URL) -> GPXRecordingSummary? {
        let parserDelegate = GPXTrackSummaryParserDelegate()
        guard let xmlParser = XMLParser(contentsOf: fileURL) else { return nil }
        xmlParser.delegate = parserDelegate
        guard xmlParser.parse() else { return nil }
        let validPoints = parserDelegate.trackPoints.filter { $0.timestamp != .distantPast }
        let points = validPoints.count > 1 ? validPoints : parserDelegate.trackPoints
        return gpxRecordingSummary(
            for: points,
            noiseThreshold: trailMinimumAscentIncrement,
            smoothingWindow: trailElevationSmoothingWindow
        )
    }

    func formattedSavedGPXDate(for fileURL: URL) -> String? {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
            let modifiedDate = attributes[.modificationDate] as? Date
        else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modifiedDate)
    }

    func formattedSavedGPXDistance(_ distanceMeters: CLLocationDistance) -> String {
        formattedDistance(distanceMeters)
    }

    func formattedSavedGPXDuration(_ duration: TimeInterval) -> String {
        MapFormatting.formattedSavedGPXDuration(duration)
    }

    func formattedSavedGPXElevation(_ elevationMeters: Double) -> String {
        formattedElevation(elevationMeters)
    }

    func shareGPXFile(_ fileURL: URL) {
        let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        if let popoverController = activityViewController.popoverPresentationController {
            popoverController.sourceView = view
            popoverController.sourceRect = CGRect(
                x: view.bounds.midX,
                y: view.bounds.midY,
                width: 1,
                height: 1
            )
        }
        present(activityViewController, animated: true)
    }

    func deleteSavedGPXFile(_ fileURL: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: fileURL)
            return true
        } catch {
            presentGPXImportAlert(title: "Delete Failed", message: error.localizedDescription)
            return false
        }
    }

    func renameSavedGPXFile(
        _ fileURL: URL,
        completion: @escaping (SavedGPXRecordingItem?) -> Void
    ) {
        let overlay = TextInputOverlayViewController(
            title: "Rename GPX File",
            message: "Enter a new name for this GPX file.",
            placeholder: "Recording name",
            initialText: fileURL.deletingPathExtension().lastPathComponent,
            confirmTitle: "Rename",
            confirmHandler: { [weak self] proposedName in
                guard let self else { return }
                let sanitizedName = sanitizedGPXFileBaseName(
                    from: proposedName,
                    defaultBaseName: self.defaultRecordedGPXFileBaseName()
                )
                let destinationURL = fileURL.deletingLastPathComponent().appendingPathComponent("\(sanitizedName).gpx")

                guard destinationURL != fileURL else {
                    completion(SavedGPXRecordingItem(fileURL: fileURL, subtitleText: self.savedGPXMetadataText(for: fileURL)))
                    return
                }

                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    self.presentGPXImportAlert(
                        title: "Rename Failed",
                        message: "A GPX file with that name already exists."
                    )
                    completion(nil)
                    return
                }

                do {
                    try FileManager.default.moveItem(at: fileURL, to: destinationURL)
                    completion(SavedGPXRecordingItem(
                        fileURL: destinationURL,
                        subtitleText: self.savedGPXMetadataText(for: destinationURL)
                    ))
                } catch {
                    self.presentGPXImportAlert(title: "Rename Failed", message: error.localizedDescription)
                    completion(nil)
                }
            },
            cancelHandler: {
                completion(nil)
            }
        )

        topmostPresentingViewController().present(overlay, animated: true)
    }

    func refreshBreadcrumbTrailOverlay() {
        refreshTrailOverlay()
    }
}
