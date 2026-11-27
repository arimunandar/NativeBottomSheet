import UIKit

/// How a sheet gets its height. All heights are detent heights, and none reaches the system maximum.
public enum BottomSheetSizing: Equatable, CustomStringConvertible {
    /// Fixed sheet height in points, including the safe area. Clamped to the maximum.
    case fixed(CGFloat)
    /// Follows the content height, clamped between `minHeight` and `maxHeight`.
    /// A nil `maxHeight` means the system maximum.
    case dynamic(minHeight: CGFloat = 0, maxHeight: CGFloat? = nil)
    /// Fraction of the maximum detent height.
    case fractional(CGFloat)
    case medium
    case large
    /// Several detents in ascending height. The user can drag between them.
    case detents([BottomSheetSizing])

    /// The detents this sizing produces. Nested `.detents` are flattened.
    var detentList: [BottomSheetSizing] {
        guard case .detents(let list) = self else { return [self] }
        let flat = list.flatMap { $0.detentList }
        return flat.isEmpty ? [.large] : flat
    }

    /// The same sizing with every number made safe. NaN and negative heights become 0 and fractions stay in 0...1.
    /// Infinity stays: it means "as tall as possible".
    var sanitized: BottomSheetSizing {
        func height(_ value: CGFloat) -> CGFloat { value.isNaN ? 0 : max(value, 0) }
        switch self {
        case .fixed(let value):
            return .fixed(height(value))
        case .dynamic(let minHeight, let maxHeight):
            return .dynamic(minHeight: height(minHeight), maxHeight: maxHeight.flatMap { $0.isNaN ? nil : max($0, 0) })
        case .fractional(let fraction):
            return .fractional(fraction.isNaN ? 0 : min(max(fraction, 0), 1))
        case .medium, .large:
            return self
        case .detents(let list):
            return .detents(list.map(\.sanitized))
        }
    }

    var followsContent: Bool {
        detentList.contains { if case .dynamic = $0 { return true } else { return false } }
    }

    public var description: String {
        switch self {
        case .fixed(let h): return h.isFinite ? "fixed(\(Int(h)))" : "fixed(max)"
        case .dynamic(let min, let max): return "dynamic(min: \(Int(min)), max: \(max.map { String(Int($0)) } ?? "system"))"
        case .fractional(let f): return "fractional(\(f))"
        case .medium: return "medium"
        case .large: return "large"
        case .detents(let list): return "detents[\(list.map(\.description).joined(separator: ", "))]"
        }
    }
}
