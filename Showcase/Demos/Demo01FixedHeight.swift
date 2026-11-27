import UIKit
import NativeBottomSheet

final class FixedHeightDemo: DemoViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        addHeader("Fixed height, including the bottom safe area")
        for height: CGFloat in [100, 200, 300, 500] {
            addButton("\(Int(height)) pt") { [weak self] in self?.show(height) }
        }
        addButton("Maximum available height") { [weak self] in self?.show(.infinity) }
        addButton("Large (full screen)") { [weak self] in
            self?.present(StackContentView([makeLabel("Large", style: .headline), makeLabel("Full screen. The page behind must stay in place.")]), sizing: .large)
        }
    }

    private func show(_ height: CGFloat) {
        let title = height.isFinite ? "Fixed \(Int(height)) pt" : "Maximum height"
        present(StackContentView([makeLabel(title, style: .headline), makeLabel("Short body text.")]), sizing: .fixed(height))
    }
}
