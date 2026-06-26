import Foundation

/// One ping result. Either a successful round-trip time in milliseconds,
/// or a dropped packet (timeout / unreachable / no reply).
enum Sample: Equatable {
    case latency(Double)   // round-trip time in milliseconds
    case dropped

    var ms: Double? {
        if case .latency(let value) = self { return value }
        return nil
    }
}
