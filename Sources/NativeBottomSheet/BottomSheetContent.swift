import UIKit

enum BottomSheetContent {
    case view(UIView)
    case viewController(UIViewController)

    var view: UIView {
        switch self {
        case .view(let view): return view
        case .viewController(let controller): return controller.view
        }
    }

    /// The scroll view that scrolls by itself, if the content is one.
    /// The controller's `view` can be a wrapper around it (a collection view controller on iOS 26),
    /// so ask the controller first.
    var scrollView: UIScrollView? {
        switch self {
        case .view(let view):
            return view as? UIScrollView
        case .viewController(let controller):
            return (controller as? UICollectionViewController)?.collectionView
                ?? (controller as? UITableViewController)?.tableView
                ?? controller.view as? UIScrollView
        }
    }

    /// False when the content cannot live in a sheet presented from `presenter`:
    /// it is the presenter or one of its parents, it is a view above the presenter's view,
    /// or it is a controller that is presented somewhere else. UIKit would raise an exception.
    func canBePresented(from presenter: UIViewController) -> Bool {
        switch self {
        case .viewController(let controller):
            if controller.presentingViewController != nil { return false }
            var node: UIViewController? = presenter
            while let current = node {
                if current === controller { return false }
                node = current.parent
            }
            return true
        case .view(let view):
            return !(presenter.viewIfLoaded?.isDescendant(of: view) ?? false)
        }
    }
}
