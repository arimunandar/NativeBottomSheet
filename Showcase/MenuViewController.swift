import UIKit

private struct Demo {
    let number: Int
    let title: String
    let subtitle: String
    let symbol: String
    let make: () -> UIViewController
}

private struct Group {
    let title: String
    let color: UIColor
    let demos: [Demo]
}

/// The icon of a row: a white symbol on a colored rounded square, as in the Settings app.
private final class DemoCell: UITableViewCell {
    static let identifier = "DemoCell"
    private let iconBackground = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let numberLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator

        iconBackground.layer.cornerRadius = 8
        iconBackground.layer.cornerCurve = .continuous
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBackground.addSubview(iconView)

        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        subtitleLabel.font = .preferredFont(forTextStyle: .footnote)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        numberLabel.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .monospacedDigitSystemFont(ofSize: 12, weight: .regular))
        numberLabel.textColor = .tertiaryLabel
        numberLabel.setContentHuggingPriority(.required, for: .horizontal)

        let texts = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        texts.axis = .vertical
        texts.spacing = 2
        let row = UIStackView(arrangedSubviews: [iconBackground, texts, numberLabel])
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            iconBackground.widthAnchor.constraint(equalToConstant: 32),
            iconBackground.heightAnchor.constraint(equalToConstant: 32),
            iconView.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            row.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 4),
            row.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -4),
            row.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(_ demo: Demo, color: UIColor) {
        iconBackground.backgroundColor = color
        iconView.image = UIImage(systemName: demo.symbol)
        titleLabel.text = demo.title
        subtitleLabel.text = demo.subtitle
        numberLabel.text = String(format: "%02d", demo.number)
    }
}

final class MenuViewController: UITableViewController {
    private let groups: [Group] = [
        Group(title: "Sizing", color: .systemBlue, demos: [
            Demo(number: 1, title: "Fixed Height", subtitle: "100, 200, 300, 500 points, maximum and large", symbol: "ruler", make: FixedHeightDemo.init),
            Demo(number: 2, title: "Runtime Resize", subtitle: "Change the height with buttons and a slider", symbol: "slider.horizontal.3", make: RuntimeResizeDemo.init),
            Demo(number: 11, title: "Detents and Appearance", subtitle: "Switch detents. Change corners, grabber and color", symbol: "square.stack.3d.up", make: MultipleDetentsDemo.init),
        ]),
        Group(title: "Follows the content", color: .systemGreen, demos: [
            Demo(number: 3, title: "Dynamic View", subtitle: "Add and remove content", symbol: "plus.rectangle.on.rectangle", make: DynamicViewDemo.init),
            Demo(number: 4, title: "Dynamic Controller", subtitle: "Embed an existing view controller", symbol: "rectangle.on.rectangle", make: DynamicControllerDemo.init),
            Demo(number: 5, title: "Expandable Content", subtitle: "Open and close sections", symbol: "chevron.down.circle", make: ExpandableDemo.init),
            Demo(number: 6, title: "Async Content", subtitle: "A loading state, then the real content", symbol: "hourglass", make: AsyncContentDemo.init),
        ]),
        Group(title: "Scrolling", color: .systemOrange, demos: [
            Demo(number: 7, title: "Scrollable Content", subtitle: "Content taller than the maximum", symbol: "arrow.up.and.down", make: ScrollableDemo.init),
            Demo(number: 8, title: "Table View", subtitle: "Insert and remove rows", symbol: "list.bullet", make: TableDemo.init),
            Demo(number: 9, title: "Collection View", subtitle: "Update collection items", symbol: "square.grid.2x2", make: CollectionDemo.init),
        ]),
        Group(title: "Layout and input", color: .systemPurple, demos: [
            Demo(number: 13, title: "Header, Footer and Pages", subtitle: "Pinned header and footer. Push pages inside the sheet", symbol: "rectangle.stack", make: HeaderFooterPushDemo.init),
            Demo(number: 10, title: "Keyboard and Form", subtitle: "Text fields, a growing text view and the footer", symbol: "keyboard", make: KeyboardFormDemo.init),
        ]),
        Group(title: "Stress", color: .systemRed, demos: [
            Demo(number: 12, title: "Stress Test", subtitle: "100 height updates and 100 present cycles", symbol: "speedometer", make: StressTestDemo.init),
        ]),
    ]

    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Bottom Sheet"
        navigationController?.navigationBar.prefersLargeTitles = true
        tableView.register(DemoCell.self, forCellReuseIdentifier: DemoCell.identifier)
        tableView.tableFooterView = makeFooter()

        #if DEBUG
        // `-smoke YES` presses every button of every demo. See SmokeRunner.
        if UserDefaults.standard.bool(forKey: "smoke") {
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if let self { await SmokeRunner.run(menu: self) }
            }
        }
        #endif

        // `-demo N` opens demo N at launch. Used for manual and scripted checks.
        let number = UserDefaults.standard.integer(forKey: "demo")
        if let path = indexPath(ofDemo: number) {
            DispatchQueue.main.async { [self] in tableView(tableView, didSelectRowAt: path) }
        }
    }

    private func makeFooter() -> UIView {
        let label = UILabel()
        label.text = "Native UIKit sheets that follow their content. Every demo shows the live numbers of its sheet at the top."
        label.font = .preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 90))
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),
        ])
        return container
    }

    private func indexPath(ofDemo number: Int) -> IndexPath? {
        for (section, group) in groups.enumerated() {
            if let row = group.demos.firstIndex(where: { $0.number == number }) { return IndexPath(row: row, section: section) }
        }
        return nil
    }

    override func numberOfSections(in tableView: UITableView) -> Int { groups.count }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { groups[section].title }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { groups[section].demos.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DemoCell.identifier, for: indexPath) as! DemoCell
        let group = groups[indexPath.section]
        cell.configure(group.demos[indexPath.row], color: group.color)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        push(groups[indexPath.section].demos[indexPath.row], animated: true)
    }

    @discardableResult
    private func push(_ demo: Demo, animated: Bool) -> UIViewController {
        let screen = demo.make()
        screen.title = demo.title
        navigationController?.pushViewController(screen, animated: animated)
        return screen
    }

    /// The numbers of all demos, in order.
    var demoNumbers: [Int] { groups.flatMap(\.demos).map(\.number).sorted() }

    /// Opens a demo without animation. Returns its screen.
    func showDemo(_ number: Int) -> UIViewController? {
        guard let path = indexPath(ofDemo: number) else { return nil }
        return push(groups[path.section].demos[path.row], animated: false)
    }
}
