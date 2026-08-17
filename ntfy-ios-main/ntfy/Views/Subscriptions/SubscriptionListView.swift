import SwiftUI
import CoreData
import FirebaseMessaging
import UserNotifications

struct SubscriptionListView: View {
    let tag = "SubscriptionList"
    
    @EnvironmentObject private var store: Store
    @ObservedObject var subscriptionsModel = SubscriptionsObservable()
    
    private var subscriptionManager: SubscriptionManager {
        return SubscriptionManager(store: store)
    }
    
    var body: some View {
        NavigationView {
            if #available(iOS 15.0, *) {
                subscriptionList
                    .refreshable {
                        pollSubscriptions()
                    }
            } else {
                subscriptionList
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                pollSubscriptions()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                    }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private var subscriptionList: some View {
        List {
            ForEach(subscriptionsModel.subscriptions) { subscription in
                SubscriptionItemNavView(subscription: subscription)
            }
        }
        .listStyle(PlainListStyle())
        .navigationTitle("Notifications")
        .overlay(Group {
            if subscriptionsModel.subscriptions.isEmpty {
                VStack {
                    Text("No group notifications yet")
                        .font(.title2)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.bottom)

                    Text("Open the My groups tab, create a group, and add a bot. Messages sent to the bot webhook will appear here.")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
            }
        })
        .onAppear {
            // Ensures subscription count stays up to date, so a pull to refresh isn't required
            pollSubscriptions()
        }
    }

    private func pollSubscriptions() {
        subscriptionsModel.subscriptions.forEach { subscription in
            subscriptionManager.poll(subscription)
        }
    }
}

struct SubscriptionItemNavView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var delegate: AppDelegate
    @ObservedObject var subscription: Subscription
    @State private var unsubscribeAlert = false
    
    private var subscriptionManager: SubscriptionManager {
        return SubscriptionManager(store: store)
    }
    
    var body: some View {
        if #available(iOS 15.0, *) {
            subscriptionRow
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        self.unsubscribeAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash.circle")
                    }
                }
        } else {
            subscriptionRow
        }
    }
    
    private var subscriptionRow: some View {
        ZStack {
            NavigationLink(
                destination: NotificationListView(subscription: subscription),
                tag: subscription.urlString(),
                selection: $delegate.selectedBaseUrl
            ) {
                EmptyView()
            }
            .opacity(0.0)
            .buttonStyle(PlainButtonStyle())
            
            SubscriptionItemRowView(subscription: subscription)
        }
        .alert(isPresented: $unsubscribeAlert) {
            Alert(
                title: Text("Unsubscribe"),
                message: Text("Do you really want to unsubscribe from this topic and delete all of the notifications you received?"),
                primaryButton: .destructive(
                    Text("Unsubscribe"),
                    action: {
                        self.subscriptionManager.unsubscribe(subscription)
                        self.unsubscribeAlert = false
                    }
                ),
                secondaryButton: .cancel()
            )
        }
    }
}

struct SubscriptionItemRowView: View {
    @ObservedObject var subscription: Subscription
    
    var body: some View {
        let totalNotificationCount = subscription.notificationCount()
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(subscription.displayName())
                    .font(.headline)
                    .bold()
                    .lineLimit(1)
                Spacer()
                Text(subscription.lastNotification()?.shortDateTime() ?? "")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 12.0))
                    .foregroundColor(.gray)
            }
            Spacer()
            Text("\(totalNotificationCount) notification\(totalNotificationCount != 1 ? "s" : "")")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.all, 4)
    }
}

struct SubscriptionListView_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store.preview // Store.previewEmpty
        SubscriptionListView()
            .environment(\.managedObjectContext, store.context)
            .environmentObject(store)
            .environmentObject(AppDelegate())
    }
}
