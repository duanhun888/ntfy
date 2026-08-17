import Foundation

/// Parses `ntfy://` deep links (Android LinkActivity / DetailActivity parity).
enum DeepLinkRouter {
    /// Supported:
    /// - ntfy://ntfy.sh/mytopic
    /// - ntfy://subscribe?url=https://ntfy.sh/mytopic
    static func handle(url: URL, store: Store, delegate: AppDelegate) {
        let manager = SubscriptionManager(store: store)

        if url.scheme == "ntfy" {
            if url.host == "subscribe",
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let topicURLString = components.queryItems?.first(where: { $0.name == "url" })?.value,
               let topicURL = URL(string: topicURLString) {
                subscribe(url: topicURL, manager: manager, delegate: delegate)
                return
            }
            var comps = URLComponents()
            comps.scheme = "https"
            comps.host = url.host
            comps.path = url.path
            if let httpsURL = comps.url {
                subscribe(url: httpsURL, manager: manager, delegate: delegate)
            }
            return
        }

        subscribe(url: url, manager: manager, delegate: delegate)
    }

    private static func subscribe(url: URL, manager: SubscriptionManager, delegate: AppDelegate) {
        guard let host = url.host else { return }
        let scheme = url.scheme ?? "https"
        let baseUrl = "\(scheme)://\(host)"
        let topic = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !topic.isEmpty, topic.range(of: #"^[-_A-Za-z0-9]{1,64}$"#, options: .regularExpression) != nil else {
            return
        }
        if Store.shared.getSubscription(baseUrl: baseUrl, topic: topic) == nil {
            manager.subscribe(baseUrl: baseUrl, topic: topic)
        }
        DispatchQueue.main.async {
            delegate.selectedBaseUrl = topicUrl(baseUrl: baseUrl, topic: topic)
        }
    }
}
