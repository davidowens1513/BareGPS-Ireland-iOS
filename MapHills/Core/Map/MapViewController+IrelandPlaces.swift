import CoreLocation
import Foundation

extension ViewController {
    func focusOnIrelandPlace(
        _ place: IrelandPlacename,
        coordinate: CLLocationCoordinate2D? = nil,
        animated: Bool = true
    ) {
        dismissActiveHillCallout(animated: false)
        dismissActiveStartPlaceCallout(animated: false)
        dismissActiveCachedAreaCallout(animated: false)
        removeSelectedIrelandPlaceHalo()

        let selectionCoordinate = coordinate ?? place.coordinate ?? mapView.centerCoordinate
        mapView.setCenter(selectionCoordinate, zoomLevel: 12.0, animated: animated)
        let haloAnnotation = showSelectedIrelandPlaceHalo(for: place, coordinate: selectionCoordinate)
        pendingIrelandPlaceHaloRemovalToken += 1
        let removalToken = pendingIrelandPlaceHaloRemovalToken

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self else { return }
            guard removalToken == self.pendingIrelandPlaceHaloRemovalToken else { return }
            guard self.selectedIrelandPlaceHaloAnnotation === haloAnnotation else { return }
            self.removeSelectedIrelandPlaceHalo()
        }
    }

    @discardableResult
    func showSelectedIrelandPlaceHalo(
        for place: IrelandPlacename,
        coordinate: CLLocationCoordinate2D
    ) -> IrelandPlaceSelectionAnnotation {
        removeSelectedIrelandPlaceHalo()
        let haloAnnotation = IrelandPlaceSelectionAnnotation()
        haloAnnotation.coordinate = coordinate
        haloAnnotation.place = place
        haloAnnotation.title = place.name
        haloAnnotation.subtitle = place.subtitle
        selectedIrelandPlaceHaloAnnotation = haloAnnotation
        mapView.addAnnotation(haloAnnotation)
        return haloAnnotation
    }

    func removeSelectedIrelandPlaceHalo() {
        pendingIrelandPlaceHaloRemovalToken += 1
        if let selectedIrelandPlaceHaloAnnotation {
            mapView.removeAnnotation(selectedIrelandPlaceHaloAnnotation)
            self.selectedIrelandPlaceHaloAnnotation = nil
        }
    }
}
