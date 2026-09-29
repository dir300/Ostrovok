import AppKit
import SwiftUI

/// Two colors pulled from the artwork: one for the progress bar, one for accents.
struct ArtworkPalette: Equatable {
    var primary: NSColor
    var secondary: NSColor

    var primaryColor: Color { Color(nsColor: primary) }
    var secondaryColor: Color { Color(nsColor: secondary) }

    static let fallback = ArtworkPalette(
        primary: NSColor(white: 0.92, alpha: 1),
        secondary: NSColor(white: 0.75, alpha: 1)
    )
}

/// Hue histogram over a small thumbnail of the artwork.
///
/// Averaging colors doesn't work (always a muddy gray): we want the most
/// saturated hue, then a second one far away from it on the color wheel.
enum PaletteExtractor {
    private static let sample = 24
    private static let buckets = 12

    static func palette(from image: NSImage) -> ArtworkPalette {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return .fallback
        }

        let side = sample
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = CGContext(
            data: &pixels,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return .fallback }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        var weight = [Double](repeating: 0, count: buckets)
        var sum = [(r: Double, g: Double, b: Double)](repeating: (0, 0, 0), count: buckets)

        for index in stride(from: 0, to: pixels.count, by: 4) {
            let r = Double(pixels[index]) / 255
            let g = Double(pixels[index + 1]) / 255
            let b = Double(pixels[index + 2]) / 255
            let (h, s, v) = hsb(r: r, g: g, b: b)

            // Background black and texture gray just dirty the math.
            guard v > 0.15, s > 0.2 else { continue }

            let bucket = min(buckets - 1, Int(h * Double(buckets)))
            let w = s * v
            weight[bucket] += w
            sum[bucket].r += r * w
            sum[bucket].g += g * w
            sum[bucket].b += b * w
        }

        let ordered = weight.indices.sorted { weight[$0] > weight[$1] }
        guard let best = ordered.first, weight[best] > 0 else { return .fallback }

        let primary = enhance(average(sum[best], weight[best]))

        // A second color only counts if it's another hue AND has real weight.
        let alternative = ordered.dropFirst().first { bucket in
            weight[bucket] >= weight[best] * 0.25 && bucketDistance(bucket, best) >= 2
        }
        let secondary = alternative.map { enhance(average(sum[$0], weight[$0])) }
            ?? lighten(primary)

        return ArtworkPalette(primary: primary, secondary: secondary)
    }

    private static func average(_ sum: (r: Double, g: Double, b: Double), _ weight: Double) -> NSColor {
        NSColor(
            srgbRed: CGFloat(sum.r / weight),
            green: CGFloat(sum.g / weight),
            blue: CGFloat(sum.b / weight),
            alpha: 1
        )
    }

    /// On a black background a washed-out color disappears; enforce a floor of
    /// saturation and brightness.
    private static func enhance(_ color: NSColor) -> NSColor {
        guard let rgb = color.usingColorSpace(.sRGB) else { return color }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        rgb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return NSColor(hue: h, saturation: max(s, 0.5), brightness: max(b, 0.78), alpha: 1)
    }

    /// Lighter variation of the same color, for monochromatic artwork.
    private static func lighten(_ color: NSColor) -> NSColor {
        guard let rgb = color.usingColorSpace(.sRGB) else { return color }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        rgb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return NSColor(hue: h, saturation: s * 0.45, brightness: min(1, b + 0.15), alpha: 1)
    }

    private static func bucketDistance(_ a: Int, _ b: Int) -> Int {
        let raw = abs(a - b)
        return min(raw, buckets - raw)
    }

    private static func hsb(r: Double, g: Double, b: Double) -> (Double, Double, Double) {
        let maxValue = max(r, g, b)
        let minValue = min(r, g, b)
        let delta = maxValue - minValue
        var h = 0.0
        if delta > 0 {
            if maxValue == r {
                h = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxValue == g {
                h = (b - r) / delta + 2
            } else {
                h = (r - g) / delta + 4
            }
            h /= 6
            if h < 0 { h += 1 }
        }
        return (h, maxValue == 0 ? 0 : delta / maxValue, maxValue)
    }
}
