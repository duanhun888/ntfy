import SwiftUI

struct MuteUntilPicker: View {
    let title: String
    @Binding var mutedUntil: Int64
    let onCommit: (Int64) -> Void

    private let options: [(Int64, String)] = [
        (0, "mute_show_all"),
        (30, "mute_30m"),
        (60, "mute_1h"),
        (120, "mute_2h"),
        (480, "mute_8h"),
        (2, "mute_tomorrow"),
        (1, "mute_forever")
    ]

    var body: some View {
        Picker(title, selection: Binding(
            get: { displaySelection },
            set: { picked in
                let resolved = NotificationPolicy.resolveMutedUntilPickerValue(picked)
                mutedUntil = resolved
                onCommit(resolved)
            }
        )) {
            ForEach(options, id: \.0) { value, key in
                Text(NSLocalizedString(key, comment: "")).tag(value)
            }
        }
        if mutedUntil > 1 {
            Text(summaryText)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var displaySelection: Int64 {
        if mutedUntil == 0 || mutedUntil == 1 {
            return mutedUntil
        }
        // Active timed mute — keep forever/show options selectable; show summary below
        return mutedUntilForeverPlaceholder
    }

    /// Placeholder tag not in options when a custom timestamp is active; map to closest UX by showing forever row disabled via summary.
    private var mutedUntilForeverPlaceholder: Int64 { 1 }

    private var summaryText: String {
        let date = Date(timeIntervalSince1970: TimeInterval(mutedUntil))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return String(format: NSLocalizedString("mute_until_format", comment: ""), formatter.string(from: date))
    }
}

struct MinPriorityPicker: View {
    let title: String
    @Binding var value: Int
    let includeUseGlobal: Bool
    let onCommit: (Int) -> Void

    var body: some View {
        Picker(title, selection: Binding(
            get: { value },
            set: { value = $0; onCommit($0) }
        )) {
            if includeUseGlobal {
                Text(NSLocalizedString("priority_use_global", comment: "")).tag(0)
            }
            Text(NSLocalizedString("priority_any", comment: "")).tag(1)
            Text(NSLocalizedString("priority_low_plus", comment: "")).tag(2)
            Text(NSLocalizedString("priority_default_plus", comment: "")).tag(3)
            Text(NSLocalizedString("priority_high_plus", comment: "")).tag(4)
            Text(NSLocalizedString("priority_max_only", comment: "")).tag(5)
        }
    }
}

struct AutoDeletePicker: View {
    let title: String
    @Binding var value: Int64
    let includeUseGlobal: Bool
    let onCommit: (Int64) -> Void

    var body: some View {
        Picker(title, selection: Binding(
            get: { value },
            set: { value = $0; onCommit($0) }
        )) {
            if includeUseGlobal {
                Text(NSLocalizedString("auto_delete_use_global", comment: "")).tag(Int64(-1))
            }
            Text(NSLocalizedString("auto_delete_never", comment: "")).tag(Int64(0))
            Text(NSLocalizedString("auto_delete_1d", comment: "")).tag(NotificationPolicy.autoDeleteOneDay)
            Text(NSLocalizedString("auto_delete_3d", comment: "")).tag(NotificationPolicy.autoDeleteThreeDays)
            Text(NSLocalizedString("auto_delete_1w", comment: "")).tag(NotificationPolicy.autoDeleteOneWeek)
            Text(NSLocalizedString("auto_delete_1m", comment: "")).tag(NotificationPolicy.autoDeleteOneMonth)
            Text(NSLocalizedString("auto_delete_3m", comment: "")).tag(NotificationPolicy.autoDeleteThreeMonths)
        }
    }
}
