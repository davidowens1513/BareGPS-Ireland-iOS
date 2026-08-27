//
//  MapViewController+Actions.swift
//  Maphills
//
//  Created by Codex on 07/07/2026.
//

import Foundation
import MapLibre
import UIKit

extension ViewController {

    @objc func recenterTapped() {
        cancelMapInactivityRecenter()
        if isUITestBypassingLocationPrompts {
            if let coord = currentValidUserCoordinate() {
                mapView.setCenter(coord, zoomLevel: followZoomLevel, animated: true)
            }
            return
        }
        switch locationAuthorizationPolicyStore.recenterResolution(for: locationManager.authorizationStatus) {
        case .requestPermission:
            mapViewportStateStore.requestFollowModeAfterAuthorization()
            locationManager.requestWhenInUseAuthorization()
        case .showAccessAlert(let title, let message):
            presentLocationAccessRequiredAlert(title: title, message: message)
        case .proceed:
            resumeLocationUpdatesIfNeeded()
            mapView.showsUserLocation = true
            mapView.userTrackingMode = selectedMapOrientationMode == .headsUp ? .followWithHeading : .follow
            applyMapOrientationMode(animated: true)

            if selectedMapOrientationMode != .headsUp, let coord = currentValidUserCoordinate() {
                mapView.setCenter(coord, zoomLevel: followZoomLevel, animated: true)
            }

            updateRecenterButtonAppearance()
        case .explainTrailRecordingPermission:
            break
        }
    }

