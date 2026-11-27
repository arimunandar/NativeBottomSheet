# Changelog

## 0.3.0

- Events: `onDismiss(reason)`, `onAttemptToDismiss`, `onDetentChange(index)`, `onPageChange(count)`.
- `BottomSheetDismissReason`: `.interactive` or `.programmatic`.
- `BottomSheetConfiguration.dimmingColor`: the color and darkness of the dimming behind the sheet.

## 0.2.1

- Fix a crash: `BottomSheetSizing.description`, which feeds `diagnostics.sizingMode`, converted heights with `Int(...)`.
  It crashed for infinite, NaN and very large values, for example `.dynamic(maxHeight: .infinity)`.
- Demo app: fix a crash in the live numbers card for "Maximum available height".
- Demo app: `-smoke YES` presses every button of every demo and prints the result.

## 0.2.0

- Header and footer: `present(content:header:footer:...)`. The header is pinned to the top, the footer to the bottom above the keyboard, and only the content scrolls.
- Pages inside the sheet: `push`, `pop`, `popToRoot`, `pageCount`. The sheet follows the height of the page on top.
- `BottomSheetDiagnostics.pageCount`.

## 0.1.0

First release.

- `BottomSheet.present(content:sizing:configuration:from:)` for a `UIView` or a `UIViewController`.
- Sizing: `.dynamic`, `.fixed`, `.fractional`, `.medium`, `.large`, `.detents([...])`.
- Runtime control: `updateHeight`, `setSizing`, `invalidateContentHeight`, `selectDetent`, `dismiss`.
- Appearance: corner radius, grabber and grabber color, solid background color, dimming, interactive dismissal.
- Automatic height changes for Auto Layout content, scroll views, table views and collection views.
- iOS 16.0 or later. Tested on one simulator, iOS 26.3.
