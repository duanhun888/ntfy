import Foundation

/// Mirrors Android Repository mute / min-priority / auto-delete semantics for notification display policy.
enum NotificationPolicy {
    static let mutedUntilShowAll: Int64 = 0
    static let mutedUntilForever: Int64 = 1
    /// Sentinel used only in UI pickers; converted to a unix timestamp before save.
    static let mutedUntilTomorrow: Int64 = 2

    static let minPriorityUseGlobal: Int = 0
    static let minPriorityAny: Int = 1

    static let autoDeleteUseGlobal: Int64 = -1
    static let autoDeleteNever: Int64 = 0
    static let autoDeleteOneDay: Int64 = 86_400
    static let autoDeleteThreeDays: Int64 = 3 * 86_400
    static let autoDeleteOneWeek: Int64 = 7 * 86_400
    static let autoDeleteOneMonth: Int64 = 30 * 86_400
    static let autoDeleteThreeMonths: Int64 = 90 * 86_400
    static let autoDeleteDefault: Int64 = autoDeleteOneMonth

    static let darkModeFollowSystem = -1
    static let darkModeLight = 1
    static let darkModeDark = 2

    /// Returns true when the system banner / sound should be suppressed (message is still persisted).
    static func shouldSuppressDisplay(store: Store, baseUrl: String, topic: String, priority: Int) -> Bool {
        if isMuted(store: store, baseUrl: baseUrl, topic: topic) {
            return true
        }
        let minPriority = effectiveMinPriority(store: store, baseUrl: baseUrl, topic: topic)
        return priority < minPriority
    }

    static func isMuted(store: Store, baseUrl: String, topic: String) -> Bool {
        let now = Int64(Date().timeIntervalSince1970)
        let global = store.getGlobalMutedUntil()
        if isMutedValue(global, now: now) {
            return true
        }
        let local = store.getSubscriptionMutedUntil(baseUrl: baseUrl, topic: topic)
        return isMutedValue(local, now: now)
    }

    static func isMutedValue(_ mutedUntil: Int64, now: Int64 = Int64(Date().timeIntervalSince1970)) -> Bool {
        if mutedUntil == mutedUntilForever {
            return true
        }
        if mutedUntil > mutedUntilForever && mutedUntil > now {
            return true
        }
        return false
    }

    static func effectiveMinPriority(store: Store, baseUrl: String, topic: String) -> Int {
        let local = store.getSubscriptionMinPriority(baseUrl: baseUrl, topic: topic)
        if local == minPriorityUseGlobal {
            return store.getMinPriority()
        }
        return local
    }

    static func resolveMutedUntilPickerValue(_ picker: Int64) -> Int64 {
        switch picker {
        case mutedUntilShowAll, mutedUntilForever:
            return picker
        case mutedUntilTomorrow:
            var calendar = Calendar.current
            calendar.timeZone = .current
            let startOfToday = calendar.startOfDay(for: Date())
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? Date().addingTimeInterval(86_400)
            return Int64(tomorrow.timeIntervalSince1970)
        default:
            // Relative minutes from now (Android entries: 30, 60, 120, 480)
            return Int64(Date().timeIntervalSince1970) + picker * 60
        }
    }
}
