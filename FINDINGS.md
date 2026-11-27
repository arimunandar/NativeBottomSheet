# Findings

## How this was tested

| Item | Value |
|---|---|
| Device | iPhone 16 Pro simulator, iOS 26.3, dark mode |
| Build | Xcode 26.3, deployment target iOS 16.0. |
| Sheet look | Most tests ran in the default iOS 26 look. The project now sets `UIDesignRequiresCompatibility`, so sheets look like iOS 16 to 18 (finding 10). Measured heights can differ in that look. |
| Method | Drove the demos by hand through the simulator. Read the debug panel and screenshots. |

**Not tested:** iOS 16.0 (the runtime is not installed on this Mac), a small iPhone, iPad, light mode,
Instruments profiling, VoiceOver. Anything that depends on those is marked "not verified".

## Answers to the Definition of Done

1. **Can it update its height after presentation?** Yes. Demo 02 went from 300 to 350 pt without re-presenting. The text field, counter and switch kept their state.
2. **Can it fit UIView content?** Yes. Demos 03, 05 and 06 follow the view when it grows or shrinks.
3. **Can it fit UIViewController content?** Yes. Auto Layout, `preferredContentSize`, table and collection controllers all work (demos 04, 08, 09). The lifecycle stayed at one `viewWillAppear` and one `viewDidAppear` through three resizes.
4. **Is automatic resizing cheap?** Mostly. One content change gave one invalidation (demo 03: 1, demo 05: 1). 100 height updates gave 100 invalidations and about 2 layout passes each.
5. **Do scrolling, keyboard and gestures work with dynamic sizing?** Keyboard: yes (finding 2). Scrolling: yes (demos 07, 08, 09). Gesture conflicts with the sheet drag: not stress tested.
6. **iOS 16 limits?** Not verified on iOS 16. See "Open questions".
7. **Can it replace a custom sheet?** See the recommendation.

## Test results

| Demo | What I ran | Result |
|---|---|---|
| 01 Fixed | 100, 200, 300, 500 pt and maximum | Pass. Actual 100 / 234 / 334 / 534 (see finding 9 for 100). Maximum fills the screen. |
| 02 Resize | +50, +50, −50 animated. Burst of 20 updates, animated and not animated. | Pass. 350 pt after the steps, state kept. Both bursts ended at 550 with 20 invalidations. Layout passes: 44 animated, 4 not animated. Slider drag: requested 634.4, actual 668.3, 23 invalidations. |
| 03 UIView | Add a row | Pass. Measured 234 → 254.3 with 1 invalidation. Remove, banner and min/max **not run**. |
| 04 Controller | Present, then `preferredContentSize` 420, then back to Auto Layout | Pass. Measured 268.3 → 420 → 268.3. Lifecycle counters stayed at ×1. "Add text" **not run**. |
| 05 Expandable | Open a section | Pass. Measured 187.3 → 403.7. |
| 06 Async | Loading, then short content | Pass. Measured 179.7 after load. Long and empty content **not run**. |
| 07 Scrollable | Tall `UIView` (max 400). `UIScrollView` as content (max 400 and system maximum). | Pass. Measured 998, resolved 400, content scrolls. The system maximum case fills the screen. |
| 08 Table | Insert 10 rows, with a `UITableViewController` and with a plain `UITableView` | Pass for both. Measured 159 → 689, resolved 450, table scrolls. |
| 09 Collection | Add 8 items, with a `UICollectionViewController` and with a plain `UICollectionView` | Pass for both after a fix (findings 3 and 4). Measured 184 → 504, resolved 450. |
| 10 Keyboard | Focus field 3, tap Done | Pass. Sheet grew to 705.7 and returned to 370.7. |
| 10 Growing text view | 7 times Return | Pass. Measured 244.7 → 356.7. The caret stays visible. |
| 11 Detents | Select 160, dyn, med, 75% in code. Change grabber, background, corner radius, dimming. | Pass. 160 → actual 194, dyn → 334, 75% → resolved 583.5, actual 617.7. Options applied at once. Large detent fills the screen. Dismissal on: a drag down dismisses. Dismissal off: the sheet stays. Scroll-expands on: scrolling moved detent 0 (194) to 1 (334). Off: it stayed at 0. |
| 11 Solid sheet | Solid indigo color, corner radius 24, white grabber | Pass on iOS 26.3. Opaque, rounded corners, grabber visible. With the key: edge-to-edge. Without it: a gap of about 8 pt. |
| 01 Large | `.large` with the new 1 pt cap | Pass. Sheet is full height and the page behind stays in place. |
| 12 Stress | 100 animated updates, 20 ms apart | Pass. 2.54 s, +100 invalidations, +209 layout passes. Final actual 247 = requested 213 + 34. |
| 12 Stress | 100 present and dismiss cycles | Pass. 0 live `BottomSheetController` after the run. The time (45.8 s) is inflated, see finding 8. |
| Dynamic Type | Switch to accessibility size with the sheet open | Pass. The sheet grew to the system maximum. The content scrolls. |
| Rotation | Portrait to landscape with the sheet open | Pass. Remeasured for the new width: 234 → 192. No loop. |

