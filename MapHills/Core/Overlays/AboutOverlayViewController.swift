//
//  GPXAndInfoOverlays.swift
//  MapHills
//
//  Created by David Owens on 26/03/2026.
//

import UIKit
import CoreLocation

private struct AboutSection {
    let title: String
    let body: String
}

private struct AboutMenuItem {
    let symbolName: String
    let title: String
    let detail: String
}

final class AboutOverlayViewController: UIViewController {
    private let aboutText: String
    private let aboutSections: [AboutSection]
    private let openBareMapLegendToken = "[[openbaremap-legend]]"

    private let dimmingView = UIView()
    private let cardView = UIView()
    private let sectionsStackView = UIStackView()
    private var expandedSectionIndex: Int? = 0

    init(aboutText: String) {
        self.aboutText = aboutText
        self.aboutSections = Self.makeSections(from: aboutText)
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
        dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissOverlay)))
        view.addSubview(dimmingView)

        configureOverlayCardChrome(cardView)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        let titleLabel = makeOverlayTitleLabel(AppBranding.aboutTitle)
        let titleRow = makeOverlayTitleRow(with: titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Hill data, tracking, logging, and offline mapping for \(ActiveRegion.current.displayName)."
        subtitleLabel.font = OverlayChromeStyle.bodyFont
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center

        sectionsStackView.axis = .vertical
        sectionsStackView.spacing = 8
        sectionsStackView.translatesAutoresizingMaskIntoConstraints = false

        let sectionsScrollView = UIScrollView()
        sectionsScrollView.translatesAutoresizingMaskIntoConstraints = false
        sectionsScrollView.backgroundColor = UIColor.secondarySystemBackground
        sectionsScrollView.layer.cornerRadius = 10
        sectionsScrollView.layer.borderWidth = 1
        sectionsScrollView.layer.borderColor = UIColor.separator.cgColor
        sectionsScrollView.showsVerticalScrollIndicator = true
        sectionsScrollView.addSubview(sectionsStackView)
        reloadSectionViews()

        let closeButton = UIButton(type: .system)
        closeButton.configuration = makeOverlayPlainButtonConfiguration(title: "Done")
        closeButton.addTarget(self, action: #selector(dismissOverlay), for: .touchUpInside)

        let contentStack = UIStackView(arrangedSubviews: [titleRow, subtitleLabel, sectionsScrollView, closeButton])
        contentStack.axis = .vertical
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            cardView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            cardView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),

            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),

            sectionsScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 260),
            sectionsStackView.leadingAnchor.constraint(equalTo: sectionsScrollView.contentLayoutGuide.leadingAnchor, constant: 10),
            sectionsStackView.trailingAnchor.constraint(equalTo: sectionsScrollView.contentLayoutGuide.trailingAnchor, constant: -10),
            sectionsStackView.topAnchor.constraint(equalTo: sectionsScrollView.contentLayoutGuide.topAnchor, constant: 10),
            sectionsStackView.bottomAnchor.constraint(equalTo: sectionsScrollView.contentLayoutGuide.bottomAnchor, constant: -10),
            sectionsStackView.widthAnchor.constraint(equalTo: sectionsScrollView.frameLayoutGuide.widthAnchor, constant: -20)
        ])
    }

    @objc private func dismissOverlay() {
        dismiss(animated: true)
    }

    @objc private func toggleSection(_ sender: UIButton) {
        let index = sender.tag
        expandedSectionIndex = expandedSectionIndex == index ? nil : index
        UIView.performWithoutAnimation {
            reloadSectionViews()
            view.layoutIfNeeded()
        }
    }

    private func reloadSectionViews() {
        sectionsStackView.arrangedSubviews.forEach { view in
            sectionsStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for (index, section) in aboutSections.enumerated() {
            sectionsStackView.addArrangedSubview(makeSectionView(for: section, at: index))
        }
    }

    private func makeSectionView(for section: AboutSection, at index: Int) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 6

        let isExpanded = expandedSectionIndex == index
        let button = UIButton(type: .system)
        button.tag = index
        button.contentHorizontalAlignment = .fill
        button.configuration = .plain()
        button.configuration?.title = section.title
        button.configuration?.image = UIImage(systemName: isExpanded ? "chevron.down" : "chevron.right")
        button.configuration?.imagePlacement = .trailing
        button.configuration?.imagePadding = 8
        button.configuration?.baseForegroundColor = .label
        button.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        button.titleLabel?.font = OverlayChromeStyle.sectionTitleFont
        button.backgroundColor = .tertiarySystemBackground
        button.layer.cornerRadius = OverlayChromeStyle.sectionCornerRadius
        button.addTarget(self, action: #selector(toggleSection(_:)), for: .touchUpInside)
        container.addArrangedSubview(button)

        if isExpanded {
            if section.title == "Menus" {
                container.addArrangedSubview(makeMenusSectionView())
            } else {
                let textView = UITextView()
                textView.backgroundColor = .clear
                textView.isEditable = false
                textView.isSelectable = true
                textView.isScrollEnabled = false
                textView.textContainerInset = UIEdgeInsets(top: 6, left: 4, bottom: 8, right: 4)
                textView.textContainer.lineFragmentPadding = 0
                textView.delegate = self
                textView.linkTextAttributes = [
                    .font: OverlayChromeStyle.bodyFont,
                    .foregroundColor: UIColor.systemBlue
                ]
                textView.attributedText = formattedAboutText(section.body)
                container.addArrangedSubview(textView)
            }
        }

        return container
    }

    private func makeMenusSectionView() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.layoutMargins = UIEdgeInsets(top: 4, left: 4, bottom: 8, right: 4)
        stack.isLayoutMarginsRelativeArrangement = true

        for item in menuItems {
            stack.addArrangedSubview(makeMenuItemRow(item))
        }

        return stack
    }

    private func makeMenuItemRow(_ item: AboutMenuItem) -> UIView {
        let iconImageView = UIImageView(
            image: UIImage(
                systemName: item.symbolName,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
            )?.withTintColor(.systemBlue, renderingMode: .alwaysOriginal)
        )
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.setContentHuggingPriority(.required, for: .horizontal)
        iconImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 30),
            iconImageView.heightAnchor.constraint(equalToConstant: 30)
        ])

        let titleLabel = UILabel()
        titleLabel.font = OverlayChromeStyle.sectionTitleFont
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1
        titleLabel.text = item.title

        let detailLabel = UILabel()
        detailLabel.font = OverlayChromeStyle.bodyFont
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0
        detailLabel.text = item.detail

        let textStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [iconImageView, textStack])
        row.axis = .horizontal
        row.alignment = .top
        row.spacing = 10
        row.layoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        row.isLayoutMarginsRelativeArrangement = true
        row.backgroundColor = UIColor.tertiarySystemBackground.withAlphaComponent(0.65)
        row.layer.cornerRadius = 8
        return row
    }

    private var menuItems: [AboutMenuItem] {
        [
            AboutMenuItem(symbolName: "magnifyingglass", title: "Search", detail: "Search filtered hills, filtered starting points, and Irish towns, villages and cities."),
            AboutMenuItem(symbolName: "questionmark", title: "About", detail: "Open app information, data credits, safety notes and this menu guide."),
            AboutMenuItem(symbolName: "gearshape.fill", title: "Settings", detail: "App Customisation"),
            AboutMenuItem(symbolName: "line.3.horizontal.decrease.circle", title: "Filter", detail: "Filter hills by height or classification, manage advanced filters, and review filtered hill lists."),
            AboutMenuItem(symbolName: "list.bullet.clipboard", title: "Log Register", detail: "Review, search, log, unlog and export your hill records."),
            AboutMenuItem(symbolName: "internaldrive.fill", title: "Cache", detail: "Save visible map areas for offline use and manage saved cached areas."),
            AboutMenuItem(symbolName: "play.fill", title: "GPX Recording", detail: "Record, import, reopen, save, export and manage GPX tracks and waypoints."),
            AboutMenuItem(symbolName: "cloud.sun.fill", title: "Weather", detail: "Open a 24 hour forecast for the vicinity of the selected hill or the closest visible hill."),
            AboutMenuItem(symbolName: "square.2.layers.3d.top.filled", title: "Map Layer", detail: "Switch between OpenTopo, OpenBareMap, OpenStreetMap and satellite map layers."),
            AboutMenuItem(symbolName: "location.north.line.fill", title: "Orientation", detail: "Reset the map to north-up; heads-up mode is changed in Settings."),
            AboutMenuItem(symbolName: "scope", title: "Recenter", detail: "Return the map to your current location.")
        ]
    }

    private func formattedAboutText(_ text: String) -> NSAttributedString {
        // The About copy is authored as plain text in ViewController and styled here so
        // wording updates do not require touching the overlay layout code.
        let result = NSMutableAttributedString()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 3
        paragraphStyle.paragraphSpacing = 6

        let headingStyle = NSMutableParagraphStyle()
        headingStyle.paragraphSpacingBefore = 8
        headingStyle.paragraphSpacing = 6

        let bulletStyle = NSMutableParagraphStyle()
        bulletStyle.lineSpacing = 3
        bulletStyle.paragraphSpacing = 3
        bulletStyle.headIndent = 0
        bulletStyle.firstLineHeadIndent = 0

        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .regular),
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ]
        let headingAttributes: [NSAttributedString.Key: Any] = [
            .font: OverlayChromeStyle.sectionTitleFont,
            .foregroundColor: UIColor.label,
            .paragraphStyle: headingStyle
        ]
        let subheadingAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor.label,
            .paragraphStyle: headingStyle
        ]
        let bulletAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .regular),
            .foregroundColor: UIColor.label,
            .paragraphStyle: bulletStyle
        ]
        let creditAttributes: [NSAttributedString.Key: Any] = bodyAttributes
        let contactAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .regular),
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ]
        let emphasizedBodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ]

        let headingLines: Set<String> = ["Overview", "Features", "Recording a GPX", "Menus", "Support", "Credits", "Credits:", "Location Permissions and Data", "Safety", "Private Land", "Additional Providers", "OpenBareMap", "Coillte", "Sport Ireland", ActiveRegion.current.externalDataProviderName]
        let subheadingLines: Set<String> = ["Recording controls", "Using Recording Controls", "Metrics Grid"]

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                result.append(NSAttributedString(string: "\n"))
                continue
            }

            if line == openBareMapLegendToken {
                result.append(openBareMapLegendAttributedText())
                continue
            }

            if headingLines.contains(line) {
                if line == ActiveRegion.current.externalDataProviderName {
                    result.append(dataProviderHeaderAttributedText())
                } else {
                    result.append(NSAttributedString(string: line + "\n", attributes: headingAttributes))
                }
                continue
            }

            if subheadingLines.contains(line) {
                result.append(NSAttributedString(string: line + "\n", attributes: subheadingAttributes))
                continue
            }

            if line.hasPrefix("- ") {
                result.append(NSAttributedString(string: "• " + line.dropFirst(2) + "\n", attributes: bulletAttributes))
                continue
            }

            if line.hasPrefix("Contact: ") {
                let prefix = "Contact: "
                let email = String(line.dropFirst(prefix.count))
                let lineText = NSMutableAttributedString(string: prefix, attributes: contactAttributes)
                lineText.append(NSAttributedString(
                    string: email + "\n",
                    attributes: contactAttributes.merging([
                        .link: "mailto:\(email)"
                    ]) { _, new in new }
                ))
                result.append(lineText)
                continue
            }

            if line.contains("@"), !line.contains(" ") {
                result.append(NSAttributedString(
                    string: line + "\n",
                    attributes: contactAttributes.merging([
                        .link: "mailto:\(line)"
                    ]) { _, new in new }
                ))
                continue
            }

            if line.contains(":") &&
                !line.hasPrefix("The map uses") &&
                !line.hasPrefix("This is free") &&
                !line.hasPrefix("This app allows you to") &&
                !line.hasPrefix("The app allows you to") {
                let creditLine = NSMutableAttributedString(string: line + "\n", attributes: creditAttributes)
                if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
                    let nsLine = line as NSString
                    let lineRange = NSRange(location: 0, length: nsLine.length)
                    for match in detector.matches(in: line, options: [], range: lineRange) {
                        if let url = match.url {
                            creditLine.addAttribute(.link, value: url, range: match.range)
                        }
                    }

                    let plainURLRange = nsLine.range(of: "www.")
                    if plainURLRange.location != NSNotFound {
                        let suffix = nsLine.substring(from: plainURLRange.location)
                        let rawURL = suffix.components(separatedBy: .whitespacesAndNewlines).first ?? suffix
                        if let url = URL(string: "https://\(rawURL)") {
                            let urlLength = (rawURL as NSString).length
                            creditLine.addAttribute(.link, value: url, range: NSRange(location: plainURLRange.location, length: urlLength))
                        }
                    }

                    let dataProviderRange = nsLine.range(of: ActiveRegion.current.externalDataProviderName)
                    if dataProviderRange.location != NSNotFound,
                       let url = URL(string: "https://mountainviews.ie") {
                        creditLine.addAttribute(.link, value: url, range: dataProviderRange)
                    }

                    let metEireannRange = nsLine.range(of: "Met Éireann")
                    if metEireannRange.location != NSNotFound,
                       let url = URL(string: "https://www.met.ie/about-us/specialised-services/open-data") {
                        creditLine.addAttribute(.link, value: url, range: metEireannRange)
                    }
                }
                result.append(creditLine)
                continue
            }

            let bodyLine = NSMutableAttributedString(string: line + "\n", attributes: bodyAttributes)
            replaceInlinePlayIcon(in: bodyLine)
            let emphasizedPhrases = ["While Using the App", "Precise Location"]
            let nsLine = line as NSString
            for emphasizedPhrase in emphasizedPhrases {
                let phraseRange = nsLine.range(of: emphasizedPhrase)
                if phraseRange.location != NSNotFound {
                    bodyLine.addAttributes(emphasizedBodyAttributes, range: phraseRange)
                }
            }
            result.append(bodyLine)
        }

        return result
    }

    private func replaceInlinePlayIcon(in attributedString: NSMutableAttributedString) {
        let token = "[icon]" as NSString
        let replacement = NSAttributedString(attachment: {
            let attachment = NSTextAttachment()
            let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
            attachment.image = UIImage(systemName: "play.fill", withConfiguration: symbolConfiguration)?
                .withTintColor(.systemBlue, renderingMode: .alwaysOriginal)
            attachment.bounds = CGRect(x: 0, y: -1, width: 11, height: 11)
            return attachment
        }())

        while true {
            let searchRange = NSRange(location: 0, length: attributedString.length)
            let foundRange = (attributedString.string as NSString).range(of: token as String, options: [], range: searchRange)
            guard foundRange.location != NSNotFound else { break }
            attributedString.replaceCharacters(in: foundRange, with: replacement)
        }
    }

    private func openBareMapLegendAttributedText() -> NSAttributedString {
        guard let image = openBareMapLegendImage() else {
            return NSAttributedString(string: "")
        }

        let maxWidth = max(180, min(320, UIScreen.main.bounds.width - 96))
        let scaledHeight = maxWidth * image.size.height / image.size.width
        let legendURL = URL(string: "openbaremap://legend")!

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: 4, width: maxWidth, height: scaledHeight)
        attachment.accessibilityLabel = "OpenBareMap legend"
        attachment.accessibilityValue = "Tap to open a zoomable version"

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.paragraphSpacingBefore = 8
        paragraphStyle.paragraphSpacing = 4

        let result = NSMutableAttributedString(attachment: attachment)
        result.addAttributes(
            [
                .paragraphStyle: paragraphStyle,
                .link: legendURL
            ],
            range: NSRange(location: 0, length: result.length)
        )
        result.append(NSAttributedString(
            string: "\nTap legend to enlarge\n",
            attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: UIColor.systemBlue,
                .paragraphStyle: paragraphStyle,
                .link: legendURL
            ]
        ))
        return result
    }

    private func openBareMapLegendImage() -> UIImage? {
        guard let bundleResourceURL = Bundle.main.resourceURL else { return nil }

        let imageURL = bundleResourceURL
            .appendingPathComponent("OpenBareMap.bundle", isDirectory: true)
            .appendingPathComponent("legend", isDirectory: true)
            .appendingPathComponent("openbaremap-legend.png")
        return UIImage(contentsOfFile: imageURL.path)
    }

    private func presentOpenBareMapLegend() {
        guard let image = openBareMapLegendImage() else { return }

        let legendViewController = OpenBareMapLegendViewController(image: image)
        let navigationController = UINavigationController(rootViewController: legendViewController)
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: true)
    }

    private static func makeSections(from text: String) -> [AboutSection] {
        let headingLines: Set<String> = [
            "Overview",
            "Features",
            "Recording a GPX",
            "Menus",
            "Support",
            "Credits",
            "Credits:",
            "Location Permissions and Data",
            "Safety",
            "Private Land",
            "Additional Providers",
            "OpenBareMap",
            "Coillte",
            "Sport Ireland",
            ActiveRegion.current.externalDataProviderName
        ]

        var sections: [AboutSection] = []
        var currentTitle: String?
        var currentLines: [String] = []

        func appendCurrentSection() {
            guard let currentTitle else { return }
            let body = currentLines
                .drop { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .reversed()
                .drop { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .reversed()
                .joined(separator: "\n")
            sections.append(AboutSection(title: currentTitle, body: body))
        }

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if headingLines.contains(line) {
                appendCurrentSection()
                currentTitle = line == "Credits:" ? "Credits" : line
                currentLines = []
            } else if currentTitle != nil {
                currentLines.append(rawLine)
            }
        }

        appendCurrentSection()
        return sections
    }

    private func dataProviderHeaderAttributedText() -> NSAttributedString {
        let result = NSMutableAttributedString()
        let headingParagraphStyle = NSMutableParagraphStyle()
        headingParagraphStyle.paragraphSpacingBefore = 8
        headingParagraphStyle.paragraphSpacing = 6
        headingParagraphStyle.alignment = .left

        if let image = UIImage(named: ActiveRegion.current.externalDataProviderAssetName) {
            result.append(
                NSAttributedString(
                    string: "\(ActiveRegion.current.externalDataProviderName)  ",
                    attributes: [
                        .font: OverlayChromeStyle.sectionTitleFont,
                        .foregroundColor: UIColor.label,
                        .paragraphStyle: headingParagraphStyle
                    ]
                )
            )
            let attachment = NSTextAttachment()
            attachment.image = image
            let targetHeight: CGFloat = 22
            let imageScale = targetHeight / max(image.size.height, 1)
            let targetWidth = image.size.width * imageScale
            attachment.bounds = CGRect(x: 0, y: -2, width: targetWidth, height: targetHeight)
            result.append(NSAttributedString(attachment: attachment))
            result.append(NSAttributedString(string: "\n"))
        } else {
            result.append(
                NSAttributedString(
                    string: "\(ActiveRegion.current.externalDataProviderName)\n",
                    attributes: [
                        .font: OverlayChromeStyle.sectionTitleFont,
                        .foregroundColor: UIColor.label,
                        .paragraphStyle: headingParagraphStyle
                    ]
                )
            )
        }

        return result
    }
}

