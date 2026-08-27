import UIKit

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
