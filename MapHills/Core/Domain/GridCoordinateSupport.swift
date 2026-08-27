//
//  PeakSupport.swift
//  MapHills
//
//  Created by David Owens on 26/03/2026.
//

import Foundation
import CoreLocation
import MapLibre
import UIKit

enum GridCoordinateSystem: Int, CaseIterable, Codable {
    case irishGrid
    case britishNationalGrid
    case itm
    case latitudeLongitude
    case mgrs
    case utm

    var title: String {
        switch self {
        case .irishGrid:
            return "Irish Grid"
        case .britishNationalGrid:
            return "British National Grid"
        case .itm:
            return "ITM"
        case .latitudeLongitude:
            return "Lat/Long"
        case .mgrs:
            return "MGRS"
        case .utm:
            return "UTM"
        }
    }
}

enum GridCoordinateUsageArea {
    case ireland
    case britain
    case elsewhere
}

struct GridCoordinateContext {
    let usageArea: GridCoordinateUsageArea
    let validSystems: [GridCoordinateSystem]
    let preferredSystem: GridCoordinateSystem
}

struct ParsedGridCoordinateInput {
    let displayString: String
    let coordinate: CLLocationCoordinate2D
}

enum GridCoordinateFormatter {
    static func usageContext(for coordinate: CLLocationCoordinate2D) -> GridCoordinateContext {
        switch usageArea(for: coordinate) {
        case .ireland:
            return GridCoordinateContext(
                usageArea: .ireland,
                validSystems: [.irishGrid, .itm, .latitudeLongitude, .mgrs, .utm],
                preferredSystem: .irishGrid
            )
        case .britain:
            return GridCoordinateContext(
                usageArea: .britain,
                validSystems: [.britishNationalGrid, .latitudeLongitude, .mgrs, .utm],
                preferredSystem: .britishNationalGrid
            )
        case .elsewhere:
            return GridCoordinateContext(
                usageArea: .elsewhere,
                validSystems: [.latitudeLongitude, .mgrs, .utm],
                preferredSystem: .latitudeLongitude
            )
        }
    }

    static func usageArea(for coordinate: CLLocationCoordinate2D) -> GridCoordinateUsageArea {
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude

        if (51.2...55.9).contains(latitude), (-10.9 ... -5.1).contains(longitude) {
            return .ireland
        }

        if (49.0...61.1).contains(latitude), (-8.8 ... 2.1).contains(longitude) {
            return .britain
        }

        return .elsewhere
    }

    static func format(
        coordinate: CLLocationCoordinate2D,
        projectedEastingMeters: Double? = nil,
        projectedNorthingMeters: Double? = nil,
        system: GridCoordinateSystem
    ) -> String? {
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }

