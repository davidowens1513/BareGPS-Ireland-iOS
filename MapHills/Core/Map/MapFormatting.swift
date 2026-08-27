import CoreLocation
import UIKit

enum MapFormatting {
    static func formattedDistance(_ distanceMeters: CLLocationDistance, unitSystem: DisplayUnitSystem) -> String {
        switch unitSystem {
        case .metric:
            if distanceMeters >= 1000 {
                return String(format: "%.2f km", distanceMeters / 1000)
            }
            return String(format: "%.0f m", distanceMeters)
        case .imperial:
            let miles = distanceMeters / 1609.344
            if miles >= 0.1 {
                return String(format: "%.2f mi", miles)
            }
            return String(format: "%.0f ft", distanceMeters * 3.28084)
        }
    }

    static func formattedElevation(_ elevationMeters: Double, unitSystem: DisplayUnitSystem) -> String {
        switch unitSystem {
        case .metric:
            return String(format: "%.0f m", elevationMeters)
        case .imperial:
            return String(format: "%.0f ft", elevationMeters * 3.28084)
        }
    }

    static func formattedProminence(_ prominenceMeters: Double, unitSystem: DisplayUnitSystem) -> String {
        switch unitSystem {
        case .metric:
            return String(format: "%.1f m", prominenceMeters)
        case .imperial:
            return String(format: "%.1f ft", prominenceMeters * 3.28084)
        }
    }

    static func formattedCompactElevation(_ elevationMeters: Double, unitSystem: DisplayUnitSystem) -> String {
        switch unitSystem {
        case .metric:
            return "\(Int(elevationMeters.rounded()))m"
        case .imperial:
            return "\(Int((elevationMeters * 3.28084).rounded()))ft"
        }
    }

    static func formattedLiveGPXDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        return formattedDuration(totalSeconds: totalSeconds, padsHours: false)
    }

    static func formattedSavedGPXDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration))
        return formattedDuration(totalSeconds: totalSeconds, padsHours: true)
    }

    static func formattedLiveGPXAccuracy(_ location: CLLocation?, unitSystem: DisplayUnitSystem) -> String {
        guard let location, location.horizontalAccuracy >= 0 else {
            return "u/a"
        }
        return formattedDistance(location.horizontalAccuracy, unitSystem: unitSystem)
    }

    static func distanceBetween(_ lhs: CGPoint, and rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    static func distanceFrom(point: CGPoint, toSegmentStart start: CGPoint, end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            return distanceBetween(point, and: start)
        }

        let projection = ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared
        let clampedProjection = max(0, min(1, projection))
        let closestPoint = CGPoint(x: start.x + clampedProjection * dx, y: start.y + clampedProjection * dy)
        return distanceBetween(point, and: closestPoint)
    }

    private static func formattedDuration(totalSeconds: Int, padsHours: Bool) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return padsHours
                ? String(format: "%02d:%02d:%02d", hours, minutes, seconds)
                : String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
