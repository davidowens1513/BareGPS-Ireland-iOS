import CoreLocation
import MapLibre
import UIKit

struct MapVisibleAreaFitter {
    let mapView: MLNMapView
    let maximumMapZoomLevel: Double

    func setVisibleArea(for coordinates: [CLLocationCoordinate2D], animated: Bool) {
        guard !coordinates.isEmpty else { return }

        let bounds = coordinateBounds(for: coordinates)
        let southwestLocation = CLLocation(latitude: bounds.sw.latitude, longitude: bounds.sw.longitude)
        let northeastLocation = CLLocation(latitude: bounds.ne.latitude, longitude: bounds.ne.longitude)
        let routeDiagonalMeters = southwestLocation.distance(from: northeastLocation)

        if routeDiagonalMeters < 250 {
            let center = CLLocationCoordinate2D(
                latitude: (bounds.sw.latitude + bounds.ne.latitude) / 2,
                longitude: (bounds.sw.longitude + bounds.ne.longitude) / 2
            )
            let targetZoomLevel = min(maximumMapZoomLevel, max(mapView.zoomLevel, 16.0))
            mapView.setCenter(center, zoomLevel: targetZoomLevel, animated: animated)
            return
        }

        mapView.setVisibleCoordinateBounds(
            bounds,
            edgePadding: UIEdgeInsets(top: 96, left: 48, bottom: 96, right: 96),
            animated: animated,
            completionHandler: nil
        )
    }

    private func coordinateBounds(for coordinates: [CLLocationCoordinate2D]) -> MLNCoordinateBounds {
        var bounds = MLNCoordinateBounds(sw: coordinates[0], ne: coordinates[0])
        for coordinate in coordinates.dropFirst() {
            bounds.sw.latitude = min(bounds.sw.latitude, coordinate.latitude)
            bounds.sw.longitude = min(bounds.sw.longitude, coordinate.longitude)
            bounds.ne.latitude = max(bounds.ne.latitude, coordinate.latitude)
            bounds.ne.longitude = max(bounds.ne.longitude, coordinate.longitude)
        }
        return bounds
    }
}
