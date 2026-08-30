//
//  GPXAndInfoOverlays.swift
//  MapHills
//
//  Created by David Owens on 26/03/2026.
//

import UIKit
import CoreLocation

final class GoToHillOverlayViewController: UIViewController {
    let target: GoToTarget
    private var goToLineColor: UIColor
    private let distanceFormatter: (CLLocationDistance) -> String
    private let dismissHandler: () -> Void
    private let cancelGoToHandler: () -> Void

    private let dimmingView = UIView()
    private let cardView = UIView()
    private let directionHeaderLabel = UILabel()
    private let directionValueLabel = UILabel()
    private let headingValueLabel = UILabel()
    private let distanceValueLabel = UILabel()
    private let compassRoseView = CompassRoseView()

    init(
        target: GoToTarget,
        goToLineColor: UIColor,
        distanceFormatter: @escaping (CLLocationDistance) -> String,
        cancelGoToHandler: @escaping () -> Void,
        dismissHandler: @escaping () -> Void
    ) {
        self.target = target
        self.goToLineColor = goToLineColor
        self.distanceFormatter = distanceFormatter
        self.cancelGoToHandler = cancelGoToHandler
        self.dismissHandler = dismissHandler
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

        let titleLabel = makeOverlayTitleLabel("Go To")
        let titleRow = makeOverlayTitleRow(with: titleLabel)

        let hillNameLabel = UILabel()
        hillNameLabel.text = target.title
        hillNameLabel.font = OverlayChromeStyle.titleFont
        hillNameLabel.textColor = .label
        hillNameLabel.textAlignment = .center
        hillNameLabel.numberOfLines = 0

        let metaLabel = UILabel()
        metaLabel.text = target.subtitle
        metaLabel.font = OverlayChromeStyle.bodyFont
        metaLabel.textColor = .secondaryLabel
        metaLabel.textAlignment = .center
        metaLabel.numberOfLines = 0
        metaLabel.isHidden = (metaLabel.text ?? "").isEmpty

        directionHeaderLabel.text = "Bearing"
        directionHeaderLabel.font = OverlayChromeStyle.sectionTitleFont
        directionHeaderLabel.textColor = goToLineColor
        directionHeaderLabel.textAlignment = .center

        directionValueLabel.text = "Waiting for heading…"
        directionValueLabel.font = UIFont.systemFont(ofSize: 36, weight: .semibold)
        directionValueLabel.textColor = goToLineColor
        directionValueLabel.textAlignment = .center
        directionValueLabel.numberOfLines = 1
        directionValueLabel.adjustsFontSizeToFitWidth = true

        let headingHeaderLabel = UILabel()
        headingHeaderLabel.text = "Heading"
        headingHeaderLabel.font = OverlayChromeStyle.sectionTitleFont
        headingHeaderLabel.textColor = .systemGreen
        headingHeaderLabel.textAlignment = .center

        headingValueLabel.text = "Waiting for heading…"
        headingValueLabel.font = UIFont.systemFont(ofSize: 36, weight: .semibold)
        headingValueLabel.textColor = .systemGreen
        headingValueLabel.textAlignment = .center
        headingValueLabel.numberOfLines = 1
        headingValueLabel.adjustsFontSizeToFitWidth = true

        let distanceHeaderLabel = UILabel()
        distanceHeaderLabel.text = "Distance"
        distanceHeaderLabel.font = OverlayChromeStyle.supportingFont
        distanceHeaderLabel.textColor = .secondaryLabel
        distanceHeaderLabel.textAlignment = .center

        distanceValueLabel.text = "Waiting for GPS…"
        distanceValueLabel.font = UIFont.systemFont(ofSize: 26, weight: .semibold)
        distanceValueLabel.textColor = .black
        distanceValueLabel.textAlignment = .center
        distanceValueLabel.numberOfLines = 1
        distanceValueLabel.adjustsFontSizeToFitWidth = true

        let directionStack = UIStackView(arrangedSubviews: [directionHeaderLabel, directionValueLabel])
        directionStack.axis = .vertical
        directionStack.spacing = 4

        let headingStack = UIStackView(arrangedSubviews: [headingHeaderLabel, headingValueLabel])
        headingStack.axis = .vertical
        headingStack.spacing = 4

        let topMetricsStack = UIStackView(arrangedSubviews: [directionStack, headingStack])
        topMetricsStack.axis = .horizontal
        topMetricsStack.alignment = .fill
        topMetricsStack.distribution = .fillEqually
        topMetricsStack.spacing = 12

        let liveBoxStack = UIStackView(arrangedSubviews: [topMetricsStack, distanceHeaderLabel, distanceValueLabel])
        liveBoxStack.axis = .vertical
        liveBoxStack.spacing = 8

        let liveBox = UIView()
        liveBox.backgroundColor = UIColor.black.withAlphaComponent(0.22)
        liveBox.layer.cornerRadius = 14
        liveBox.layer.borderWidth = 1
        liveBox.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        liveBox.translatesAutoresizingMaskIntoConstraints = false
        liveBox.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showGoToActions)))
        liveBox.isUserInteractionEnabled = true
        liveBox.addSubview(liveBoxStack)
        liveBoxStack.translatesAutoresizingMaskIntoConstraints = false

        compassRoseView.translatesAutoresizingMaskIntoConstraints = false
        compassRoseView.updateGoToLineColor(goToLineColor)

        let closeButton = UIButton(type: .system)
        closeButton.configuration = makeOverlayPlainButtonConfiguration(title: "Done")
        closeButton.titleLabel?.numberOfLines = 1
        closeButton.titleLabel?.adjustsFontSizeToFitWidth = true
        closeButton.titleLabel?.minimumScaleFactor = 0.8
        closeButton.addTarget(self, action: #selector(dismissOverlay), for: .touchUpInside)

        let contentStack = UIStackView(arrangedSubviews: [
            titleRow,
            hillNameLabel,
            metaLabel,
            liveBox,
            compassRoseView,
            closeButton
        ])
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
            cardView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),

            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),

            liveBoxStack.leadingAnchor.constraint(equalTo: liveBox.leadingAnchor, constant: 14),
            liveBoxStack.trailingAnchor.constraint(equalTo: liveBox.trailingAnchor, constant: -14),
            liveBoxStack.topAnchor.constraint(equalTo: liveBox.topAnchor, constant: 14),
            liveBoxStack.bottomAnchor.constraint(equalTo: liveBox.bottomAnchor, constant: -14),

            compassRoseView.heightAnchor.constraint(equalToConstant: 308),
            compassRoseView.widthAnchor.constraint(equalToConstant: 308),
            compassRoseView.centerXAnchor.constraint(equalTo: contentStack.centerXAnchor)
        ])
    }

    @objc private func dismissOverlay() {
        dismiss(animated: true, completion: dismissHandler)
    }

    @objc private func showGoToActions() {
        let overlay = ActionOverlayViewController(
            title: target.title,
            actions: [
                .init(title: "Cancel Go To", style: .destructive) { [weak self] in
                    self?.dismiss(animated: true) {
                        self?.cancelGoToHandler()
                    }
                },
                .init(title: "Close", style: .cancel, handler: {})
            ]
        )
        present(overlay, animated: true)
    }

    func updateNavigation(distanceMeters: CLLocationDistance?, bearingDegrees: CLLocationDirection?, headingDegrees: CLLocationDirection?) {
        // The overlay remains useful before heading is available by falling back to a
        // north-up bearing readout. Once heading arrives, the rose becomes device-relative.
        if let distanceMeters {
            distanceValueLabel.text = formattedDistance(distanceMeters)
        } else {
            distanceValueLabel.text = "Waiting for GPS…"
        }

        if let bearingDegrees {
            if headingDegrees != nil {
                directionValueLabel.text = "\(Int(bearingDegrees.rounded()))°"
            } else {
                directionValueLabel.text = "\(Int(bearingDegrees.rounded()))° from North"
            }
        } else {
            directionValueLabel.text = "Waiting for heading…"
        }

        if let headingDegrees {
            let normalizedHeading = headingDegrees.truncatingRemainder(dividingBy: 360)
            let positiveHeading = normalizedHeading >= 0 ? normalizedHeading : normalizedHeading + 360
            headingValueLabel.text = "\(Int(positiveHeading.rounded()))°"
        } else {
            headingValueLabel.text = "Waiting for heading…"
        }

        let rotationDegrees: CLLocationDirection
        if let bearingDegrees, let headingDegrees {
            rotationDegrees = bearingDegrees - headingDegrees
        } else if let bearingDegrees {
            rotationDegrees = bearingDegrees
        } else {
            rotationDegrees = 0
        }

        compassRoseView.setNeedleRotation(degrees: rotationDegrees)
        compassRoseView.setNorthRotation(degrees: headingDegrees.map { -$0 })
    }

    private func formattedDistance(_ distanceMeters: CLLocationDistance) -> String {
        distanceFormatter(distanceMeters)
    }

    func updateGoToLineColor(_ color: UIColor) {
        goToLineColor = color
        directionHeaderLabel.textColor = color
        directionValueLabel.textColor = color
        compassRoseView.updateGoToLineColor(color)
    }

    private func cardinalDirection(for degrees: CLLocationDirection) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW", "N"]
        let normalized = degrees.truncatingRemainder(dividingBy: 360)
        let positive = normalized >= 0 ? normalized : normalized + 360
        let index = Int((positive + 22.5) / 45.0)
        return directions[index]
    }
}

