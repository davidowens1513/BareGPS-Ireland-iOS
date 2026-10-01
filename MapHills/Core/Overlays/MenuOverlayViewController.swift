//
//  PrimaryOverlays.swift
//  MapHills
//
//  Created by David Owens on 26/03/2026.
//

import UIKit

struct MenuOption {
    let id: String
    let title: String
    let countText: String?
    var isSelected: Bool
    var isSectionHeader: Bool = false
    var isEnabled: Bool = true

    static func sectionHeader(_ title: String) -> MenuOption {
        MenuOption(id: "__section__\(title)", title: title, countText: nil, isSelected: false, isSectionHeader: true, isEnabled: false)
    }
}

struct MarkerColorOption {
    let id: String
    let title: String
    var color: UIColor
}

enum MenuFilterSchema: Int, CaseIterable {
    case classification
    case height

    var title: String {
        switch self {
        case .classification:
            return "Classification"
        case .height:
            return "Height"
        }
    }

    var headerTitle: String {
        "Filter"
    }

    func descriptionText(visibleHillCount: Int) -> String {
        _ = visibleHillCount
        return """
        Your filter choices are remembered. Turn on one or more classifications to filter the map.
        Hills currently visible on map: \(visibleHillCount)
        """
    }
}

final class MenuOverlayViewController: UIViewController {
    private var selectedSchema: MenuFilterSchema
    private var optionsBySchema: [MenuFilterSchema: [MenuOption]]
    private var visibleHillCount: Int
    private let visibleHillCountProvider: () -> Int
    private var selectedMarkerColorSchema: MenuFilterSchema
    private var markerColorOptionsBySchema: [MenuFilterSchema: [MarkerColorOption]]
    private let toggleHandler: (MenuFilterSchema, String, Bool) -> Void
    private let schemaChangeHandler: (MenuFilterSchema) -> Void
    private let markerColorChangeHandler: (String, UIColor) -> Void
    private let markerColorSchemaChangeHandler: (MenuFilterSchema) -> Void
    private let filteredPeaksProvider: () -> [Peak]
    private let isPeakLoggedProvider: (Peak) -> Bool
    private let classificationCodesProvider: (Peak) -> [String]
    private let classificationDisplayNameProvider: (String) -> String
    private let currentFilterDescriptionProvider: () -> String

    private let dimmingView = UIView()
    private let cardView = UIView()
    private let contentScrollView = UIScrollView()
    private let schemaControl = UISegmentedControl(items: MenuFilterSchema.allCases.map(\.title))
    private let filterHeaderLabel = UILabel()
    private let filterDescriptionLabel = UILabel()
    private let markerColorsDescriptionLabel = UILabel()
    private let optionsScrollView = UIScrollView()
    private let optionsContainerView = UIView()
    private let stackView = UIStackView()
    private let markerColorsStackView = UIStackView()

