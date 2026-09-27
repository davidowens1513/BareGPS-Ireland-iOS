import CoreLocation

struct StartPlaceWalkSummaryProvider {
    let coillteTrailSummaries: [CoillteTrailSummary]
    let sportIrelandTrailSummariesByTrailID: [String: SportIrelandTrailSummary]
    let outscapeTrailSummariesByTrailID: [String: OutscapeTrailSummary]
    let sportIrelandTrailIDByStartPlaceID: [String: String]

    func walkSummaries(
        for startPlace: StartPlace,
        routeLengthFilter: StartPlaceRouteLengthFilter,
        displayUnitSystem: DisplayUnitSystem,
        showCoillteTrail: @escaping (CoillteTrailSummary) -> Void,
        showSportIrelandTrail: @escaping (SportIrelandTrailSummary) -> Void,
        showOutscapeTrail: @escaping (OutscapeTrailSummary) -> Void
    ) -> [StartPlaceWalkSummary] {
        switch startPlace.provider {
        case .coillte:
            return coillteTrailSummaries(for: startPlace)
                .filter { Self.routeLengthPassesFilter($0.lengthMeters, routeLengthFilter: routeLengthFilter) }
                .map { trail in
                    StartPlaceWalkSummary(
                        name: trail.name,
                        length: formattedDistance(trail.lengthMeters, displayUnitSystem: displayUnitSystem),
                        ascent: formattedElevation(trail.ascentMeters, displayUnitSystem: displayUnitSystem),
                        selectionHandler: {
                            showCoillteTrail(trail)
                        }
                    )
                }
        case .sportIreland:
            guard
                let trail = sportIrelandTrailSummary(for: startPlace),
                Self.routeLengthPassesFilter(trail.lengthMeters, routeLengthFilter: routeLengthFilter)
            else {
                return []
            }

            return [
                StartPlaceWalkSummary(
                    name: trail.name,
                    length: formattedDistance(trail.lengthMeters, displayUnitSystem: displayUnitSystem),
                    ascent: formattedElevation(trail.ascentMeters, displayUnitSystem: displayUnitSystem),
                    selectionHandler: {
                        showSportIrelandTrail(trail)
                    }
                )
            ]
        case .outscape:
            guard
                let trail = outscapeTrailSummary(for: startPlace),
                Self.routeLengthPassesFilter(trail.lengthMeters, routeLengthFilter: routeLengthFilter)
            else {
                return []
            }

            return [
                StartPlaceWalkSummary(
                    name: trail.name,
                    length: formattedDistance(trail.lengthMeters, displayUnitSystem: displayUnitSystem),
                    ascent: formattedElevation(trail.ascentMeters, displayUnitSystem: displayUnitSystem),
                    selectionHandler: {
                        showOutscapeTrail(trail)
                    }
                )
            ]
        case .mountainViews:
            return []
        }
    }

    func coillteTrailSummaries(for startPlace: StartPlace) -> [CoillteTrailSummary] {
        let startLocation = CLLocation(latitude: startPlace.latitude, longitude: startPlace.longitude)
        return coillteTrailSummaries
            .filter { trail in
                let trailStart = CLLocation(latitude: trail.startCoordinate.latitude, longitude: trail.startCoordinate.longitude)
                let trailFinish = CLLocation(latitude: trail.finishCoordinate.latitude, longitude: trail.finishCoordinate.longitude)
                return startLocation.distance(from: trailStart) <= 20 || startLocation.distance(from: trailFinish) <= 20
            }
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    func startPlacePassesRouteLengthFilter(
        _ startPlace: StartPlace,
        routeLengthFilter: StartPlaceRouteLengthFilter
    ) -> Bool {
        switch startPlace.provider {
        case .mountainViews:
            return true
        case .coillte:
            let routeLengths = coillteTrailSummaries(for: startPlace).map(\.lengthMeters)
            guard !routeLengths.isEmpty else { return true }
            return routeLengths.contains { Self.routeLengthPassesFilter($0, routeLengthFilter: routeLengthFilter) }
        case .sportIreland:
            guard let trail = sportIrelandTrailSummary(for: startPlace) else { return true }
            return Self.routeLengthPassesFilter(trail.lengthMeters, routeLengthFilter: routeLengthFilter)
        case .outscape:
            guard let trail = outscapeTrailSummary(for: startPlace) else { return true }
            return Self.routeLengthPassesFilter(trail.lengthMeters, routeLengthFilter: routeLengthFilter)
        }
    }

    static func routeLengthPassesFilter(
        _ lengthMeters: Double?,
        routeLengthFilter: StartPlaceRouteLengthFilter
    ) -> Bool {
        guard
            let minimumLengthMeters = routeLengthFilter.minimumLengthMeters,
            let lengthMeters
        else {
            return true
        }
        return lengthMeters >= minimumLengthMeters
    }

    private func sportIrelandTrailSummary(for startPlace: StartPlace) -> SportIrelandTrailSummary? {
        guard let trailID = sportIrelandTrailIDByStartPlaceID[startPlace.id] else { return nil }
        return sportIrelandTrailSummariesByTrailID[trailID]
    }

    private func outscapeTrailSummary(for startPlace: StartPlace) -> OutscapeTrailSummary? {
        outscapeTrailSummariesByTrailID[startPlace.id]
    }

    private func formattedDistance(
        _ lengthMeters: Double?,
        displayUnitSystem: DisplayUnitSystem
    ) -> String {
        lengthMeters.map { MapFormatting.formattedDistance($0, unitSystem: displayUnitSystem) } ?? "Not supplied"
    }

    private func formattedElevation(
        _ ascentMeters: Double?,
        displayUnitSystem: DisplayUnitSystem
    ) -> String {
        ascentMeters.map { MapFormatting.formattedElevation($0, unitSystem: displayUnitSystem) } ?? "Not supplied"
    }
}
