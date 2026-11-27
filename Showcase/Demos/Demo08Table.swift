import UIKit
import NativeBottomSheet

final class TableDemo: DemoViewController {
    private let source = RowsSource()
    private lazy var tableController = RowsTableViewController(source: source)

    override func viewDidLoad() {
        super.viewDidLoad()
        addHeader("A table as content. Row changes are observed automatically.")
        addButton("Present UITableViewController, dynamic(max 450)", prominent: true) { [weak self] in
            guard let self else { return }
            present(tableController, sizing: .dynamic(maxHeight: 450))
        }
        addButton("Present UITableView (as a view), dynamic(max 450)", prominent: true) { [weak self] in
            guard let self else { return }
            let tableView = UITableView(frame: .zero, style: .plain)
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
            tableView.dataSource = source
            source.tableView = tableView
            present(tableView, sizing: .dynamic(maxHeight: 450))
        }
        addButton("Insert row") { [weak self] in self?.source.insertRows(1) }
        addButton("Insert 10 rows") { [weak self] in self?.source.insertRows(10) }
        addButton("Remove row") { [weak self] in self?.source.removeRow() }
    }
}

/// Rows shared by the controller and the plain table view. Changes go to the table on screen.
private final class RowsSource: NSObject, UITableViewDataSource {
    weak var tableView: UITableView?
    private var rows = (1...3).map { "Row \($0)" }
    private var nextNumber = 4

    func insertRows(_ count: Int) {
        let paths = (0..<count).map { IndexPath(row: rows.count + $0, section: 0) }
        for _ in 0..<count { rows.append("Row \(nextNumber)"); nextNumber += 1 }
        tableView?.insertRows(at: paths, with: .automatic)
    }

    func removeRow() {
        guard !rows.isEmpty else { return }
        rows.removeLast()
        tableView?.deleteRows(at: [IndexPath(row: rows.count, section: 0)], with: .automatic)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var configuration = cell.defaultContentConfiguration()
        configuration.text = rows[indexPath.row]
        cell.contentConfiguration = configuration
        return cell
    }
}

private final class RowsTableViewController: UITableViewController {
    private let source: RowsSource

    init(source: RowsSource) {
        self.source = source
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.dataSource = source
        source.tableView = tableView
    }
}
