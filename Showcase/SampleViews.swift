import UIKit

func makeLabel(_ text: String, style: UIFont.TextStyle = .body, color: UIColor = .label) -> UILabel {
    let label = UILabel()
    label.text = text
    label.font = .preferredFont(forTextStyle: style)
    label.adjustsFontForContentSizeCategory = true
    label.textColor = color
    label.numberOfLines = 0
    return label
}

func makeButton(_ title: String, action: @escaping () -> Void) -> UIButton {
    var configuration = UIButton.Configuration.bordered()
    configuration.title = title
    return UIButton(configuration: configuration, primaryAction: UIAction { _ in action() })
}

let loremIpsum = "Native sheets resize through detents. The sheet asks each custom detent for a height whenever it is invalidated. This paragraph is long enough to wrap over several lines, so the measured height depends on the available width."

/// A padded vertical stack. Its height comes only from Auto Layout, so the sheet can measure it.
class StackContentView: UIView {
    let stack = UIStackView()

    init(_ arrangedSubviews: [UIView] = [], spacing: CGFloat = 12) {
        super.init(frame: .zero)
        stack.axis = .vertical
        stack.spacing = spacing
        arrangedSubviews.forEach(stack.addArrangedSubview)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
