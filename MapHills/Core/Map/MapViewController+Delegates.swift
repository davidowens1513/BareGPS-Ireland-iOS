//
//  MapViewController+Delegates.swift
//  MapHills
//
//  Created by Codex.
//

import CoreLocation
import MapLibre
import UIKit

extension ViewController: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latestLocation = locations.last else { return }
        guard CLLocationCoordinate2DIsValid(latestLocation.coordinate) else { return }

        if mapViewportStateStore.consumePendingAutoRecenter() {
            recenterTapped()
        }

        if mapView.showsUserLocation == false {
            mapView.showsUserLocation = true
        }

        appendTrailCoordinateIfNeeded(latestLocation)
        appendBreadcrumbCoordinateIfNeeded(latestLocation)
        updateCurrentGridRefOverlay()
        updateLiveGPXStatsCard()

        if mapView.userTrackingMode == .follow {
            mapView.setCenter(latestLocation.coordinate, zoomLevel: followZoomLevel, animated: true)
        }

        if let activeGoToTarget {
            refreshGoToPolyline(from: latestLocation.coordinate, to: activeGoToTarget.coordinate)
        }

        if let overlay = goToOverlayViewController {
            updateGoToOverlayNavigation(for: overlay.target)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        latestHeading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        updatePositionIndicator()
        if let overlay = goToOverlayViewController {
            updateGoToOverlayNavigation(for: overlay.target)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location update failed: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard !isUITestBypassingLocationPrompts else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            mapView.showsUserLocation = true
            updateBackgroundLocationMode()
            locationManager.startUpdatingLocation()
            startHeadingUpdatesIfAvailable()
            applyMapOrientationMode(animated: false)
            updateRecenterButtonAppearance()
            updateCurrentGridRefOverlay()
            updatePositionIndicator()

            if let pendingTrailStartMode {
                self.pendingTrailStartMode = nil
                if pendingTrailStartMode == .fresh {
                    discardTrailRecording()
                }
                startTrailRecording()
            }

            if mapViewportStateStore.consumeFollowModeAfterAuthorization() {
                recenterTapped()
            }

            if let pendingGoToTarget {
                self.pendingGoToTarget = nil
                DispatchQueue.main.async {
                    self.startGoTo(for: pendingGoToTarget)
                }
            }

        case .denied, .restricted:
            mapView.showsUserLocation = false
            updateBackgroundLocationMode()
            locationManager.stopUpdatingHeading()
            mapView.userTrackingMode = .none
            latestHeading = nil
            mapViewportStateStore.clearLocationDependentResumeState()
            updateRecenterButtonAppearance()
            updateCurrentGridRefOverlay()
            updatePositionIndicator()
            pendingTrailStartMode = nil
            pendingGoToTarget = nil

        case .notDetermined:
            updateCurrentGridRefOverlay()
            updatePositionIndicator()
            break

        @unknown default:
            break
        }
    }
}

extension ViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let fileURL = urls.first else { return }
        importGPX(from: fileURL)
    }
}

extension ViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer === goToLineTapRecognizer {
            return isTapNearActiveGoToLine(at: touch.location(in: view))
        }

        if gestureRecognizer === providerTrailTapRecognizer {
            return isTapNearSelectedProviderTrail(at: touch.location(in: view))
        }

        if gestureRecognizer === hillSearchDismissTapRecognizer {
            let touchLocation = touch.location(in: view)
            if hillSearchField.frame.contains(touchLocation) ||
                hillSearchSuggestionsTableView.frame.contains(touchLocation) {
                return false
            }
            return !hillSearchField.isHidden
        }

        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer === providerTrailTapRecognizer || gestureRecognizer === goToLineTapRecognizer
    }
}
