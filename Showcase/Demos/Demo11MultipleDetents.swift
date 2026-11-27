import UIKit
import NativeBottomSheet

final class MultipleDetentsDemo: DemoViewController {
    private let detents: BottomSheetSizing = .detents([.fixed(160), .dynamic(maxHeight: 300), .medium, .fractional(0.75), .large])
    private var detentButtons = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        addButton("Present 5 detents") { [weak self] in
            guard let self else { return }
            present(StackContentView((1...14).map { makeLabel("Row \($0)") }), sizing: detents)
        }

        addButton("Present solid background, fixed(300)") { [weak self] in
            guard let self else { return }
            var solid = configuration
            solid.backgroundColor = .systemIndigo
            solid.cornerRadius = 24
            solid.grabberColor = .white
            BottomSheet.present(content: StackContentView([makeLabel("Solid background", style: .headline, color: .white)]), sizing: .fixed(300), configuration: solid, from: self)
        }

        addHeader("Select a detent in code")
        detentButtons.spacing = 8
        detentButtons.distribution = .fillEqually
        for (index, name) in ["160", "dyn", "med", "75%", "large"].enumerated() {
            detentButtons.addArrangedSubview(makeButton(name) { [weak self] in self?.sheet?.selectDetent(at: index) })
        }
        controls.addArrangedSubview(detentButtons)

        addHeader("Appearance")
        addToggle("Grabber", isOn: configuration.showsGrabber) { $0.showsGrabber = $1 }
        addToggle("Dim background", isOn: configuration.dimsBackground) { $0.dimsBackground = $1 }
        addToggle("Interactive dismissal", isOn: configuration.allowsInteractiveDismissal) { $0.allowsInteractiveDismissal = $1 }
        addToggle("Scroll expands sheet", isOn: configuration.prefersScrollingExpandsWhenScrolledToEdge) {
            $0.prefersScrollingExpandsWhenScrolledToEdge = $1
        }
        let radius = UISegmentedControl(items: ["System", "8", "24", "40"])
        radius.selectedSegmentIndex = 0
        radius.addAction(UIAction { [weak self, unowned radius] _ in
            self?.update { $0.cornerRadius = [nil, 8, 24, 40][radius.selectedSegmentIndex] }
        }, for: .valueChanged)
        addRow("Corner radius", radius)
        let background = UISegmentedControl(items: ["System", "Yellow"])
        background.selectedSegmentIndex = 0
        background.addAction(UIAction { [weak self, unowned background] _ in
            self?.update { $0.backgroundColor = background.selectedSegmentIndex == 0 ? nil : .systemYellow.withAlphaComponent(0.3) }
        }, for: .valueChanged)
        addRow("Background", background)
    }

    private func addToggle(_ title: String, isOn: Bool, _ change: @escaping (inout BottomSheetConfiguration, Bool) -> Void) {
        let toggle = UISwitch()
        toggle.isOn = isOn
        toggle.addAction(UIAction { [weak self, unowned toggle] _ in
            self?.update { change(&$0, toggle.isOn) }
        }, for: .valueChanged)
        addRow(title, toggle)
    }

    private func update(_ change: (inout BottomSheetConfiguration) -> Void) {
        change(&configuration)
        sheet?.configuration = configuration
    }
}
