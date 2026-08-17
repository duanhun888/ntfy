import SwiftUI
import UniformTypeIdentifiers

struct PublishView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    let subscription: Subscription

    @State private var message = ""
    @State private var title = ""
    @State private var tags = ""
    @State private var priority = 3
    @State private var markdown = false
    @State private var clickUrl = ""
    @State private var delay = ""
    @State private var email = ""
    @State private var phoneCall = ""
    @State private var attachUrl = ""
    @State private var showTitle = false
    @State private var showTags = false
    @State private var showPriority = false
    @State private var showClick = false
    @State private var showDelay = false
    @State private var showEmail = false
    @State private var showPhone = false
    @State private var showAttachUrl = false
    @State private var attachFilename: String?
    @State private var attachData: Data?
    @State private var attachMime: String?
    @State private var showFileImporter = false
    @State private var publishing = false
    @State private var errorText: String?

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextEditor(text: $message)
                        .frame(minHeight: 120)
                } header: {
                    Text(NSLocalizedString("publish_message", comment: ""))
                }

                Section {
                    Toggle(NSLocalizedString("publish_chip_title", comment: ""), isOn: $showTitle)
                    if showTitle {
                        TextField(NSLocalizedString("publish_title_placeholder", comment: ""), text: $title)
                    }
                    Toggle(NSLocalizedString("publish_chip_tags", comment: ""), isOn: $showTags)
                    if showTags {
                        TextField(NSLocalizedString("publish_tags_placeholder", comment: ""), text: $tags)
                    }
                    Toggle(NSLocalizedString("publish_chip_priority", comment: ""), isOn: $showPriority)
                    if showPriority {
                        Picker(NSLocalizedString("publish_chip_priority", comment: ""), selection: $priority) {
                            Text(NSLocalizedString("priority_min", comment: "")).tag(1)
                            Text(NSLocalizedString("priority_low", comment: "")).tag(2)
                            Text(NSLocalizedString("priority_default", comment: "")).tag(3)
                            Text(NSLocalizedString("priority_high", comment: "")).tag(4)
                            Text(NSLocalizedString("priority_max", comment: "")).tag(5)
                        }
                    }
                    Toggle(NSLocalizedString("publish_chip_markdown", comment: ""), isOn: $markdown)
                    Toggle(NSLocalizedString("publish_chip_click", comment: ""), isOn: $showClick)
                    if showClick {
                        TextField("https://…", text: $clickUrl)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                    }
                    Toggle(NSLocalizedString("publish_chip_delay", comment: ""), isOn: $showDelay)
                    if showDelay {
                        TextField(NSLocalizedString("publish_delay_placeholder", comment: ""), text: $delay)
                    }
                    Toggle(NSLocalizedString("publish_chip_email", comment: ""), isOn: $showEmail)
                    if showEmail {
                        TextField("email@example.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                    }
                    Toggle(NSLocalizedString("publish_chip_call", comment: ""), isOn: $showPhone)
                    if showPhone {
                        TextField("+15551234567", text: $phoneCall)
                            .keyboardType(.phonePad)
                    }
                    Toggle(NSLocalizedString("publish_chip_attach_url", comment: ""), isOn: $showAttachUrl)
                    if showAttachUrl {
                        TextField("https://…", text: $attachUrl)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                    }
                    Button(NSLocalizedString("publish_attach_file", comment: "")) {
                        showFileImporter = true
                    }
                    if let attachFilename {
                        Text(attachFilename)
                            .foregroundColor(.secondary)
                        Button(NSLocalizedString("publish_clear_attachment", comment: ""), role: .destructive) {
                            self.attachFilename = nil
                            attachData = nil
                            attachMime = nil
                        }
                    }
                }

                if let errorText {
                    Section {
                        Text(errorText).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("publish_title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("cancel", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("publish_send", comment: "")) { send() }
                        .disabled(publishing || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    do {
                        attachData = try Data(contentsOf: url)
                        attachFilename = url.lastPathComponent
                        attachMime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
                    } catch {
                        errorText = error.localizedDescription
                    }
                case .failure(let error):
                    errorText = error.localizedDescription
                }
            }
        }
    }

    private func send() {
        guard let baseUrl = subscription.baseUrl, let topic = subscription.topic else { return }
        publishing = true
        errorText = nil
        let user = store.getUser(baseUrl: baseUrl)?.toBasicUser()
        let tagList = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        ApiService.shared.publish(
            subscription: subscription,
            user: user,
            message: message,
            title: showTitle ? title : "",
            priority: showPriority ? priority : 3,
            tags: showTags ? tagList : [],
            markdown: markdown,
            click: showClick ? clickUrl : nil,
            delay: showDelay ? delay : nil,
            email: showEmail ? email : nil,
            call: showPhone ? phoneCall : nil,
            attachUrl: showAttachUrl ? attachUrl : nil,
            attachData: attachData,
            attachFilename: attachFilename,
            attachMime: attachMime,
            customHeaders: store.getCustomHeaders()
        ) { error in
            DispatchQueue.main.async {
                publishing = false
                if let error {
                    errorText = error.localizedDescription
                } else {
                    dismiss()
                }
            }
        }
    }
}
