//
//  PrimaryOverlays.swift
//  MapHills
//
//  Created by David Owens on 26/03/2026.
//

import UIKit
import CoreLocation
import MapKit

final class RecordsOverlayViewController: UIViewController {
    enum DisplayMode {
        case records
        case search
    }

    private let peaks: [Peak]
    private let startPlaces: [StartPlace]
    private let displayMode: DisplayMode
    private var loggedPeakIDs: Set<String>
    private let toggleLoggedStateHandler: (Peak, @escaping (Bool) -> Void) -> Void
    private let openStartPlaceHandler: (StartPlace) -> Void

    private var selectedSummarySchema: MenuFilterSchema = .classification
    private var searchQuery = ""

    private let dimmingView = UIView()
    private let cardView = UIView()
    private let contentScrollView = UIScrollView()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let searchTextField = UISearchTextField()
    private let titleLabel = UILabel()
    private let summaryHeaderLabel = UILabel()
    private let searchHeaderLabel = UILabel()
    private let summarySection = UIStackView()
    private let buttonStack = UIStackView()
    private let shareButton = UIButton(type: .system)
    private let overallSummaryContainer = UIView()
    private let subtitleLabel = UILabel()
    private let overallSummaryLabel = UILabel()
    private let summarySchemaControl = UISegmentedControl(items: MenuFilterSchema.allCases.map(\.title))
    private let overallSummaryScrollView = UIScrollView()
    private var keyboardObservers: [NSObjectProtocol] = []
    private lazy var dismissKeyboardTapRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        recognizer.cancelsTouchesInView = false
        return recognizer
    }()

    init(
        peaks: [Peak],
        startPlaces: [StartPlace],
        displayMode: DisplayMode = .records,
        loggedPeakIDs: Set<String>,
        toggleLoggedStateHandler: @escaping (Peak, @escaping (Bool) -> Void) -> Void,
        openStartPlaceHandler: @escaping (StartPlace) -> Void
    ) {
        self.peaks = peaks
        self.startPlaces = startPlaces
        self.displayMode = displayMode
        self.loggedPeakIDs = loggedPeakIDs
        self.toggleLoggedStateHandler = toggleLoggedStateHandler
        self.openStartPlaceHandler = openStartPlaceHandler
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        view.addGestureRecognizer(dismissKeyboardTapRecognizer)
        observeKeyboardChanges()

        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(OverlayChromeStyle.dimmingAlpha)
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissRecords)))
        view.addSubview(dimmingView)

        configureOverlayCardChrome(cardView)
        cardView.accessibilityIdentifier = "recordsOverlayCard"
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.alwaysBounceVertical = true
        cardView.addSubview(contentScrollView)

        titleLabel.text = AppBranding.loggedPeaksTitle
        titleLabel.accessibilityIdentifier = "recordsTitleLabel"
        titleLabel.font = OverlayChromeStyle.titleFont
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        let titleRow = makeOverlayTitleRow(with: titleLabel)

        summaryHeaderLabel.text = "Summary"
        summaryHeaderLabel.font = OverlayChromeStyle.sectionTitleFont
        summaryHeaderLabel.textColor = .label
        summaryHeaderLabel.textAlignment = .center
        summaryHeaderLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        summaryHeaderLabel.setContentHuggingPriority(.required, for: .vertical)

        styleSchemaControl(summarySchemaControl)
        summarySchemaControl.selectedSegmentIndex = selectedSummarySchema.rawValue
        summarySchemaControl.addTarget(self, action: #selector(summarySchemaChanged(_:)), for: .valueChanged)
        summarySchemaControl.setContentCompressionResistancePriority(.required, for: .vertical)
        summarySchemaControl.setContentHuggingPriority(.required, for: .vertical)

        searchTextField.translatesAutoresizingMaskIntoConstraints = false
        searchTextField.accessibilityIdentifier = "recordsSearchField"
        searchTextField.placeholder = displayMode == .search ? "Search hills, start places, or Ireland places" : "Search hills"
        searchTextField.clearButtonMode = .whileEditing
        searchTextField.returnKeyType = .done
        searchTextField.delegate = self
        searchTextField.addTarget(self, action: #selector(searchQueryChanged(_:)), for: .editingChanged)

        subtitleLabel.text = displayMode == .search
            ? "Search hills, start points, and Ireland places by name, region, status, parking, or grid reference. Tap a hill to log it, or a place to open it on the map."
            : "Search Hills. Tap a hill to log it or unlog it."
        subtitleLabel.font = OverlayChromeStyle.supportingFont
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center
        subtitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        overallSummaryLabel.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        overallSummaryLabel.textColor = .label
        overallSummaryLabel.numberOfLines = 0
        overallSummaryLabel.textAlignment = .center
        overallSummaryLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        overallSummaryLabel.translatesAutoresizingMaskIntoConstraints = false
        overallSummaryScrollView.translatesAutoresizingMaskIntoConstraints = false
        overallSummaryScrollView.alwaysBounceVertical = true
        overallSummaryScrollView.addSubview(overallSummaryLabel)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = UIColor.secondarySystemBackground
        tableView.layer.cornerRadius = OverlayChromeStyle.sectionCornerRadius
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "RecordsCell")
        tableView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        let closeButton = UIButton(type: .system)
        closeButton.accessibilityIdentifier = "recordsDoneButton"
        closeButton.configuration = makeOverlayPlainButtonConfiguration(title: "Done")
        closeButton.addTarget(self, action: #selector(dismissRecords), for: .touchUpInside)

        shareButton.accessibilityIdentifier = "recordsShareButton"
        shareButton.configuration = makeOverlayPlainButtonConfiguration(title: "Save/Share...")
        shareButton.addTarget(self, action: #selector(shareRecords), for: .touchUpInside)

        buttonStack.addArrangedSubview(shareButton)
        buttonStack.addArrangedSubview(closeButton)
        buttonStack.axis = .horizontal
        buttonStack.alignment = .fill
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 12

        let buttonContainer = UIView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false

        overallSummaryContainer.translatesAutoresizingMaskIntoConstraints = false
        overallSummaryContainer.backgroundColor = UIColor.secondarySystemBackground
        overallSummaryContainer.layer.cornerRadius = OverlayChromeStyle.sectionCornerRadius
        overallSummaryContainer.layer.borderWidth = 1
        overallSummaryContainer.layer.borderColor = UIColor.separator.cgColor
        overallSummaryContainer.clipsToBounds = true
        overallSummaryContainer.addSubview(overallSummaryScrollView)

        summarySection.axis = .vertical
        summarySection.spacing = 8
        summarySection.isLayoutMarginsRelativeArrangement = true
        summarySection.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 6, leading: 0, bottom: 0, trailing: 0)
        summarySection.addArrangedSubview(summaryHeaderLabel)
        summarySection.addArrangedSubview(summarySchemaControl)
        summarySection.addArrangedSubview(overallSummaryContainer)

        searchHeaderLabel.text = "Search Hills"
        searchHeaderLabel.font = OverlayChromeStyle.sectionTitleFont
        searchHeaderLabel.textColor = .label
        searchHeaderLabel.textAlignment = .center
        searchHeaderLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        searchHeaderLabel.setContentHuggingPriority(.required, for: .vertical)

        let searchSection = UIStackView(arrangedSubviews: [searchHeaderLabel, searchTextField, subtitleLabel])
        searchSection.axis = .vertical
        searchSection.spacing = 6

        let contentStack = UIStackView(arrangedSubviews: [titleRow, summarySection, searchSection, tableView])
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.setCustomSpacing(20, after: summarySection)
        contentScrollView.addSubview(contentStack)
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(buttonStack)
        cardView.addSubview(buttonContainer)

        NSLayoutConstraint.activate([
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            cardView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            cardView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),

            contentScrollView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            contentScrollView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            contentScrollView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            contentScrollView.bottomAnchor.constraint(equalTo: buttonContainer.topAnchor, constant: -16),

            contentStack.leadingAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: contentScrollView.frameLayoutGuide.widthAnchor),

            buttonContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            buttonContainer.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            buttonContainer.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),
            buttonContainer.heightAnchor.constraint(equalToConstant: 44),

            buttonStack.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor),
            buttonStack.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor),
            buttonStack.topAnchor.constraint(equalTo: buttonContainer.topAnchor),
            buttonStack.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor),

            overallSummaryContainer.heightAnchor.constraint(equalToConstant: 260),

            overallSummaryScrollView.leadingAnchor.constraint(equalTo: overallSummaryContainer.leadingAnchor, constant: 12),
            overallSummaryScrollView.trailingAnchor.constraint(equalTo: overallSummaryContainer.trailingAnchor, constant: -12),
            overallSummaryScrollView.topAnchor.constraint(equalTo: overallSummaryContainer.topAnchor, constant: 10),
            overallSummaryScrollView.bottomAnchor.constraint(equalTo: overallSummaryContainer.bottomAnchor, constant: -10),

            overallSummaryLabel.leadingAnchor.constraint(equalTo: overallSummaryScrollView.contentLayoutGuide.leadingAnchor),
            overallSummaryLabel.trailingAnchor.constraint(equalTo: overallSummaryScrollView.contentLayoutGuide.trailingAnchor),
            overallSummaryLabel.topAnchor.constraint(equalTo: overallSummaryScrollView.contentLayoutGuide.topAnchor),
            overallSummaryLabel.bottomAnchor.constraint(equalTo: overallSummaryScrollView.contentLayoutGuide.bottomAnchor),
            overallSummaryLabel.widthAnchor.constraint(equalTo: overallSummaryScrollView.frameLayoutGuide.widthAnchor),

            tableView.heightAnchor.constraint(greaterThanOrEqualToConstant: 320)
        ])

        cardView.bringSubviewToFront(buttonContainer)
        if displayMode == .search {
            titleLabel.text = "Search"
            searchHeaderLabel.text = "Search Hills"
            summarySection.isHidden = true
            shareButton.isHidden = true
            overallSummaryContainer.isHidden = true
            searchTextField.becomeFirstResponder()
        }
        updateSubtitle()
    }

    deinit {
        keyboardObservers.forEach(NotificationCenter.default.removeObserver)
    }

    @objc private func dismissRecords() {
        dismiss(animated: true)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func observeKeyboardChanges() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            UIResponder.keyboardWillChangeFrameNotification,
            UIResponder.keyboardWillHideNotification,
        ]

        keyboardObservers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                self?.handleKeyboardNotification(notification)
            }
        }
    }

    private func handleKeyboardNotification(_ notification: Notification) {
        let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        let curveRawValue = (notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt) ?? 7
        let options = UIView.AnimationOptions(rawValue: curveRawValue << 16)

        let targetTransform: CGAffineTransform
        if let endFrameValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            let endFrameInView = view.convert(endFrameValue.cgRectValue, from: nil)
            let intersection = cardView.frame.intersection(endFrameInView)
            let overlap = max(0, intersection.height)
            let upwardShift = min(max(0, overlap + 12), 160)
            targetTransform = upwardShift > 0 ? CGAffineTransform(translationX: 0, y: -upwardShift) : .identity
        } else {
            targetTransform = .identity
        }

        UIView.animate(withDuration: duration, delay: 0, options: [options, .beginFromCurrentState]) {
            self.cardView.transform = targetTransform
        }
    }

    @objc private func summarySchemaChanged(_ sender: UISegmentedControl) {
        guard let schema = MenuFilterSchema(rawValue: sender.selectedSegmentIndex) else { return }
        selectedSummarySchema = schema
        updateSubtitle()
        tableView.reloadData()
    }

    @objc private func searchQueryChanged(_ sender: UISearchTextField) {
        searchQuery = sender.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        tableView.reloadData()
    }

    @objc private func shareRecords(_ sender: UIButton) {
        let overlay = ActionOverlayViewController(
            title: "Share Logged Data",
            actions: [
                .init(title: "Summary PDF", style: .normal) { [weak self] in
                    self?.shareSummaryPDF(from: sender)
                },
                .init(title: "Full Database PDF", style: .normal) { [weak self] in
                    self?.shareFullDatabasePDF(from: sender)
                },
                .init(title: "Full Database CSV", style: .normal) { [weak self] in
                    self?.shareFullDatabaseCSV(from: sender)
                },
                .init(title: "Cancel", style: .cancel, handler: {})
            ]
        )
        present(overlay, animated: true)
    }

    private func shareSummaryPDF(from sender: UIButton) {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "\(AppBranding.fileSafeName)-Logged.pdf"
        )
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: UIColor.label
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor.label
        ]
        let monospacedBodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor.label
        ]
        let groupAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: UIColor.label
        ]
        let lines = exportLines()

        let data = renderer.pdfData { context in
            var y: CGFloat = 24
            let leftMargin: CGFloat = 24
            let pageWidth: CGFloat = 595
            let pageHeight: CGFloat = 842

            func beginPage() {
                context.beginPage()
                y = 24

                if let logoImage = overlayLogoImage() {
                    let logoRect = CGRect(x: leftMargin, y: y, width: 24, height: 24)
                    UIBezierPath(roundedRect: logoRect, cornerRadius: 5).addClip()
                    logoImage.draw(in: logoRect)
                    context.cgContext.resetClip()
                }

                (AppBranding.loggedPeaksTitle as NSString).draw(
                    in: CGRect(x: leftMargin + 36, y: y, width: pageWidth - 84, height: 22),
                    withAttributes: titleAttributes
                )
                y += 28
                ("View: Search Hills" as NSString).draw(
                    in: CGRect(x: leftMargin + 36, y: y, width: pageWidth - 84, height: 18),
                    withAttributes: bodyAttributes
                )
                y += 28
            }

            beginPage()

            for line in lines {
                let attributes: [NSAttributedString.Key: Any]
                if line.hasPrefix("## ") {
                    attributes = groupAttributes
                } else if isSummaryExportLine(line) {
                    attributes = monospacedBodyAttributes
                } else {
                    attributes = bodyAttributes
                }
                let renderedLine = line.hasPrefix("## ") ? String(line.dropFirst(3)) : line
                let rect = (renderedLine as NSString).boundingRect(
                    with: CGSize(width: pageWidth - (leftMargin * 2), height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                )

                if y + rect.height + 20 > pageHeight {
                    beginPage()
                }

                (renderedLine as NSString).draw(
                    in: CGRect(x: leftMargin, y: y, width: pageWidth - (leftMargin * 2), height: rect.height),
                    withAttributes: attributes
                )
                y += ceil(rect.height) + 8
            }
        }

        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            presentShareErrorAlert(message: "Could not prepare the PDF for sharing.")
            return
        }

        presentShareSheet(for: fileURL, from: sender)
    }

    private func shareFullDatabaseCSV(from sender: UIButton) {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "\(AppBranding.fileSafeName)-Database.csv"
        )

        let header = fullDatabaseExportHeader()

        let rows = fullDatabaseExportRows()

        let csvText = ([header] + rows)
            .map { row in row.map(csvEscapedField).joined(separator: ",") }
            .joined(separator: "\n")

        do {
            try csvText.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            presentShareErrorAlert(message: "Could not prepare the CSV for sharing.")
            return
        }

        presentShareSheet(for: fileURL, from: sender)
    }

    private func shareFullDatabasePDF(from sender: UIButton) {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "\(AppBranding.fileSafeName)-Database.pdf"
        )
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: UIColor.label
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 8, weight: .regular),
            .foregroundColor: UIColor.label
        ]
        let groupAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 8, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        let header = fullDatabaseExportHeader()
        let rows = fullDatabaseExportRows()
        let lines = ["## Full Database", "Count: \(rows.count)", "", header.joined(separator: " | ")] + rows.map { $0.joined(separator: " | ") }

        let data = renderer.pdfData { context in
            var y: CGFloat = 24
            let leftMargin: CGFloat = 24
            let pageWidth: CGFloat = 595
            let pageHeight: CGFloat = 842

            func beginPage() {
                context.beginPage()
                y = 24

                if let logoImage = overlayLogoImage() {
                    let logoRect = CGRect(x: leftMargin, y: y, width: 24, height: 24)
                    UIBezierPath(roundedRect: logoRect, cornerRadius: 5).addClip()
                    logoImage.draw(in: logoRect)
                    context.cgContext.resetClip()
                }

                (AppBranding.fullDatabaseTitle as NSString).draw(
                    in: CGRect(x: leftMargin + 36, y: y, width: pageWidth - 84, height: 22),
                    withAttributes: titleAttributes
                )
                y += 34
            }

            beginPage()

            for (index, line) in lines.enumerated() {
                let attributes = (line.hasPrefix("## ") || index == 3) ? groupAttributes : bodyAttributes
                let renderedLine = line.hasPrefix("## ") ? String(line.dropFirst(3)) : line
                let rect = (renderedLine as NSString).boundingRect(
                    with: CGSize(width: pageWidth - (leftMargin * 2), height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                )

                if y + rect.height + 12 > pageHeight {
                    beginPage()
                }

                (renderedLine as NSString).draw(
                    in: CGRect(x: leftMargin, y: y, width: pageWidth - (leftMargin * 2), height: rect.height),
                    withAttributes: attributes
                )
                y += ceil(rect.height) + 3
            }
        }

        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            presentShareErrorAlert(message: "Could not prepare the PDF for sharing.")
            return
        }

        presentShareSheet(for: fileURL, from: sender)
    }

    private func fullDatabaseExportHeader() -> [String] {
        [
            "Name",
            "Alternate Name",
            "Range",
            "County",
            "Province",
            "Height (m)",
            "Prominence (m)",
            "Grid Ref",
            "Classes",
            "Logged"
        ]
    }

    private func fullDatabaseExportRows() -> [[String]] {
        peaks
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            .map { peak -> [String] in
                let codes = orderedClassificationCodes(from: Set(classificationCodes(for: peak)))
                let names = codes.compactMap(displayNameForClassificationCode)
                return [
                    peak.name,
                    peak.alternateHillName,
                    peak.rangeName,
                    peak.administrativeArea,
                    peak.regionGroup,
                    String(format: "%.1f", peak.heightM),
                    String(format: "%.1f", peak.prominenceM),
                    peak.formattedRegionGridReference ?? "",
                    names.joined(separator: " | "),
                    loggedPeakIDs.contains(peak.id) ? "Yes" : "No"
                ]
            }
    }

    private func presentShareSheet(for fileURL: URL, from sender: UIButton) {
        let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        if let popoverPresentationController = activityViewController.popoverPresentationController {
            let sourceView: UIView = sender.window == nil ? view : sender
            popoverPresentationController.sourceView = sourceView
            popoverPresentationController.sourceRect = sourceView.bounds
        }
        present(activityViewController, animated: true)
    }

    private func csvEscapedField(_ value: String) -> String {
        let escapedValue = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escapedValue.contains(",") || escapedValue.contains("\"") || escapedValue.contains("\n") {
            return "\"\(escapedValue)\""
        }
        return escapedValue
    }

    private func presentShareErrorAlert(message: String) {
        let overlay = ActionOverlayViewController(
            title: "Share Unavailable",
            message: message,
            actions: [
                .init(title: "OK", style: .normal, handler: {})
            ]
        )
        present(overlay, animated: true)
    }

    private func exportLines() -> [String] {
        let summaryLines = ["## Summary"] + overallSummaryLines() + [""]
        let loggedHillLines = peaks
            .filter { loggedPeakIDs.contains($0.id) }
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            .map { peak -> String in
                let altName = peak.alternateHillName.trimmingCharacters(in: .whitespacesAndNewlines)
                let altFragment = altName.isEmpty ? "" : " (\(altName))"
                let region = peak.rangeName.trimmingCharacters(in: .whitespacesAndNewlines)
                let regionFragment = region.isEmpty ? "" : " • \(region)"
                return "  ✓ \(peak.name)\(altFragment) • \(Int(peak.heightM.rounded())) m\(regionFragment)"
            }

        return summaryLines + ["## Logged Hills"] + loggedHillLines
    }

    private func isSummaryExportLine(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLine.isEmpty else { return false }
        return trimmedLine.hasPrefix("List")
            || trimmedLine.hasPrefix("─")
            || currentSummaryTitles().contains { trimmedLine.hasPrefix($0) }
    }

    private func updateSubtitle() {
        subtitleLabel.text = displayMode == .search
            ? "Search hills, start points, and Ireland places by name, region, status, parking, or grid reference. Tap a hill to log it, or a place to open it on the map."
            : "Search Hills. Tap a hill to log it or unlog it."
        overallSummaryLabel.attributedText = overallSummaryAttributedText()
    }

    private func overallSummaryAttributedText() -> NSAttributedString {
        let lines = overallSummaryLines()
        let summaryText = NSMutableAttributedString(
            string: lines.joined(separator: "\n"),
            attributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
        )
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 3
        summaryText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: summaryText.length))
        let firstLineLength = lines.first?.count ?? 0
        summaryText.addAttributes(
            [.font: UIFont.monospacedSystemFont(ofSize: 12, weight: .bold)],
            range: NSRange(location: 0, length: min(firstLineLength, summaryText.length))
        )
        return summaryText
    }

    private func overallSummaryHeaderLine() -> String {
        formattedSummaryLine(list: "List", logged: "Logged", total: "Total", percentage: "%")
    }

    private func overallSummarySeparatorLine() -> String {
        String(repeating: "─", count: 33)
    }

    private func overallSummaryLines() -> [String] {
        switch selectedSummarySchema {
        case .height:
            return [overallSummaryHeaderLine(), overallSummarySeparatorLine()]
                + currentSummaryDefinitions().map { definition in
                    overallSummaryLine(title: definition.title, peaks: peaks.filter(definition.includes))
                }
        case .classification:
            return classificationSummaryLines()
        }
    }

    private func overallSummaryLine(title: String, peaks matchingPeaks: [Peak]) -> String {
        let loggedCount = matchingPeaks.reduce(into: 0) { count, peak in
            if loggedPeakIDs.contains(peak.id) {
                count += 1
            }
        }
        let totalCount = matchingPeaks.count
        let percentage = totalCount > 0 ? Int((Double(loggedCount) / Double(totalCount) * 100).rounded()) : 0
        return formattedSummaryLine(
            list: title,
            logged: String(loggedCount),
            total: String(totalCount),
            percentage: "\(percentage)%"
        )
    }

    private func formattedSummaryLine(list: String, logged: String, total: String, percentage: String) -> String {
        let listColumn = list.padding(toLength: 16, withPad: " ", startingAt: 0)
        let loggedColumn = leftPadded(logged, width: 6)
        let totalColumn = leftPadded(total, width: 6)
        let percentageColumn = leftPadded(percentage, width: 5)
        return "\(listColumn)\(loggedColumn)\(totalColumn)\(percentageColumn)"
    }

    private func leftPadded(_ string: String, width: Int) -> String {
        if string.count >= width {
            return string
        }
        return String(repeating: " ", count: width - string.count) + string
    }

    private func displayedSearchResults() -> [SearchResultItem] {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            switch displayMode {
            case .records:
                return peaks
                    .sorted { lhs, rhs in
                        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                    }
                    .map(SearchResultItem.hill)
            case .search:
                return interleaveResults(
                    Array(peaks.prefix(10)).map(SearchResultItem.hill),
                    Array(startPlaces.prefix(10)).map(SearchResultItem.startPlace)
                )
            }
        }

        let lowercasedQuery = trimmedQuery.localizedLowercase

        let hillResults = peaks.filter { peak in
            [peak.name, peak.alternateHillName, peak.rangeName, peak.administrativeArea, peak.regionGroup, peak.classification]
                .contains { field in
                    field.localizedLowercase.contains(lowercasedQuery)
                }
        }
        .sorted { lhs, rhs in
            let lhsNameMatch = lhs.name.localizedLowercase.contains(lowercasedQuery)
            let rhsNameMatch = rhs.name.localizedLowercase.contains(lowercasedQuery)
            if lhsNameMatch != rhsNameMatch {
                return lhsNameMatch && !rhsNameMatch
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        .map(SearchResultItem.hill)

        switch displayMode {
        case .records:
            return hillResults
        case .search:
            let startPlaceResults = startPlaces.filter { startPlace in
                [
                    startPlace.shortDisplayName,
                    startPlace.fullDisplayName,
                    startPlace.provider.title,
                    startPlace.gridReference,
                    startPlace.status,
                    startPlace.parking,
                    startPlace.nearbyHills
                ].contains { field in
                    field.localizedLowercase.contains(lowercasedQuery)
                }
            }
            .sorted { lhs, rhs in
                let lhsNameMatch = lhs.shortDisplayName.localizedLowercase.contains(lowercasedQuery)
                let rhsNameMatch = rhs.shortDisplayName.localizedLowercase.contains(lowercasedQuery)
                if lhsNameMatch != rhsNameMatch {
                    return lhsNameMatch && !rhsNameMatch
                }
                return lhs.shortDisplayName.localizedCaseInsensitiveCompare(rhs.shortDisplayName) == .orderedAscending
            }
            .map(SearchResultItem.startPlace)
            return interleaveResults(hillResults, startPlaceResults)
        }
    }

    private func interleaveResults(_ groups: [SearchResultItem]...) -> [SearchResultItem] {
        let maxCount = groups.map(\.count).max() ?? 0
        var combined: [SearchResultItem] = []
        combined.reserveCapacity(groups.reduce(0) { $0 + $1.count })

        for index in 0..<maxCount {
            for group in groups where group.indices.contains(index) {
                combined.append(group[index])
            }
        }

        return combined
    }

    private func heightBandDefinitions() -> [(title: String, includes: (Peak) -> Bool)] {
        [
            ("600m+", { $0.heightM >= 600 }),
            ("500-600m", { $0.heightM >= 500 && $0.heightM < 600 }),
            ("400-500m", { $0.heightM >= 400 && $0.heightM < 500 }),
            ("300-400m", { $0.heightM >= 300 && $0.heightM < 400 }),
            ("200-300m", { $0.heightM >= 200 && $0.heightM < 300 }),
            ("100-200m", { $0.heightM >= 100 && $0.heightM < 200 }),
            ("0-100m", { $0.heightM < 100 })
        ]
    }

    private func classificationDefinitions() -> [(title: String, includes: (Peak) -> Bool)] {
        allClassificationCodes().map { code in
            (
                title: displayNameForClassificationCode(code) ?? code,
                includes: { peak in classificationCodes(for: peak).contains(code) }
            )
        }
    }

    private func classificationSummaryLines() -> [String] {
        let availableCodes = Set(allClassificationCodes())
        var lines = [overallSummaryHeaderLine(), overallSummarySeparatorLine()]

        for section in classificationSections(for: availableCodes) {
            if lines.count > 2 {
                lines.append("")
            }
            lines.append(section.title)
            lines.append(overallSummarySeparatorLine())
            for code in section.codes {
                let matchingPeaks = peaks.filter { classificationCodes(for: $0).contains(code) }
                lines.append(overallSummaryLine(title: displayNameForClassificationCode(code) ?? code, peaks: matchingPeaks))
            }
        }

        return lines
    }

    private func currentSummaryDefinitions() -> [(title: String, includes: (Peak) -> Bool)] {
        switch selectedSummarySchema {
        case .height:
            return heightBandDefinitions()
        case .classification:
            return classificationDefinitions()
        }
    }

    private func currentSummaryTitles() -> [String] {
        currentSummaryDefinitions().map(\.title)
    }

    private func allClassificationCodes() -> [String] {
        let seenCodes = Set(
            peaks.flatMap { peak in
                classificationCodes(for: peak).filter { displayNameForClassificationCode($0) != nil }
            }
        )
        return orderedClassificationCodes(from: seenCodes.union(alwaysVisibleClassificationCodes()))
    }

    private func styleSchemaControl(_ control: UISegmentedControl) {
        control.selectedSegmentTintColor = .systemBlue
        control.backgroundColor = UIColor.secondarySystemBackground
        control.setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.label
        ], for: .normal)
        control.setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.white
        ], for: .selected)
    }
}

