import Foundation
import CoreLocation

struct IrelandPlacename {
    enum Kind {
        case populationCentre
        case townland

        var title: String {
            switch self {
            case .populationCentre:
                return "Place"
            case .townland:
                return "Townland"
            }
        }
    }

    let name: String
    let irishName: String
    let county: String
    let classification: String
    let kind: Kind
    let latitude: Double?
    let longitude: Double?
    let itmEasting: Double?
    let itmNorthing: Double?
    let searchableText: String

    var subtitle: String {
        let parts = [
            kind.title,
            county,
            irishName.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        .filter { !$0.isEmpty }
        return parts.joined(separator: " • ")
    }

    var coordinate: CLLocationCoordinate2D? {
        if let latitude, let longitude {
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
        }

        guard let itmEasting, let itmNorthing else { return nil }
        return IrelandPlacename.itmCoordinate(easting: itmEasting, northing: itmNorthing)
    }

    private static func itmCoordinate(easting: Double, northing: Double) -> CLLocationCoordinate2D? {
        guard let inverse = inverseTransverseMercator(
            easting: easting,
            northing: northing,
            semiMajorAxis: 6378137.0,
            semiMinorAxis: 6356752.314140356,
            scaleFactor: 0.99982,
            originLatitudeDegrees: 53.5,
            originLongitudeDegrees: -8.0,
            falseNorthing: 750_000,
            falseEasting: 600_000
        ) else { return nil }

        return CLLocationCoordinate2D(
            latitude: inverse.latitudeRadians * 180 / .pi,
            longitude: inverse.longitudeRadians * 180 / .pi
        )
    }

    private static func inverseTransverseMercator(
        easting: Double,
        northing: Double,
        semiMajorAxis: Double,
        semiMinorAxis: Double,
        scaleFactor: Double,
        originLatitudeDegrees: Double,
        originLongitudeDegrees: Double,
        falseNorthing: Double,
        falseEasting: Double
    ) -> (latitudeRadians: Double, longitudeRadians: Double)? {
        let e2 = 1 - (semiMinorAxis * semiMinorAxis) / (semiMajorAxis * semiMajorAxis)
        let lat0 = originLatitudeDegrees * .pi / 180
        let lon0 = originLongitudeDegrees * .pi / 180
        let n = (semiMajorAxis - semiMinorAxis) / (semiMajorAxis + semiMinorAxis)

        var lat = (northing - falseNorthing) / (semiMajorAxis * scaleFactor) + lat0
        var meridionalArc = 0.0

        repeat {
            lat = (northing - falseNorthing - meridionalArc) / (semiMajorAxis * scaleFactor) + lat
            meridionalArc = semiMinorAxis * scaleFactor * (
                (1 + n + 1.25 * n * n + 1.25 * n * n * n) * (lat - lat0)
                - (3 * n + 3 * n * n + 2.625 * n * n * n) * sin(lat - lat0) * cos(lat + lat0)
                + (1.875 * n * n + 1.875 * n * n * n) * sin(2 * (lat - lat0)) * cos(2 * (lat + lat0))
                - (35.0 / 24.0) * n * n * n * sin(3 * (lat - lat0)) * cos(3 * (lat + lat0))
            )
        } while northing - falseNorthing - meridionalArc >= 0.00001

        let sinLat = sin(lat)
        let cosLat = cos(lat)
        let tanLat = tan(lat)
        let nu = semiMajorAxis * scaleFactor / sqrt(1 - e2 * sinLat * sinLat)
        let rho = semiMajorAxis * scaleFactor * (1 - e2) / pow(1 - e2 * sinLat * sinLat, 1.5)
        let eta2 = nu / rho - 1
        let dE = easting - falseEasting

        let vii = tanLat / (2 * rho * nu)
        let viii = tanLat / (24 * rho * pow(nu, 3)) * (5 + 3 * tanLat * tanLat + eta2 - 9 * tanLat * tanLat * eta2)
        let ix = tanLat / (720 * rho * pow(nu, 5)) * (61 + 90 * tanLat * tanLat + 45 * pow(tanLat, 4))
        let x = 1 / (cosLat * nu)
        let xi = 1 / (6 * cosLat * pow(nu, 3)) * (nu / rho + 2 * tanLat * tanLat)
        let xii = 1 / (120 * cosLat * pow(nu, 5)) * (5 + 28 * tanLat * tanLat + 24 * pow(tanLat, 4))
        let xiia = 1 / (5040 * cosLat * pow(nu, 7)) * (61 + 662 * tanLat * tanLat + 1320 * pow(tanLat, 4) + 720 * pow(tanLat, 6))

        let latitude = lat - vii * pow(dE, 2) + viii * pow(dE, 4) - ix * pow(dE, 6)
        let longitude = lon0 + x * dE - xi * pow(dE, 3) + xii * pow(dE, 5) - xiia * pow(dE, 7)
        return (latitude, longitude)
    }
}
