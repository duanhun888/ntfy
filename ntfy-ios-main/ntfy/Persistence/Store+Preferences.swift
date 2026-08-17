import Foundation
import UIKit

extension Store {
    // MARK: - Preference keys (Android parity)

    static let prefKeyGlobalMutedUntil = "globalMutedUntil"
    static let prefKeyMinPriority = "minPriority"
    static let prefKeyAutoDeleteSeconds = "autoDeleteSeconds"
    static let prefKeyDarkMode = "darkMode"
    static let prefKeyLanguage = "language"
    static let prefKeyConnectionAlertSeconds = "connectionAlertSeconds"
    static let prefKeyCustomHeadersJSON = "customHeadersJSON"
    static let prefKeyRecordLogs = "recordLogs"

    private func subKey(_ suffix: String, baseUrl: String, topic: String) -> String {
        "sub:\(normalizeBaseUrl(baseUrl))|\(topic):\(suffix)"
    }

    // MARK: Global mute / priority / auto-delete

    func getGlobalMutedUntil() -> Int64 {
        Int64(getPreference(key: Store.prefKeyGlobalMutedUntil)?.value ?? "0") ?? 0
    }

    func setGlobalMutedUntil(_ value: Int64) {
        setPreference(key: Store.prefKeyGlobalMutedUntil, value: String(value))
    }

    func getMinPriority() -> Int {
        Int(getPreference(key: Store.prefKeyMinPriority)?.value ?? "1") ?? NotificationPolicy.minPriorityAny
    }

    func setMinPriority(_ value: Int) {
        setPreference(key: Store.prefKeyMinPriority, value: String(value))
    }

    func getAutoDeleteSeconds() -> Int64 {
        Int64(getPreference(key: Store.prefKeyAutoDeleteSeconds)?.value ?? String(NotificationPolicy.autoDeleteDefault))
            ?? NotificationPolicy.autoDeleteDefault
    }

    func setAutoDeleteSeconds(_ value: Int64) {
        setPreference(key: Store.prefKeyAutoDeleteSeconds, value: String(value))
    }

    func getDarkMode() -> Int {
        Int(getPreference(key: Store.prefKeyDarkMode)?.value ?? String(NotificationPolicy.darkModeFollowSystem))
            ?? NotificationPolicy.darkModeFollowSystem
    }

    func setDarkMode(_ value: Int) {
        setPreference(key: Store.prefKeyDarkMode, value: String(value))
        applyDarkMode(value)
    }

    func getLanguage() -> String {
        getPreference(key: Store.prefKeyLanguage)?.value ?? "zh-Hans"
    }

