//
//  UserEditorView.swift
//  ntfy
//
//  Created by Alek Michelson on 4/10/26.
//

import SwiftUI

struct UserEditorView: View {
    @EnvironmentObject private var store: Store
    
    let selectedUser: User?
    let onSave: (String, String, String) -> Void
    let onDelete: (User) -> Void
    let onCancel: () -> Void
    
    @State private var baseUrl: String
    @State private var username: String
    @State private var password: String
    
    init(
        selectedUser: User?,
        onSave: @escaping (String, String, String) -> Void,
        onDelete: @escaping (User) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.selectedUser = selectedUser
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _baseUrl = State(initialValue: selectedUser?.baseUrl ?? "")
        _username = State(initialValue: selectedUser?.username ?? "")
        _password = State(initialValue: "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(footer: footerText) {
                    if isNewUser {
                        TextField(NSLocalizedString("user_base_url", comment: ""), text: $baseUrl)
                            .disableAutocapitalization()
                            .disableAutocorrection(true)
                    }
                    TextField(NSLocalizedString("user_username", comment: ""), text: $username)
                        .disableAutocapitalization()
                        .disableAutocorrection(true)
                    SecureField(
                        NSLocalizedString(isNewUser ? "user_password" : "user_password_edit", comment: ""),
                        text: $password
                    )
                }
            }
            .navigationTitle(NSLocalizedString(isNewUser ? "user_add_title" : "user_edit_title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isNewUser {
                        Button(NSLocalizedString("cancel", comment: "")) {
                            onCancel()
                        }
                    } else {
                        Menu {
                            Button(NSLocalizedString("cancel", comment: "")) {
                                onCancel()
                            }
                            if #available(iOS 15.0, *) {
                                Button(role: .destructive) {
                                    deleteAction()
                                } label: {
                                    Text(NSLocalizedString("user_delete", comment: ""))
                                }
                            } else {
                                Button(NSLocalizedString("user_delete", comment: "")) {
                                    deleteAction()
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .padding([.leading], 40)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: saveAction) {
                        Text(NSLocalizedString("save", comment: ""))
                    }
                    .disabled(!isValid())
                }
            }
        }
    }

    private var footerText: Text {
        if isNewUser {
            return Text(NSLocalizedString("user_footer_add", comment: ""))
        }
        let format = NSLocalizedString("user_footer_edit", comment: "")
        return Text(String(format: format, shortUrl(url: baseUrl)))
    }
    
    private var isNewUser: Bool {
        selectedUser == nil
    }
    
    private func saveAction() {
        let finalPassword: String
        if let user = selectedUser, password.isEmpty {
            finalPassword = user.password ?? "?"
        } else {
            finalPassword = password
        }
        onSave(baseUrl, username, finalPassword)
    }
    
    private func deleteAction() {
        guard let selectedUser = selectedUser else { return }
        onDelete(selectedUser)
    }
    
    private func isValid() -> Bool {
        if isNewUser {
            if baseUrl.range(of: "^https?://.+", options: .regularExpression, range: nil, locale: nil) == nil {
                return false
            } else if username.isEmpty || password.isEmpty {
                return false
            } else if store.getUser(baseUrl: baseUrl) != nil {
                return false
            }
        } else if username.isEmpty {
            return false
        }
        return true
    }
}