extension RecordsOverlayViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        displayedSearchResults().count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let result = displayedSearchResults()[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "RecordsCell", for: indexPath)
        var content = cell.defaultContentConfiguration()

        content.attributedText = attributedTitle(for: result)
        content.secondaryText = result.subtitle
        content.secondaryTextProperties.numberOfLines = 2
        content.textProperties.numberOfLines = 1

        switch result {
        case .hill(let peak):
            cell.accessoryView = UIImageView(
                image: UIImage(systemName: loggedPeakIDs.contains(peak.id) ? "checkmark.circle.fill" : "circle")
            )
            (cell.accessoryView as? UIImageView)?.tintColor = loggedPeakIDs.contains(peak.id) ? .systemBlue : .systemGray3
            cell.accessoryType = .none
        case .startPlace:
            cell.accessoryView = nil
            cell.accessoryType = .disclosureIndicator
        }
        cell.backgroundColor = .systemBackground
        cell.selectionStyle = .default

        cell.contentConfiguration = content
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        let result = displayedSearchResults()[indexPath.row]
        switch result {
        case .hill(let peak):
            toggleLoggedStateHandler(peak) { [weak self, weak tableView] didChange in
                guard let self, didChange else { return }
                if self.loggedPeakIDs.contains(peak.id) {
                    self.loggedPeakIDs.remove(peak.id)
                } else {
                    self.loggedPeakIDs.insert(peak.id)
                }
                self.updateSubtitle()
                tableView?.reloadData()
            }
        case .startPlace(let startPlace):
            dismiss(animated: true) { [weak self] in
                self?.openStartPlaceHandler(startPlace)
            }
        }
    }
}

