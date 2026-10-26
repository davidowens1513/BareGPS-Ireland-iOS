import UIKit

enum MapAnnotationImages {
    enum ZoomPresentation: String {
        case full
        case mediumDot
        case smallDot
        case tinyDot

        init(zoomLevel: Double) {
            switch zoomLevel {
            case 11...:
                self = .full
            case 9..<11:
                self = .mediumDot
            case 7..<9:
                self = .smallDot
            default:
                self = .tinyDot
            }
        }

        var dotDiameter: CGFloat? {
            switch self {
            case .full:
                nil
            case .mediumDot:
                12
            case .smallDot:
                9
            case .tinyDot:
                6
            }
        }
    }

    static func colorCacheKey(for color: UIColor) -> String {
        guard let components = color.cgColor.components else { return "" }
        let normalizedComponents: [CGFloat]
        if components.count >= 4 {
            normalizedComponents = Array(components.prefix(4))
        } else if components.count == 2 {
            normalizedComponents = [components[0], components[0], components[0], components[1]]
        } else {
            normalizedComponents = [0, 0, 0, 1]
        }
        return normalizedComponents
            .map { String(format: "%.4f", $0) }
            .joined(separator: ",")
    }

    static func hillMarkerImage(markerColor: UIColor, isLogged: Bool, isSelected: Bool) -> UIImage {
        let iconSize = isSelected ? CGSize(width: 38, height: 38) : CGSize(width: 28, height: 28)
        let renderer = UIGraphicsImageRenderer(size: iconSize)

        return renderer.image { _ in
            let imageBounds = CGRect(origin: .zero, size: iconSize)
            if isSelected {
                let glowPath = UIBezierPath(ovalIn: imageBounds.insetBy(dx: 0.5, dy: 0.5))
                UIColor.systemYellow.withAlphaComponent(0.34).setFill()
                glowPath.fill()
            }

            let circleInset: CGFloat = isSelected ? 6 : 3
            let circleBounds = imageBounds.insetBy(dx: circleInset, dy: circleInset)

            markerColor.setFill()
            (isSelected ? UIColor.systemYellow : UIColor.white).setStroke()

            let circlePath = UIBezierPath(ovalIn: circleBounds)
            circlePath.lineWidth = isSelected ? 4 : 2
            circlePath.fill()
            circlePath.stroke()

            if isLogged {
                let checkmarkPath = UIBezierPath()
                let scale = iconSize.width / 28
                checkmarkPath.move(to: CGPoint(x: 8.5 * scale, y: 14 * scale))
                checkmarkPath.addLine(to: CGPoint(x: 11.8 * scale, y: 17.2 * scale))
                checkmarkPath.addLine(to: CGPoint(x: 18.8 * scale, y: 10 * scale))
                checkmarkPath.lineWidth = 3 * scale
                checkmarkPath.lineCapStyle = .round
                checkmarkPath.lineJoinStyle = .round
                UIColor.white.setStroke()
                checkmarkPath.stroke()
            } else {
                let mountainPath = UIBezierPath()
                let scale = iconSize.width / 28
                mountainPath.move(to: CGPoint(x: 8 * scale, y: 18 * scale))
                mountainPath.addLine(to: CGPoint(x: 14 * scale, y: 9 * scale))
                mountainPath.addLine(to: CGPoint(x: 20 * scale, y: 18 * scale))
                mountainPath.close()
                UIColor.white.withAlphaComponent(0.95).setFill()
                mountainPath.fill()
            }
        }
    }

