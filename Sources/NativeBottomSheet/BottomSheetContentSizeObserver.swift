import UIKit

/// Detects content changes and reports them at most once per run loop turn.
@MainActor
final class BottomSheetContentSizeObserver {
    var onChange: (() -> Void)?
    private var tokens: [NSKeyValueObservation] = []
    private var isScheduled = false

    /// Automatic: reports every `contentSize` height change of the scroll view.
    func observe(_ scrollView: UIScrollView) {
        let token = scrollView.observe(\.contentSize, options: [.old, .new]) { [weak self] _, change in
            guard change.oldValue?.height != change.newValue?.height else { return }
            MainActor.assumeIsolated { self?.contentDidChange() }
        }
        tokens.append(token)
    }

    /// Manual: call when a change cannot be seen automatically.
    func contentDidChange() {
        guard !isScheduled else { return }
        isScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            isScheduled = false
            onChange?()
        }
    }
}
