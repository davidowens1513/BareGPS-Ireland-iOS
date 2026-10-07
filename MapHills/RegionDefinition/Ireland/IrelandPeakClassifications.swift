import Foundation

extension IrelandRegionDefinition {
    func derivedClassificationMemberships(
        for peaks: [Peak],
        localHundredConfiguration: LocalHundredConfiguration?
    ) -> DerivedClassificationMemberships {
        let highestHundredPeakIDs = Set(
            peaks
                .filter { $0.prominenceM >= 100 }
                .sorted { lhs, rhs in
                    if lhs.heightM != rhs.heightM {
                        return lhs.heightM > rhs.heightM
                    }
                    if lhs.prominenceM != rhs.prominenceM {
                        return lhs.prominenceM > rhs.prominenceM
                    }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                .prefix(100)
                .map(\.id)
        )

        let normalizedRangePeaks = Dictionary(grouping: peaks) { peak in
            peak.rangeName.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let rangeHighpointPeakIDs = Set(
            normalizedRangePeaks
                .filter { !$0.key.isEmpty }
                .compactMap { _, peaksInRange in
                    peaksInRange.max { lhs, rhs in
                        if lhs.heightM != rhs.heightM {
                            return lhs.heightM < rhs.heightM
                        }
                        if lhs.prominenceM != rhs.prominenceM {
                            return lhs.prominenceM < rhs.prominenceM
                        }
                        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedDescending
                    }?.id
                }
        )

        let provincePeakGroups = Dictionary(grouping: peaks) { peak in
            peak.province.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var provinceTopFiftyPeakIDsByCode: [String: Set<String>] = [:]
        for (province, peaksInProvince) in provincePeakGroups {
            guard let code = provinceTopFiftyCode(forProvinceName: province) else { continue }
            let selectedPeakIDs = Set(
                peaksInProvince
                    .filter { $0.prominenceM >= 100 }
                    .sorted { lhs, rhs in
                        if lhs.heightM != rhs.heightM {
                            return lhs.heightM > rhs.heightM
                        }
                        if lhs.prominenceM != rhs.prominenceM {
                            return lhs.prominenceM > rhs.prominenceM
                        }
                        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                    }
                    .prefix(50)
                    .map(\.id)
            )
            if !selectedPeakIDs.isEmpty {
                provinceTopFiftyPeakIDsByCode[code] = selectedPeakIDs
            }
        }

        let localHundredPeakIDs: Set<String>
        if let localHundredConfiguration {
            localHundredPeakIDs = Set(
                peaks
                    .filter { $0.eastingM != nil && $0.northingM != nil }
                    .sorted { lhs, rhs in
                        let lhsDistance = squaredGridDistance(
                            easting: lhs.eastingM ?? 0,
                            northing: lhs.northingM ?? 0,
                            referenceEasting: localHundredConfiguration.easting,
                            referenceNorthing: localHundredConfiguration.northing
                        )
                        let rhsDistance = squaredGridDistance(
                            easting: rhs.eastingM ?? 0,
                            northing: rhs.northingM ?? 0,
                            referenceEasting: localHundredConfiguration.easting,
                            referenceNorthing: localHundredConfiguration.northing
                        )
                        if lhsDistance != rhsDistance {
                            return lhsDistance < rhsDistance
                        }
                        if lhs.heightM != rhs.heightM {
                            return lhs.heightM > rhs.heightM
                        }
                        if lhs.prominenceM != rhs.prominenceM {
                            return lhs.prominenceM > rhs.prominenceM
                        }
                        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                    }
                    .prefix(100)
                    .map(\.id)
            )
        } else {
            localHundredPeakIDs = []
        }

        return DerivedClassificationMemberships(
            highestHundredPeakIDs: highestHundredPeakIDs,
            rangeHighpointPeakIDs: rangeHighpointPeakIDs,
            provinceTopFiftyPeakIDsByCode: provinceTopFiftyPeakIDsByCode,
            localHundredPeakIDs: localHundredPeakIDs
        )
    }

    func classificationCodes(for peak: Peak, derivedMemberships: DerivedClassificationMembershipStore) -> [String] {
        var codes = Set(normalizedClassificationCodes(from: peak.classification))

        codes.remove("A")
        codes.remove("BIN")
        codes.remove("AB")
        codes.remove("VL")
        codes.remove("4")
        codes.remove("HEW")
        codes.remove("F")
        codes.remove("MA")
        codes.remove("HU")
        codes.remove("HH")
        codes.remove("COH")
        codes.remove("RHP")
        codes.remove("OTHER")
        codes.remove("L100")
        codes.remove("PT50_CONNACHT")
        codes.remove("PT50_LEINSTER")
        codes.remove("PT50_MUNSTER")
        codes.remove("PT50_ULSTER")

        if peak.prominenceM >= 100 {
            codes.insert("HU")
        }

        if peak.prominenceM >= 150 {
            codes.insert("MA")
        }

        if peak.prominenceM >= 30 {
            codes.insert("TU")
        }

        if peak.heightM >= 500, peak.prominenceM >= 30 {
            codes.insert("A")
        }

        if peak.heightM >= 914.4 {
            codes.insert("F")
        }

        if peak.heightM >= 609.6, peak.prominenceM >= 30 {
            codes.insert("HEW")
        }

        if peak.heightM >= 500, peak.prominenceM >= 15, peak.prominenceM < 30 {
            codes.insert("AB")
        }

        if peak.heightM >= 100, peak.heightM < 400, peak.prominenceM >= 100 {
            codes.insert("BIN")
        }

        if peak.heightM >= 600, peak.prominenceM >= 15 {
            codes.insert("VL")
        }

        if peak.heightM >= 400, peak.heightM < 500, peak.prominenceM >= 30 {
            codes.insert("4")
        }

        if peak.prominenceM >= 500 {
            codes.insert("P500")
        }

        if peak.prominenceM >= 600 {
            codes.insert("P600")
        }

        if derivedMemberships.isHighestHundred(peak) {
            codes.insert("HH")
        }

        if derivedMemberships.isLocalHundred(peak) {
            codes.insert("L100")
        }

        if derivedMemberships.isRangeHighpoint(peak) {
            codes.insert("RHP")
        }

        if let provinceTopFiftyCode = derivedMemberships.provinceTopFiftyMembershipCode(for: peak) {
            codes.insert(provinceTopFiftyCode)
        }

        if !peak.countyHighpointOf.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            codes.insert("COH")
        }

        if codes.compactMap(displayNameForClassificationCode).isEmpty {
            codes.insert("OTHER")
        }

        return codes.sorted()
    }

    func displayNameForClassificationCode(_ code: String) -> String? {
        switch code.uppercased() {
        case "MA":
            return "Marilyn"
        case "F":
            return "Furth"
        case "SIB":
            return "Island"
        case "COH":
            return "County Highpoint"
        case "DEW":
            return "Dewey"
        case "N":
            return "Nuttall"
        case "HU":
            return "Hump"
        case "TU":
            return "Tump"
        case "SIM":
            return "Simm"
        case "HEW":
            return "Hewitt"
        case "DIL":
            return "Dillon"
        case "A":
            return "Arderin"
        case "AB":
            return "Arderin Beg"
        case "BIN":
            return "Binnion"
        case "VL":
            return "Vandeleur-Lynam"
        case "P500":
            return "P500"
        case "P600":
            return "P600"
        case "HH":
            return "Highest Hundred"
        case "L100":
            return "Nearest 100"
        case "RHP":
            return "Range Highpoint"
        case "PT50_CONNACHT":
            return "Connacht Top 50"
        case "PT50_LEINSTER":
            return "Leinster Top 50"
        case "PT50_MUNSTER":
            return "Munster Top 50"
        case "PT50_ULSTER":
            return "Ulster Top 50"
        case "OTHER":
            return "Other"
        case "5":
            return "Dodd (500-599m)"
        case "4":
            return "Carn"
        default:
            return nil
        }
    }

    func classificationSections(for availableCodes: Set<String>) -> [ClassificationSection] {
        let provinceTopFiftyCodes = ["PT50_CONNACHT", "PT50_LEINSTER", "PT50_MUNSTER", "PT50_ULSTER"]
            .filter { availableCodes.contains($0) }
        let irishBaseCodes = ["A", "AB", "VL", "HH", "4", "BIN", "L100", "RHP", "COH"]
            .filter { availableCodes.contains($0) }
        let otherIrishCodes = ["OTHER"].filter { availableCodes.contains($0) }
        let irishCodes = irishBaseCodes + provinceTopFiftyCodes + otherIrishCodes
        let britishCodes = ["F", "HEW", "MA", "HU", "TU"].filter { availableCodes.contains($0) }
        let prioritizedCodes = Set(irishCodes + britishCodes)
        let extraCodes = availableCodes
            .subtracting(prioritizedCodes)
            .sorted()

        var sections: [ClassificationSection] = []
        if !irishCodes.isEmpty {
            sections.append(ClassificationSection(title: "Irish Classifications", codes: irishCodes))
        }
        if !britishCodes.isEmpty {
            sections.append(ClassificationSection(title: "British Classifications", codes: britishCodes))
        }
        if !extraCodes.isEmpty {
            sections.append(ClassificationSection(title: "Other Classifications", codes: extraCodes))
        }
        return sections
    }
}

private func provinceTopFiftyCode(forProvinceName province: String) -> String? {
    switch province.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "connacht":
        return "PT50_CONNACHT"
    case "leinster":
        return "PT50_LEINSTER"
    case "munster":
        return "PT50_MUNSTER"
    case "ulster":
        return "PT50_ULSTER"
    default:
        return nil
    }
}

private func squaredGridDistance(
    easting: Double,
    northing: Double,
    referenceEasting: Double,
    referenceNorthing: Double
) -> Double {
    let dEasting = easting - referenceEasting
    let dNorthing = northing - referenceNorthing
    return (dEasting * dEasting) + (dNorthing * dNorthing)
}
