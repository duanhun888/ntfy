import SwiftUI
import UIKit

struct GroupDetailView: View {
    let group: ChatGroup

    @EnvironmentObject private var store: Store
    @State private var members: [ChatMember] = []
    @State private var bots: [ChatBot] = []
    @State private var errorMessage: String?
    @State private var memberUsername = ""
    @State private var botName = ""
    @State private var webhookToShow: String?
    @State private var busy = false

    private var baseUrl: String {
        store.getDefaultBaseUrl()
    }

    private var user: BasicUser? {
        store.getUser(baseUrl: baseUrl)?.toBasicUser()
    }

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundColor(.red)
                }
            }

            Section(header: Text("Members")) {
                ForEach(members) { member in
                    HStack {
                        Text(member.username ?? member.userId)
                        Spacer()
                        Text(member.role ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onDelete(perform: removeMembers)

                HStack {
                    TextField("Username", text: $memberUsername)
                    Button("Add") { addMember() }
                        .disabled(busy || memberUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Section(header: Text("Bots / Webhook"), footer: Text("Create a bot to get a Webhook URL. POST DingTalk-style text JSON to notify the group.")) {
                ForEach(bots) { bot in
                    HStack {
                        Text(bot.name)
                        Spacer()
                        if let hint = bot.tokenHint {
                            Text(hint)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteBots)

                HStack {
                    TextField("Bot name", text: $botName)
                    Button("Create") { createBot() }
                        .disabled(busy || botName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .navigationTitle(group.name)
        .onAppear(perform: reload)
        .alert(isPresented: Binding(
            get: { webhookToShow != nil },
            set: { if !$0 { webhookToShow = nil } }
        )) {
            Alert(
                title: Text("Bot webhook"),
                message: Text(webhookToShow ?? ""),
                primaryButton: .default(Text("Copy")) {
                    if let webhookToShow {
                        UIPasteboard.general.string = webhookToShow
                    }
                },
                secondaryButton: .cancel(Text("OK"))
            )
        }
    }

    private func reload() {
        guard let user else {
            errorMessage = GroupsApiError.unauthorized.localizedDescription
            return
        }
        errorMessage = nil
        GroupsApi.shared.listMembers(baseUrl: baseUrl, user: user, groupId: group.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let list): members = list
                case .failure(let error): errorMessage = error.localizedDescription
                }
            }
        }
        GroupsApi.shared.listBots(baseUrl: baseUrl, user: user, groupId: group.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let list): bots = list
                case .failure(let error): errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func addMember() {
        guard let user else { return }
        let username = memberUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        busy = true
        GroupsApi.shared.addMember(baseUrl: baseUrl, user: user, groupId: group.id, username: username) { result in
            DispatchQueue.main.async {
                busy = false
                switch result {
                case .success:
                    memberUsername = ""
                    reload()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func removeMembers(at offsets: IndexSet) {
        guard let user else { return }
        for index in offsets {
            let member = members[index]
            let key = member.username?.isEmpty == false ? member.username! : member.userId
            GroupsApi.shared.removeMember(baseUrl: baseUrl, user: user, groupId: group.id, userKey: key) { result in
                DispatchQueue.main.async {
                    if case .failure(let error) = result {
                        errorMessage = error.localizedDescription
                    } else {
                        reload()
                    }
                }
            }
        }
    }

    private func createBot() {
        guard let user else { return }
        let name = botName.trimmingCharacters(in: .whitespacesAndNewlines)
        busy = true
        GroupsApi.shared.createBot(baseUrl: baseUrl, user: user, groupId: group.id, name: name) { result in
            DispatchQueue.main.async {
                busy = false
                switch result {
                case .success(let bot):
                    botName = ""
                    webhookToShow = bot.webhookUrl
                    reload()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func deleteBots(at offsets: IndexSet) {
        guard let user else { return }
        for index in offsets {
            let bot = bots[index]
            GroupsApi.shared.deleteBot(baseUrl: baseUrl, user: user, groupId: group.id, botId: bot.id) { result in
                DispatchQueue.main.async {
                    if case .failure(let error) = result {
                        errorMessage = error.localizedDescription
                    } else {
                        reload()
                    }
                }
            }
        }
    }
}
