import UIKit
import UniformTypeIdentifiers

/// Share Extension: publish shared text/URL/file to a selected subscription (Android ShareActivity parity).
class ShareViewController: UIViewController {
    private let tag = "ShareViewController"
    private var store: Store?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        store = Store.shared

        let label = UILabel()
        label.text = NSLocalizedString("share_select_topic", comment: "")
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.tag = 42
        table.dataSource = self
        table.delegate = self
        table.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(table)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            table.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 12),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private var subscriptions: [Subscription] {
        store?.getSubscriptions() ?? []
    }

    private func publish(to subscription: Subscription) {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            extensionContext?.completeRequest(returningItems: nil)
            return
        }
        extractPayload(from: items) { message, title, data, filename, mime in
            let user = self.store?.getUser(baseUrl: subscription.baseUrl ?? "")?.toBasicUser()
            ApiService.shared.publish(
                subscription: subscription,
                user: user,
                message: message.isEmpty ? (title ?? filename ?? "shared") : message,
                title: title ?? "",
                priority: 3,
                tags: [],
                attachData: data,
                attachFilename: filename,
                attachMime: mime,
                customHeaders: self.store?.getCustomHeaders() ?? []
            ) { _ in
                DispatchQueue.main.async {
                    self.extensionContext?.completeRequest(returningItems: nil)
                }
            }
        }
    }

    private func extractPayload(
        from items: [NSExtensionItem],
        completion: @escaping (_ message: String, _ title: String?, _ data: Data?, _ filename: String?, _ mime: String?) -> Void
    ) {
        var message = ""
        var title: String?
        var data: Data?
        var filename: String?
        var mime: String?
        let group = DispatchGroup()

        for item in items {
            guard let providers = item.attachments else { continue }
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                        if let url = item as? URL {
                            message = url.absoluteString
                        }
                        group.leave()
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                        if let text = item as? String {
                            message = text
                        }
                        group.leave()
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.data.identifier, options: nil) { item, _ in
                        if let url = item as? URL {
                            let accessed = url.startAccessingSecurityScopedResource()
                            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                            data = try? Data(contentsOf: url)
                            filename = url.lastPathComponent
                            mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
                        } else if let d = item as? Data {
                            data = d
                            filename = "attachment.bin"
                        }
                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .main) {
            completion(message, title, data, filename, mime)
        }
    }
}

extension ShareViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        subscriptions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        let sub = subscriptions[indexPath.row]
        cell.textLabel?.text = sub.displayName()
        cell.detailTextLabel?.text = sub.urlString()
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        publish(to: subscriptions[indexPath.row])
    }
}
