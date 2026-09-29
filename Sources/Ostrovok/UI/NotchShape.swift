import SwiftUI

/// The island outline: bottom corners with Apple's continuous ("squircle")
/// curvature and two concave corners on top that melt into the screen edge.
///
/// The bottom corners are not drawn by hand: we take the path of a
/// `RoundedRectangle(style: .continuous)` — which is the exact system curve —
/// and union it with the concave "wings". Hand-approximating a superellipse
/// gets the straight-edge transition wrong.
struct NotchShape: Shape {
    var wingRadius: CGFloat = Metrics.wingRadius
    var bottomRadius: CGFloat = Metrics.bottomRadiusCollapsed

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(wingRadius, bottomRadius) }
        set {
            wingRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let bodyMinX = rect.minX + wingRadius
        let bodyMaxX = rect.maxX - wingRadius
        guard bodyMaxX > bodyMinX else { return Path(rect) }

        // The continuous curve consumes ~1.53×radius along each edge. If the body
        // started at the screen edge, that entry would show as an inward bulge, so
        // the body extends up past the top edge of the drawing.
        let overhang = bottomRadius * 1.7
        let body = CGRect(
            x: bodyMinX,
            y: rect.minY - overhang,
            width: bodyMaxX - bodyMinX,
            height: rect.height + overhang
        )
        let base = RoundedRectangle(cornerRadius: bottomRadius, style: .continuous).path(in: body)

        guard wingRadius > 0 else { return base }

        var wings = Path()
        wings.addPath(wing(topX: rect.minX, bodyX: bodyMinX, topY: rect.minY))
        wings.addPath(wing(topX: rect.maxX, bodyX: bodyMaxX, topY: rect.minY))

        return Path(base.cgPath.union(wings.cgPath))
    }

    /// Concave piece between the screen edge and the body side.
    private func wing(topX: CGFloat, bodyX: CGFloat, topY: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: topX, y: topY))
        path.addQuadCurve(
            to: CGPoint(x: bodyX, y: topY + wingRadius),
            control: CGPoint(x: bodyX, y: topY)
        )
        path.addLine(to: CGPoint(x: bodyX, y: topY))
        path.closeSubpath()
        return path
    }
}
