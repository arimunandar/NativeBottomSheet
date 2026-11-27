import UIKit
import NativeBottomSheet

final class StressTestDemo: DemoViewController {
    private let result = makeLabel("No run yet", style: .footnote, color: .secondaryLabel)
    private var isRunning = false

    override func viewDidLoad() {
        super.viewDidLoad()
        addButton("100 animated updates (20 ms apart)") { [weak self] in self?.run { await self?.heightUpdates(animated: true, spacing: 20_000_000) } }
        addButton("100 non-animated updates (one loop)") { [weak self] in self?.run { await self?.heightUpdates(animated: false, spacing: 0) } }
        addButton("100 present + dismiss cycles") { [weak self] in self?.run { await self?.presentCycles() } }
        controls.addArrangedSubview(result)
    }

    private func run(_ work: @escaping () async -> Void) {
        guard !isRunning else { return }
        isRunning = true
        Task { @MainActor in
            await work()
            isRunning = false
        }
    }

    private func heightUpdates(animated: Bool, spacing: UInt64) async {
        present(StackContentView([makeLabel("Stress test", style: .headline), makeLabel(loremIpsum)]), sizing: .fixed(300))
        try? await Task.sleep(nanoseconds: 800_000_000)
        guard let sheet, let before = sheet.diagnostics else { return }
        let start = CACurrentMediaTime()
        for step in 0..<100 {
            sheet.updateHeight(CGFloat(150 + (step * 37) % 450), animated: animated)
            if spacing > 0 { try? await Task.sleep(nanoseconds: spacing) }
        }
        let elapsed = CACurrentMediaTime() - start
        try? await Task.sleep(nanoseconds: 600_000_000)
        guard let after = sheet.diagnostics else { return }
        result.text = String(format: "100 updates in %.2f s. Invalidations +%d, layout passes +%d. Final actual height %.1f, resolved %.1f.",
                             elapsed, after.invalidations - before.invalidations, after.layoutPasses - before.layoutPasses,
                             after.actualSheetHeight, after.resolvedDetentHeight ?? 0)
    }

    private func presentCycles() async {
        dismiss(animated: false)
        let start = CACurrentMediaTime()
        for _ in 0..<100 {
            await cycle()
        }
        let elapsed = CACurrentMediaTime() - start
        try? await Task.sleep(nanoseconds: 500_000_000)
        #if DEBUG
        result.text = String(format: "100 cycles in %.2f s. Live BottomSheetController instances: %d (expected 0).", elapsed, BottomSheet.liveSheetCount)
        #endif
    }

    private func cycle() async {
        await withCheckedContinuation { continuation in
            let content = StackContentView([makeLabel("Cycle", style: .headline), makeLabel(loremIpsum)])
            let handle = BottomSheet.present(content: content, from: self, animated: false) {
                self.dismiss(animated: false) { continuation.resume() }
            }
            _ = handle
        }
    }
}