        switch system {
        case .irishGrid:
            if let projectedEastingMeters, let projectedNorthingMeters {
                return irishGridReference(easting: projectedEastingMeters, northing: projectedNorthingMeters)
            }
            guard let projected = tm65IrishGridEastingNorthing(for: coordinate) else { return nil }
            return irishGridReference(easting: projected.easting, northing: projected.northing)
        case .britishNationalGrid:
            guard let projected = osgb36BritishGridEastingNorthing(for: coordinate) else { return nil }
            return britishGridReference(easting: projected.easting, northing: projected.northing)
        case .itm:
            guard let projected = itmEastingNorthing(for: coordinate) else { return nil }
            return String(format: "ITM %.0f %.0f", projected.easting.rounded(), projected.northing.rounded())
        case .latitudeLongitude:
            return String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
        case .mgrs:
            guard let utm = utmCoordinate(for: coordinate),
                  let square = mgrs100kSquare(for: utm.zoneNumber, easting: utm.easting, northing: utm.northing) else { return nil }
            let eastingRemainder = Int(utm.easting.rounded()) % 100_000
            let northingRemainder = Int(utm.northing.rounded()) % 100_000
            return String(format: "%02d%@ %@ %05d %05d", utm.zoneNumber, utm.zoneLetter, square, eastingRemainder, northingRemainder)
        case .utm:
            guard let utm = utmCoordinate(for: coordinate) else { return nil }
            return String(format: "%02d%@ %.0f %.0f", utm.zoneNumber, utm.zoneLetter, utm.easting.rounded(), utm.northing.rounded())
        }
    }

    static func parse(input: String, system: GridCoordinateSystem) -> ParsedGridCoordinateInput? {
        switch system {
        case .irishGrid:
            guard let parsed = ActiveRegion.current.parseGridReference(input),
                  let coordinate = irishGridCoordinate(easting: parsed.easting, northing: parsed.northing) else { return nil }
            return ParsedGridCoordinateInput(displayString: parsed.gridReference, coordinate: coordinate)
        case .britishNationalGrid:
            guard let parsed = parseBritishGridReference(input),
                  let coordinate = britishGridCoordinate(easting: parsed.easting, northing: parsed.northing) else { return nil }
            return ParsedGridCoordinateInput(displayString: britishGridReference(easting: parsed.easting, northing: parsed.northing) ?? parsed.displayString, coordinate: coordinate)
        case .itm:
            guard let parsed = parseITM(input),
                  let coordinate = itmCoordinate(easting: parsed.easting, northing: parsed.northing) else { return nil }
            return ParsedGridCoordinateInput(displayString: String(format: "ITM %.0f %.0f", parsed.easting.rounded(), parsed.northing.rounded()), coordinate: coordinate)
        case .latitudeLongitude:
            guard let coordinate = parseLatitudeLongitude(input) else { return nil }
            return ParsedGridCoordinateInput(displayString: String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude), coordinate: coordinate)
        case .utm:
            guard let utm = parseUTM(input),
                  let coordinate = coordinateFromUTM(zoneNumber: utm.zoneNumber, hemisphereNorth: utm.hemisphereNorth, easting: utm.easting, northing: utm.northing) else { return nil }
            let zoneLetter = utm.zoneLetter ?? utmLatitudeBand(for: coordinate.latitude)
            return ParsedGridCoordinateInput(
                displayString: String(format: "%02d%@ %.0f %.0f", utm.zoneNumber, zoneLetter, utm.easting.rounded(), utm.northing.rounded()),
                coordinate: coordinate
            )
        case .mgrs:
            guard let mgrs = parseMGRS(input),
                  let coordinate = coordinateFromUTM(zoneNumber: mgrs.zoneNumber, hemisphereNorth: mgrs.hemisphereNorth, easting: mgrs.easting, northing: mgrs.northing) else { return nil }
            let zoneLetter = mgrs.zoneLetter
            return ParsedGridCoordinateInput(
                displayString: String(format: "%02d%@ %@ %05d %05d", mgrs.zoneNumber, zoneLetter, mgrs.square, Int(mgrs.easting.rounded()) % 100_000, Int(mgrs.northing.rounded()) % 100_000),
                coordinate: coordinate
            )
        }
    }

    private static func irishGridReference(easting: Double, northing: Double) -> String? {
        guard easting >= 0, northing >= 0 else { return nil }

        let e100k = Int(floor(easting / 100_000))
        let n100k = Int(floor(northing / 100_000))
        guard (0...4).contains(e100k), (0...4).contains(n100k) else { return nil }

        let squareIndex = (4 - n100k) * 5 + e100k
        let letters = Array("ABCDEFGHJKLMNOPQRSTUVWXYZ")
        guard letters.indices.contains(squareIndex) else { return nil }

        let eRemainder = Int(easting.rounded()) % 100_000
        let nRemainder = Int(northing.rounded()) % 100_000
        return "\(letters[squareIndex]) \(String(format: "%05d", eRemainder)) \(String(format: "%05d", nRemainder))"
    }

    private static func britishGridReference(easting: Double, northing: Double) -> String? {
        guard easting >= 0, northing >= 0 else { return nil }
        let e100k = Int(floor(easting / 100_000))
        let n100k = Int(floor(northing / 100_000))
        guard (0...6).contains(e100k), (0...12).contains(n100k) else { return nil }

        let firstLetterValue = ((19 - n100k) - ((19 - n100k) % 5)) / 5 * 5 + ((e100k + 10) / 5)
        let secondLetterValue = ((19 - n100k) * 5 % 25) + (e100k % 5)
        let firstLetter = gridLetter(for: firstLetterValue)
        let secondLetter = gridLetter(for: secondLetterValue)
        guard let firstLetter, let secondLetter else { return nil }

        let eRemainder = Int(easting.rounded()) % 100_000
        let nRemainder = Int(northing.rounded()) % 100_000
        return "\(firstLetter)\(secondLetter) \(String(format: "%05d", eRemainder)) \(String(format: "%05d", nRemainder))"
    }

    private static func gridLetter(for value: Int) -> Character? {
        guard (0...24).contains(value) else { return nil }
        let scalarOffset = value >= 8 ? value + 1 : value
        return UnicodeScalar(65 + scalarOffset).map(Character.init)
    }

    static func tm65IrishGridEastingNorthing(for coordinate: CLLocationCoordinate2D) -> (easting: Double, northing: Double)? {
        let a = 6378137.0
        let b = 6356752.3141
        let e2 = 1 - (b * b) / (a * a)

        let lat = coordinate.latitude * .pi / 180
        let lon = coordinate.longitude * .pi / 180

        let nu = a / sqrt(1 - e2 * pow(sin(lat), 2))
        let x1 = nu * cos(lat) * cos(lon)
        let y1 = nu * cos(lat) * sin(lon)
        let z1 = (nu * (1 - e2)) * sin(lat)

        let tx = -482.5
        let ty = 130.6
        let tz = -564.6
        let s = -8.15 * 1e-6
        let rx = (1.042 / 3600) * .pi / 180
        let ry = (0.214 / 3600) * .pi / 180
        let rz = (0.631 / 3600) * .pi / 180

        let x2 = tx + (1 + s) * x1 + (-rz) * y1 + ry * z1
        let y2 = ty + rz * x1 + (1 + s) * y1 + (-rx) * z1
        let z2 = tz + (-ry) * x1 + rx * y1 + (1 + s) * z1

        let airyA = 6377340.189
        let airyB = 6356034.447
        let airyE2 = 1 - (airyB * airyB) / (airyA * airyA)
        let p = sqrt(x2 * x2 + y2 * y2)
        var lat2 = atan2(z2, p * (1 - airyE2))
        var previousLat = 0.0

        while abs(lat2 - previousLat) > 1e-10 {
            previousLat = lat2
            let nu2 = airyA / sqrt(1 - airyE2 * pow(sin(lat2), 2))
            lat2 = atan2(z2 + airyE2 * nu2 * sin(lat2), p)
        }

        let lon2 = atan2(y2, x2)

        return transverseMercatorProjection(
            latitudeRadians: lat2,
            longitudeRadians: lon2,
            semiMajorAxis: airyA,
            semiMinorAxis: airyB,
            scaleFactor: 1.000035,
            originLatitudeDegrees: 53.5,
            originLongitudeDegrees: -8.0,
            falseNorthing: 250_000,
            falseEasting: 200_000
        )
    }

    private static func irishGridCoordinate(easting: Double, northing: Double) -> CLLocationCoordinate2D? {
        guard let local = inverseTransverseMercator(
            easting: easting,
            northing: northing,
            semiMajorAxis: 6377340.189,
            semiMinorAxis: 6356034.447,
            scaleFactor: 1.000035,
            originLatitudeDegrees: 53.5,
            originLongitudeDegrees: -8.0,
            falseNorthing: 250_000,
            falseEasting: 200_000
        ) else { return nil }

        return convertLocalDatumToWGS84(
            latitudeRadians: local.latitudeRadians,
            longitudeRadians: local.longitudeRadians,
            semiMajorAxis: 6377340.189,
            semiMinorAxis: 6356034.447,
            tx: 482.5,
            ty: -130.6,
            tz: 564.6,
            scale: 8.15 * 1e-6,
            rxArcSeconds: -1.042,
            ryArcSeconds: -0.214,
            rzArcSeconds: -0.631
        )
    }

    private static func osgb36BritishGridEastingNorthing(for coordinate: CLLocationCoordinate2D) -> (easting: Double, northing: Double)? {
        let a = 6378137.0
        let b = 6356752.3141
        let e2 = 1 - (b * b) / (a * a)
        let lat = coordinate.latitude * .pi / 180
        let lon = coordinate.longitude * .pi / 180

        let nu = a / sqrt(1 - e2 * pow(sin(lat), 2))
        let x1 = nu * cos(lat) * cos(lon)
        let y1 = nu * cos(lat) * sin(lon)
        let z1 = nu * (1 - e2) * sin(lat)

        let tx = -446.448
        let ty = 125.157
        let tz = -542.060
        let s = 20.4894 * 1e-6
        let rx = (-0.1502 / 3600) * .pi / 180
        let ry = (-0.2470 / 3600) * .pi / 180
        let rz = (-0.8421 / 3600) * .pi / 180

        let x2 = tx + (1 + s) * x1 + (-rz) * y1 + ry * z1
        let y2 = ty + rz * x1 + (1 + s) * y1 + (-rx) * z1
        let z2 = tz + (-ry) * x1 + rx * y1 + (1 + s) * z1

        let airyA = 6377563.396
        let airyB = 6356256.909
        let airyE2 = 1 - (airyB * airyB) / (airyA * airyA)
        let p = sqrt(x2 * x2 + y2 * y2)
        var lat2 = atan2(z2, p * (1 - airyE2))
        var previousLat = 0.0

        while abs(lat2 - previousLat) > 1e-10 {
            previousLat = lat2
            let nu2 = airyA / sqrt(1 - airyE2 * pow(sin(lat2), 2))
            lat2 = atan2(z2 + airyE2 * nu2 * sin(lat2), p)
        }

        let lon2 = atan2(y2, x2)

        return transverseMercatorProjection(
            latitudeRadians: lat2,
            longitudeRadians: lon2,
            semiMajorAxis: airyA,
            semiMinorAxis: airyB,
            scaleFactor: 0.9996012717,
            originLatitudeDegrees: 49.0,
            originLongitudeDegrees: -2.0,
            falseNorthing: -100_000,
            falseEasting: 400_000
        )
    }

    private static func britishGridCoordinate(easting: Double, northing: Double) -> CLLocationCoordinate2D? {
        guard let local = inverseTransverseMercator(
            easting: easting,
            northing: northing,
            semiMajorAxis: 6377563.396,
            semiMinorAxis: 6356256.909,
            scaleFactor: 0.9996012717,
            originLatitudeDegrees: 49.0,
            originLongitudeDegrees: -2.0,
            falseNorthing: -100_000,
            falseEasting: 400_000
        ) else { return nil }

        return convertLocalDatumToWGS84(
            latitudeRadians: local.latitudeRadians,
            longitudeRadians: local.longitudeRadians,
            semiMajorAxis: 6377563.396,
            semiMinorAxis: 6356256.909,
            tx: 446.448,
            ty: -125.157,
            tz: 542.060,
            scale: -20.4894 * 1e-6,
            rxArcSeconds: 0.1502,
            ryArcSeconds: 0.2470,
            rzArcSeconds: 0.8421
        )
    }

    private static func itmEastingNorthing(for coordinate: CLLocationCoordinate2D) -> (easting: Double, northing: Double)? {
        transverseMercatorProjection(
            latitudeRadians: coordinate.latitude * .pi / 180,
            longitudeRadians: coordinate.longitude * .pi / 180,
            semiMajorAxis: 6378137.0,
            semiMinorAxis: 6356752.314140356,
            scaleFactor: 0.99982,
            originLatitudeDegrees: 53.5,
            originLongitudeDegrees: -8.0,
            falseNorthing: 750_000,
            falseEasting: 600_000
        )
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

    private static func transverseMercatorProjection(
        latitudeRadians: Double,
        longitudeRadians: Double,
        semiMajorAxis: Double,
        semiMinorAxis: Double,
        scaleFactor: Double,
        originLatitudeDegrees: Double,
        originLongitudeDegrees: Double,
        falseNorthing: Double,
        falseEasting: Double
    ) -> (easting: Double, northing: Double)? {
        let e2 = 1 - (semiMinorAxis * semiMinorAxis) / (semiMajorAxis * semiMajorAxis)
        let lat0 = originLatitudeDegrees * .pi / 180
        let lon0 = originLongitudeDegrees * .pi / 180
        let n = (semiMajorAxis - semiMinorAxis) / (semiMajorAxis + semiMinorAxis)
        let sinLat = sin(latitudeRadians)
        let cosLat = cos(latitudeRadians)
        let tanLat = tan(latitudeRadians)
        let nu = semiMajorAxis * scaleFactor / sqrt(1 - e2 * sinLat * sinLat)
        let rho = semiMajorAxis * scaleFactor * (1 - e2) / pow(1 - e2 * sinLat * sinLat, 1.5)
        let eta2 = nu / rho - 1
        let meridionalArc =
            semiMinorAxis * scaleFactor * (
                (1 + n + 1.25 * n * n + 1.25 * n * n * n) * (latitudeRadians - lat0)
                - (3 * n + 3 * n * n + 2.625 * n * n * n) * sin(latitudeRadians - lat0) * cos(latitudeRadians + lat0)
                + (1.875 * n * n + 1.875 * n * n * n) * sin(2 * (latitudeRadians - lat0)) * cos(2 * (latitudeRadians + lat0))
                - (35.0 / 24.0) * n * n * n * sin(3 * (latitudeRadians - lat0)) * cos(3 * (latitudeRadians + lat0))
            )

        let dLon = longitudeRadians - lon0
        let i = meridionalArc + falseNorthing
        let ii = nu / 2 * sinLat * cosLat
        let iii = nu / 24 * sinLat * pow(cosLat, 3) * (5 - tanLat * tanLat + 9 * eta2)
        let iiia = nu / 720 * sinLat * pow(cosLat, 5) * (61 - 58 * tanLat * tanLat + pow(tanLat, 4))
        let iv = nu * cosLat
        let v = nu / 6 * pow(cosLat, 3) * (nu / rho - tanLat * tanLat)
        let vi = nu / 120 * pow(cosLat, 5) * (5 - 18 * tanLat * tanLat + pow(tanLat, 4) + 14 * eta2 - 58 * tanLat * tanLat * eta2)

        let northing = i + ii * pow(dLon, 2) + iii * pow(dLon, 4) + iiia * pow(dLon, 6)
        let easting = falseEasting + iv * dLon + v * pow(dLon, 3) + vi * pow(dLon, 5)
        return (easting, northing)
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

    private static func convertLocalDatumToWGS84(
        latitudeRadians: Double,
        longitudeRadians: Double,
        semiMajorAxis: Double,
        semiMinorAxis: Double,
        tx: Double,
        ty: Double,
        tz: Double,
        scale: Double,
        rxArcSeconds: Double,
        ryArcSeconds: Double,
        rzArcSeconds: Double
    ) -> CLLocationCoordinate2D? {
        let e2 = 1 - (semiMinorAxis * semiMinorAxis) / (semiMajorAxis * semiMajorAxis)
        let sinLat = sin(latitudeRadians)
        let cosLat = cos(latitudeRadians)
        let nu = semiMajorAxis / sqrt(1 - e2 * sinLat * sinLat)
        let x1 = nu * cosLat * cos(longitudeRadians)
        let y1 = nu * cosLat * sin(longitudeRadians)
        let z1 = nu * (1 - e2) * sinLat

        let rx = (rxArcSeconds / 3600) * .pi / 180
        let ry = (ryArcSeconds / 3600) * .pi / 180
        let rz = (rzArcSeconds / 3600) * .pi / 180

        let x2 = tx + (1 + scale) * x1 + (-rz) * y1 + ry * z1
        let y2 = ty + rz * x1 + (1 + scale) * y1 + (-rx) * z1
        let z2 = tz + (-ry) * x1 + rx * y1 + (1 + scale) * z1

        return wgs84Coordinate(fromCartesianX: x2, y: y2, z: z2)
    }

    private static func wgs84Coordinate(fromCartesianX x: Double, y: Double, z: Double) -> CLLocationCoordinate2D? {
        let a = 6378137.0
        let b = 6356752.3141
        let e2 = 1 - (b * b) / (a * a)
        let p = sqrt(x * x + y * y)
        guard p > 0 else { return nil }

        var lat = atan2(z, p * (1 - e2))
        var previousLat = 0.0
        while abs(lat - previousLat) > 1e-12 {
            previousLat = lat
            let nu = a / sqrt(1 - e2 * pow(sin(lat), 2))
            lat = atan2(z + e2 * nu * sin(lat), p)
        }
        let lon = atan2(y, x)
        return CLLocationCoordinate2D(latitude: lat * 180 / .pi, longitude: lon * 180 / .pi)
    }

    private struct UTMCoordinate {
        let zoneNumber: Int
        let zoneLetter: String
        let easting: Double
        let northing: Double
    }

    private static func utmCoordinate(for coordinate: CLLocationCoordinate2D) -> UTMCoordinate? {
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude
        guard latitude >= -80, latitude <= 84 else { return nil }

        let zoneNumber = utmZoneNumber(latitude: latitude, longitude: longitude)
        let zoneLetter = utmLatitudeBand(for: latitude)
        let lonOrigin = Double(zoneNumber - 1) * 6 - 180 + 3

        let a = 6378137.0
        let eccSquared = 0.00669438
        let k0 = 0.9996

        let latRad = latitude * .pi / 180
        let lonRad = longitude * .pi / 180
        let lonOriginRad = lonOrigin * .pi / 180

        let eccPrimeSquared = eccSquared / (1 - eccSquared)
        let n = a / sqrt(1 - eccSquared * pow(sin(latRad), 2))
        let t = pow(tan(latRad), 2)
        let c = eccPrimeSquared * pow(cos(latRad), 2)
        let aTerm = cos(latRad) * (lonRad - lonOriginRad)

        let m = a * (
            (1 - eccSquared / 4 - 3 * pow(eccSquared, 2) / 64 - 5 * pow(eccSquared, 3) / 256) * latRad
            - (3 * eccSquared / 8 + 3 * pow(eccSquared, 2) / 32 + 45 * pow(eccSquared, 3) / 1024) * sin(2 * latRad)
            + (15 * pow(eccSquared, 2) / 256 + 45 * pow(eccSquared, 3) / 1024) * sin(4 * latRad)
            - (35 * pow(eccSquared, 3) / 3072) * sin(6 * latRad)
        )

        let easting = k0 * n * (
            aTerm
            + (1 - t + c) * pow(aTerm, 3) / 6
            + (5 - 18 * t + t * t + 72 * c - 58 * eccPrimeSquared) * pow(aTerm, 5) / 120
        ) + 500_000

        var northing = k0 * (
            m
            + n * tan(latRad) * (
                pow(aTerm, 2) / 2
                + (5 - t + 9 * c + 4 * c * c) * pow(aTerm, 4) / 24
                + (61 - 58 * t + t * t + 600 * c - 330 * eccPrimeSquared) * pow(aTerm, 6) / 720
            )
        )

        if latitude < 0 {
            northing += 10_000_000
        }

        return UTMCoordinate(zoneNumber: zoneNumber, zoneLetter: zoneLetter, easting: easting, northing: northing)
    }

    private static func coordinateFromUTM(zoneNumber: Int, hemisphereNorth: Bool, easting: Double, northing: Double) -> CLLocationCoordinate2D? {
        let a = 6378137.0
        let eccSquared = 0.00669438
        let k0 = 0.9996
        let eccPrimeSquared = eccSquared / (1 - eccSquared)
        let x = easting - 500_000
        let y = hemisphereNorth ? northing : northing - 10_000_000
        let lonOrigin = Double(zoneNumber - 1) * 6 - 180 + 3

        let m = y / k0
        let mu = m / (a * (1 - eccSquared / 4 - 3 * pow(eccSquared, 2) / 64 - 5 * pow(eccSquared, 3) / 256))
        let e1 = (1 - sqrt(1 - eccSquared)) / (1 + sqrt(1 - eccSquared))

        let phi1Rad =
            mu
            + (3 * e1 / 2 - 27 * pow(e1, 3) / 32) * sin(2 * mu)
            + (21 * pow(e1, 2) / 16 - 55 * pow(e1, 4) / 32) * sin(4 * mu)
            + (151 * pow(e1, 3) / 96) * sin(6 * mu)
            + (1097 * pow(e1, 4) / 512) * sin(8 * mu)

        let n1 = a / sqrt(1 - eccSquared * pow(sin(phi1Rad), 2))
        let t1 = pow(tan(phi1Rad), 2)
        let c1 = eccPrimeSquared * pow(cos(phi1Rad), 2)
        let r1 = a * (1 - eccSquared) / pow(1 - eccSquared * pow(sin(phi1Rad), 2), 1.5)
        let d = x / (n1 * k0)

        let latitude = phi1Rad - (n1 * tan(phi1Rad) / r1) * (
            pow(d, 2) / 2
            - (5 + 3 * t1 + 10 * c1 - 4 * c1 * c1 - 9 * eccPrimeSquared) * pow(d, 4) / 24
            + (61 + 90 * t1 + 298 * c1 + 45 * t1 * t1 - 252 * eccPrimeSquared - 3 * c1 * c1) * pow(d, 6) / 720
        )

        let longitude = (d
            - (1 + 2 * t1 + c1) * pow(d, 3) / 6
            + (5 - 2 * c1 + 28 * t1 - 3 * c1 * c1 + 8 * eccPrimeSquared + 24 * t1 * t1) * pow(d, 5) / 120
        ) / cos(phi1Rad)

        return CLLocationCoordinate2D(
            latitude: latitude * 180 / .pi,
            longitude: lonOrigin + (longitude * 180 / .pi)
        )
    }

    private static func utmZoneNumber(latitude: Double, longitude: Double) -> Int {
        if (56..<64).contains(latitude), (3..<12).contains(longitude) {
            return 32
        }

        if (72..<84).contains(latitude) {
            switch longitude {
            case 0..<9: return 31
            case 9..<21: return 33
            case 21..<33: return 35
            case 33..<42: return 37
            default: break
            }
        }

        return Int(floor((longitude + 180) / 6)) + 1
    }

    private static func utmLatitudeBand(for latitude: Double) -> String {
        let bands = Array("CDEFGHJKLMNPQRSTUVWX")
        let index = max(0, min(bands.count - 1, Int(floor((latitude + 80) / 8))))
        return String(bands[index])
    }

    private static func mgrs100kSquare(for zoneNumber: Int, easting: Double, northing: Double) -> String? {
        let columnSets = ["ABCDEFGH", "JKLMNPQR", "STUVWXYZ"]
        let rowSets = ["ABCDEFGHJKLMNPQRSTUV", "FGHJKLMNPQRSTUVABCDE"]
        let columnSet = columnSets[(zoneNumber - 1) % columnSets.count]
        let rowSet = rowSets[(zoneNumber - 1) % rowSets.count]

        let columnIndex = max(1, min(8, Int(floor(easting / 100_000)))) - 1
        let rowIndex = Int(floor(northing / 100_000)) % 20

        guard columnSet.indices.contains(columnSet.index(columnSet.startIndex, offsetBy: columnIndex)),
              rowSet.indices.contains(rowSet.index(rowSet.startIndex, offsetBy: rowIndex)) else { return nil }

        let column = columnSet[columnSet.index(columnSet.startIndex, offsetBy: columnIndex)]
        let row = rowSet[rowSet.index(rowSet.startIndex, offsetBy: rowIndex)]
        return "\(column)\(row)"
    }

    private static func parseLatitudeLongitude(_ input: String) -> CLLocationCoordinate2D? {
        let normalized = input
            .replacingOccurrences(of: ",", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard normalized.count == 2,
              let latitude = Double(normalized[0]),
              let longitude = Double(normalized[1]),
              (-90...90).contains(latitude),
              (-180...180).contains(longitude) else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private static func parseITM(_ input: String) -> (easting: Double, northing: Double)? {
        let cleaned = input.uppercased().replacingOccurrences(of: "ITM", with: "")
        let parts = cleaned.split(whereSeparator: { $0.isWhitespace || $0 == "," }).map(String.init)
        guard parts.count == 2,
              let easting = Double(parts[0]),
              let northing = Double(parts[1]) else { return nil }
        return (easting, northing)
    }

    private static func parseBritishGridReference(_ input: String) -> (displayString: String, easting: Double, northing: Double)? {
        let cleaned = input.uppercased().filter { $0.isLetter || $0.isNumber }
        guard cleaned.count >= 4 else { return nil }
        let letters = Array(cleaned.prefix(2))
        let digits = String(cleaned.dropFirst(2))
        guard digits.count.isMultiple(of: 2), digits.count <= 10 else { return nil }
        guard let first = gridValue(for: letters[0]), let second = gridValue(for: letters[1]) else { return nil }

        let e100k = ((first - 2) % 5) * 5 + (second % 5)
        let n100k = (19 - (first / 5) * 5) - (second / 5)
        guard e100k >= 0, n100k >= 0 else { return nil }

        let half = digits.count / 2
        let eastingDigits = String(digits.prefix(half))
        let northingDigits = String(digits.suffix(half))
        guard let eastingBase = Int(eastingDigits), let northingBase = Int(northingDigits) else { return nil }
        let scale = Int(pow(10.0, Double(5 - half)))
        let easting = Double(e100k * 100_000 + eastingBase * scale)
        let northing = Double(n100k * 100_000 + northingBase * scale)
        return ("\(letters[0])\(letters[1]) \(String(format: "%05d", Int(easting) % 100_000)) \(String(format: "%05d", Int(northing) % 100_000))", easting, northing)
    }

    private static func gridValue(for letter: Character) -> Int? {
        guard let scalar = letter.unicodeScalars.first?.value else { return nil }
        var value = Int(scalar) - 65
        if value > 7 { value -= 1 }
        return (0...24).contains(value) ? value : nil
    }

    private struct ParsedUTMInput {
        let zoneNumber: Int
        let zoneLetter: String?
        let hemisphereNorth: Bool
        let easting: Double
        let northing: Double
    }

    private static func parseUTM(_ input: String) -> ParsedUTMInput? {
        let cleaned = input.uppercased().replacingOccurrences(of: ",", with: " ")
        let parts = cleaned.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count >= 3 else { return nil }

        let zoneToken = parts[0]
        let zoneDigits = zoneToken.prefix { $0.isNumber }
        let zoneLetters = zoneToken.drop { $0.isNumber }
        guard let zoneNumber = Int(zoneDigits), (1...60).contains(zoneNumber) else { return nil }

        let zoneLetter = zoneLetters.isEmpty ? nil : String(zoneLetters)
        let hemisphereNorth = zoneLetter.map { $0 >= "N" } ?? true
        guard let easting = Double(parts[1]), let northing = Double(parts[2]) else { return nil }
        return ParsedUTMInput(zoneNumber: zoneNumber, zoneLetter: zoneLetter, hemisphereNorth: hemisphereNorth, easting: easting, northing: northing)
    }

    private struct ParsedMGRSInput {
        let zoneNumber: Int
        let zoneLetter: String
        let hemisphereNorth: Bool
        let square: String
        let easting: Double
        let northing: Double
    }

    private static func parseMGRS(_ input: String) -> ParsedMGRSInput? {
        let cleaned = input.uppercased().filter { !$0.isWhitespace && $0 != "," }
        let prefixDigits = cleaned.prefix { $0.isNumber }
        guard let zoneNumber = Int(prefixDigits), (1...60).contains(zoneNumber) else { return nil }
        let remainder = cleaned.dropFirst(prefixDigits.count)
        guard remainder.count >= 3 else { return nil }
        let zoneLetter = String(remainder.prefix(1))
        let square = String(remainder.dropFirst().prefix(2))
        let digits = String(remainder.dropFirst(3))
        guard digits.count.isMultiple(of: 2), digits.count <= 10 else { return nil }
        let half = digits.count / 2
        let eastingDigits = String(digits.prefix(half))
        let northingDigits = String(digits.suffix(half))
        guard let eastingBase = Int(eastingDigits), let northingBase = Int(northingDigits) else { return nil }
        let scale = Int(pow(10.0, Double(5 - half)))
        guard let base = mgrsBaseCoordinate(zoneNumber: zoneNumber, zoneLetter: zoneLetter, square: square) else { return nil }
        let easting = base.easting + Double(eastingBase * scale)
        let northing = base.northing + Double(northingBase * scale)
        return ParsedMGRSInput(zoneNumber: zoneNumber, zoneLetter: zoneLetter, hemisphereNorth: zoneLetter >= "N", square: square, easting: easting, northing: northing)
    }

    private static func mgrsBaseCoordinate(zoneNumber: Int, zoneLetter: String, square: String) -> (easting: Double, northing: Double)? {
        guard square.count == 2 else { return nil }
        let columnSets = ["ABCDEFGH", "JKLMNPQR", "STUVWXYZ"]
        let rowSets = ["ABCDEFGHJKLMNPQRSTUV", "FGHJKLMNPQRSTUVABCDE"]
        let columnSet = columnSets[(zoneNumber - 1) % columnSets.count]
        let rowSet = rowSets[(zoneNumber - 1) % rowSets.count]
        let column = square.first!
        let row = square.last!
        guard let columnIndex = columnSet.firstIndex(of: column),
              let rowIndex = rowSet.firstIndex(of: row) else { return nil }

        let easting = Double(columnSet.distance(from: columnSet.startIndex, to: columnIndex) + 1) * 100_000
        var northing = Double(rowSet.distance(from: rowSet.startIndex, to: rowIndex)) * 100_000
        let minNorthing = minimumNorthingForLatitudeBand(zoneLetter)
        while northing < minNorthing {
            northing += 2_000_000
        }
        return (easting, northing)
    }

    private static func minimumNorthingForLatitudeBand(_ zoneLetter: String) -> Double {
        let lowerBandLatitudes: [String: Double] = [
            "C": -80, "D": -72, "E": -64, "F": -56, "G": -48, "H": -40,
            "J": -32, "K": -24, "L": -16, "M": -8, "N": 0, "P": 8,
            "Q": 16, "R": 24, "S": 32, "T": 40, "U": 48, "V": 56,
            "W": 64, "X": 72
        ]
        guard let lowerLatitude = lowerBandLatitudes[zoneLetter] else { return 0 }
        let probeCoordinate = CLLocationCoordinate2D(latitude: lowerLatitude, longitude: 3)
        return utmCoordinate(for: probeCoordinate)?.northing ?? 0
    }
}
