import UIKit
import NativeBottomSheet

final class ScrollableDemo: DemoViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        addHeader("Natural height is taller than the maximum")
        addButton("Tall UIView, max 400 (sheet scrolls it)") { [weak self] in
            self?.present(Self.makeRows(), sizing: .dynamic(maxHeight: 400))
        }
        addButton("UIScrollView content, max 400") { [weak self] in
            self?.present(Self.makeScrollView(), sizing: .dynamic(maxHeight: 400))
        }
        addButton("UIScrollView content, system maximum") { [weak self] in
            self?.present(Self.makeScrollView(), sizing: .dynamic())
        }
    }

    private static func makeRows() -> UIView {
        StackContentView((1...30).map { makeLabel("Row \($0)") })
    }

    private static func makeScrollView() -> UIScrollView {
        let scrollView = UIScrollView()
        let stack = UIStackView(arrangedSubviews: (1...30).map { makeLabel("Scroll row \($0)") })
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),
        ])
        return scrollView
    }
}
