import CoreLocation
import Foundation

enum WaypointPresentation {
    static func defaultName(gridReference: String?) -> String {
        if let gridReference {
            return "Waypoint \(gridReference)"
        }
        return "Waypoint"
    }

    static func subtitleText(for waypoint: SavedWaypoint, gridReference: String?) -> String {
        if let gridReference {
            return "Grid Ref: \(gridReference)"
        }
        return String(format: "Lat/Long: %.5f, %.5f", waypoint.latitude, waypoint.longitude)
    }

    static func annotation(for waypoint: SavedWaypoint, gridReference: String?) -> SavedWaypointAnnotation {
        let annotation = SavedWaypointAnnotation()
        annotation.coordinate = waypoint.coordinate
        annotation.title = waypoint.name
        annotation.subtitle = gridReference
        annotation.waypoint = waypoint
        return annotation
    }
}
