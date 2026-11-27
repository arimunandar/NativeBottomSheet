import UIKit
import NativeBottomSheet

final class KeyboardFormDemo: DemoViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        addHeader("Tap a field to show the keyboard")
        addButton("Form, dynamic()") { [weak self] in self?.present(FormView(fields: 3), sizing: .dynamic()) }
        addButton("Form, fixed(300)") { [weak self] in self?.present(FormView(fields: 3), sizing: .fixed(300)) }
        addButton("Form, medium") { [weak self] in self?.present(FormView(fields: 3), sizing: .medium) }
        addButton("Growing text view, dynamic()") { [weak self] in
            self?.present(FormView(fields: 1, growingTextView: true), sizing: .dynamic())
        }
        addButton("Growing text view, dynamic(max 400)") { [weak self] in
            self?.present(FormView(fields: 1, growingTextView: true), sizing: .dynamic(maxHeight: 400))
        }
        addButton("Long form (10 fields), dynamic(max 400)") { [weak self] in
            self?.present(FormView(fields: 10), sizing: .dynamic(maxHeight: 400))
        }
    }
}

private final class FormView: StackContentView, UITextFieldDelegate {
    /// A growing text view has no scrolling of its own, so every new line makes it taller.
    init(fields: Int, growingTextView: Bool = false) {
        super.init([makeLabel("Form", style: .headline)])
        for index in 1...fields {
            let field = UITextField()
            field.borderStyle = .roundedRect
            field.placeholder = "Field \(index)"
            field.delegate = self
            stack.addArrangedSubview(field)
        }
        let textView = UITextView()
        textView.font = .preferredFont(forTextStyle: .body)
        textView.layer.borderColor = UIColor.separator.cgColor
        textView.layer.borderWidth = 1
        textView.layer.cornerRadius = 8
        if growingTextView {
            textView.isScrollEnabled = false
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true
        } else {
            textView.heightAnchor.constraint(equalToConstant: 80).isActive = true
        }
        stack.addArrangedSubview(textView)
        stack.addArrangedSubview(makeButton("Done") { [weak self] in self?.endEditing(true) })
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