extension AboutOverlayViewController: UITextViewDelegate {
    func textView(
        _ textView: UITextView,
        primaryActionFor textItem: UITextItem,
        defaultAction: UIAction
    ) -> UIAction? {
        guard case .link(let URL) = textItem.content,
              URL.scheme == "openbaremap",
              URL.host == "legend" else {
            return defaultAction
        }

        return UIAction { [weak self] _ in
            self?.presentOpenBareMapLegend()
        }
    }
}

private final class OpenBareMapLegendViewController: UIViewController, UIScrollViewDelegate {
    private let image: UIImage
    private let scrollView = UIScrollView()
    private let imageView: UIImageView
    private var previousMinimumZoomScale: CGFloat = 0

    init(image: UIImage) {
        self.image = image
        self.imageView = UIImageView(image: image)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "OpenBareMap Legend"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .done,
            primaryAction: UIAction { [weak self] _ in
                self?.dismiss(animated: true)
            }
        )

        scrollView.delegate = self
        scrollView.backgroundColor = .systemBackground
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        imageView.frame = CGRect(origin: .zero, size: image.size)
        imageView.contentMode = .scaleAspectFit
        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = "OpenBareMap legend"
        imageView.accessibilityHint = "Pinch or double-tap to change the size"
        scrollView.addSubview(imageView)
        scrollView.contentSize = image.size

        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let availableSize = scrollView.bounds.size
        guard availableSize.width > 0, availableSize.height > 0,
              image.size.width > 0, image.size.height > 0 else { return }