extension RecordsOverlayViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

private extension RecordsOverlayViewController {
    enum SearchResultItem {
        case hill(Peak)
        case startPlace(StartPlace)

        var displayTitle: String {
            switch self {
            case .hill(let peak):
                return peak.name
            case .startPlace(let startPlace):
                return startPlace.shortDisplayName
            }
        }

        var title: String {
            switch self {
            case .hill(let peak):
                return "\(peak.name) • \(Int(peak.heightM.rounded())) m"
            case .startPlace(let startPlace):
                return startPlace.shortDisplayName
            }
        }

        var subtitle: String {
            switch self {
            case .hill(let peak):
                let alternateName = peak.alternateHillName.trimmingCharacters(in: .whitespacesAndNewlines)
                let region = peak.rangeName.trimmingCharacters(in: .whitespacesAndNewlines)
                var parts: [String] = []
                if !alternateName.isEmpty {
                    parts.insert(alternateName, at: 0)
                }
                if !region.isEmpty {
                    parts.append(region)
                }
                return parts.joined(separator: " • ")
            case .startPlace(let startPlace):
                var parts: [String] = [startPlace.provider.title]
                let gridReference = startPlace.gridReference.trimmingCharacters(in: .whitespacesAndNewlines)
                if !gridReference.isEmpty {
                    parts.append(gridReference)
                }
                let status = startPlace.status.trimmingCharacters(in: .whitespacesAndNewlines)
                if !status.isEmpty {
                    parts.append(status)
                }
                let parking = startPlace.parking.trimmingCharacters(in: .whitespacesAndNewlines)
                if !parking.isEmpty {
                    parts.append(parking)
                }
                return parts.joined(separator: " • ")
            }
        }

        var badgeText: String {
            switch self {
            case .hill:
                return "H"
            case .startPlace:
                return "SP"
            }
        }

        var badgeColor: UIColor {
            switch self {
            case .hill:
                return .systemRed
            case .startPlace:
                return .systemBlue
            }
        }
    }

    func attributedTitle(for result: SearchResultItem) -> NSAttributedString {
        if displayMode == .records, case .hill = result {
            return NSAttributedString(
                string: result.title,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                    .foregroundColor: UIColor.label
                ]
            )
        }

        let attributedTitle = NSMutableAttributedString(
            string: "\(result.badgeText) ",
            attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .bold),
                .foregroundColor: result.badgeColor
            ]
        )
        attributedTitle.append(
            NSAttributedString(
                string: result.title,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                    .foregroundColor: UIColor.label
                ]
            )
        )
        return attributedTitle
    }

}
