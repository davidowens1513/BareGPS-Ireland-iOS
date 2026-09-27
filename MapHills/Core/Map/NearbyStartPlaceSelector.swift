import CoreLocation

struct NearbyStartPlaceCandidate {
    let startPlace: StartPlace
    let distanceMeters: CLLocationDistance
}

struct NearbyStartPlaceSelector {
    let startPlaces: [StartPlace]
    let visibleProviders: Set<StartPlaceProvider>
    let routeLengthFilter: StartPlaceRouteLengthFilter
    let walkSummaryProvider: StartPlaceWalkSummaryProvider

    func candidates(
        near peak: Peak,
        maximumDistanceMeters: CLLocationDistance = 6_000,
        maximumResultCount: Int = 8
    ) -> [NearbyStartPlaceCandidate] {
        let peakLocation = CLLocation(latitude: peak.latitude, longitude: peak.longitude)

        return startPlaces
            .filter { startPlace in
                visibleProviders.contains(startPlace.provider)
                    && walkSummaryProvider.startPlacePassesRouteLengthFilter(
                        startPlace,
                        routeLengthFilter: routeLengthFilter
                    )
            }
            .compactMap { startPlace -> NearbyStartPlaceCandidate? in
                let startLocation = CLLocation(latitude: startPlace.latitude, longitude: startPlace.longitude)
                let distanceMeters = startLocation.distance(from: peakLocation)
                guard distanceMeters <= maximumDistanceMeters else { return nil }
                return NearbyStartPlaceCandidate(startPlace: startPlace, distanceMeters: distanceMeters)
            }
            .sorted { lhs, rhs in
                if lhs.distanceMeters != rhs.distanceMeters {
                    return lhs.distanceMeters < rhs.distanceMeters
                }
                return lhs.startPlace.shortDisplayName.localizedCaseInsensitiveCompare(rhs.startPlace.shortDisplayName) == .orderedAscending
            }
            .prefix(maximumResultCount)
            .map { $0 }
    }
}
