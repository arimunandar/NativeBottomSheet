# Changelog

## 0.1.0

First release.

- `BottomSheet.present(content:sizing:configuration:from:)` for a `UIView` or a `UIViewController`.
- Sizing: `.dynamic`, `.fixed`, `.fractional`, `.medium`, `.large`, `.detents([...])`.
- Runtime control: `updateHeight`, `setSizing`, `invalidateContentHeight`, `selectDetent`, `dismiss`.
- Appearance: corner radius, grabber and grabber color, solid background color, dimming, interactive dismissal.
- Automatic height changes for Auto Layout content, scroll views, table views and collection views.
- iOS 16.0 or later. Tested on one simulator, iOS 26.3.
