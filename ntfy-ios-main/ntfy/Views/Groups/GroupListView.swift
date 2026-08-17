import SwiftUI

struct GroupListView: View {
    @EnvironmentObject private var store: Store
    @State private var groups: [ChatGroup] = []
    @State private var errorMessage: String?
    @State private var loading = false
    @State private var showingCreate = false
    @State private var newGroupName = ""
    @State private var busy = false
    @State private var createError: String?

    private var baseUrl: String {
        store.getDefaultBaseUrl()
    }

    private var user: BasicUser? {
        store.getUser(baseUrl: baseUrl)?.toBasicUser()
    }

    private var showEmptyGuide: Bool {
        !loading && groups.isEmpty
    }

    var body: some View {
        NavigationView {
            ZStack {
                CnTheme.paper.ignoresSafeArea()

                if showEmptyGuide {
                    GroupEmptyGuideView(
                        needsAccount: user == nil,
                        onCreate: { showingCreate = true }
                    )
                } else {
                    List {
                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundColor(CnTheme.cinnabar)
                        }
                        ForEach(groups) { group in
                            NavigationLink(destination: GroupDetailView(group: group)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(group.name)
                                        .font(.headline)
                                        .foregroundColor(CnTheme.ink)
                                    Text(String(format: NSLocalizedString("groups_members_count", comment: ""), group.memberCount ?? 0))
                                        .font(.caption)
                                        .foregroundColor(CnTheme.inkMuted)
                                }
                                .padding(.vertical, 2)
                            }
                            .listRowBackground(CnTheme.panel)
                        }
                        .onDelete(perform: deleteGroups)
                    }
                    .listStyle(PlainListStyle())
                }

                if loading {
                    ProgressView()
                }
            }
            .navigationTitle(NSLocalizedString("groups_title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !groups.isEmpty {
                        Button {
                            showingCreate = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCreate) {
                NavigationView {
                    Form {
                        Section(footer: Text(NSLocalizedString("groups_create_footer", comment: ""))) {
                            TextField(NSLocalizedString("groups_name_placeholder", comment: ""), text: $newGroupName)
                        }
                        if let createError {
                            Text(createError).foregroundColor(CnTheme.cinnabar)
                        }
                    }
                    .navigationTitle(NSLocalizedString("groups_create_title", comment: ""))
                    .navigationBarItems(
                        leading: Button(NSLocalizedString("cancel", comment: "")) {
                            showingCreate = false
                            createError = nil
                        },
                        trailing: Button(NSLocalizedString("groups_create_action", comment: "")) { createGroup() }
                            .disabled(busy || newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    )
                }
            }
            .onAppear(perform: loadGroups)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func loadGroups() {
        guard let user else {
            errorMessage = nil
            groups = []
            loading = false
            return
        }
        loading = true
        errorMessage = nil
        GroupsApi.shared.listGroups(baseUrl: baseUrl, user: user) { result in
            DispatchQueue.main.async {
                loading = false
                switch result {
                case .success(let list):
                    groups = list
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    groups = []
                }
            }
        }
    }

    private func createGroup() {
        guard let user else {
            createError = NSLocalizedString("groups_need_account", comment: "")
            return
        }
        let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        busy = true
        createError = nil
        GroupsApi.shared.createGroup(baseUrl: baseUrl, user: user, name: name) { result in
            DispatchQueue.main.async {
                busy = false
                switch result {
                case .success(let group):
                    SubscriptionManager(store: store).subscribe(baseUrl: baseUrl, topic: group.topic)
                    newGroupName = ""
                    showingCreate = false
                    loadGroups()
                case .failure(let error):
                    createError = error.localizedDescription
                }
            }
        }
    }

    private func deleteGroups(at offsets: IndexSet) {
        guard let user else { return }
        for index in offsets {
            let group = groups[index]
            GroupsApi.shared.deleteGroup(baseUrl: baseUrl, user: user, groupId: group.id) { result in
                DispatchQueue.main.async {
                    if case .failure(let error) = result {
                        errorMessage = error.localizedDescription
                    } else {
                        loadGroups()
                    }
                }
            }
        }
    }
}

/// Matches Android `main_empty_state` — Chinese-style onboarding for groups.
private struct GroupEmptyGuideView: View {
    let needsAccount: Bool
    let onCreate: () -> Void

    private let steps: [(String, String)] = [
        ("groups_step1_title", "groups_step1_body"),
        ("groups_step2_title", "groups_step2_body"),
        ("groups_step3_title", "groups_step3_body"),
        ("groups_step4_title", "groups_step4_body")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Rectangle()
                    .fill(CnTheme.cinnabar)
                    .frame(width: 36, height: 3)

                Text(NSLocalizedString("groups_brand", comment: ""))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(CnTheme.ink)
                    .padding(.top, 12)
                    .tracking(1.2)

                Text(NSLocalizedString("groups_empty_title", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(CnTheme.inkMuted)
                    .padding(.top, 6)

                Text(NSLocalizedString("groups_empty_subtitle", comment: ""))
                    .font(.footnote)
                    .foregroundColor(CnTheme.inkMuted)
                    .padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)

                Text(NSLocalizedString("groups_steps_header", comment: ""))
                    .font(.caption)
                    .foregroundColor(CnTheme.inkMuted)
                    .tracking(2)
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(CnTheme.seal)
                            .cornerRadius(2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString(step.0, comment: ""))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(CnTheme.ink)
                            Text(NSLocalizedString(step.1, comment: ""))
                                .font(.footnote)
                                .foregroundColor(CnTheme.inkMuted)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CnTheme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(CnTheme.lineStrong, lineWidth: 1)
                    )
                    .padding(.bottom, 8)
                }

                Button(action: onCreate) {
                    Text(NSLocalizedString("groups_create_action", comment: ""))
                        .font(.system(size: 16, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(CnTheme.celadon)
                        .cornerRadius(2)
                }
                .padding(.top, 8)

                HStack(alignment: .top, spacing: 10) {
                    Rectangle()
                        .fill(CnTheme.cinnabar)
                        .frame(width: 3)
                        .frame(minHeight: 36)

                    Text(NSLocalizedString(
                        needsAccount ? "groups_tip_need_account" : "groups_tip_account",
                        comment: ""
                    ))
                    .font(.footnote)
                    .foregroundColor(CnTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(CnTheme.celadonSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(CnTheme.lineStrong.opacity(0.5), lineWidth: 1)
                )
                .padding(.top, 16)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
    }
}
