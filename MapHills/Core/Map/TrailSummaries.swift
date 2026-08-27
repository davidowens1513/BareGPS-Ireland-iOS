import CoreLocation

enum PendingTrailStartMode {
    case standard
    case fresh
}

struct CoillteTrailSummary {
    let name: String
    let lengthMeters: Double?
    let ascentMeters: Double?
    let coordinateSegments: [[CLLocationCoordinate2D]]
    let startCoordinate: CLLocationCoordinate2D
    let finishCoordinate: CLLocationCoordinate2D
}

struct SportIrelandTrailSummary {
    let trailID: String
    let name: String
    let lengthMeters: Double?
    let ascentMeters: Double?
    let coordinateSegments: [[CLLocationCoordinate2D]]
}

struct OutscapeTrailSummary {
    let trailID: String
    let name: String
    let lengthMeters: Double?
    let ascentMeters: Double?
    let coordinateSegments: [[CLLocationCoordinate2D]]
}
