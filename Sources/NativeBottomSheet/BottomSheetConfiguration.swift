import UIKit

/// Appearance and behavior of a sheet. Every option has a sensible default.
public struct BottomSheetConfiguration {
    /// The corner radius in points. nil keeps the system corner radius.
    public var cornerRadius: CGFloat?
    /// Shows a grabber at the top of the sheet.
    public var showsGrabber = false
    /// When false, the user cannot drag the sheet down to dismiss it.
    public var allowsInteractiveDismissal = true
    /// When true, scrolling content at its edge moves the sheet to the next detent.
    public var prefersScrollingExpandsWhenScrolledToEdge = true
    /// nil uses `.systemBackground`. On iOS 26.1 and later the color is also applied as a solid
    /// sheet background (`UIColorEffect`), so the system glass never shows through.
    public var backgroundColor: UIColor?
    /// false removes the dimming at every detent, so the screen behind stays usable.
    public var dimsBackground = true
    /// nil keeps the system grabber. A color draws the component's own grabber instead,
    /// because UIKit has no API for the system grabber color. Needs `showsGrabber`.
    public var grabberColor: UIColor?

    public init(
        cornerRadius: CGFloat? = nil,
        showsGrabber: Bool = false,
        allowsInteractiveDismissal: Bool = true,
        prefersScrollingExpandsWhenScrolledToEdge: Bool = true,
        backgroundColor: UIColor? = nil,
        dimsBackground: Bool = true,
        grabberColor: UIColor? = nil
    ) {
        self.cornerRadius = cornerRadius
        self.showsGrabber = showsGrabber
        self.allowsInteractiveDismissal = allowsInteractiveDismissal
        self.prefersScrollingExpandsWhenScrolledToEdge = prefersScrollingExpandsWhenScrolledToEdge
        self.backgroundColor = backgroundColor
        self.dimsBackground = dimsBackground
        self.grabberColor = grabberColor
    }
}
