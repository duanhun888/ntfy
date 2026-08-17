import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var delegate: AppDelegate
    @State private var userDialog: UserDialog?
    @State private var globalMutedUntil: Int64 = 0
    @State private var minPriority = 1
    @State private var autoDelete = NotificationPolicy.autoDeleteDefault

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(NSLocalizedString("settings_notifications_header", comment: ""))) {
                    MuteUntilPicker(
                        title: NSLocalizedString("settings_mute", comment: ""),
                        mutedUntil: $globalMutedUntil
                    ) { value in
                        store.setGlobalMutedUntil(value)
                    }
                    MinPriorityPicker(
                        title: NSLocalizedString("settings_min_priority", comment: ""),
                        value: $minPriority,
                        includeUseGlobal: false
                    ) { value in
                        store.setMinPriority(value)
                    }
                    AutoDeletePicker(
                        title: NSLocalizedString("settings_auto_delete", comment: ""),
                        value: $autoDelete,
                        includeUseGlobal: false
                    ) { value in
                        store.setAutoDeleteSeconds(value)
                    }
                    AttachmentAutoDownloadView()
                    CriticalAlertsSettingView()
                }

                Section(
                    header: Text(NSLocalizedString("settings_general_header", comment: "")),
                    footer: Text(NSLocalizedString("settings_default_server_footer", comment: ""))
                ) {
                    DefaultServerView()
                    LanguagePicker()
                    DarkModePicker()
                }

                Section(
                    header: Text(NSLocalizedString("settings_users_header", comment: "")),
                    footer: Text(NSLocalizedString("settings_users_footer", comment: ""))
                ) {
                    UserTableView(dialog: $userDialog)
                }

                BackupRestoreView()
                CustomHeadersView()

                Section(header: Text(NSLocalizedString("settings_advanced_header", comment: ""))) {
                    ConnectionAlertPicker()
                }

                LogsSettingsView()

                Section(header: Text(NSLocalizedString("settings_about_header", comment: ""))) {
                    AboutView()
                }
            }
            .navigationTitle(NSLocalizedString("settings_title", comment: ""))
            .onAppear {
                globalMutedUntil = store.getGlobalMutedUntil()
                minPriority = store.getMinPriority()
                autoDelete = store.getAutoDeleteSeconds()
                store.applyDarkMode()
            }
        }
        .sheet(item: $userDialog) { dialog in
            UserEditorView(
                selectedUser: dialog.user,
                onSave: { baseUrl, username, password in
                    store.saveUser(baseUrl: baseUrl, username: username, password: password)
                    userDialog = nil
                },
                onDelete: { user in
                    store.delete(user: user)
                    userDialog = nil
                },
                onCancel: {
                    userDialog = nil
                }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store.preview
        SettingsView()
            .environment(\.managedObjectContext, store.context)
            .environmentObject(store)
            .environmentObject(AppDelegate())
            .environmentObject(AppUpdatePrompt())
    }
}
