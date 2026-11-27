import UIKit
import NativeBottomSheet

final class ExpandableDemo: DemoViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        addHeader("Sections animate open. The sheet follows.")
        addButton("Present expandable content", prominent: true) { [weak self] in
            self?.present(ExpandableContentView(), sizing: .dynamic())
        }
    }
}

private final class ExpandableContentView: StackContentView {
    private var bodies: [UILabel] = []

    init() {
        super.init([makeLabel("Expandable content", style: .headline)], spacing: 8)
        for index in 1...3 {
            let body = makeLabel(loremIpsum + " " + loremIpsum, style: .callout, color: .secondaryLabel)
            body.isHidden = true
            bodies.append(body)
            let header = makeButton("Section \(index)") { [weak self] in self?.toggle(body) }
            stack.addArrangedSubview(header)
            stack.addArrangedSubview(body)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func toggle(_ body: UILabel) {
        UIView.animate(withDuration: 0.3) {
            body.isHidden.toggle()
            body.alpha = body.isHidden ? 0 : 1
            self.superview?.layoutIfNeeded()
        }
    }
}
