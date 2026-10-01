//
//  MapViewController+MapViewDelegate.swift
//  Maphills
//
//  Created by Codex on 07/07/2026.
//

import Foundation
import MapLibre
import UIKit

extension ViewController: MLNMapViewDelegate {

    func mapView(_ mapView: MLNMapView, didUpdate userLocation: MLNUserLocation?) {
        // Refresh pin distances whenever the user's location changes.
        refreshPeakAnnotationSubtitles()

        updatePositionIndicator()

        // Only auto-center if follow mode is active.
        guard mapView.userTrackingMode == .follow,
              let coordinate = userLocation?.coordinate else {
            return
        }

        mapView.setCenter(coordinate, zoomLevel: followZoomLevel, animated: true)
    }

    func mapView(_ mapView: MLNMapView,
                 regionWillChangeAnimated animated: Bool,
                 reason: MLNCameraChangeReason) {
        let userGestureReasons: MLNCameraChangeReason = [
            .gesturePan,
            .gesturePinch,
            .gestureRotate,
            .gestureZoomIn,
            .gestureZoomOut,
            .gestureOneFingerZoom
        ]

        if !reason.intersection(userGestureReasons).isEmpty {
            mapView.userTrackingMode = .none
            scheduleMapInactivityRecenter()
            updateRecenterButtonAppearance()
            dismissActiveHillCallout(animated: false)
            dismissActiveCachedAreaCallout(animated: false)
        }
    }

    func mapView(_ mapView: MLNMapView,
                 didChange mode: MLNUserTrackingMode,
                 animated: Bool) {
        updateRecenterButtonAppearance()
        updateOrientationButtonAppearance()
    }

    func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
        updateCachingIndicatorAppearance()
        updatePositionIndicator()
        updateCurrentGridRefOverlay()
        updateZoomSliderFromMap()
    }

    func mapViewRegionIsChanging(_ mapView: MLNMapView) {
        updateOrientationButtonAppearance()
        updatePositionIndicator()
        updateCurrentGridRefOverlay()
        updateZoomSliderFromMap()
    }
}
