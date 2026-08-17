import SwiftUI
import Firebase

// TODO: Errors are not shown to the user, but instead just logged

@main
struct AppMain: App {
    private let tag = "AppMain"
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate: AppDelegate
    @StateObject private var store = Store.shared
    @StateObject private var updatePrompt = AppUpdatePrompt()

    init() {
        Log.d(tag, "Launching ntfy 🥳. Welcome!")
        Log.d(tag, "Base URL is \(Config.appBaseUrl), user agent is \(ApiService.userAgent)")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(delegate)
                .environmentObject(updatePrompt)
                .environment(\.managedObjectContext, store.context)
                .onAppear {
                    store.ensureDefaultLanguage()
                    store.applyDarkMode()
                    if store.getRecordLogs() {
                        Log.setRecordingEnabled(true)
                    }
                    store.deleteExpiredNotificationsForAllSubscriptions()
                    updatePrompt.check(manual: false)
                }
                .onOpenURL { url in
                    DeepLinkRouter.handle(url: url, store: store, delegate: delegate)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    Log.d(tag, "App became active, refreshing objects")
                    store.hardRefresh()
                    store.applyDarkMode()
                    store.deleteExpiredNotificationsForAllSubscriptions()
                    delegate.refreshNotificationSettings()
                }
                .alert(NSLocalizedString("update_dialog_title", comment: ""), isPresented: $updatePrompt.showAlert) {
                    Button(NSLocalizedString("update_now", comment: "")) {
                        updatePrompt.openUpdate()
                    }
                    Button(NSLocalizedString("update_later", comment: ""), role: .cancel) {
                        updatePrompt.postpone()
                    }
                } message: {
                    Text(updateAlertMessage)
                }
                .alert(NSLocalizedString("update_up_to_date", comment: ""), isPresented: $updatePrompt.showUpToDate) {
                    Button("OK", role: .cancel) {}
                }
                .alert(NSLocalizedString("update_check_failed", comment: ""), isPresented: $updatePrompt.showError) {
                    Button("OK", role: .cancel) {}
                }
        }
    }

    private var updateAlertMessage: String {
        guard let release = updatePrompt.release else { return "" }
        let notes = release.body.isEmpty
            ? NSLocalizedString("update_no_notes", comment: "")
            : String(release.body.prefix(800))
        return String(
            format: NSLocalizedString("update_dialog_message", comment: ""),
            Config.version,
            release.version,
            notes
        )
    }
}
