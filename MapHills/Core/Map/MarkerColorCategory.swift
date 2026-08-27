import UIKit

enum MarkerColorCategory: String, CaseIterable {
    case logged
    case from600Up
    case from500To600
    case from400To500
    case from300To400
    case from200To300
    case from100To200
    case below100

    var title: String {
        switch self {
        case .logged:
            return "Logged Hills"
        case .from600Up:
            return "600m+ Hills"
        case .from500To600:
            return "500-600m Hills"
        case .from400To500:
            return "400-500m Hills"
        case .from300To400:
            return "300-400m Hills"
        case .from200To300:
            return "200-300m Hills"
        case .from100To200:
            return "100-200m Hills"
        case .below100:
            return "0-100m Hills"
        }
    }

    var defaultColor: UIColor {
        switch self {
        case .logged:
            return .systemBlue
        case .from600Up:
            return .red
        case .from500To600,
             .from400To500,
             .from300To400,
             .from200To300,
             .from100To200,
             .below100:
            return .systemOrange
        }
    }

    var userDefaultsKey: String {
        "markerColor.\(rawValue)"
    }
}
