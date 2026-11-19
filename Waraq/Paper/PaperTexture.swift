import SwiftUI
import UIKit

/// Procedural paper grain and fibres, generated once and tiled.
enum PaperTexture {
    static let grain: UIImage = makeGrain(size: 160, seed: 0x9E3779B9, fibres: 26)
    static let linen: UIImage = makeLinen(size: 96)

    private struct RNG {
        var state: UInt32
        mutating func next() -> UInt32 {
            state ^= state << 13
            state ^= state >> 17
            state ^= state << 5
            return state
        }
        mutating func unit() -> CGFloat { CGFloat(next() % 10_000) / 10_000 }
    }

    private static func makeGrain(size: Int, seed: UInt32, fibres: Int) -> UIImage {
        var rng = RNG(state: seed)
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        for i in 0..<(size * size) {
            let v = UInt8(rng.next() % 256)
            // premultiplied warm-grey speck with very low alpha
            let alpha = UInt8(Int(v) * 22 / 255)
            let base = UInt8(Int(alpha) * 92 / 255)
            pixels[i * 4 + 0] = base
            pixels[i * 4 + 1] = UInt8(Int(base) * 96 / 100)
            pixels[i * 4 + 2] = UInt8(Int(base) * 88 / 100)
            pixels[i * 4 + 3] = alpha
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        let cgImage: CGImage? = pixels.withUnsafeMutableBytes { buffer -> CGImage? in
            guard let ctx = CGContext(data: buffer.baseAddress, width: size, height: size, bitsPerComponent: 8,
                                      bytesPerRow: size * 4, space: cs, bitmapInfo: info) else { return nil }
            // fibres: short faint curved hairlines
            ctx.setLineCap(.round)
            for _ in 0..<fibres {
                let x = rng.unit() * CGFloat(size), y = rng.unit() * CGFloat(size)
                let len = 4 + rng.unit() * 10
                let angle = rng.unit() * .pi * 2
                ctx.setStrokeColor(UIColor(white: 0.45, alpha: 0.05 + rng.unit() * 0.05).cgColor)
                ctx.setLineWidth(0.4 + rng.unit() * 0.4)
                ctx.move(to: CGPoint(x: x, y: y))
                ctx.addQuadCurve(to: CGPoint(x: x + cos(angle) * len, y: y + sin(angle) * len),
                                 control: CGPoint(x: x + cos(angle + 0.6) * len * 0.5, y: y + sin(angle + 0.6) * len * 0.5))
                ctx.strokePath()
            }
            return ctx.makeImage()
        }
        guard let cg = cgImage else { return UIImage() }
        return UIImage(cgImage: cg, scale: 2, orientation: .up)
    }

    /// Woven texture for cloth/leather covers.
    private static func makeLinen(size: Int) -> UIImage {
        var rng = RNG(state: 0x1234567)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let s = CGFloat(size)
        return UIGraphicsImageRenderer(size: CGSize(width: s, height: s), format: format).image { c in
            let ctx = c.cgContext
            for i in stride(from: 0, to: size, by: 2) {
                let a = 0.025 + rng.unit() * 0.04
                ctx.setFillColor(UIColor(white: rng.unit() > 0.5 ? 1 : 0, alpha: a).cgColor)
                ctx.fill(CGRect(x: 0, y: CGFloat(i), width: s, height: 1))
                let b = 0.02 + rng.unit() * 0.035
                ctx.setFillColor(UIColor(white: rng.unit() > 0.5 ? 1 : 0, alpha: b).cgColor)
                ctx.fill(CGRect(x: CGFloat(i), y: 0, width: 1, height: s))
            }
        }
    }
}

struct PaperGrainView: View {
    var opacity: Double = 1
    var body: some View {
        Image(uiImage: PaperTexture.grain)
            .resizable(resizingMode: .tile)
            .opacity(opacity)
            .allowsHitTesting(false)
    }
}

struct LinenView: View {
    var opacity: Double = 1
    var body: some View {
        Image(uiImage: PaperTexture.linen)
            .resizable(resizingMode: .tile)
            .opacity(opacity)
            .allowsHitTesting(false)
    }
}
