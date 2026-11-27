import UIKit

final class MenuViewController: UITableViewController {
    private struct Demo {
        let title: String
        let subtitle: String
        let make: () -> UIViewController
    }

    private let demos: [Demo] = [
        Demo(title: "01 — Fixed Height", subtitle: "100, 200, 300, 500 pt and maximum", make: FixedHeightDemo.init),
        Demo(title: "02 — Runtime Resize", subtitle: "Buttons and slider change the height", make: RuntimeResizeDemo.init),
        Demo(title: "03 — Dynamic UIView", subtitle: "Add and remove content", make: DynamicViewDemo.init),
        Demo(title: "04 — Dynamic UIViewController", subtitle: "Embed an existing controller", make: DynamicControllerDemo.init),
        Demo(title: "05 — Expandable Content", subtitle: "Expand and collapse sections", make: ExpandableDemo.init),
        Demo(title: "06 — Async Content", subtitle: "Loading state, then loaded content", make: AsyncContentDemo.init),
        Demo(title: "07 — Scrollable Content", subtitle: "Content taller than the maximum", make: ScrollableDemo.init),
        Demo(title: "08 — Dynamic TableView", subtitle: "Insert and remove rows", make: TableDemo.init),
        Demo(title: "09 — Dynamic CollectionView", subtitle: "Update collection items", make: CollectionDemo.init),
        Demo(title: "10 — Keyboard & Form", subtitle: "Text fields and a text view", make: KeyboardFormDemo.init),
        Demo(title: "11 — Multiple Detents", subtitle: "Detents and appearance options", make: MultipleDetentsDemo.init),
        Demo(title: "12 — Stress Test", subtitle: "100 updates and 100 present cycles", make: StressTestDemo.init),
    ]

    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Native Bottom Sheet POC"
        navigationController?.navigationBar.prefersLargeTitles = true
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        // `-demo N` opens demo N at launch. Used for manual and scripted checks.
        let number = UserDefaults.standard.integer(forKey: "demo")
        if demos.indices.contains(number - 1) {
            DispatchQueue.main.async { [self] in tableView(tableView, didSelectRowAt: IndexPath(row: number - 1, section: 0)) }
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { demos.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var configuration = cell.defaultContentConfiguration()
        configuration.text = demos[indexPath.row].title
        configuration.secondaryText = demos[indexPath.row].subtitle
        cell.contentConfiguration = configuration
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let demo = demos[indexPath.row].make()
        demo.title = demos[indexPath.row].title
        navigationController?.pushViewController(demo, animated: true)
    }
}