private final class CompassDialView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - 4
        let outerRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        let innerRadius = radius - 10
        let innerRect = CGRect(x: center.x - innerRadius, y: center.y - innerRadius, width: innerRadius * 2, height: innerRadius * 2)

        let colors = [
            UIColor.black.cgColor,
            UIColor.black.cgColor
        ] as CFArray
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) {
            context.saveGState()
            context.addEllipse(in: outerRect)
            context.clip()
            context.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: radius * 0.05,
                endCenter: center,
                endRadius: radius,
                options: []
            )
            context.restoreGState()
        }

        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2.5)
        context.strokeEllipse(in: outerRect)

        context.setStrokeColor(UIColor.white.withAlphaComponent(0.2).cgColor)
        context.setLineWidth(1)
        context.strokeEllipse(in: outerRect.insetBy(dx: 3, dy: 3))

        context.setFillColor(UIColor.black.cgColor)
        context.fillEllipse(in: innerRect)

        context.setStrokeColor(UIColor.white.withAlphaComponent(0.22).cgColor)
        context.setLineWidth(1)
        context.strokeEllipse(in: innerRect)

        for tick in stride(from: 0, to: 360, by: 30) {
            let isMajorTick = tick % 90 == 0
            let tickLength: CGFloat = isMajorTick ? 18 : 10
            let lineWidth: CGFloat = isMajorTick ? 2.5 : 1.25
            let angle = CGFloat(tick) * .pi / 180 - .pi / 2

            let outerPoint = CGPoint(x: center.x + cos(angle) * (radius - 10), y: center.y + sin(angle) * (radius - 10))
            let innerPoint = CGPoint(x: center.x + cos(angle) * (radius - 10 - tickLength), y: center.y + sin(angle) * (radius - 10 - tickLength))

            context.setStrokeColor((isMajorTick ? UIColor.white : UIColor.white.withAlphaComponent(0.55)).cgColor)
            context.setLineWidth(lineWidth)
            context.move(to: outerPoint)
            context.addLine(to: innerPoint)
            context.strokePath()
        }

        let cardinals: [(String, CGFloat, UIColor)] = [
            ("N", -.pi / 2, .white),
            ("E", 0, .white),
            ("S", .pi / 2, .white),
            ("W", .pi, .white)
        ]

        for (label, angle, color) in cardinals {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                .foregroundColor: color
            ]
            let size = (label as NSString).size(withAttributes: attributes)
            let labelRadius = radius - 30
            let point = CGPoint(
                x: center.x + cos(angle) * labelRadius - size.width / 2,
                y: center.y + sin(angle) * labelRadius - size.height / 2
            )
            (label as NSString).draw(at: point, withAttributes: attributes)
        }
    }
}

