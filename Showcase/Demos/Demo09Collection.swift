import UIKit
import NativeBottomSheet

final class CollectionDemo: DemoViewController {
    private let items = ItemsModel()
    private lazy var collectionController = ItemsCollectionViewController(model: items)

    override func viewDidLoad() {
        super.viewDidLoad()
        addHeader("A collection as content. Item changes are observed automatically.")
        addButton("Present UICollectionViewController, dynamic(max 450)") { [weak self] in
            guard let self else { return }
            present(collectionController, sizing: .dynamic(maxHeight: 450))
        }
        addButton("Present UICollectionView (as a view), dynamic(max 450)") { [weak self] in
            guard let self else { return }
            let collectionView = UICollectionView(frame: .zero, collectionViewLayout: ItemsModel.makeLayout())
            items.attach(collectionView)
            present(collectionView, sizing: .dynamic(maxHeight: 450))
        }
        addButton("Add 2 items") { [weak self] in self?.items.add(2) }
        addButton("Add 8 items") { [weak self] in self?.items.add(8) }
        addButton("Remove 2 items") { [weak self] in self?.items.remove(2) }
    }
}

private final class ItemCell: UICollectionViewCell {
    let label = makeLabel("", style: .headline)

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .secondarySystemFill
        contentView.layer.cornerRadius = 12
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

/// Items shared by the controller and the plain collection view. Changes go to the collection on screen.
private final class ItemsModel {
    private var dataSource: UICollectionViewDiffableDataSource<Int, Int>?
    private var items = Array(1...4)

    static func makeLayout() -> UICollectionViewLayout {
        let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(0.5), heightDimension: .fractionalHeight(1)))
        item.contentInsets = .init(top: 4, leading: 4, bottom: 4, trailing: 4)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(80)), subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .init(top: 12, leading: 12, bottom: 12, trailing: 12)
        return UICollectionViewCompositionalLayout(section: section)
    }

    func attach(_ collectionView: UICollectionView) {
        collectionView.backgroundColor = .clear
        let registration = UICollectionView.CellRegistration<ItemCell, Int> { cell, _, item in cell.label.text = "Item \(item)" }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: item)
        }
        applySnapshot(animated: false)
    }

    func add(_ count: Int) {
        let start = (items.last ?? 0) + 1
        items += start..<(start + count)
        applySnapshot(animated: true)
    }

    func remove(_ count: Int) {
        items = Array(items.dropLast(count))
        applySnapshot(animated: true)
    }

    private func applySnapshot(animated: Bool) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
        snapshot.appendSections([0])
        snapshot.appendItems(items)
        dataSource?.apply(snapshot, animatingDifferences: animated)
    }
}

private final class ItemsCollectionViewController: UICollectionViewController {
    private let model: ItemsModel

    init(model: ItemsModel) {
        self.model = model
        super.init(collectionViewLayout: ItemsModel.makeLayout())
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        model.attach(collectionView)
    }
}
