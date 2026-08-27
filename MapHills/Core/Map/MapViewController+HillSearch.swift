import CoreLocation
import UIKit

struct SearchSuggestionItem {
    enum Kind {
        case hill
        case startPlace
        case irelandPlace

        var sortOrder: Int {
            switch self {
            case .hill:
                return 0
            case .startPlace:
                return 1
            case .irelandPlace:
                return 2
            }
        }

        var badgeImageName: String? {
            switch self {
            case .hill:
                return "triangle.fill"
            case .startPlace:
                return "figure.walk"
            case .irelandPlace:
                return nil
            }
        }

        var badgeColor: UIColor {
            switch self {
            case .hill:
                return .systemRed
            case .startPlace:
                return .systemGreen
            case .irelandPlace:
                return .systemBlue
            }
        }

        var badgeImage: UIImage? {
            switch self {
            case .hill, .startPlace:
                guard let badgeImageName else { return nil }
                return UIImage(systemName: badgeImageName)
            case .irelandPlace:
                return MapAnnotationImages.irelandPlaceSearchBadgeImage(markerColor: badgeColor)
            }
        }

        var usesSymbolTint: Bool {
            switch self {
            case .hill, .startPlace:
                return true
            case .irelandPlace:
                return false
            }
        }
    }

    let kind: Kind
    let title: String
    let subtitle: String
    let peak: Peak?
    let startPlace: StartPlace?
    let irelandPlace: IrelandPlacename?

    static func hill(_ peak: Peak) -> SearchSuggestionItem {
        SearchSuggestionItem(
            kind: .hill,
            title: "\(peak.name) • \(Int(peak.heightM.rounded())) m",
            subtitle: [peak.alternateHillName, peak.rangeName, peak.administrativeArea]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: " • "),
            peak: peak,
            startPlace: nil,
            irelandPlace: nil
        )
    }

    static func startPlace(_ startPlace: StartPlace) -> SearchSuggestionItem {
        SearchSuggestionItem(
            kind: .startPlace,
            title: startPlace.fullDisplayName,
            subtitle: [startPlace.provider.title, startPlace.gridReference, startPlace.status, startPlace.parking]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: " • "),
            peak: nil,
            startPlace: startPlace,
            irelandPlace: nil
        )
    }

    static func irelandPlace(_ place: IrelandPlacename) -> SearchSuggestionItem {
        SearchSuggestionItem(
            kind: .irelandPlace,
            title: place.name,
            subtitle: place.subtitle,
            peak: nil,
            startPlace: nil,
            irelandPlace: place
        )
    }
}

extension ViewController {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard tableView === hillSearchSuggestionsTableView else { return 0 }
        return hillSearchSuggestions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HillSearchSuggestionCell", for: indexPath)
        let suggestion = hillSearchSuggestions[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.image = suggestion.kind.badgeImage
        content.secondaryText = suggestion.subtitle
        content.text = suggestion.title
        content.textProperties.font = .systemFont(ofSize: 14, weight: .semibold)
        content.textProperties.numberOfLines = 1
        content.secondaryTextProperties.font = .systemFont(ofSize: 12, weight: .regular)
        content.secondaryTextProperties.color = .secondaryLabel
        content.secondaryTextProperties.numberOfLines = 1
        if suggestion.kind.usesSymbolTint {
            content.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
            content.imageProperties.tintColor = suggestion.kind.badgeColor
        } else {
            content.imageProperties.preferredSymbolConfiguration = nil
            content.imageProperties.tintColor = nil
        }
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        cell.contentConfiguration = content
        cell.backgroundColor = .systemBackground
        cell.selectionStyle = .default
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard tableView === hillSearchSuggestionsTableView else { return }
        let suggestion = hillSearchSuggestions[indexPath.row]
        tableView.deselectRow(at: indexPath, animated: true)
        switch suggestion.kind {
        case .hill:
            if let peak = suggestion.peak {
                focusOnPeak(
                    peak,
                    placementMode: .belowAnchor,
                    positionsPeakForCallout: true,
                    invocationSource: .search,
                    animated: false
                )
            }
        case .startPlace:
            if let startPlace = suggestion.startPlace {
                focusOnStartPlace(
                    startPlace,
                    placementMode: .belowAnchor,
                    invocationSource: .search,
                    animated: false
                )
            }
        case .irelandPlace:
            if let place = suggestion.irelandPlace {
                focusOnIrelandPlace(place, coordinate: place.coordinate, animated: false)
            }
        }
        DispatchQueue.main.async { [weak self] in
            self?.clearHillSearchPulldownImmediately()
            self?.setHillSearchVisible(false, animated: true)
        }
    }

    func resolveCoordinate(for place: IrelandPlacename) async -> CLLocationCoordinate2D? {
        place.coordinate
    }
}
