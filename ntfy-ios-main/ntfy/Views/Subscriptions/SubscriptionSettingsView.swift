import SwiftUI

struct SubscriptionSettingsView: View {
    @EnvironmentObject private var store: Store
    @ObservedObject var subscription: Subscription

    @State private var mutedUntil: Int64 = 0
    @State private var minPriority = 0
    @State private var autoDelete: Int64 = -1
    @State private var displayName = ""

    private var baseUrl: String { subscription.baseUrl ?? "" }
    private var topic: String { subscription.topic ?? "" }

    var body: some View {
        Form {
            Section(header: Text(NSLocalizedString("settings_notifications_header", comment: ""))) {
                MuteUntilPicker(
                    title: NSLocalizedString("settings_mute", comment: ""),
                    mutedUntil: $mutedUntil
                ) { value in
                    store.setSubscriptionMutedUntil(baseUrl: baseUrl, topic: topic, value: value)
                }
                MinPriorityPicker(
                    title: NSLocalizedString("settings_min_priority", comment: ""),
                    value: $minPriority,
                    includeUseGlobal: true
                ) { value in
                    store.setSubscriptionMinPriority(baseUrl: baseUrl, topic: topic, value: value)
                }
                AutoDeletePicker(
                    title: NSLocalizedString("settings_auto_delete", comment: ""),
                    value: $autoDelete,
                    includeUseGlobal: true
                ) { value in
                    store.setSubscriptionAutoDeleteSeconds(baseUrl: baseUrl, topic: topic, value: value)
                }
            }
            Section(header: Text(NSLocalizedString("settings_appearance_header", comment: ""))) {
                TextField(NSLocalizedString("settings_display_name", comment: ""), text: $displayName)
                    .onChange(of: displayName) { newValue in
                        store.setSubscriptionDisplayName(
                            baseUrl: baseUrl,
                            topic: topic,
                            value: newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    }
            }
            Section(header: Text(NSLocalizedString("settings_about_header", comment: ""))) {
                Text(subscription.urlString())
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
        }
        .navigationTitle(NSLocalizedString("subscription_settings", comment: ""))
        .onAppear {
            mutedUntil = store.getSubscriptionMutedUntil(baseUrl: baseUrl, topic: topic)
            minPriority = store.getSubscriptionMinPriority(baseUrl: baseUrl, topic: topic)
            autoDelete = store.getSubscriptionAutoDeleteSeconds(baseUrl: baseUrl, topic: topic)
            displayName = store.getSubscriptionDisplayName(baseUrl: baseUrl, topic: topic) ?? ""
        }
    }
}