    static func markerDotImage(markerColor: UIColor, diameter: CGFloat, isSelected: Bool) -> UIImage {
        let selectionInset: CGFloat = isSelected ? 3 : 1
        let imageSize = diameter + selectionInset * 2
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: imageSize, height: imageSize))

        return renderer.image { _ in
            let dotBounds = CGRect(
                x: selectionInset,
                y: selectionInset,
                width: diameter,
                height: diameter
            )
            let dotPath = UIBezierPath(ovalIn: dotBounds)
            markerColor.setFill()
            dotPath.fill()

            if isSelected {
                UIColor.systemYellow.setStroke()
                dotPath.lineWidth = 2
                dotPath.stroke()
            }
        }
    }

    static func startPlaceMarkerImage(markerColor: UIColor, title: String, isSelected: Bool) -> UIImage {
        let size = isSelected ? CGSize(width: 64, height: 56) : CGSize(width: 56, height: 48)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let circleConfiguration = UIImage.SymbolConfiguration(pointSize: isSelected ? 24 : 20, weight: .bold)
            let walkerConfiguration = UIImage.SymbolConfiguration(pointSize: isSelected ? 13 : 11, weight: .bold)
            let circleImage = UIImage(systemName: "circle.fill", withConfiguration: circleConfiguration)?
                .withTintColor(markerColor, renderingMode: .alwaysOriginal)
            let walkerImage = UIImage(systemName: "figure.walk", withConfiguration: walkerConfiguration)?
                .withTintColor(.white, renderingMode: .alwaysOriginal)

            if isSelected {
                let glowPath = UIBezierPath(ovalIn: CGRect(x: 15, y: 0, width: 34, height: 34))
                UIColor.systemYellow.withAlphaComponent(0.34).setFill()
                glowPath.fill()

                let outlinePath = UIBezierPath(ovalIn: CGRect(x: 18, y: 3, width: 28, height: 28))
                UIColor.systemYellow.setStroke()
                outlinePath.lineWidth = 4
                outlinePath.stroke()
            }

            let circleRect = isSelected ? CGRect(x: 20, y: 5, width: 24, height: 24) : CGRect(x: 17, y: 2, width: 22, height: 22)
            let walkerRect = isSelected ? CGRect(x: 23.5, y: 8.5, width: 17, height: 17) : CGRect(x: 20.5, y: 5.5, width: 15, height: 15)
            circleImage?.draw(in: circleRect)
            walkerImage?.draw(in: walkerRect)

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraphStyle
            ]
            let labelRect = CGRect(x: 2, y: isSelected ? 33 : 25, width: size.width - 4, height: 20)
            NSString(string: title).draw(
                with: labelRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
        }
    }

    static func irelandPlaceSearchBadgeImage(markerColor: UIColor) -> UIImage {
        let size = CGSize(width: 20, height: 20)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let context = UIGraphicsGetCurrentContext()
            context?.setAllowsAntialiasing(true)
            context?.setShouldAntialias(true)

            let scale = size.width / 1024.0
            let pinPath = UIBezierPath()
            pinPath.move(to: CGPoint(x: 512 * scale, y: 80 * scale))
            pinPath.addCurve(
                to: CGPoint(x: 224 * scale, y: 368 * scale),
                controlPoint1: CGPoint(x: 352.942 * scale, y: 80 * scale),
                controlPoint2: CGPoint(x: 224 * scale, y: 208.942 * scale)
            )
            pinPath.addCurve(
                to: CGPoint(x: 512 * scale, y: 944 * scale),
                controlPoint1: CGPoint(x: 224 * scale, y: 594 * scale),
                controlPoint2: CGPoint(x: 512 * scale, y: 944 * scale)
            )
            pinPath.addCurve(
                to: CGPoint(x: 800 * scale, y: 368 * scale),
                controlPoint1: CGPoint(x: 512 * scale, y: 944 * scale),
                controlPoint2: CGPoint(x: 800 * scale, y: 594 * scale)
            )
            pinPath.addCurve(
                to: CGPoint(x: 512 * scale, y: 80 * scale),
                controlPoint1: CGPoint(x: 800 * scale, y: 208.942 * scale),
                controlPoint2: CGPoint(x: 671.058 * scale, y: 80 * scale)
            )
            pinPath.close()

            markerColor.setFill()
            pinPath.fill()

            let centerPath = UIBezierPath(ovalIn: CGRect(x: 400 * scale, y: 256 * scale, width: 224 * scale, height: 224 * scale))
            UIColor.white.setFill()
            centerPath.fill()
        }
    }

    static func goToTargetMarkerImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 28, height: 28)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let outerRect = CGRect(x: 2, y: 2, width: 24, height: 24)
            let innerRect = CGRect(x: 7, y: 7, width: 14, height: 14)

            let outerPath = UIBezierPath(ovalIn: outerRect)
            color.setFill()
            outerPath.fill()

            let innerPath = UIBezierPath(ovalIn: innerRect)
            UIColor.white.setFill()
            innerPath.fill()
        }
    }

    static func savedWaypointMarkerImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 28, height: 28)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let outerRect = CGRect(x: 2, y: 2, width: 24, height: 24)
            let outerPath = UIBezierPath(ovalIn: outerRect)
            color.setFill()
            outerPath.fill()

            let image = UIImage(
                systemName: "flag.fill",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
            )?.withTintColor(.white, renderingMode: .alwaysOriginal)
            image?.draw(in: CGRect(x: 7, y: 6, width: 14, height: 14))
        }
    }
}
