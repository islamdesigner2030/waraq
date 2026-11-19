import UIKit

/// What sits behind the current page: the cover boards edging out around the paper,
/// a few sheets of the page block on the opening side, and the binding along the spine.
final class PageStackDecorView: UIView {
    private let board = CAShapeLayer()
    private var sheets: [CAShapeLayer] = []
    private let spine = CAGradientLayer()

    var spineOnLeft = true { didSet { setNeedsLayout() } }
    var coverColor: UIColor = .gray { didSet { board.fillColor = coverColor.cgColor } }
    var paperColor: UIColor = .white { didSet { sheets.forEach { $0.fillColor = paperColor.darker(0.035).cgColor } } }
    var pageRadius: CGFloat = 6 { didSet { setNeedsLayout() } }
    var binding: BindingStyle = .stitched { didSet { setNeedsLayout() } }
    /// Pages remaining after the current one (0…3 drawn).
    var sheetsBelow = 3 { didSet { setNeedsLayout() } }
    var pageRect: CGRect = .zero { didSet { setNeedsLayout() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        board.shadowColor = UIColor.black.cgColor
        board.shadowOpacity = 0.20
        board.shadowRadius = 14
        board.shadowOffset = CGSize(width: 0, height: 9)
        layer.addSublayer(board)
        for _ in 0..<3 {
            let s = CAShapeLayer()
            s.strokeColor = UIColor.black.withAlphaComponent(0.09).cgColor
            s.lineWidth = 0.5
            layer.addSublayer(s)
            sheets.append(s)
        }
        layer.addSublayer(spine)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !pageRect.isEmpty else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let outerSign: CGFloat = spineOnLeft ? 1 : -1
        // cover boards: a little larger than the paper, more at the opening edge
        var b = pageRect.insetBy(dx: -5, dy: -6)
        b.origin.x += outerSign * 2
        board.path = shape(for: b, radius: pageRadius + 3).cgPath
        board.shadowPath = board.path

        for (i, s) in sheets.enumerated() {
            let visible = i < min(3, sheetsBelow)
            s.isHidden = !visible
            let step = CGFloat(3 - i) * 1.3
            var r = pageRect
            r.origin.x += outerSign * step
            r.origin.y += step * 0.6
            s.path = shape(for: r, radius: pageRadius).cgPath
        }

        let w: CGFloat = binding == .leather ? 12 : 7
        spine.frame = CGRect(x: spineOnLeft ? pageRect.minX - w : pageRect.maxX, y: b.minY, width: w, height: b.height)
        let dark = coverColor.darker(binding == .leather ? 0.25 : 0.12).cgColor
        let light = coverColor.darker(0.02).cgColor
        spine.colors = spineOnLeft ? [light, dark] : [dark, light]
        spine.startPoint = CGPoint(x: 0, y: 0.5)
        spine.endPoint = CGPoint(x: 1, y: 0.5)
        CATransaction.commit()
    }

    private func shape(for r: CGRect, radius: CGFloat) -> UIBezierPath {
        let corners: UIRectCorner = spineOnLeft ? [.topRight, .bottomRight] : [.topLeft, .bottomLeft]
        return UIBezierPath(roundedRect: r, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
    }
}

extension UIColor {
    func darker(_ amount: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        return UIColor(hue: h, saturation: s, brightness: max(0, b - amount), alpha: a)
    }
}