    @objc func toggleHillSearch() {
        dismissOpenHillAndStartPlaceCallouts()
        if hillSearchField.isHidden {
            setHillSearchVisible(true, animated: true)
        } else if let text = hillSearchField.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            hillSearchField.becomeFirstResponder()
        } else {
            setHillSearchVisible(false, animated: true)
        }
    }

    @objc func hillSearchSubmitted() {
        performHillSearch(using: hillSearchField.text ?? "")
    }

    @objc func hillSearchTextDidChange() {
        updateHillSearchSuggestions(for: hillSearchField.text, animated: false)
    }

    @objc func hillSearchEditingDidEnd() {
        let trimmedText = hillSearchField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedText.isEmpty {
            setHillSearchVisible(false, animated: true)
        } else {
            updateHillSearchSuggestions(for: trimmedText, animated: false)
        }
    }

    @objc func handleHillSearchDismissTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended, !hillSearchField.isHidden else { return }
        setHillSearchVisible(false, animated: true)
    }

    @objc func resetMapToNorthTapped() {
        saveMapOrientationMode(.northUp)
    }

    @objc func zoomSliderChanged(_ sender: UISlider) {
        let clampedZoomLevel = max(minimumMapZoomLevel, min(Double(sender.value), maximumMapZoomLevel))
        mapView.setZoomLevel(clampedZoomLevel, animated: false)
    }

    @objc func showMapLayerChooser(_ sender: UIButton) {
        let currentLayerName: String
        switch selectedMapBaseLayer {
        case .topographic:
            currentLayerName = "OpenTopo"
        case .standard:
            currentLayerName = "Map"
        case .satellite:
            currentLayerName = "Satellite"
        }
        let overlay = SelectionOverlayViewController(
            title: "Map Layer",
            message: "Current: \(currentLayerName)",
            options: [
                .init(title: "OpenTopo", isSelected: selectedMapBaseLayer == .topographic) { [weak self] in
                    self?.setMapBaseLayer(.topographic)
                },
                .init(title: "OpenStreetMap", isSelected: selectedMapBaseLayer == .standard) { [weak self] in
                    self?.setMapBaseLayer(.standard)
                },
                .init(title: "Satellite", isSelected: selectedMapBaseLayer == .satellite) { [weak self] in
                    self?.setMapBaseLayer(.satellite)
                }
            ]
        )
        topmostPresentingViewController().present(overlay, animated: true)
    }

    func setMapBaseLayer(_ layer: MapBaseLayer) {
        guard selectedMapBaseLayer != layer else { return }
        selectedMapBaseLayer = layer
        applySelectedMapBaseLayer()
    }

    func applySelectedMapBaseLayer() {
        let center = mapView.centerCoordinate
        let zoomLevel = mapView.zoomLevel
        let direction = mapView.direction

        mapView.styleURL = currentMapStyleURL
        mapView.setCenter(center, zoomLevel: zoomLevel, direction: direction, animated: false)
        updateAttributionLabel()
        updateLayerButtonAppearance()
        updateDownloadButtonForExistingPack()
        reloadPeakAnnotations()
        refreshCachedAreaOverlays()
    }

    @objc func downloadOffline() {
        if selectedMapBaseLayer == .standard {
            presentInfoOverlay(
                title: "Caching Not Available",
                message: "The Map layer uses public OpenStreetMap tiles, so offline area saving is only available for OpenTopo and Satellite."
            )
            return
        }

        guard offlinePack == nil else {
            presentInfoOverlay(
                title: "Download In Progress",
                message: "Wait for the current offline area to finish downloading before saving another one."
            )
            return
        }

        let overlay = TextInputOverlayViewController(
            title: "Save Offline Area",
            message: "Name this cached area so it can be reloaded and shown on the map later.",
            placeholder: "Snowdonia North",
            confirmTitle: "Save Area"
        ) { [weak self] proposedName in
            self?.startOfflineDownload(
                named: proposedName,
                detailLevel: self?.selectedCacheDetailLevel ?? .standard
            )
        }
        topmostPresentingViewController().present(overlay, animated: true)
    }

    func startOfflineDownload(named proposedName: String, detailLevel: CachedAreaDetailLevel) {
        let visibleBounds = mapView.visibleCoordinateBounds
        let resolvedName = resolvedOfflineAreaName(from: proposedName)
        let cachedArea = CachedOfflineArea(
            id: UUID().uuidString,
            name: resolvedName,
            detailLevel: detailLevel,
            bounds: visibleBounds,
            status: .downloading,
            byteCount: 0,
            statusMessage: nil
        )
        offlineCacheStore.clearTransientMetadata(for: cachedArea.id)
        let zoomRange = detailLevel.zoomRange
        let region = MLNTilePyramidOfflineRegion(
            styleURL: currentMapStyleURL,
            bounds: visibleBounds,
            fromZoomLevel: zoomRange.lowerBound,
            toZoomLevel: zoomRange.upperBound
        )

        let contextData = encodedOfflineContext(for: cachedArea)
        setDownloadButtonTitle("Preparing offline map…")

        MLNOfflineStorage.shared.addPack(for: region, withContext: contextData) { [weak self] pack, error in
            guard let self = self else { return }

            if let error = error {
                print("Offline pack error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.offlineCacheStore.markFailed(id: cachedArea.id, message: error.localizedDescription)
                    self.reloadPersistedOfflineAreas()
                    self.updateDownloadButtonForExistingPack()
                }
                return
            }

            guard let pack = pack else {
                DispatchQueue.main.async {
                    self.reloadPersistedOfflineAreas()
                    self.updateDownloadButtonForExistingPack()
                }
                return
            }

            self.offlinePack = pack
            self.reloadPersistedOfflineAreas()
            pack.resume()

            DispatchQueue.main.async {
                self.setDownloadButtonTitle("Downloading \(resolvedName)…")
                self.updateCacheProgressOverlay()
            }
        }
    }

    @objc func handleApplicationDidBecomeActive() {
        resumeLocationUpdatesIfNeeded()
        refreshOfflinePackInventory()

        let canUseLocation = locationAuthorizationPolicyStore.canUseLocation(locationManager.authorizationStatus)
        let shouldRecenterImmediately = mapViewportStateStore.handleApplicationDidBecomeActive(
            canUseLocation: canUseLocation,
            isTrailRecording: isTrailRecording,
            hasActiveGoTo: activeGoToTarget != nil,
            hasCurrentUserCoordinate: currentValidUserCoordinate() != nil
        )
        if shouldRecenterImmediately {
            recenterTapped()
        }
    }

    @objc func handleApplicationDidEnterBackground() {
        mapViewportStateStore.handleApplicationDidEnterBackground(
            wasFollowingUser: isUserTrackingActive
        )
        persistActiveRecordingState()
    }

    // MARK: - Offline Progress

    func observeOfflineProgress() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProgress),
            name: .MLNOfflinePackProgressChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOfflineError(_:)),
            name: .MLNOfflinePackError,
            object: nil
        )
    }

    @objc func handleProgress(_ notification: Notification) {
        guard let pack = notification.object as? MLNOfflinePack else { return }
        guard pack == offlinePack else { return }

        let progress = pack.progress
        let completed = progress.countOfResourcesCompleted
        let expected = progress.countOfResourcesExpected
        let downloadedMegabytes = Double(progress.countOfBytesCompleted) / 1_048_576

        if expected > 0 {
            let progressPercentage = Int((Double(completed) / Double(expected)) * 100)
            let progressText = String(
                format: "Downloading %.1f MB • %d%%",
                downloadedMegabytes,
                progressPercentage
            )
            print("\(progressText) (\(completed)/\(expected))")

            DispatchQueue.main.async {
                self.setDownloadButtonTitle(progressText)
            }
        }

        DispatchQueue.main.async {
            self.reloadPersistedOfflineAreas()
            self.updateCacheProgressOverlay()
            if expected > 0 && completed == expected {
                if let id = self.decodedOfflineContext(from: pack.context)?.id {
                    self.offlineCacheStore.markCompleted(
                        id: id,
                        byteCount: UInt64(max(0, progress.countOfBytesCompleted))
                    )
                }
                self.offlinePack = nil
                self.reloadPersistedOfflineAreas()
                self.setDownloadButtonTitle("Offline Area Saved")
                self.updateCacheProgressOverlay()
            }
        }
    }

    @objc func handleOfflineError(_ notification: Notification) {
        guard let pack = notification.object as? MLNOfflinePack else { return }
        guard let id = decodedOfflineContext(from: pack.context)?.id else { return }

        let message: String
        if let error = notification.userInfo?[NSUnderlyingErrorKey] as? NSError {
            message = error.localizedDescription
        } else {
            message = "Offline download failed."
        }

        offlineCacheStore.markFailed(id: id, message: message)

        DispatchQueue.main.async {
            if self.offlinePack == pack {
                self.offlinePack = nil
            }
            self.reloadPersistedOfflineAreas()
            self.setDownloadButtonTitle("Offline Download Failed")
            self.updateCacheProgressOverlay()
        }
    }
}
