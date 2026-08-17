import Foundation

/// JSON backup compatible in spirit with Android Backuper (magic + settings/subscriptions/users).
struct Backuper {
    private let store: Store
    private let magic = "ntfy"

    init(store: Store) {
        self.store = store
    }

    func exportJSON() throws -> Data {
        var settings = store.allPreferencesMap()
        var subscriptions: [[String: Any]] = []
        for sub in store.getSubscriptions() ?? [] {
            guard let baseUrl = sub.baseUrl, let topic = sub.topic else { continue }
            subscriptions.append([
                "baseUrl": baseUrl,
                "topic": topic,
                "displayName": store.getSubscriptionDisplayName(baseUrl: baseUrl, topic: topic) ?? ""
            ])
        }
        var users: [[String: Any]] = []
        let userRequest = User.fetchRequest()
        for user in (try? store.context.fetch(userRequest)) ?? [] {
            users.append([
                "baseUrl": user.baseUrl ?? "",
                "username": user.username ?? "",
                "password": user.password ?? ""
            ])
        }
        let payload: [String: Any] = [
            "magic": magic,
            "version": 1,
            "settings": settings,
            "subscriptions": subscriptions,
            "users": users
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    func importJSON(_ data: Data) throws {
        guard
            let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            (obj["magic"] as? String) == magic
        else {
            throw NSError(domain: "Backuper", code: 1, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("settings_backup_invalid", comment: "")
            ])
        }
        if let settings = obj["settings"] as? [String: String] {
            store.applyPreferencesMap(settings)
        }
        if let users = obj["users"] as? [[String: Any]] {
            for row in users {
                guard
                    let baseUrl = row["baseUrl"] as? String,
                    let username = row["username"] as? String,
                    let password = row["password"] as? String,
                    !baseUrl.isEmpty, !username.isEmpty
                else { continue }
                store.saveUser(baseUrl: baseUrl, username: username, password: password)
            }
        }
        if let subscriptions = obj["subscriptions"] as? [[String: Any]] {
            let manager = SubscriptionManager(store: store)
            for row in subscriptions {
                guard let baseUrl = row["baseUrl"] as? String, let topic = row["topic"] as? String else { continue }
                if store.getSubscription(baseUrl: baseUrl, topic: topic) == nil {
                    manager.subscribe(baseUrl: baseUrl, topic: topic)
                }
                if let displayName = row["displayName"] as? String, !displayName.isEmpty {
                    store.setSubscriptionDisplayName(baseUrl: baseUrl, topic: topic, value: displayName)
                }
            }
        }
    }
}