## Findings

1. **Detent values do not include the bottom safe area.**
   For `fixed(300)` the sheet frame was 334 pt. The extra 34 pt is the bottom safe area.
   The maximum detent value was 778; the large sheet frame is 812.
   The component therefore adds only the top inset to the content height.
   Measured on iOS 26.3. **Not verified on iOS 16.**
   Apple documents this in the SDK header: the resolver value is a height inside the safe area.
   The sheet is that value plus the bottom inset when it is edge-attached, and just that value when it floats.
2. **The keyboard needs no code.**
   When the keyboard opens, UIKit makes the sheet taller by itself (370.7 → 705.7), whatever the detent.
   The sheet goes back after the keyboard closes. The component only keeps its content above the keyboard with `keyboardLayoutGuide`.
   This means the detent and the real height can differ while the keyboard is open. Do not use the real height for logic then.
3. **`UICollectionViewController.view` is a wrapper on iOS 26.3.**
   It is a `UICollectionViewControllerWrapperView` that contains the collection view. A cast to `UIScrollView` fails.
   The component asks the controller for `collectionView` and `tableView` first.
   Without this, the collection was measured as plain content and got a height of 0.
4. **A scroll view with a height of 0 can never grow.**
   A collection view with a compositional layout does not lay out in empty bounds, so its `contentSize` stays 0.
   Before the sheet is shown, the content is not in a window and its height is 0.
   The component reports at least 1 pt for scroll content. The sheet opens, the content lays out, and the size arrives by observation.
   **Effect:** table, collection and async content cause one extra invalidation right after the sheet appears.
   The sheet grows a little after it opens. It is not measured exactly before the first frame.
5. **Automatic or manual.**
   Automatic: Auto Layout changes, scroll view `contentSize`, width changes, Dynamic Type, `preferredContentSize` on an embedded controller.
   Manual (`invalidateContentHeight()`): changes with no layout pass, such as frame-based layout.
6. **Loops are stopped by comparing heights.**
   The sheet only invalidates when the measured height changes by 0.5 pt or more. The observer reports at most once per run loop turn.
   I saw no loop in any run. The layout count stayed low (3 to 13).
7. **`animateChanges` handled 100 updates in a row.**
   No crash, no wrong final height. I did not check visually for flicker. **Not verified.**
8. **Test tool side effect.**
   The `serve-sim` tool polls the accessibility tree and slowed the main thread. The first 100-cycle run looked stuck for 20 s.
   It finished after I stopped the tool. Timing numbers in this file were taken with the tool attached.
   A later 100-cycle run with the tool stopped right after the tap still took 44.25 s (about 0.44 s per cycle).
   So most of that time is UIKit present and dismiss work, not the tool.
9. **A 100 pt sheet has no extra bottom area.**
   For 160, 200, 300 and 500 pt the frame was the detent plus 34. For 100 pt the frame was exactly 100.
   The scroll area was then only 66 pt, so the second line of text was cut off.
   The header says a floating sheet gets no bottom inset, so the 100 pt sheet was probably floating. **Not verified on iOS 16.**