    func setLanguage(_ value: String) {
        setPreference(key: Store.prefKeyLanguage, value: value)
        UserDefaults.standard.set([value], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }

    func getConnectionAlertSeconds() -> Int64 {
        Int64(getPreference(key: Store.prefKeyConnectionAlertSeconds)?.value ?? "0") ?? 0
    }

    func setConnectionAlertSeconds(_ value: Int64) {
        setPreference(key: Store.prefKeyConnectionAlertSeconds, value: String(value))
    }

    func getCustomHeaders() -> [(name: String, value: String)] {
        guard
            let raw = getPreference(key: Store.prefKeyCustomHeadersJSON)?.value,
            let data = raw.data(using: .utf8),
            let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: String]]
        else {
            return []
        }
        return arr.compactMap { row in
            guard let name = row["name"], let value = row["value"], !name.isEmpty else { return nil }
            return (name, value)
        }
    }

    func setCustomHeaders(_ headers: [(name: String, value: String)]) {
        let arr = headers.map { ["name": $0.name, "value": $0.value] }
        if let data = try? JSONSerialization.data(withJSONObject: arr),
           let raw = String(data: data, encoding: .utf8) {
            setPreference(key: Store.prefKeyCustomHeadersJSON, value: raw)
        }
    }

    func getRecordLogs() -> Bool {
        getPreference(key: Store.prefKeyRecordLogs)?.value == "true"
    }

    func setRecordLogs(_ enabled: Bool) {
        setPreference(key: Store.prefKeyRecordLogs, value: String(enabled))
        Log.setRecordingEnabled(enabled)
    }

    // MARK: Per-subscription

    func getSubscriptionMutedUntil(baseUrl: String, topic: String) -> Int64 {
        Int64(getPreference(key: subKey("mutedUntil", baseUrl: baseUrl, topic: topic))?.value ?? "0") ?? 0
    }

    func setSubscriptionMutedUntil(baseUrl: String, topic: String, value: Int64) {
        setPreference(key: subKey("mutedUntil", baseUrl: baseUrl, topic: topic), value: String(value))
    }

    func getSubscriptionMinPriority(baseUrl: String, topic: String) -> Int {
        Int(getPreference(key: subKey("minPriority", baseUrl: baseUrl, topic: topic))?.value ?? "0")
            ?? NotificationPolicy.minPriorityUseGlobal
    }

    func setSubscriptionMinPriority(baseUrl: String, topic: String, value: Int) {
        setPreference(key: subKey("minPriority", baseUrl: baseUrl, topic: topic), value: String(value))
    }

    func getSubscriptionAutoDeleteSeconds(baseUrl: String, topic: String) -> Int64 {
        Int64(getPreference(key: subKey("autoDelete", baseUrl: baseUrl, topic: topic))?.value ?? "-1")
            ?? NotificationPolicy.autoDeleteUseGlobal
    }

    func setSubscriptionAutoDeleteSeconds(baseUrl: String, topic: String, value: Int64) {
        setPreference(key: subKey("autoDelete", baseUrl: baseUrl, topic: topic), value: String(value))
    }

    func getSubscriptionDisplayName(baseUrl: String, topic: String) -> String? {
        getPreference(key: subKey("displayName", baseUrl: baseUrl, topic: topic))?.value
    }

    func setSubscriptionDisplayName(baseUrl: String, topic: String, value: String?) {
        if let value, !value.isEmpty {
            setPreference(key: subKey("displayName", baseUrl: baseUrl, topic: topic), value: value)
        } else {
            deletePreference(key: subKey("displayName", baseUrl: baseUrl, topic: topic))
        }
    }

    func effectiveAutoDeleteSeconds(baseUrl: String, topic: String) -> Int64 {
        let local = getSubscriptionAutoDeleteSeconds(baseUrl: baseUrl, topic: topic)
        if local == NotificationPolicy.autoDeleteUseGlobal {
            return getAutoDeleteSeconds()
        }
        return local
    }

    func applyDarkMode(_ mode: Int? = nil) {
        let value = mode ?? getDarkMode()
        DispatchQueue.main.async {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            for window in scene.windows {
                switch value {
                case NotificationPolicy.darkModeLight:
                    window.overrideUserInterfaceStyle = .light
                case NotificationPolicy.darkModeDark:
                    window.overrideUserInterfaceStyle = .dark
                default:
                    window.overrideUserInterfaceStyle = .unspecified
                }
            }
        }
    }

    func ensureDefaultLanguage() {
        if getPreference(key: Store.prefKeyLanguage) == nil {
            setLanguage("zh-Hans")
        }
    }

    // MARK: Preference helpers

    func setPreference(key: String, value: String) {
        do {
            let pref = getPreference(key: key) ?? Preference(context: context)
            pref.key = key
            pref.value = value
            try context.save()
        } catch {
            Log.w(Store.tag, "Cannot store preference \(key)", error)
            rollbackAndRefresh()
        }
    }

    func deletePreference(key: String) {
        if let pref = getPreference(key: key) {
            context.delete(pref)
            try? context.save()
        }
    }

    func allPreferencesMap() -> [String: String] {
        let request = Preference.fetchRequest()
        let prefs = (try? context.fetch(request)) ?? []
        var map: [String: String] = [:]
        for pref in prefs {
            if let k = pref.key, let v = pref.value {
                map[k] = v
            }
        }
        return map
    }

    func applyPreferencesMap(_ map: [String: String]) {
        for (key, value) in map {
            setPreference(key: key, value: value)
        }
    }
}