    init(
        selectedSchema: MenuFilterSchema,
        optionsBySchema: [MenuFilterSchema: [MenuOption]],
        visibleHillCount: Int,
        visibleHillCountProvider: @escaping () -> Int,
        selectedMarkerColorSchema: MenuFilterSchema,
        markerColorOptionsBySchema: [MenuFilterSchema: [MarkerColorOption]],
        toggleHandler: @escaping (MenuFilterSchema, String, Bool) -> Void,
        schemaChangeHandler: @escaping (MenuFilterSchema) -> Void,
        markerColorChangeHandler: @escaping (String, UIColor) -> Void,
        markerColorSchemaChangeHandler: @escaping (MenuFilterSchema) -> Void,
        filteredPeaksProvider: @escaping () -> [Peak],
        isPeakLoggedProvider: @escaping (Peak) -> Bool,
        classificationCodesProvider: @escaping (Peak) -> [String],
        classificationDisplayNameProvider: @escaping (String) -> String,
        currentFilterDescriptionProvider: @escaping () -> String
    ) {
        self.selectedSchema = selectedSchema
        self.optionsBySchema = optionsBySchema
        self.visibleHillCount = visibleHillCount
        self.visibleHillCountProvider = visibleHillCountProvider
        self.selectedMarkerColorSchema = selectedMarkerColorSchema
        self.markerColorOptionsBySchema = markerColorOptionsBySchema
        self.toggleHandler = toggleHandler
        self.schemaChangeHandler = schemaChangeHandler
        self.markerColorChangeHandler = markerColorChangeHandler
        self.markerColorSchemaChangeHandler = markerColorSchemaChangeHandler
        self.filteredPeaksProvider = filteredPeaksProvider
        self.isPeakLoggedProvider = isPeakLoggedProvider
        self.classificationCodesProvider = classificationCodesProvider
        self.classificationDisplayNameProvider = classificationDisplayNameProvider
        self.currentFilterDescriptionProvider = currentFilterDescriptionProvider
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

        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(OverlayChromeStyle.dimmingAlpha)
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissMenu)))
        view.addSubview(dimmingView)

        configureOverlayCardChrome(cardView)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.alwaysBounceVertical = true
        cardView.addSubview(contentScrollView)

        let titleLabel = makeOverlayTitleLabel("Hill Filters")
        let titleRow = makeOverlayTitleRow(with: titleLabel)

        filterHeaderLabel.text = selectedSchema.headerTitle
        filterHeaderLabel.font = OverlayChromeStyle.sectionTitleFont
        filterHeaderLabel.textColor = .label

        filterDescriptionLabel.text = selectedSchema.descriptionText(visibleHillCount: visibleHillCount)
        filterDescriptionLabel.font = OverlayChromeStyle.bodyFont
        filterDescriptionLabel.textColor = .secondaryLabel
        filterDescriptionLabel.numberOfLines = 0

        styleSchemaControl(schemaControl)
        schemaControl.translatesAutoresizingMaskIntoConstraints = false
        schemaControl.selectedSegmentIndex = selectedSchema.rawValue
        schemaControl.addTarget(self, action: #selector(schemaChanged(_:)), for: .valueChanged)

        optionsScrollView.translatesAutoresizingMaskIntoConstraints = false
        optionsScrollView.alwaysBounceVertical = true

        optionsContainerView.translatesAutoresizingMaskIntoConstraints = false
        optionsScrollView.addSubview(optionsContainerView)

        let markerColorsHeaderLabel = UILabel()
        markerColorsHeaderLabel.text = "Marker Colours"
        markerColorsHeaderLabel.font = OverlayChromeStyle.sectionTitleFont
        markerColorsHeaderLabel.textColor = .label

        markerColorsDescriptionLabel.text = markerColorDescriptionText(for: selectedMarkerColorSchema)
        markerColorsDescriptionLabel.font = OverlayChromeStyle.bodyFont
        markerColorsDescriptionLabel.textColor = .secondaryLabel
        markerColorsDescriptionLabel.numberOfLines = 0

        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        optionsContainerView.addSubview(stackView)

        markerColorsStackView.axis = .vertical
        markerColorsStackView.spacing = 10
        markerColorsStackView.translatesAutoresizingMaskIntoConstraints = false

        let filterStack = UIStackView(arrangedSubviews: [
            filterHeaderLabel,
            schemaControl,
            optionsScrollView,
            filterDescriptionLabel
        ])
        filterStack.axis = .vertical
        filterStack.spacing = 6
        filterStack.translatesAutoresizingMaskIntoConstraints = false

        let schemeSpecificMarkerColorsStack = UIStackView(
            arrangedSubviews: [
                markerColorsStackView,
                markerColorsDescriptionLabel
            ]
        )
        schemeSpecificMarkerColorsStack.axis = .vertical
        schemeSpecificMarkerColorsStack.spacing = 8
        schemeSpecificMarkerColorsStack.translatesAutoresizingMaskIntoConstraints = false

        let markerColorsContainerStack = UIStackView(
            arrangedSubviews: [
                markerColorsHeaderLabel,
                schemeSpecificMarkerColorsStack
            ]
        )
        markerColorsContainerStack.axis = .vertical
        markerColorsContainerStack.spacing = 10
        markerColorsContainerStack.translatesAutoresizingMaskIntoConstraints = false

        let filterContainerView = UIView()
        filterContainerView.backgroundColor = UIColor.secondarySystemBackground
        filterContainerView.layer.cornerRadius = OverlayChromeStyle.sectionCornerRadius
        filterContainerView.layer.borderWidth = 1
        filterContainerView.layer.borderColor = UIColor.separator.cgColor
        filterContainerView.translatesAutoresizingMaskIntoConstraints = false
        filterContainerView.addSubview(filterStack)

        let markerColorsContainerView = UIView()
        markerColorsContainerView.backgroundColor = UIColor.secondarySystemBackground
        markerColorsContainerView.layer.cornerRadius = OverlayChromeStyle.sectionCornerRadius
        markerColorsContainerView.layer.borderWidth = 1
        markerColorsContainerView.layer.borderColor = UIColor.separator.cgColor
        markerColorsContainerView.translatesAutoresizingMaskIntoConstraints = false
        markerColorsContainerView.addSubview(markerColorsContainerStack)

        let closeButton = UIButton(type: .system)
        closeButton.configuration = makeOverlayPlainButtonConfiguration(title: "Done")
        closeButton.addTarget(self, action: #selector(dismissMenu), for: .touchUpInside)

        let shareFilteredHeaderLabel = UILabel()
        shareFilteredHeaderLabel.text = "Share Current Filtered List"
        shareFilteredHeaderLabel.font = OverlayChromeStyle.sectionTitleFont
        shareFilteredHeaderLabel.textColor = .label

        let shareFilteredDescriptionLabel = UILabel()
        shareFilteredDescriptionLabel.tag = 9101
        shareFilteredDescriptionLabel.font = OverlayChromeStyle.bodyFont
        shareFilteredDescriptionLabel.textColor = .secondaryLabel
        shareFilteredDescriptionLabel.numberOfLines = 0
        shareFilteredDescriptionLabel.text = shareFilteredDescriptionText()

        let shareFilteredButton = UIButton(type: .system)
        shareFilteredButton.configuration = makeOverlayButtonConfiguration(
            title: "Save/Share...",
            foregroundColor: .systemBlue,
            backgroundColor: .secondarySystemBackground
        )
        shareFilteredButton.contentHorizontalAlignment = .leading
        shareFilteredButton.addTarget(self, action: #selector(shareFilteredPeaks(_:)), for: .touchUpInside)

        let shareFilteredContainerStack = UIStackView(
            arrangedSubviews: [shareFilteredHeaderLabel, shareFilteredDescriptionLabel, shareFilteredButton]
        )
        shareFilteredContainerStack.axis = .vertical
        shareFilteredContainerStack.spacing = 8
        shareFilteredContainerStack.translatesAutoresizingMaskIntoConstraints = false

        let shareFilteredContainerView = UIView()
        shareFilteredContainerView.backgroundColor = UIColor.secondarySystemBackground
        shareFilteredContainerView.layer.cornerRadius = 12
        shareFilteredContainerView.layer.borderWidth = 1
        shareFilteredContainerView.layer.borderColor = UIColor.separator.cgColor
        shareFilteredContainerView.translatesAutoresizingMaskIntoConstraints = false
        shareFilteredContainerView.addSubview(shareFilteredContainerStack)

        let contentStack = UIStackView(
            arrangedSubviews: [
                titleRow,
                filterContainerView,
                shareFilteredContainerView
            ]
        )
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.addSubview(contentStack)

        let footerContainerView = UIView()
        footerContainerView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(footerContainerView)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        footerContainerView.addSubview(closeButton)

        let safeArea = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            cardView.centerXAnchor.constraint(equalTo: safeArea.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: safeArea.centerYAnchor),
            cardView.leadingAnchor.constraint(greaterThanOrEqualTo: safeArea.leadingAnchor, constant: 24),
            cardView.trailingAnchor.constraint(lessThanOrEqualTo: safeArea.trailingAnchor, constant: -24),
            cardView.topAnchor.constraint(greaterThanOrEqualTo: safeArea.topAnchor, constant: 24),
            cardView.bottomAnchor.constraint(lessThanOrEqualTo: safeArea.bottomAnchor, constant: -24),
            cardView.widthAnchor.constraint(equalToConstant: 320),
            cardView.heightAnchor.constraint(equalTo: safeArea.heightAnchor, multiplier: 0.82),

            contentScrollView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            contentScrollView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            contentScrollView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            contentScrollView.bottomAnchor.constraint(equalTo: footerContainerView.topAnchor, constant: -12),

            footerContainerView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            footerContainerView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            footerContainerView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),
            footerContainerView.heightAnchor.constraint(equalToConstant: 32),

            closeButton.centerXAnchor.constraint(equalTo: footerContainerView.centerXAnchor),
            closeButton.centerYAnchor.constraint(equalTo: footerContainerView.centerYAnchor),

            contentStack.leadingAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: contentScrollView.frameLayoutGuide.widthAnchor),

            filterStack.leadingAnchor.constraint(equalTo: filterContainerView.leadingAnchor, constant: 14),
            filterStack.trailingAnchor.constraint(equalTo: filterContainerView.trailingAnchor, constant: -14),
            filterStack.topAnchor.constraint(equalTo: filterContainerView.topAnchor, constant: 14),
            filterStack.bottomAnchor.constraint(equalTo: filterContainerView.bottomAnchor, constant: -14),

            shareFilteredContainerStack.leadingAnchor.constraint(equalTo: shareFilteredContainerView.leadingAnchor, constant: 14),
            shareFilteredContainerStack.trailingAnchor.constraint(equalTo: shareFilteredContainerView.trailingAnchor, constant: -14),
            shareFilteredContainerStack.topAnchor.constraint(equalTo: shareFilteredContainerView.topAnchor, constant: 14),
            shareFilteredContainerStack.bottomAnchor.constraint(equalTo: shareFilteredContainerView.bottomAnchor, constant: -14),

            optionsScrollView.heightAnchor.constraint(equalToConstant: 248),

            optionsContainerView.leadingAnchor.constraint(equalTo: optionsScrollView.contentLayoutGuide.leadingAnchor),
            optionsContainerView.trailingAnchor.constraint(equalTo: optionsScrollView.contentLayoutGuide.trailingAnchor),
            optionsContainerView.topAnchor.constraint(equalTo: optionsScrollView.contentLayoutGuide.topAnchor),
            optionsContainerView.bottomAnchor.constraint(equalTo: optionsScrollView.contentLayoutGuide.bottomAnchor),
            optionsContainerView.widthAnchor.constraint(equalTo: optionsScrollView.frameLayoutGuide.widthAnchor),

            stackView.leadingAnchor.constraint(equalTo: optionsContainerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: optionsContainerView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: optionsContainerView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: optionsContainerView.bottomAnchor),

            markerColorsContainerStack.leadingAnchor.constraint(equalTo: markerColorsContainerView.leadingAnchor, constant: 14),
            markerColorsContainerStack.trailingAnchor.constraint(equalTo: markerColorsContainerView.trailingAnchor, constant: -14),
            markerColorsContainerStack.topAnchor.constraint(equalTo: markerColorsContainerView.topAnchor, constant: 14),
            markerColorsContainerStack.bottomAnchor.constraint(equalTo: markerColorsContainerView.bottomAnchor, constant: -14)
        ])

        rebuildOptionButtons()
    }

    private func rebuildOptionButtons() {
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let options = optionsBySchema[selectedSchema] ?? []
        let isClassificationSchema = selectedSchema == .classification
        stackView.spacing = isClassificationSchema ? 6 : 8

        for (index, option) in options.enumerated() {
            if option.isSectionHeader {
                let label = UILabel()
                label.text = option.title
                label.font = .systemFont(ofSize: isClassificationSchema ? 11 : 12, weight: .bold)
                label.textColor = .secondaryLabel
                label.textAlignment = .left
                label.numberOfLines = 1
                if !stackView.arrangedSubviews.isEmpty {
                    label.setContentHuggingPriority(.required, for: .vertical)
                }
                stackView.addArrangedSubview(label)
            } else {
                let button = UIButton(type: .system)
                button.tag = index
                button.contentHorizontalAlignment = .leading
                button.tintColor = option.isEnabled ? .systemBlue : .tertiaryLabel
                button.isEnabled = option.isEnabled
                button.titleLabel?.font = .systemFont(ofSize: isClassificationSchema ? 14 : 15, weight: .medium)
                button.configuration = checkboxConfiguration(for: option)
                button.addTarget(self, action: #selector(toggleOption(_:)), for: .touchUpInside)
                stackView.addArrangedSubview(button)
            }
        }
    }

    private func rebuildMarkerColorPickers() {
        markerColorsStackView.arrangedSubviews.forEach { view in
            markerColorsStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let markerColorOptions = markerColorOptionsBySchema[.classification] ?? []
        for (index, option) in markerColorOptions.enumerated() {
            let titleLabel = UILabel()
            titleLabel.text = option.title
            titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
            titleLabel.textColor = .label

            let colorWell = UIColorWell()
            colorWell.selectedColor = option.color
            colorWell.supportsAlpha = false
            colorWell.tag = index
            colorWell.addTarget(self, action: #selector(markerColorChanged(_:)), for: .valueChanged)

            let row = UIStackView(arrangedSubviews: [titleLabel, colorWell])
            row.axis = .horizontal
            row.alignment = .center
            row.distribution = .equalSpacing
            markerColorsStackView.addArrangedSubview(row)
        }
    }

    private func checkboxConfiguration(for option: MenuOption) -> UIButton.Configuration {
        let isClassificationSchema = selectedSchema == .classification
        let titleColor: UIColor = option.isEnabled ? .label : .tertiaryLabel
        let countColor: UIColor = option.isEnabled ? .secondaryLabel : .tertiaryLabel
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(
            systemName: option.isSelected ? "checkmark.square.fill" : "square"
        )
        configuration.imagePadding = isClassificationSchema ? 6 : 8
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: isClassificationSchema ? 1 : 2,
            leading: 0,
            bottom: isClassificationSchema ? 1 : 2,
            trailing: 0
        )
        var title = AttributedString(
            option.title,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: isClassificationSchema ? 12 : 13, weight: .medium),
                .foregroundColor: titleColor
            ])
        )
        if let countText = option.countText {
            let count = AttributedString(
                " \(countText)",
                attributes: AttributeContainer([
                    .font: UIFont.systemFont(ofSize: isClassificationSchema ? 9 : 10, weight: .regular),
                    .foregroundColor: countColor
                ])
            )
            title.append(count)
        }
        configuration.attributedTitle = title
        return configuration
    }

    private func refreshVisibleHillCount() {
        visibleHillCount = visibleHillCountProvider()
        updateFilterDescription()
        updateShareFilteredDescription()
    }

    private func offlineButtonConfiguration(title: String) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.plain()
        configuration.baseForegroundColor = .systemBlue
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
        configuration.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: UIColor.systemBlue
            ])
        )
        return configuration
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

    @objc private func toggleOption(_ sender: UIButton) {
        guard var options = optionsBySchema[selectedSchema], options.indices.contains(sender.tag) else { return }
        guard !options[sender.tag].isSectionHeader else { return }
        guard options[sender.tag].isEnabled else { return }

        options[sender.tag].isSelected.toggle()
        sender.configuration = checkboxConfiguration(for: options[sender.tag])
        optionsBySchema[selectedSchema] = options

        if options[sender.tag].isSelected {
            let otherSchema: MenuFilterSchema = selectedSchema == .classification ? .height : .classification
            if var otherOptions = optionsBySchema[otherSchema] {
                for index in otherOptions.indices where !otherOptions[index].isSectionHeader {
                    otherOptions[index].isSelected = false
                }
                optionsBySchema[otherSchema] = otherOptions
            }
        }

        toggleHandler(selectedSchema, options[sender.tag].id, options[sender.tag].isSelected)
        refreshVisibleHillCount()
    }

    @objc private func schemaChanged(_ sender: UISegmentedControl) {
        guard let schema = MenuFilterSchema(rawValue: sender.selectedSegmentIndex) else { return }
        selectedSchema = schema
        filterHeaderLabel.text = schema.headerTitle
        rebuildOptionButtons()
        schemaChangeHandler(schema)
        refreshVisibleHillCount()
        updateFilterDescription()
    }

    @objc private func markerColorChanged(_ sender: UIColorWell) {
        guard var markerColorOptions = markerColorOptionsBySchema[selectedMarkerColorSchema],
              markerColorOptions.indices.contains(sender.tag),
              let selectedColor = sender.selectedColor else { return }
        markerColorOptions[sender.tag].color = selectedColor
        markerColorOptionsBySchema[selectedMarkerColorSchema] = markerColorOptions
        markerColorChangeHandler(markerColorOptions[sender.tag].id, selectedColor)
    }

    private func markerColorDescriptionText(for schema: MenuFilterSchema) -> String {
        "Choose colours for markers, points and lines."
    }

    private func updateMarkerColorDescription() {
        markerColorsDescriptionLabel.text = markerColorDescriptionText(for: selectedMarkerColorSchema)
    }

    private func updateFilterDescription() {
        let visibleHillCount = visibleHillCountProvider()
        self.visibleHillCount = visibleHillCount
        filterDescriptionLabel.text = selectedSchema.descriptionText(visibleHillCount: visibleHillCount)
    }

    private func shareFilteredDescriptionText() -> String {
        let count = filteredPeaksProvider().count
        let hillWord = count == 1 ? "hill" : "hills"
        return "Currently selected: \(count) \(hillWord). Share the current filtered list as PDF or CSV."
    }

    private func updateShareFilteredDescription() {
        (view.viewWithTag(9101) as? UILabel)?.text = shareFilteredDescriptionText()
    }

    @objc private func dismissMenu() {
        dismiss(animated: true)
    }

    @objc private func shareFilteredPeaks(_ sender: UIButton) {
        let overlay = ActionOverlayViewController(
            title: "Share Current Hill List",
            actions: [
                .init(title: "PDF", style: .normal) { [weak self] in
                    self?.shareFilteredPeaksPDF(from: sender)
                },
                .init(title: "CSV", style: .normal) { [weak self] in
                    self?.shareFilteredPeaksCSV(from: sender)
                },
                .init(title: "Cancel", style: .cancel, handler: {})
            ]
        )
        present(overlay, animated: true)
    }

    private func shareFilteredPeaksPDF(from sender: UIButton) {
        let filteredPeaks = filteredPeaksProvider()
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        let filterDescription = currentFilterDescriptionProvider()
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(AppBranding.fileSafeName)-Filtered-Hills.pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: UIColor.label
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor.label
        ]
        let groupAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: UIColor.label
        ]

        let lines = [
            "## Current Filtered Hills",
            "Filter: \(filterDescription)",
            "Count: \(filteredPeaks.count)",
            ""
        ] + filteredPeaks.map { peak in
            let altName = peak.alternateHillName.trimmingCharacters(in: .whitespacesAndNewlines)
            let altFragment = altName.isEmpty ? "" : " (\(altName))"
            let regionFragment = peak.rangeName.isEmpty ? "" : " • \(peak.rangeName)"
            let loggedFragment = isPeakLoggedProvider(peak) ? " • Logged" : ""
            return "• \(peak.name)\(altFragment) • \(Int(peak.heightM.rounded())) m • Prom \(String(format: "%.1f", peak.prominenceM)) m\(regionFragment)\(loggedFragment)"
        }

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

                (AppBranding.filteredPeaksTitle as NSString).draw(
                    in: CGRect(x: leftMargin + 36, y: y, width: pageWidth - 84, height: 22),
                    withAttributes: titleAttributes
                )
                y += 34
            }

            beginPage()

            for line in lines {
                let attributes = line.hasPrefix("## ") ? groupAttributes : bodyAttributes
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
            presentFilterShareErrorAlert(message: "Could not prepare the PDF for sharing.")
            return
        }

        presentFilterShareSheet(for: fileURL, from: sender)
    }

    private func shareFilteredPeaksCSV(from sender: UIButton) {
        let filteredPeaks = filteredPeaksProvider()
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        let filterDescription = currentFilterDescriptionProvider()
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(AppBranding.fileSafeName)-Filtered-Hills.csv")
        let header = [
            "MV Index", "Name", "Alternate Name", "Range", "County", "Province",
            "Height (m)", "Prominence (m)", "Grid Ref", "Latitude", "Longitude", "Easting", "Northing",
            "Raw Classification", "Derived Classification Codes", "Derived Classification Names", "County Highpoint Of", "Logged"
        ]

        let rows = filteredPeaks.map { peak -> [String] in
            let codes = orderedClassificationCodes(from: Set(classificationCodesProvider(peak)))
            let names = codes.map(classificationDisplayNameProvider)
            return [
                peak.mvIndex,
                peak.name,
                peak.alternateHillName,
                peak.rangeName,
                peak.administrativeArea,
                peak.regionGroup,
                String(format: "%.1f", peak.heightM),
                String(format: "%.1f", peak.prominenceM),
                peak.formattedRegionGridReference ?? "",
                String(peak.latitude),
                String(peak.longitude),
                peak.projectedEastingMeters.map { String(format: "%.1f", $0) } ?? "",
                peak.projectedNorthingMeters.map { String(format: "%.1f", $0) } ?? "",
                peak.classification,
                codes.joined(separator: "|"),
                names.joined(separator: "|"),
                peak.highpointAreas,
                isPeakLoggedProvider(peak) ? "Yes" : "No"
            ]
        }

        let metadataRows = [
            ["Filter", filterDescription],
            ["Count", String(filteredPeaks.count)],
            Array(repeating: "", count: header.count)
        ]

        let csvText = (metadataRows + [header] + rows)
            .map { row in row.map(filterCSVField).joined(separator: ",") }
            .joined(separator: "\n")

        do {
            try csvText.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            presentFilterShareErrorAlert(message: "Could not prepare the CSV for sharing.")
            return
        }

        presentFilterShareSheet(for: fileURL, from: sender)
    }

    private func presentFilterShareSheet(for fileURL: URL, from sender: UIButton) {
        let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        if let popoverPresentationController = activityViewController.popoverPresentationController {
            let sourceView: UIView = sender.window == nil ? view : sender
            popoverPresentationController.sourceView = sourceView
            popoverPresentationController.sourceRect = sourceView.bounds
        }
        present(activityViewController, animated: true)
    }

    private func presentFilterShareErrorAlert(message: String) {
        let overlay = ActionOverlayViewController(
            title: "Share Unavailable",
            message: message,
            actions: [
                .init(title: "OK", style: .normal, handler: {})
            ]
        )
        present(overlay, animated: true)
    }

    private func filterCSVField(_ value: String) -> String {
        let escapedValue = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escapedValue.contains(",") || escapedValue.contains("\"") || escapedValue.contains("\n") {
            return "\"\(escapedValue)\""
        }
        return escapedValue
    }

    private func buttonConfiguration(title: String, color: UIColor) -> UIButton.Configuration {
        makeOverlayPlainButtonConfiguration(title: title, foregroundColor: color)
    }
}
