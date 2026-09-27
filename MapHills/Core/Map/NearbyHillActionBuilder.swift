import CoreLocation

struct NearbyHillActionBuilder {
    let peaks: [Peak]
    let displayUnitSystem: DisplayUnitSystem
    let bearing: (CLLocationCoordinate2D, CLLocationCoordinate2D) -> CLLocationDirection
    let focusOnPeak: (Peak) -> Void

    func actions(
        for startPlace: StartPlace,
        maximumDistanceMeters: CLLocationDistance = 6_000,
        maximumResultCount: Int = 6
    ) -> [StartPlaceNearbyHillAction] {
        let startLocation = CLLocation(latitude: startPlace.latitude, longitude: startPlace.longitude)

        return peaks.compactMap { peak -> (peak: Peak, distanceMeters: CLLocationDistance)? in
            let hillLocation = CLLocation(latitude: peak.latitude, longitude: peak.longitude)
            let distanceMeters = hillLocation.distance(from: startLocation)
            guard distanceMeters <= maximumDistanceMeters else { return nil }
            return (peak, distanceMeters)
        }
        .sorted { lhs, rhs in
            if lhs.distanceMeters != rhs.distanceMeters {
                return lhs.distanceMeters < rhs.distanceMeters
            }
            return lhs.peak.name.localizedCaseInsensitiveCompare(rhs.peak.name) == .orderedAscending
        }
        .prefix(maximumResultCount)
        .map { candidate in
            let peak = candidate.peak
            return StartPlaceNearbyHillAction(
                title: peak.name,
                metrics: metricsText(
                    for: candidate,
                    from: startPlace
                ),
                handler: {
                    focusOnPeak(peak)
                }
            )
        }
    }

    private func metricsText(
        for candidate: (peak: Peak, distanceMeters: CLLocationDistance),
        from startPlace: StartPlace
    ) -> String {
        let peak = candidate.peak
        let distanceText = formattedDistance(candidate.distanceMeters).replacingOccurrences(of: " ", with: "")
        let bearingDegrees = bearing(startPlace.coordinate, peak.coordinate)
        let bearingText = MapFormatting.formattedDegrees(bearingDegrees)

        guard let startHeight = startPlace.heightM else {
            return "\(distanceText), \(bearingText)"
        }

        let heightDifference = peak.heightM - startHeight
        let gainText = formattedElevation(heightDifference).replacingOccurrences(of: " ", with: "")
        return "\(distanceText), \(gainText)↑, \(bearingText)"
    }

    private func formattedDistance(_ distanceMeters: CLLocationDistance) -> String {
        MapFormatting.formattedDistance(distanceMeters, unitSystem: displayUnitSystem)
    }

    private func formattedElevation(_ elevationMeters: Double) -> String {
        MapFormatting.formattedElevation(elevationMeters, unitSystem: displayUnitSystem)
    }
}
