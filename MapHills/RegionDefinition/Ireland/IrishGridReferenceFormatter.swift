import Foundation

extension IrelandRegionDefinition {
    func parseGridReference(_ input: String) -> (gridReference: String, easting: Double, northing: Double)? {
        let cleaned = input
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }

        guard let firstCharacter = cleaned.first, firstCharacter.isLetter else { return nil }
        let digits = String(cleaned.dropFirst())
        guard !digits.isEmpty, digits.count.isMultiple(of: 2), digits.count <= 10 else { return nil }

        let letters = Array("ABCDEFGHJKLMNOPQRSTUVWXYZ")
        guard let squareIndex = letters.firstIndex(of: firstCharacter) else { return nil }

        let e100k = squareIndex % 5
        let n100k = 4 - (squareIndex / 5)

        let halfCount = digits.count / 2
        let eastingDigits = String(digits.prefix(halfCount))
        let northingDigits = String(digits.suffix(halfCount))

        guard
            let eastingBase = Int(eastingDigits),
            let northingBase = Int(northingDigits)
        else {
            return nil
        }

        let scale = Int(pow(10.0, Double(5 - halfCount)))
        let easting = (e100k * 100_000) + (eastingBase * scale)
        let northing = (n100k * 100_000) + (northingBase * scale)

        return (
            gridReference: "\(firstCharacter) \(String(format: "%05d", easting % 100_000)) \(String(format: "%05d", northing % 100_000))",
            easting: Double(easting),
            northing: Double(northing)
        )
    }

    func gridReference(easting: Double, northing: Double) -> String? {
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
}
