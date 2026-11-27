#if DEBUG
import UIKit

/// `-smoke YES` opens every demo and presses every button on its screen and in its sheet.
/// It prints one line per press. A crash ends the output, so the last line shows where it happened.
@MainActor
enum SmokeRunner {
    static func run(menu: MenuViewController) async {
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("smoke.log") {
            try? FileManager.default.removeItem(at: url)
        }
        for number in menu.demoNumbers {
            guard let screen = menu.showDemo(number) else { continue }
            await pause(0.8)
            let hostButtons = buttons(in: screen.view)
            log("[SMOKE] demo \(number): \(hostButtons.count) buttons")
            for (index, button) in hostButtons.enumerated() {
                log("[SMOKE] demo \(number) button \(index) \"\(button.configuration?.title ?? "?")\"")
                button.sendActions(for: .primaryActionTriggered)
                await pause(1.3)
                if let sheetView = screen.presentedViewController?.view {
                    for (inner, innerButton) in buttons(in: sheetView).enumerated() {
                        log("[SMOKE]   in the sheet \(inner) \"\(innerButton.configuration?.title ?? "?")\"")
                        innerButton.sendActions(for: .primaryActionTriggered)
                        await pause(0.9)
                    }
                }
                if screen.presentedViewController != nil {
                    screen.dismiss(animated: false)
                    await pause(0.4)
                }
            }
            menu.navigationController?.popViewController(animated: false)
            await pause(0.3)
        }
        log("[SMOKE] done")
    }

    private static func buttons(in view: UIView) -> [UIButton] {
        var result: [UIButton] = []
        for subview in view.subviews where !subview.isHidden {
            if let button = subview as? UIButton { result.append(button) }
            result += buttons(in: subview)
        }
        return result
    }

    /// Written at once, to the console and to `Documents/smoke.log`. The last line survives a crash.
    /// Copy the file from a device with `devicectl device copy from`.
    private static func log(_ line: String) {
        fputs(line + "\n", stderr)
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("smoke.log"),
              let data = (line + "\n").data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.synchronize()
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }

    private static func pause(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
#endif
