import UIKit

enum OverlayChromeStyle {
    static let dimmingAlpha: CGFloat = 0.35
    static let cardCornerRadius: CGFloat = 16
    static let sectionCornerRadius: CGFloat = 12
    static let cardContentPadding: CGFloat = 20
    static let sectionContentPadding: CGFloat = 14
    static let verticalSpacing: CGFloat = 14
    static let buttonHeight: CGFloat = 42

    static let titleFont = UIFont.systemFont(ofSize: 20, weight: .semibold)
    static let sectionTitleFont = UIFont.systemFont(ofSize: 15, weight: .semibold)
    static let bodyFont = UIFont.systemFont(ofSize: 13, weight: .regular)
    static let supportingFont = UIFont.systemFont(ofSize: 12, weight: .regular)
    static let actionFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
}

func overlayLogoImage() -> UIImage? {
    let iconDictionaryKeys = ["CFBundleIcons", "CFBundleIcons~ipad"]

    for dictionaryKey in iconDictionaryKeys {
        guard
            let iconsDictionary = Bundle.main.object(forInfoDictionaryKey: dictionaryKey) as? [String: Any],
            let primaryIconDictionary = iconsDictionary["CFBundlePrimaryIcon"] as? [String: Any],
            let iconFiles = primaryIconDictionary["CFBundleIconFiles"] as? [String]
        else {
            continue
        }

        for iconName in iconFiles.reversed() {
            if let image = UIImage(named: iconName) {
                return image
            }
        }
    }

    return UIImage(named: "app-store-1024")
}

func makeOverlayTitleRow(with titleLabel: UILabel) -> UIStackView {
    let leadingView: UIView
    if let image = overlayLogoImage() {
        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 5
        imageView.layer.borderWidth = 0.5
        imageView.layer.borderColor = UIColor.separator.cgColor
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 24),
            imageView.heightAnchor.constraint(equalToConstant: 24)
        ])
        leadingView = imageView
    } else {
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            spacer.widthAnchor.constraint(equalToConstant: 24),
            spacer.heightAnchor.constraint(equalToConstant: 24)
        ])
        leadingView = spacer
    }

    let trailingSpacer = UIView()
    trailingSpacer.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        trailingSpacer.widthAnchor.constraint(equalToConstant: 24),
        trailingSpacer.heightAnchor.constraint(equalToConstant: 24)
    ])

    titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
    titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    let row = UIStackView(arrangedSubviews: [leadingView, titleLabel, trailingSpacer])
    row.axis = .horizontal
    row.alignment = .center
    row.spacing = 10
    return row
}

func configureOverlayCardChrome(_ view: UIView) {
    view.backgroundColor = .systemBackground
    view.layer.cornerRadius = OverlayChromeStyle.cardCornerRadius
}

func makeOverlayTitleLabel(_ text: String, alignment: NSTextAlignment = .center) -> UILabel {
    let label = UILabel()
    label.text = text
    label.font = OverlayChromeStyle.titleFont
    label.textColor = .label
    label.textAlignment = alignment
    label.numberOfLines = 0
    return label
}

func makeOverlaySectionTitleLabel(_ text: String, alignment: NSTextAlignment = .left) -> UILabel {
    let label = UILabel()
    label.text = text
    label.font = OverlayChromeStyle.sectionTitleFont
    label.textColor = .label
    label.textAlignment = alignment
    label.numberOfLines = 0
    return label
}

func makeOverlayBodyLabel(
    _ text: String,
    alignment: NSTextAlignment = .center,
    color: UIColor = .secondaryLabel
) -> UILabel {
    let label = UILabel()
    label.text = text
    label.font = OverlayChromeStyle.bodyFont
    label.textColor = color
    label.textAlignment = alignment
    label.numberOfLines = 0
    return label
}

func makeOverlaySupportingLabel(
    _ text: String,
    alignment: NSTextAlignment = .center,
    color: UIColor = .secondaryLabel
) -> UILabel {
    let label = UILabel()
    label.text = text
    label.font = OverlayChromeStyle.supportingFont
    label.textColor = color
    label.textAlignment = alignment
    label.numberOfLines = 0
    return label
}

func makeOverlayButtonConfiguration(
    title: String,
    foregroundColor: UIColor,
    backgroundColor: UIColor,
    font: UIFont = OverlayChromeStyle.actionFont
) -> UIButton.Configuration {
    var configuration = UIButton.Configuration.filled()
    configuration.baseForegroundColor = foregroundColor
    configuration.baseBackgroundColor = backgroundColor
    configuration.cornerStyle = .medium
    configuration.attributedTitle = AttributedString(
        title,
        attributes: AttributeContainer([
            .font: font,
            .foregroundColor: foregroundColor
        ])
    )
    return configuration
}

func makeOverlayPlainButtonConfiguration(
    title: String,
    foregroundColor: UIColor = .systemBlue,
    font: UIFont = OverlayChromeStyle.actionFont
) -> UIButton.Configuration {
    var configuration = UIButton.Configuration.plain()
    configuration.baseForegroundColor = foregroundColor
    configuration.attributedTitle = AttributedString(
        title,
        attributes: AttributeContainer([
            .font: font,
            .foregroundColor: foregroundColor
        ])
    )
    return configuration
}
