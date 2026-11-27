import UIKit

/// Pure height math. It never touches the sheet.
@MainActor
struct BottomSheetHeightResolver {
    /// Natural detent height of the content at `width`.
    ///
    /// UIKit detent values do not include the bottom safe area (the sheet frame is the detent
    /// plus the bottom inset). Only `topInset` is added, because the content starts below it.
    ///
    /// - A scroll view reports its `contentSize`.
    /// - A view controller with a `preferredContentSize` height reports that height.
    /// - Everything else is measured with Auto Layout.
    func contentHeight(of content: BottomSheetContent, width: CGFloat, topInset: CGFloat) -> CGFloat {
        let view = content.view

        if let scrollView = content.scrollView {
            scrollView.layoutIfNeeded()
            let height = scrollView.contentSize.height + scrollView.contentInset.top + scrollView.contentInset.bottom + topInset
            // A scroll view with empty bounds can skip layout, so its contentSize stays 0 and the sheet
            // could never grow. Never report less than 1 pt. The real size then arrives by observation.
            return max(height, 1)
        }
        if case .viewController(let controller) = content, controller.preferredContentSize.height > 0 {
            return controller.preferredContentSize.height + topInset
        }
        let fitting = view.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return max(fitting.height + topInset, 0)
    }

    /// The detent height for one custom detent. Never reaches `maximum`.
    ///
    /// At exactly the maximum height, UIKit pushes the page behind the sheet back (the stack effect).
    /// One point less keeps the sheet visually full height and the page in place.
    func detentHeight(for sizing: BottomSheetSizing, contentHeight: CGFloat, maximum: CGFloat) -> CGFloat {
        let limit = max(maximum - 1, 0)
        switch sizing {
        case .fixed(let height):
            return min(height, limit)
        case .dynamic(let minHeight, let maxHeight):
            let upper = min(maxHeight ?? limit, limit)
            let lower = min(minHeight, upper)
            return min(max(contentHeight, lower), upper)
        case .fractional(let fraction):
            return limit * min(max(fraction, 0), 1)
        case .large, .medium, .detents:
            return limit
        }
    }
}