10. **Solid, edge-to-edge sheet on iOS 26.**
    On iOS 26 a small sheet floats with a gap on the sides and bottom, and has a glass background.
    A plain `backgroundColor` on the view is washed out by the glass, and the page behind shows through.
    - **Opaque color:** `UIColorEffect(color:)` on each detent (`Detent.backgroundEffect`, iOS 26.1 and later) gives a solid color.
      The component sets it from `BottomSheetConfiguration.backgroundColor`. Verified: no ghosting.
    - **Corner radius:** it works with the solid color. Radius 24 gave rounded corners. Radius 0 gave square corners.
      It does not change the gap. An earlier note here said radius 0 removed the gap. That was wrong.
    - **The gap cannot be removed per sheet.** A floating iOS 26 sheet keeps about 8 pt on the sides and bottom.
      The SDK has no setting to choose floating or edge-attached.
    - **App-wide option:** the Info.plist key `UIDesignRequiresCompatibility` turns the iOS 26 look off for the whole app.
      Sheets are then edge-attached with rounded top corners, as on iOS 16 to 18. Verified with the solid sheet and radius 24.
      This project sets the key. Apple describes it as temporary, so a future Xcode may ignore it.
    Before iOS 26.1 the color effect does not exist. There, only the view color is used, as on iOS 16.
11. **The grabber color cannot be changed.**
    UIKit has no API for it. When `grabberColor` is set, the component hides the system grabber and draws its own
    inside its own view. It is a 36 x 5 pt pill that takes no touches. Verified: a white grabber on a solid sheet.
12. **UIKit pushes the page back at full height.**
    In the pre-iOS-26 look, a sheet at exactly the maximum height scales the page behind it back and shows its rounded top edge.
    This happened for the system `.large` detent and for a custom detent at the maximum.
    `largestUndimmedDetentIdentifier` did not stop it.
    The component keeps every detent 1 pt below the maximum, and `.large` is a custom detent at that height.
    The sheet still looks full height, and the page stays in place. Verified in the compatibility look and in the default iOS 26 look.
    A 97% and a 99.9% sheet also kept the page in place.
    Not verified on iOS 16. `.large` no longer has the system large detent behavior.

13. **Hardening against edge cases.**
    | Case | What the library does | How it was checked |
    |---|---|---|
    | `NaN` or negative heights, fractions outside 0 to 1 | Made safe before use. Equal values compare as equal, so repeats are ignored. | Unit tests |
    | Maximum detent value below 1 pt | Height never goes below 0. | Unit test |
    | Content already in another parent | Moved into the sheet. | Unit test |
    | Content reused after dismissal | The sheet gives it back: no parent, original `translatesAutoresizingMaskIntoConstraints`. | Unit tests, and on screen (same table controller presented twice) |
    | Content that is the presenter, one of its parents, or presented elsewhere | Refused. The handle does nothing and the completion runs. | Unit tests |
    | Presenter already presents something | The sheet goes on top of the stack. | **Not tested** |
    | `dismiss` on a sheet that is gone | The completion still runs. | Unit test |
    | Presenter without a window or loaded view | Width guess of 375 pt, corrected at the first layout. | Unit test |
    | Zero width after dismissal | No remeasure. | Code only |
    | Leaks | 0 live controllers after 50 controllers (test) and 100 present cycles (screen). | Both |
    Detents must go from small to large. The library cannot check this, because dynamic heights are only known at run time.
    The system medium detent is inactive in landscape on iPhone (UIKit rule). Use `.fractional(0.5)` there. **Not tested.**

14. **Header, footer and pages.**
    A page is an optional header, the content and an optional footer. Verified on iOS 26.3 in demo 13:
    - The header stays at the top, the footer at the bottom, and only the content scrolls (measured 945, capped at 400).
    - The footer rises above the keyboard, because the page stops at the keyboard layout guide.
    - Pushing a page moved the sheet to the height of that page (322 to 266). Pop went back (266 to 322). The first page kept its state.
    - A long page (measured 1765) was capped at 520 and scrolled between the header and the footer.
    - Five pushes in a row gave 6 pages and 1 invalidation. Waiting calls skip their animation.
    - Pop to root went from 6 pages to 1 and restored the height.
    Limits: a page below the top is hidden, not removed. Its controller gets no appearance callbacks.
    There is no swipe-back gesture and no navigation bar. The header must offer its own back button.
    The slide animation was not checked frame by frame. Pages with `.fixed` or `.detents` sizing keep one height.