        let widthScale = availableSize.width / image.size.width
        let heightScale = availableSize.height / image.size.height
        let minimumScale = min(widthScale, heightScale, 1)
        let wasAtMinimumScale = previousMinimumZoomScale == 0 ||
            abs(scrollView.zoomScale - previousMinimumZoomScale) < 0.001

        scrollView.minimumZoomScale = minimumScale
        scrollView.maximumZoomScale = max(4, minimumScale * 4)
        if wasAtMinimumScale {
            scrollView.zoomScale = minimumScale
        }
        previousMinimumZoomScale = minimumScale
        centerImage()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
    }

    @objc private func handleDoubleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale * 1.01 {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            return
        }

        let targetScale = min(
            scrollView.maximumZoomScale,
            max(1, scrollView.minimumZoomScale * 2.5)
        )
        let tapPoint = gestureRecognizer.location(in: imageView)
        let zoomWidth = scrollView.bounds.width / targetScale
        let zoomHeight = scrollView.bounds.height / targetScale
        let zoomRect = CGRect(
            x: tapPoint.x - zoomWidth / 2,
            y: tapPoint.y - zoomHeight / 2,
            width: zoomWidth,
            height: zoomHeight
        )
        scrollView.zoom(to: zoomRect, animated: true)
    }

    private func centerImage() {
        let horizontalInset = max(0, (scrollView.bounds.width - scrollView.contentSize.width) / 2)
        let verticalInset = max(0, (scrollView.bounds.height - scrollView.contentSize.height) / 2)
        scrollView.contentInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
    }
}
