# NativeBottomSheet

A bottom sheet for UIKit. It uses `UISheetPresentationController`, so it looks and feels native.
The sheet follows the height of your content, and you can resize it while it is shown.

- Swift Package. UIKit only. No dependencies. No private APIs. No method swizzling.
- iOS 16.0 or later.
- Needs Xcode 26.1 to get the solid background color on iOS 26. Older Xcode builds the package without it.

## Install

In Xcode: **File → Add Package Dependencies**, then enter the URL of this repository.

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/arimunandar/NativeBottomSheet.git", from: "0.1.0"),
],
targets: [
    .target(name: "MyApp", dependencies: [.product(name: "NativeBottomSheet", package: "NativeBottomSheet")]),
]
```

For a local copy, use `.package(path: "../NativeBottomSheet")`.

## Quick start

```swift
import NativeBottomSheet

BottomSheet.present(content: myView, from: self)
```

That is all. The sheet is as tall as `myView`, and it grows or shrinks when `myView` changes.

More examples:

```swift
// An existing view controller, fixed height
BottomSheet.present(content: viewController, sizing: .fixed(300), from: self)

// Follow the content, but keep it between 200 and 400 points
BottomSheet.present(content: myView, sizing: .dynamic(minHeight: 200, maxHeight: 400), from: self)

// A table view, a collection view or a scroll view, as it is
BottomSheet.present(content: tableView, sizing: .dynamic(maxHeight: 450), from: self)

// Several detents. The list goes from small to large.
BottomSheet.present(content: myView, sizing: .detents([.fixed(160), .medium, .large]), from: self)
```

## How to use

This is a full walk-through. Each step builds on the one before.

### 1. Add the package

Add `NativeBottomSheet` to your app (see [Install](#install)). Then import it where you present sheets:

```swift
import UIKit
import NativeBottomSheet
```

### 2. Make the content

The content is any `UIView` or `UIViewController`. The sheet needs to know its height.
So the view must get its height from Auto Layout, with constraints from the top edge to the bottom edge:

```swift
final class DetailsView: UIView {
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()

    init(title: String, body: String) {
        super.init(frame: .zero)
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        bodyLabel.text = body
        bodyLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),   // top to bottom
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(body: String) { bodyLabel.text = body }   // the sheet follows this change
}
```

You do not set a width or a height on the view. The sheet gives it the width.

### 3. Present it

Call `BottomSheet.present` from a view controller that is on screen.
Keep the returned handle in a property if you want to change the sheet later.

```swift
final class ProductViewController: UIViewController {
    private var sheet: BottomSheet?

    func showDetails() {
        let details = DetailsView(title: "Details", body: "Some text.")
        sheet = BottomSheet.present(content: details, sizing: .dynamic(maxHeight: 500), from: self)
    }
}
```

The sheet is as tall as the view, but never taller than 500 points. If the view is taller, it scrolls.

### 4. Present a table, a collection or a scroll view

Pass a `UITableViewController`, a `UICollectionViewController`, or the scroll view itself.
Do not put the table inside another view. The sheet reads the `contentSize` of the scroll view you pass.

```swift
BottomSheet.present(content: FruitsViewController(), sizing: .dynamic(maxHeight: 450), from: self)
```

When you pass a plain `UITableView`, remember that `dataSource` and `delegate` are weak.
Keep your own strong reference to them.

```swift
let tableView = UITableView()
tableView.dataSource = source          // `source` must be kept alive by you
BottomSheet.present(content: tableView, sizing: .dynamic(maxHeight: 450), from: self)
```

Rows you insert or remove change the sheet height by themselves.

### 5. Change the content later

Change the content as you normally do. The sheet follows it. You write nothing for this:

```swift
detailsView.update(body: "A much longer text that needs more lines.")   // the sheet grows
```

Call `sheet?.invalidateContentHeight()` only when the content changes its height without a layout pass,
for example with frame-based layout.

### 6. Change the sheet

```swift
sheet?.updateHeight(400, animated: true)       // a fixed height of 400
sheet?.setSizing(.dynamic())                   // follow the content again
sheet?.dismiss(animated: true)
```

### 7. Change the look

```swift
var configuration = BottomSheetConfiguration(cornerRadius: 24, showsGrabber: true)
configuration.backgroundColor = .systemIndigo   // solid
configuration.grabberColor = .white
BottomSheet.present(content: details, sizing: .fixed(300), configuration: configuration, from: self)
```

### Common mistakes

| Mistake | What happens | Fix |
|---|---|---|
| The view has no constraint from top to bottom | The content measures 0 points. The sheet is only a thin strip (34 points on an iPhone with a home indicator) | Constrain the content to the top and the bottom of the view, or set `minHeight` |
| A table view inside a plain view | The sheet does not see the rows | Pass the table view itself |
| A weak `dataSource` that nobody keeps | The table is empty | Keep a strong reference to the data source |
| Presenting from a controller that is not on screen | UIKit refuses to present | Present from `viewDidAppear` or later |
| Detents from large to small | UIKit expects them from small to large. The library does not check the order | List them from small to large |
| Setting `UIDesignRequiresCompatibility` only for this library | The whole app loses the iOS 26 look | Do not set it. Accept the small gap of floating sheets on iOS 26 |

## Control the sheet

`present` returns a handle. Keep it if you want to change the sheet later.
The handle holds the sheet weakly. It never keeps the sheet alive, and its calls do nothing after the sheet is dismissed.

```swift
let sheet = BottomSheet.present(content: myView, from: self)

