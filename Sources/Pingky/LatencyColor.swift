import SwiftUI

enum LatencyColor {
    /// Latency at or above this (ms) is fully red.
    static let redThreshold: Double = 1000

    /// Color used for dropped-packet boxes.
    static let droppedColor = Color.black

    /// Maps a sample to its fill color.
    /// 0 ms -> green, `redThreshold` ms or more -> red, gradient between
    /// (green -> yellow -> red via HSV hue interpolation).
    static func color(for sample: Sample) -> Color {
        switch sample {
        case .dropped:
            return droppedColor
        case .latency(let ms):
            let frac = min(max(ms, 0), redThreshold) / redThreshold
            // Hue 0.33 (~green) down to 0.0 (red).
            let hue = (1 - frac) * 0.33
            return Color(hue: hue, saturation: 0.85, brightness: 0.9)
        }
    }
}