15. **A crash found on a device, and the check that now guards against it.**
    "Maximum available height" in demo 1 crashed the demo app. The cause was in the demo app, not in the library:
    the live numbers card called `Int(value)` on an infinite requested height. Swift traps on that.
    The crash report said "Double value cannot be converted to Int because it is either infinite or NaN" at `MetricsView.swift:74`.
    A search found the same pattern in the library: `BottomSheetSizing.description` called `Int(...)` on the min and max of `.dynamic`
    and on very large `.fixed` values. So `diagnostics.sizingMode` could crash for `.dynamic(maxHeight: .infinity)`.
    Both now use a formatter that cannot trap, and a test covers infinity, NaN and 1e30.
    The smoke run (`-smoke YES`) now presses every button of all 13 demos and every button inside the sheets.
    Result: 50 presses on the screens and 25 inside the sheets, no crash, on a simulator (iOS 26.3) and on an iPhone 15 Pro.
    It does not cover sliders, switches, typing, rotation or iPad.

## Capability matrix

| Capability | Status | Evidence |
|---|---|---|
| Fixed height | Native support | Demo 01: 100, 200, 300, 500 pt |
| Maximum height | Native support | Demo 01: `fixed(.infinity)` fills the screen |
| Runtime height update, animated | Native support | Demo 02 |
| Runtime height update, not animated | Native support | Demo 02 burst and slider |
| Dynamic height from a `UIView` | Supported with custom implementation | Demos 03, 05, 06. UIKit has no content-fit detent. The component measures and invalidates. |
| Dynamic height from a view controller | Supported with custom implementation | Demos 04, 08, 09 |
| Automatic change detection | Partially supported | Works for layout and scroll size. Not for changes without layout (finding 5). |
| Min and max height | Supported with custom implementation | Demos 07, 08, 09 |
| Scrollable overflow | Supported with custom implementation | Demos 07, 08, 09. The component adds a scroll view for plain content. `UIScrollView`, `UITableView` and `UICollectionView` work as content, as views or in controllers. |
| Medium and large detents | Native support | Demo 11 |
| Fractional and custom detents | Native support | Demo 11 |
| Programmatic detent selection | Native support | Demo 11 |
| Corner radius, grabber, dimming, background | Native support | Demo 11 |
| Interactive dismissal, scroll-expands | Native support | Demo 11 |
| Opaque background color | Native support (iOS 26.1 and later only) | Demo 11, finding 10 |
| Edge-to-edge sheet on iOS 26 | Supported with custom implementation | Only app-wide, with `UIDesignRequiresCompatibility`. Not possible per sheet. |
| Corner radius with a solid color | Native support | Demo 11, radius 24 |
| Grabber color | Supported with custom implementation | Demo 11, finding 11 |
| Page behind stays at full height | Supported with custom implementation | Demos 01 and 11, finding 12 |
| Header and footer | Supported with custom implementation | Demo 13, finding 14 |
| Push and pop inside the sheet | Supported with custom implementation | Demo 13, finding 14. Swipe-back is not supported. |
| Keyboard handling | Native support | Demo 10 (finding 2) |
| Width change and rotation | Supported with custom implementation | Rotation run |
| Dynamic Type | Supported with custom implementation | Accessibility size run |
| No leaks in repeated present | Native support | 0 live controllers after 100 cycles |
| iPad adaptive presentation | Requires further investigation | **Not tested** |
| iOS 16.0 behavior | Requires further investigation | **Not tested** |

## Open questions

- Does the safe area rule in finding 1 hold on iOS 16.0? Install the iOS 16.0 runtime and repeat demos 01, 03 and 10.
- Does `UICollectionViewController.view` equal the collection view on iOS 16? The code handles both.
- iPad: the sheet width differs from the window width. The first measure uses the window width, so expect one extra invalidation. **Not tested.**
- Profile with Instruments. Only counters were collected.
- Short sheets in landscape on a small iPhone.

## Recommendation

Use native `UISheetPresentationController` for new sheets that have a fixed height, medium and large detents, forms, tables and collections.
For content-fitting sheets, the component works on iOS 26.3 and needs about 630 lines of Swift, with comments.

Do **not** replace a production custom sheet yet. These checks are missing:

1. Run the demos on iOS 16.0 and on iPad.
2. Run the small cases still open: remove, banner and min/max in demo 03, "Add text" in demo 04, long and empty content in demo 06, and the non-animated stress loop.
3. Profile in Instruments.

If those pass, adopt the component. Keep the 1 pt floor and the controller lookup from findings 3 and 4.