sheet.updateHeight(400, animated: true)   // becomes .fixed(400). The sheet is not presented again.
sheet.setSizing(.dynamic(maxHeight: 500))
sheet.invalidateContentHeight()           // only for changes the sheet cannot see
sheet.selectDetent(at: 1)                 // with .detents([...])
sheet.dismiss(animated: true)
```

## Sizing

| Case | Meaning |
|---|---|
| `.dynamic(minHeight:maxHeight:)` | Follows the content, inside the limits. This is the default. |
| `.fixed(h)` | `h` points. |
| `.fractional(f)` | `f` times the maximum height. |
| `.medium` | The system medium detent. |
| `.large` | Full height. |
| `.detents([...])` | Several of the above. The user can drag between them. |

Heights are detent heights. The sheet frame is taller by the bottom safe area when it is edge-attached.
No height reaches the system maximum. It stops 1 point short, so UIKit does not push the page behind the sheet back.

## Appearance

```swift
let configuration = BottomSheetConfiguration(
    cornerRadius: 24,
    showsGrabber: true,
    allowsInteractiveDismissal: true,
    prefersScrollingExpandsWhenScrolledToEdge: false,
    backgroundColor: .systemIndigo,   // solid. On iOS 26.1 and later it replaces the glass background
    dimsBackground: false,            // the screen behind stays usable
    grabberColor: .white              // UIKit has no grabber color, so the library draws this grabber
)
BottomSheet.present(content: myView, configuration: configuration, from: self)
```

Every option is optional. You can change the configuration while the sheet is shown: `sheet.configuration = configuration`.

## What the content must do

| Content | How the height is found |
|---|---|
| A `UIView`, or a view controller | Auto Layout, from top to bottom. The view must define its own height. |
| A view controller with `preferredContentSize` | The height of `preferredContentSize`, if it is above 0. |
| A `UIScrollView`, `UITableView`, `UICollectionView`, or their controllers | The `contentSize`. Pass the scroll view itself, not a view that contains it. |

If the content is taller than the maximum, it scrolls.

### What the sheet follows by itself

- Auto Layout changes: text, hidden views, added and removed views, Dynamic Type.
- `contentSize` changes of a scroll view.
- A change of the sheet width, for example after rotation.
- A change of `preferredContentSize` on a view controller.

Call `sheet.invalidateContentHeight()` after a change that needs no layout pass, such as frame-based layout.

## Edge cases

- **Bad numbers.** `NaN` and negative heights become 0. Fractions stay between 0 and 1. Infinity means as tall as possible.
- **Reusing content.** After the sheet is dismissed, the library gives the view or controller back. You can present it again.
  If it still sits in another parent, the library moves it into the sheet. A sheet that shows it at the same time loses it.
- **Content that cannot work.** The presenter itself, one of its parents, or a controller that is presented elsewhere is refused.
  The handle does nothing, and your completion still runs.
- **A busy presenter.** If the presenter already presents something, the sheet goes on top of it.
- **A gone sheet.** Calls on the handle do nothing, and `dismiss(animated:completion:)` still runs your completion.
- **Order of detents.** The list must go from small to large. The library cannot check it.
- **Landscape on iPhone.** UIKit turns the system `.medium` detent off there. Use `.fractional(0.5)` instead.

## Keyboard

You do not need code for it. UIKit makes the sheet taller while the keyboard is shown, and the library keeps the content above the keyboard.

## iOS 26

- Small sheets float with a gap on the sides and bottom. UIKit has no setting to remove it for one sheet.
  The Info.plist key `UIDesignRequiresCompatibility` removes it, but for the whole app, and Apple calls it temporary.
- `backgroundColor` is solid on iOS 26.1 and later. Before that, only the view color is used.

## Debug numbers

`sheet.diagnostics` and `sheet.onDiagnosticsChange` give the measured content height, the resolved detent height,
the actual sheet height, the maximum detent value, the layout passes and the invalidations.
In debug builds, `BottomSheet.liveSheetCount` tells you how many sheets are alive. It helps to find leaks.

## Showcase app

`BottomSheetPOC.xcodeproj` is a demo app with 12 screens. Open it and run it.
The `Showcase/` folder holds the screens. The project file is made from `project.yml` with XcodeGen.
Pass `-demo N` (1 to 12) as a launch argument to open a screen at launch.

The demo app sets `UIDesignRequiresCompatibility`. Your app does not need it.

## Limits and test results

See [FINDINGS.md](FINDINGS.md). It lists what was tested, what was not, and what differs from iOS 16.
It was tested on one simulator, iOS 26.3. iOS 16.0 and iPad are **not tested yet**.

## License

MIT. See [LICENSE](LICENSE).
