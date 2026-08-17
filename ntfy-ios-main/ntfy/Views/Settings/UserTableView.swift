//
//  UserTableView.swift
//  ntfy
//
//  Created by Alek Michelson on 4/10/26.
//

import SwiftUI

enum UserDialog: Identifiable {
    case add
    case edit(User)
    
    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let user):
            return user.objectID.uriRepresentation().absoluteString
        }
    }
    
    var user: User? {
        switch self {
        case .add:
            return nil
        case .edit(let user):
            return user
        }
    }
}

struct UserTableView: View {
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \User.baseUrl, ascending: true)]) var users: FetchedResults<User>
    
    @Binding var dialog: UserDialog?
    
    var body: some View {
        if users.isEmpty {
            UsersEmptyTipView()
        }
        ForEach(users) { user in
            Button(action: {
                dialog = .edit(user)
            }) {
                UserRowView(user: user)
                    .foregroundColor(.primary)
            }
        }
        Button(action: {
            dialog = .add
        }) {
            HStack {
                Image(systemName: "plus")
                Text(NSLocalizedString("user_add", comment: ""))
            }
            .foregroundColor(CnTheme.celadon)
        }
    }
}

/// Chinese-style tip when no server accounts exist yet.
private struct UsersEmptyTipView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(CnTheme.cinnabar)
                .frame(width: 3)
                .frame(minHeight: 36)

            Text(NSLocalizedString("user_empty_tip", comment: ""))
                .font(.footnote)
                .foregroundColor(CnTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .listRowBackground(CnTheme.celadonSoft)
    }
}
