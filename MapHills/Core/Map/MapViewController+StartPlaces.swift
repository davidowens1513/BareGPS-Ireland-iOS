import Foundation
import MapLibre
import UIKit

extension ViewController {
    func showStartPlaceCallout(
        for startPlaceAnnotation: StartPlaceAnnotation,
        placementMode: StartPlaceCalloutView.PlacementMode = .belowAnchor
    ) {
        dismissActiveHillCallout(animated: false)
        dismissActiveStartPlaceCallout(animated: false)
        dismissActiveCachedAreaCallout(animated: false)
        removeSelectedIrelandPlaceHalo()

        guard let startPlace = startPlaceAnnotation.startPlace else { return }

        let calloutView = StartPlaceCalloutView(
            annotation: startPlaceAnnotation,
            title: startPlaceDisplayTitle(for: startPlace),
            fullName: startPlace.shortDisplayName,
            gridReference: startPlace.gridReference.isEmpty ? "Not supplied" : startPlace.gridReference,
            height: startPlace.heightM.map { "Height: \(formattedCompactElevation($0))" } ?? "Height: Not supplied",
            status: startPlace.status,
            parking: startPlace.parking.isEmpty ? "Not supplied" : startPlace.parking,
            provider: startPlace.provider,
            providerColor: markerColor(for: startPlace),
            walkSummaries: walkSummaries(for: startPlace),
            nearbyHillActions: nearbyHillActions(for: startPlace),
            directionsHandler: { [weak self] in
                self?.openDirections(to: startPlace)
            },
            googleDirectionsHandler: { [weak self] in
                self?.openGoogleMapsDirections(to: startPlace)
            },
            mountainViewsStartPlaceHandler: mountainViewsStartPlaceURL(for: startPlace).map { url in
                { UIApplication.shared.open(url) }
            },
            placementMode: placementMode
        )

        // The annotation view can still have its pre-camera frame for a render
        // cycle. Coordinate conversion reflects the camera synchronously.
        let anchorPoint = mapView.convert(startPlaceAnnotation.coordinate, toPointTo: mapView)
        let anchorRectInMapView = CGRect(
            x: anchorPoint.x - 22,
            y: anchorPoint.y - 22,
            width: 44,
            height: 44
        )

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
        activeStartPlaceCalloutView = calloutView
    }

    func startPlaceDisplayTitle(for startPlace: StartPlace) -> String {
        let title = startPlace.fullDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let duplicateSecondarySuffix = " (Secondary)"
        guard title.hasSuffix(duplicateSecondarySuffix) else { return title }

        let titleBeforeSuffix = String(title.dropLast(duplicateSecondarySuffix.count))
        if titleBeforeSuffix.range(of: "Secondary", options: [.caseInsensitive, .diacriticInsensitive]) != nil {
            return titleBeforeSuffix.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return title
    }

    func walkSummaries(for startPlace: StartPlace) -> [StartPlaceWalkSummary] {
        startPlaceWalkSummaryProvider.walkSummaries(
            for: startPlace,
            routeLengthFilter: startPlaceRouteLengthFilter,
            displayUnitSystem: selectedDisplayUnitSystem,
            showCoillteTrail: { [weak self] trail in
                self?.showCoillteTrailPolyline(trail)
            },
            showSportIrelandTrail: { [weak self] trail in
                self?.showSportIrelandTrailPolyline(trail)
            },
            showOutscapeTrail: { [weak self] trail in
                self?.showOutscapeTrailPolyline(trail)
            }
        )
    }

    func coillteTrailSummaries(for startPlace: StartPlace) -> [CoillteTrailSummary] {
        startPlaceWalkSummaryProvider.coillteTrailSummaries(for: startPlace)
    }

    func selectionKey(for startPlace: StartPlace) -> String {
        "\(startPlace.provider.rawValue)|\(startPlace.id)|\(String(format: "%.6f", startPlace.latitude))|\(String(format: "%.6f", startPlace.longitude))"
    }

    func startPlaceAnnotation(for startPlace: StartPlace) -> StartPlaceAnnotation? {
        let targetKey = selectionKey(for: startPlace)
        return startPlaceAnnotation(forSelectionKey: targetKey)
    }

    func startPlaceAnnotation(forSelectionKey targetKey: String) -> StartPlaceAnnotation? {
        return startPlaceAnnotations(from: mapView.annotations).first { annotation in
            guard let candidate = annotation.startPlace else { return false }
            return selectionKey(for: candidate) == targetKey
        }
    }

    func refreshStartPlaceAnnotation(forSelectionKey targetKey: String) -> StartPlaceAnnotation? {
        guard let existingAnnotation = startPlaceAnnotation(forSelectionKey: targetKey) else { return nil }

        let refreshedAnnotation = StartPlaceAnnotation()
        refreshedAnnotation.coordinate = existingAnnotation.coordinate
        refreshedAnnotation.title = existingAnnotation.title
        refreshedAnnotation.subtitle = existingAnnotation.subtitle
        refreshedAnnotation.startPlace = existingAnnotation.startPlace

        mapView.removeAnnotation(existingAnnotation)
        mapView.addAnnotation(refreshedAnnotation)
        return refreshedAnnotation
    }

    func focusOnStartPlace(
        _ startPlace: StartPlace,
        placementMode: StartPlaceCalloutView.PlacementMode = .belowAnchor,
        invocationSource: CalloutInvocationSource = .other,
        animated: Bool = true
    ) {
        dismissActiveHillCallout(animated: false)
        removeSelectedIrelandPlaceHalo()
        pendingStartPlaceCalloutPlacementMode = placementMode
        pendingStartPlaceCalloutSelectionToken += 1
        let selectionToken = pendingStartPlaceCalloutSelectionToken

        let targetZoomLevel: Double = invocationSource == .search ? 14.0 : 16.0
        if invocationSource == .search {
            mapView.setCenter(startPlace.coordinate, zoomLevel: targetZoomLevel, animated: animated)
            positionCoordinateForCallout(startPlace.coordinate)
        } else {
            mapView.setCenter(startPlace.coordinate, zoomLevel: mapView.zoomLevel, animated: animated)
            positionCoordinateForCallout(startPlace.coordinate)
        }

        guard let annotation = startPlaceAnnotation(for: startPlace) else {
            pendingStartPlaceCalloutPlacementMode = nil
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self else { return }
            guard selectionToken == self.pendingStartPlaceCalloutSelectionToken else { return }
            self.mapView.selectAnnotation(annotation, animated: false, completionHandler: nil)
        }
    }
}
