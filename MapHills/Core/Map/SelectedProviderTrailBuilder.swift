import CoreLocation
import MapLibre
import UIKit

struct SelectedProviderTrailPresentation<Polyline: MLNAnnotation> {
    let polylines: [Polyline]
    let name: String
    let provider: StartPlaceProvider
    let lengthMeters: Double?
    let color: UIColor
    let coordinateSegments: [[CLLocationCoordinate2D]]

    var visibleCoordinates: [CLLocationCoordinate2D] {
        coordinateSegments.flatMap { $0 }
    }
}

enum SelectedProviderTrailBuilder {
    static func coilltePresentation(
        for trail: CoillteTrailSummary,
        color: UIColor
    ) -> SelectedProviderTrailPresentation<CoillteTrailPolyline> {
        presentation(
            name: trail.name,
            provider: .coillte,
            lengthMeters: trail.lengthMeters,
            color: color,
            coordinateSegments: trail.coordinateSegments
        ) { coordinates in
            var mutableCoordinates = coordinates
            return CoillteTrailPolyline(coordinates: &mutableCoordinates, count: UInt(mutableCoordinates.count))
        }
    }

    static func sportIrelandPresentation(
        for trail: SportIrelandTrailSummary,
        color: UIColor
    ) -> SelectedProviderTrailPresentation<SportIrelandTrailPolyline> {
        presentation(
            name: trail.name,
            provider: .sportIreland,
            lengthMeters: trail.lengthMeters,
            color: color,
            coordinateSegments: trail.coordinateSegments
        ) { coordinates in
            var mutableCoordinates = coordinates
            return SportIrelandTrailPolyline(coordinates: &mutableCoordinates, count: UInt(mutableCoordinates.count))
        }
    }

    static func outscapePresentation(
        for trail: OutscapeTrailSummary,
        color: UIColor
    ) -> SelectedProviderTrailPresentation<OutscapeTrailPolyline> {
        presentation(
            name: trail.name,
            provider: .outscape,
            lengthMeters: trail.lengthMeters,
            color: color,
            coordinateSegments: trail.coordinateSegments
        ) { coordinates in
            var mutableCoordinates = coordinates
            return OutscapeTrailPolyline(coordinates: &mutableCoordinates, count: UInt(mutableCoordinates.count))
        }
    }

    private static func presentation<Polyline: MLNAnnotation>(
        name: String,
        provider: StartPlaceProvider,
        lengthMeters: Double?,
        color: UIColor,
        coordinateSegments: [[CLLocationCoordinate2D]],
        makePolyline: ([CLLocationCoordinate2D]) -> Polyline
    ) -> SelectedProviderTrailPresentation<Polyline> {
        let displaySegments = displayCoordinateSegments(from: coordinateSegments)
        return SelectedProviderTrailPresentation(
            polylines: displaySegments.map(makePolyline),
            name: name,
            provider: provider,
            lengthMeters: lengthMeters,
            color: color,
            coordinateSegments: displaySegments
        )
    }

    private static func displayCoordinateSegments(
        from segments: [[CLLocationCoordinate2D]],
        maximumPointCount: Int = 3_000
    ) -> [[CLLocationCoordinate2D]] {
        let totalPointCount = segments.reduce(0) { $0 + $1.count }
        guard totalPointCount > maximumPointCount else { return segments }

        let strideLength = max(1, Int(ceil(Double(totalPointCount) / Double(maximumPointCount))))
        return segments.compactMap { segment in
            guard segment.count > 2 else { return segment }
            var simplified = segment.enumerated().compactMap { index, coordinate in
                index % strideLength == 0 ? coordinate : nil
            }
            if simplified.first?.latitude != segment.first?.latitude || simplified.first?.longitude != segment.first?.longitude,
               let first = segment.first {
                simplified.insert(first, at: 0)
            }
            if simplified.last?.latitude != segment.last?.latitude || simplified.last?.longitude != segment.last?.longitude,
               let last = segment.last {
                simplified.append(last)
            }
            return simplified.count > 1 ? simplified : nil
        }
    }
}
