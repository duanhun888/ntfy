import Foundation
import SwiftUI

struct MainView: View {
    var body: some View {
        TabView {
            GroupListView()
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text(NSLocalizedString("tab_groups", comment: ""))
                }
            SubscriptionListView()
                .tabItem {
                    Image(systemName: "message.fill")
                    Text(NSLocalizedString("tab_notifications", comment: ""))
                }
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text(NSLocalizedString("tab_settings", comment: ""))
                }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store.preview // Store.previewEmpty
        MainView()
            .environment(\.managedObjectContext, store.context)
            .environmentObject(store)
            .environmentObject(AppDelegate())
    }
}
