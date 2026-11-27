import UIKit
import NativeBottomSheet

final class AsyncContentDemo: DemoViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        addHeader("Content changes after presentation")
        addButton("Loading, then short content") { [weak self] in self?.show(paragraphs: 1) }
        addButton("Loading, then long content") { [weak self] in self?.show(paragraphs: 12) }
        addButton("Empty content") { [weak self] in self?.present(UIView(), sizing: .dynamic()) }
    }

    private func show(paragraphs: Int) {
        present(AsyncContentView(paragraphs: paragraphs), sizing: .dynamic())
    }
}

private final class AsyncContentView: StackContentView {
    private let spinner = UIActivityIndicatorView(style: .large)
    private let loading = makeLabel("Loading…", style: .callout, color: .secondaryLabel)
    private let paragraphs: Int

    init(paragraphs: Int) {
        self.paragraphs = paragraphs
        super.init(spacing: 16)
        spinner.startAnimating()
        loading.textAlignment = .center
        [spinner, loading].forEach(stack.addArrangedSubview)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self?.showLoaded()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func showLoaded() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        stack.addArrangedSubview(makeLabel("Loaded", style: .headline))
        for index in 1...paragraphs { stack.addArrangedSubview(makeLabel("\(index). " + loremIpsum, style: .callout)) }
    }
}
