import UIKit
import NativeBottomSheet

final class DynamicViewDemo: DemoViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        addHeader("Height follows the view. Changes are observed automatically.")
        addButton("Present dynamic()", prominent: true) { [weak self] in
            self?.present(DynamicRowsView(), sizing: .dynamic())
        }
        addButton("Present dynamic(min 200, max 400)", prominent: true) { [weak self] in
            self?.present(DynamicRowsView(), sizing: .dynamic(minHeight: 200, maxHeight: 400))
        }
    }
}

private final class DynamicRowsView: StackContentView {
    private let rows = UIStackView()
    private let banner = makeLabel("Hidden banner. Showing it changes the height.", style: .callout, color: .systemOrange)
    private var count = 0

    init() {
        super.init([makeLabel("Dynamic UIView", style: .headline), makeLabel(loremIpsum, style: .callout)])
        rows.axis = .vertical
        rows.spacing = 8
        banner.isHidden = true
        let buttons = UIStackView(arrangedSubviews: [
            makeButton("Add") { [weak self] in self?.addRow() },
            makeButton("Remove") { [weak self] in self?.rows.arrangedSubviews.last?.removeFromSuperview() },
            makeButton("Banner") { [weak self] in self?.banner.isHidden.toggle() },
        ])
        buttons.distribution = .fillEqually
        buttons.spacing = 8
        [buttons, banner, rows].forEach(stack.addArrangedSubview)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func addRow() {
        count += 1
        rows.addArrangedSubview(makeLabel("Row \(count). " + String(repeating: "More text. ", count: count % 4 * 3)))
    }
}
