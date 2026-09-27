import Foundation

struct RecordsTableFormatter {
    let peaks: [Peak]
    let classificationCodes: [String]
    let classificationDisplayName: (String) -> String
    let peakClassificationCodes: (Peak) -> [String]
    let isPeakLogged: (Peak) -> Bool

    func tableText() -> String {
        let sortedPeaks = peaks.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let nameColumnWidth = min(max(sortedPeaks.map { $0.name.count }.max() ?? 8, 8), 28)
        let codeColumnWidth = max(
            4,
            classificationCodes.map { classificationDisplayName($0).count }.max() ?? 4
        )

        let widths = [nameColumnWidth] + Array(repeating: codeColumnWidth, count: classificationCodes.count)
        let header = row(
            ["Hill"] + classificationCodes.map(classificationDisplayName),
            widths: widths
        )
        let horizontalRule = separator(widths: widths)

        let rows = sortedPeaks.map { peak -> String in
            let peakCodes = Set(peakClassificationCodes(peak))
            let cells = classificationCodes.map { code -> String in
                guard peakCodes.contains(code) else {
                    return ""
                }

                return isPeakLogged(peak) ? "✓" : "·"
            }

            return row([peak.name] + cells, widths: widths)
        }

        var lines = [horizontalRule, header, horizontalRule]
        for tableRow in rows {
            lines.append(tableRow)
            lines.append(horizontalRule)
        }

        return lines.joined(separator: "\n")
    }

    private func padded(_ text: String, width: Int) -> String {
        if text.count >= width {
            return String(text.prefix(width))
        }

        return text + String(repeating: " ", count: width - text.count)
    }

    private func row(_ values: [String], widths: [Int]) -> String {
        "|" + zip(values, widths).map { value, width in
            " " + padded(value, width: width) + " "
        }.joined(separator: "|") + "|"
    }

    private func separator(widths: [Int]) -> String {
        "+" + widths.map { String(repeating: "-", count: $0 + 2) }.joined(separator: "+") + "+"
    }
}