private final class CompassRoseView: UIView {
    private let dialView = CompassDialView()
    private let headingLineContainerView = UIView()
    private let headingLineView = UIView()
    private let headingArrowView = ArrowheadView(fillColor: .systemGreen, strokeColor: UIColor.systemGreen.withAlphaComponent(0.75))
    private let northNeedleContainerView = UIView()
    private let northNeedleHeadView = UIView()
    private let northNeedleTailView = UIView()
    private let northNeedleArrowView = ArrowheadView(fillColor: .systemRed, strokeColor: UIColor.systemRed.withAlphaComponent(0.45))
    private let needleContainerView = UIView()
    private let needleHeadView = UIView()
    private let needleTailView = UIView()
    private let needleArrowView = ArrowheadView(fillColor: .systemGreen, strokeColor: UIColor.systemGreen.withAlphaComponent(0.45))
    private let centerDotView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        dialView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dialView)

        headingLineContainerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headingLineContainerView)

        headingLineView.translatesAutoresizingMaskIntoConstraints = false
        headingLineView.backgroundColor = .systemGreen
        headingLineView.layer.cornerRadius = 2
        headingLineContainerView.addSubview(headingLineView)

        headingArrowView.translatesAutoresizingMaskIntoConstraints = false
        headingLineContainerView.addSubview(headingArrowView)

        northNeedleContainerView.translatesAutoresizingMaskIntoConstraints = false
        northNeedleContainerView.isHidden = false
        addSubview(northNeedleContainerView)

        northNeedleHeadView.translatesAutoresizingMaskIntoConstraints = false
        northNeedleHeadView.backgroundColor = .systemRed
        northNeedleHeadView.layer.cornerRadius = 1.5
        northNeedleContainerView.addSubview(northNeedleHeadView)

        northNeedleTailView.translatesAutoresizingMaskIntoConstraints = false
        northNeedleTailView.backgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
        northNeedleTailView.layer.cornerRadius = 2
        northNeedleContainerView.addSubview(northNeedleTailView)

        northNeedleArrowView.translatesAutoresizingMaskIntoConstraints = false
        northNeedleContainerView.addSubview(northNeedleArrowView)

        needleContainerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(needleContainerView)

        needleHeadView.translatesAutoresizingMaskIntoConstraints = false
        needleHeadView.backgroundColor = .systemGreen
        needleHeadView.layer.cornerRadius = 3
        needleContainerView.addSubview(needleHeadView)

        needleTailView.translatesAutoresizingMaskIntoConstraints = false
        needleTailView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.9)
        needleTailView.layer.cornerRadius = 2
        needleContainerView.addSubview(needleTailView)

        needleArrowView.translatesAutoresizingMaskIntoConstraints = false
        needleContainerView.addSubview(needleArrowView)

        centerDotView.translatesAutoresizingMaskIntoConstraints = false
        centerDotView.backgroundColor = .black
        centerDotView.layer.cornerRadius = 7
        centerDotView.layer.borderWidth = 2
        centerDotView.layer.borderColor = UIColor.white.cgColor
        addSubview(centerDotView)
        bringSubviewToFront(northNeedleContainerView)
        bringSubviewToFront(needleContainerView)
        bringSubviewToFront(centerDotView)

        NSLayoutConstraint.activate([
            dialView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dialView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dialView.topAnchor.constraint(equalTo: topAnchor),
            dialView.bottomAnchor.constraint(equalTo: bottomAnchor),

            headingLineContainerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            headingLineContainerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            headingLineContainerView.widthAnchor.constraint(equalToConstant: 10),
            headingLineContainerView.heightAnchor.constraint(equalToConstant: 228),

            headingLineView.centerXAnchor.constraint(equalTo: headingLineContainerView.centerXAnchor),
            headingLineView.centerYAnchor.constraint(equalTo: headingLineContainerView.centerYAnchor),
            headingLineView.widthAnchor.constraint(equalToConstant: 4),
            headingLineView.heightAnchor.constraint(equalTo: headingLineContainerView.heightAnchor),

            headingArrowView.centerXAnchor.constraint(equalTo: headingLineContainerView.centerXAnchor),
            headingArrowView.topAnchor.constraint(equalTo: headingLineContainerView.topAnchor, constant: 2),
            headingArrowView.widthAnchor.constraint(equalToConstant: 16),
            headingArrowView.heightAnchor.constraint(equalToConstant: 20),

            northNeedleContainerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            northNeedleContainerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            northNeedleContainerView.widthAnchor.constraint(equalToConstant: 18),
            northNeedleContainerView.heightAnchor.constraint(equalToConstant: 92),

            northNeedleHeadView.centerXAnchor.constraint(equalTo: northNeedleContainerView.centerXAnchor),
            northNeedleHeadView.topAnchor.constraint(equalTo: northNeedleContainerView.topAnchor, constant: 10),
            northNeedleHeadView.widthAnchor.constraint(equalToConstant: 6),
            northNeedleHeadView.heightAnchor.constraint(equalToConstant: 42),

            northNeedleTailView.centerXAnchor.constraint(equalTo: northNeedleContainerView.centerXAnchor),
            northNeedleTailView.bottomAnchor.constraint(equalTo: northNeedleContainerView.bottomAnchor, constant: -16),
            northNeedleTailView.widthAnchor.constraint(equalToConstant: 6),
            northNeedleTailView.heightAnchor.constraint(equalToConstant: 28),

            northNeedleArrowView.centerXAnchor.constraint(equalTo: northNeedleContainerView.centerXAnchor),
            northNeedleArrowView.topAnchor.constraint(equalTo: northNeedleContainerView.topAnchor, constant: 2),
            northNeedleArrowView.widthAnchor.constraint(equalToConstant: 18),
            northNeedleArrowView.heightAnchor.constraint(equalToConstant: 22),

            needleContainerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            needleContainerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            needleContainerView.widthAnchor.constraint(equalToConstant: 22),
            needleContainerView.heightAnchor.constraint(equalToConstant: 182),

            needleHeadView.centerXAnchor.constraint(equalTo: needleContainerView.centerXAnchor),
            needleHeadView.topAnchor.constraint(equalTo: needleContainerView.topAnchor, constant: 12),
            needleHeadView.widthAnchor.constraint(equalToConstant: 6),
            needleHeadView.heightAnchor.constraint(equalToConstant: 104),

            needleTailView.centerXAnchor.constraint(equalTo: needleContainerView.centerXAnchor),
            needleTailView.bottomAnchor.constraint(equalTo: needleContainerView.bottomAnchor, constant: -18),
            needleTailView.widthAnchor.constraint(equalToConstant: 6),
            needleTailView.heightAnchor.constraint(equalToConstant: 72),

            needleArrowView.centerXAnchor.constraint(equalTo: needleContainerView.centerXAnchor),
            needleArrowView.topAnchor.constraint(equalTo: needleContainerView.topAnchor, constant: 2),
            needleArrowView.widthAnchor.constraint(equalToConstant: 18),
            needleArrowView.heightAnchor.constraint(equalToConstant: 22),

            centerDotView.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerDotView.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerDotView.widthAnchor.constraint(equalToConstant: 18),
            centerDotView.heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setNeedleRotation(degrees: CLLocationDirection) {
        let radians = CGFloat(degrees * .pi / 180)
        UIView.animate(withDuration: 0.18, delay: 0, options: [.beginFromCurrentState, .curveEaseInOut]) {
            self.needleContainerView.transform = CGAffineTransform(rotationAngle: radians)
        }
    }

    func setNorthRotation(degrees: CLLocationDirection?) {
        guard let degrees else {
            northNeedleContainerView.isHidden = true
            UIView.animate(withDuration: 0.18, delay: 0, options: [.beginFromCurrentState, .curveEaseInOut]) {
                self.dialView.transform = .identity
                self.northNeedleContainerView.transform = .identity
            }
            return
        }

        northNeedleContainerView.isHidden = false
        let radians = CGFloat(degrees * .pi / 180)
        UIView.animate(withDuration: 0.18, delay: 0, options: [.beginFromCurrentState, .curveEaseInOut]) {
            self.dialView.transform = CGAffineTransform(rotationAngle: radians)
            self.northNeedleContainerView.transform = CGAffineTransform(rotationAngle: radians)
        }
    }

    func updateGoToLineColor(_ color: UIColor) {
        needleHeadView.backgroundColor = color
        needleTailView.backgroundColor = color.withAlphaComponent(0.9)
        needleArrowView.updateColors(fillColor: color, strokeColor: color.withAlphaComponent(0.45))
    }
}

private final class ArrowheadView: UIView {
    private var fillColor: UIColor
    private var strokeColor: UIColor

    init(fillColor: UIColor, strokeColor: UIColor) {
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.close()

        fillColor.setFill()
        path.fill()

        strokeColor.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    func updateColors(fillColor: UIColor, strokeColor: UIColor) {
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        setNeedsDisplay()
    }
}

