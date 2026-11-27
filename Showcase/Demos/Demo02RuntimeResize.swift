import UIKit
import NativeBottomSheet

final class RuntimeResizeDemo: DemoViewController {
    private var height: CGFloat = 300
    private let animatedSwitch = UISwitch()
    private let slider = UISlider()
    private let valueLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        animatedSwitch.isOn = true
        addButton("Present at 300 pt") { [weak self] in self?.presentSheet() }
        addHeader("Update the presented sheet")
        addButton("+ 50 pt") { [weak self] in self?.update(by: 50) }
        addButton("− 50 pt") { [weak self] in self?.update(by: -50) }
        addButton("Burst: 20 updates in one turn") { [weak self] in
            guard let self else { return }
            for step in 1...20 { set(150 + CGFloat(step) * 20) }
        }
        addRow("Animated", animatedSwitch)
        slider.minimumValue = 100
        slider.maximumValue = 900
        slider.value = Float(height)
        slider.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            sheet?.updateHeight(CGFloat(slider.value), animated: false)
            valueLabel.text = "\(Int(slider.value)) pt"
        }, for: .valueChanged)
        controls.addArrangedSubview(slider)
        valueLabel.text = "\(Int(height)) pt"
        valueLabel.textAlignment = .center
        controls.addArrangedSubview(valueLabel)
    }

    private func presentSheet() {
        // A text field, a switch and a counter show that content state survives resizing.
        let field = UITextField()
        field.borderStyle = .roundedRect
        field.placeholder = "Type here. The text must survive resizing."
        let counter = makeButton("Taps: 0") {}
        var taps = 0
        counter.addAction(UIAction { _ in
            taps += 1
            counter.configuration?.title = "Taps: \(taps)"
        }, for: .touchUpInside)
        let content = StackContentView([makeLabel("Runtime resize", style: .headline), field, counter, UISwitch()])
        present(content, sizing: .fixed(height))
    }

    private func update(by delta: CGFloat) { set(max(height + delta, 50)) }

    private func set(_ newHeight: CGFloat) {
        height = newHeight
        slider.value = Float(newHeight)
        valueLabel.text = "\(Int(newHeight)) pt"
        sheet?.updateHeight(newHeight, animated: animatedSwitch.isOn)
    }
}
