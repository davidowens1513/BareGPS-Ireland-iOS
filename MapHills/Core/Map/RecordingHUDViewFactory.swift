import UIKit

enum RecordingHUDViewFactory {
    static func liveMetricsRow(
        leftTitle: String,
        leftValueLabel: UILabel,
        rightTitle: String,
        rightValueLabel: UILabel
    ) -> UIStackView {
        let row = UIStackView(arrangedSubviews: [
            liveMetricCell(title: leftTitle, valueLabel: leftValueLabel),
            liveMetricCell(title: rightTitle, valueLabel: rightValueLabel)
        ])
        row.axis = .horizontal
        row.spacing = 8
        row.distribution = .fillEqually
        return row
    }

    static func liveMetricCell(title: String, valueLabel: UILabel) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.48)
        container.layer.cornerRadius = 8
        container.layer.borderWidth = 0.5
        container.layer.borderColor = UIColor.systemGray3.withAlphaComponent(0.55).cgColor

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 9, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.numberOfLines = 1

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = .systemFont(ofSize: 12.5, weight: .bold)
        valueLabel.textColor = .label
        valueLabel.numberOfLines = 1
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.75

        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.axis = .vertical
        stack.spacing = 1
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 1),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -1)
        ])

        return container
    }

    static func compactRecordingMetricBox(title: String, valueLabel: UILabel) -> UIView {
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 8.5, weight: .semibold)
        titleLabel.textColor = .black
        titleLabel.textAlignment = .left
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = .systemFont(ofSize: 13, weight: .bold)
        valueLabel.textColor = .black
        valueLabel.textAlignment = .left
        valueLabel.numberOfLines = 1
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.65

        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView()
        container.backgroundColor = .clear
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
        ])

        addCompactRecordingSeparator(to: container)
        return container
    }

    static func compactRecordingStatusBox(boxView: UIView, dotView: UIView) -> UIView {
        boxView.translatesAutoresizingMaskIntoConstraints = false
        boxView.backgroundColor = .clear
        boxView.layer.cornerRadius = 0
        boxView.layer.borderWidth = 0

        dotView.translatesAutoresizingMaskIntoConstraints = false
        dotView.backgroundColor = .clear
        dotView.layer.borderWidth = 2
        dotView.layer.borderColor = UIColor.systemGray.cgColor
        dotView.layer.cornerRadius = 13
        dotView.clipsToBounds = true

        boxView.addSubview(dotView)

        NSLayoutConstraint.activate([
            dotView.centerXAnchor.constraint(equalTo: boxView.centerXAnchor),
            dotView.centerYAnchor.constraint(equalTo: boxView.centerYAnchor),
            dotView.widthAnchor.constraint(equalToConstant: 26),
            dotView.heightAnchor.constraint(equalToConstant: 26)
        ])

        return boxView
    }

    private static func addCompactRecordingSeparator(to boxView: UIView) {
        let separatorView = UIView()
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        separatorView.backgroundColor = .black
        boxView.addSubview(separatorView)

        NSLayoutConstraint.activate([
            separatorView.topAnchor.constraint(equalTo: boxView.topAnchor),
            separatorView.bottomAnchor.constraint(equalTo: boxView.bottomAnchor),
            separatorView.trailingAnchor.constraint(equalTo: boxView.trailingAnchor),
            separatorView.widthAnchor.constraint(equalToConstant: 1)
        ])
    }
}
