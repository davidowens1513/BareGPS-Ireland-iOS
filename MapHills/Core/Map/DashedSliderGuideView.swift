import UIKit

final class DashedSliderGuideView: UIView {
    private let shapeLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        shapeLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(shapeLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let insetBounds = bounds.insetBy(dx: 3, dy: 3)
        let path = UIBezierPath()
        let tickCount = 11
        let leftX = insetBounds.minX + 3
        let rightX = insetBounds.maxX - 3

        for index in 0..<tickCount {
            let progress = CGFloat(index) / CGFloat(tickCount - 1)
            let y = insetBounds.minY + (insetBounds.height * progress)
            path.move(to: CGPoint(x: leftX, y: y))
            path.addLine(to: CGPoint(x: rightX, y: y))
        }

        shapeLayer.frame = bounds
        shapeLayer.path = path.cgPath
        shapeLayer.lineWidth = 1.6
        shapeLayer.lineDashPattern = [8, 5]
        shapeLayer.lineCap = .round
        shapeLayer.strokeColor = UIColor.white.withAlphaComponent(0.9).cgColor
    }
}
