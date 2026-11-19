import CoreGraphics
import simd

/// Mirrors `CurlUniforms` in PageCurl.metal — keep the field order identical.
struct CurlUniforms {
    var viewSize: SIMD2<Float> = .zero
    var pageOrigin: SIMD2<Float> = .zero
    var pageSize: SIMD2<Float> = .zero
    var linePoint: SIMD2<Float> = .zero
    var lineNormal: SIMD2<Float> = SIMD2(1, 0)
    var radius: Float = 0
    var mirror: Float = 0
    var zScale: Float = 0.0018
    var shadowStrength: Float = 0
    var backTint: SIMD4<Float> = SIMD4(1, 1, 1, 1)
}

/// Geometry of a sheet being turned, in logical page space:
/// spine at x = 0, the turned (free) edge at x = width, y downward.
///
/// The model is a cylinder fold: the part of the sheet beyond the curl line wraps
/// around a cylinder of radius `r` and lies back over the page. The line is placed so that
/// the grabbed point lands exactly under the finger.
enum CurlGeometry {
    struct Line {
        var point: CGPoint
        var normal: CGVector
    }

    /// The sheet stays attached to the spine: the finger can't pull a point further
    /// from the spine's top or bottom corner than it was.
    static func constrain(_ f: CGPoint, grab a: CGPoint, size: CGSize) -> CGPoint {
        var p = f
        let top = CGPoint(x: 0, y: 0)
        let bottom = CGPoint(x: 0, y: size.height)
        for _ in 0..<2 {
            for anchor in [top, bottom] {
                let limit = hypot(a.x - anchor.x, a.y - anchor.y)
                let dx = p.x - anchor.x, dy = p.y - anchor.y
                let d = hypot(dx, dy)
                if d > limit, d > 0.0001 {
                    p = CGPoint(x: anchor.x + dx / d * limit, y: anchor.y + dy / d * limit)
                }
            }
        }
        return p
    }

    static func line(grab a: CGPoint, finger f: CGPoint, radius r: CGFloat) -> Line {
        let vx = a.x - f.x, vy = a.y - f.y
        let dist = hypot(vx, vy)
        let n = dist > 0.5 ? CGVector(dx: vx / dist, dy: vy / dist) : CGVector(dx: 1, dy: 0)
        let mid = CGPoint(x: (a.x + f.x) / 2, y: (a.y + f.y) / 2)
        let shift = CGFloat.pi * r / 2
        return Line(point: CGPoint(x: mid.x - n.dx * shift, y: mid.y - n.dy * shift), normal: n)
    }
}
