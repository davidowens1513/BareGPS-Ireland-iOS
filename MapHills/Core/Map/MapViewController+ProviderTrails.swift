import MapLibre
import UIKit

extension ViewController {
    func showCoillteTrailPolyline(_ trail: CoillteTrailSummary) {
        let presentation = SelectedProviderTrailBuilder.coilltePresentation(
            for: trail,
            color: markerColor(for: .coillte)
        )
        showSelectedProviderTrail(presentation) { polylines in
            selectedCoillteTrailPolylines = polylines
        }
    }

    func showSportIrelandTrailPolyline(_ trail: SportIrelandTrailSummary) {
        let presentation = SelectedProviderTrailBuilder.sportIrelandPresentation(
            for: trail,
            color: markerColor(for: .sportIreland)
        )
        showSelectedProviderTrail(presentation) { polylines in
            selectedSportIrelandTrailPolylines = polylines
        }
    }

    func showOutscapeTrailPolyline(_ trail: OutscapeTrailSummary) {
        let presentation = SelectedProviderTrailBuilder.outscapePresentation(
            for: trail,
            color: markerColor(for: .outscape)
        )
        showSelectedProviderTrail(presentation) { polylines in
            selectedOutscapeTrailPolylines = polylines
        }
    }

    func showSelectedProviderTrail<Polyline: MLNAnnotation>(
        _ presentation: SelectedProviderTrailPresentation<Polyline>,
        storePolylines: ([Polyline]) -> Void
    ) {
        dismissActiveHillCallout(animated: false)
        dismissActiveStartPlaceCallout(animated: false)

        clearSelectedTrailPolylines()
        storePolylines(presentation.polylines)

        selectedProviderTrailName = presentation.name
        selectedProviderTrailProvider = presentation.provider
        selectedProviderTrailLengthMeters = presentation.lengthMeters
        selectedProviderTrailColor = presentation.color
        selectedProviderTrailCoordinateSegments = presentation.coordinateSegments

        guard !presentation.polylines.isEmpty else { return }
        mapView.addAnnotations(presentation.polylines)
        updateSelectedProviderTrailPill(animated: true)
        setMapVisibleArea(for: presentation.visibleCoordinates, animated: true)
    }

    func clearSelectedTrailPolylines() {
        if !selectedCoillteTrailPolylines.isEmpty {
            deselectAnnotationsBeforeRemoval(selectedCoillteTrailPolylines)
            mapView.removeAnnotations(selectedCoillteTrailPolylines)
            selectedCoillteTrailPolylines.removeAll()
        }
        if !selectedSportIrelandTrailPolylines.isEmpty {
            deselectAnnotationsBeforeRemoval(selectedSportIrelandTrailPolylines)
            mapView.removeAnnotations(selectedSportIrelandTrailPolylines)
            selectedSportIrelandTrailPolylines.removeAll()
        }
        if !selectedOutscapeTrailPolylines.isEmpty {
            deselectAnnotationsBeforeRemoval(selectedOutscapeTrailPolylines)
            mapView.removeAnnotations(selectedOutscapeTrailPolylines)
            selectedOutscapeTrailPolylines.removeAll()
        }
        selectedProviderTrailName = nil
        selectedProviderTrailProvider = nil
        selectedProviderTrailLengthMeters = nil
        selectedProviderTrailColor = nil
        selectedProviderTrailCoordinateSegments.removeAll()
        updateSelectedProviderTrailPill(animated: true)
    }

    func deselectAnnotationsBeforeRemoval(_ annotations: [MLNAnnotation]) {
        let selectedAnnotations = mapView.selectedAnnotations
        guard !selectedAnnotations.isEmpty else { return }

        for annotation in annotations {
            if selectedAnnotations.contains(where: { $0 === annotation }) {
                mapView.deselectAnnotation(annotation, animated: false)
            }
        }
    }

    func updateSelectedProviderTrailPill(animated: Bool) {
        let isVisible = selectedProviderTrailName?.isEmpty == false
        selectedProviderTrailNameLabel.text = selectedProviderTrailName
        let providerColor = selectedProviderTrailColor ?? .label
        selectedProviderTrailPillView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.94)
        selectedProviderTrailPillView.layer.borderColor = UIColor.separator.withAlphaComponent(0.55).cgColor
        selectedProviderTrailNameLabel.textColor = isVisible ? providerColor : .label
        selectedProviderTrailCloseButton.tintColor = isVisible ? providerColor : .secondaryLabel

        let changes = {
            self.selectedProviderTrailPillView.alpha = isVisible ? 1 : 0
        }
        let completion: (Bool) -> Void = { _ in
            self.selectedProviderTrailPillView.isHidden = !isVisible
        }

        if isVisible {
            selectedProviderTrailPillView.isHidden = false
        }

        guard animated else {
            changes()
            completion(true)
            return
        }

        UIView.animate(
            withDuration: 0.18,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseOut],
            animations: changes,
            completion: completion
        )
    }
}
