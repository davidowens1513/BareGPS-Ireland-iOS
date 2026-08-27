import UIKit

struct CalloutButtonAction {
    let title: String
    let tintColor: UIColor?
    let handler: () -> Void

    init(title: String, tintColor: UIColor? = nil, handler: @escaping () -> Void) {
        self.title = title
        self.tintColor = tintColor
        self.handler = handler
    }
}

struct StartPlaceNearbyHillAction {
    let title: String
    let metrics: String
    let handler: () -> Void
}

struct StartPlaceWalkSummary {
    let name: String
    let length: String
    let ascent: String
    let selectionHandler: () -> Void
}
