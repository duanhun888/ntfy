import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct BackupRestoreView: View {
    @EnvironmentObject private var store: Store
    @State private var exportItem: BackupDocument?
    @State private var showImporter = false
    @State private var status: String?

    var body: some View {
        Section(header: Text(NSLocalizedString("settings_backup", comment: ""))) {
            Button(NSLocalizedString("settings_backup_export", comment: "")) {
                do {
                    let data = try Backuper(store: store).exportJSON()
                    exportItem = BackupDocument(data: data)
                } catch {
                    status = error.localizedDescription
                }
            }
            Button(NSLocalizedString("settings_backup_import", comment: "")) {
                showImporter = true
            }
            if let status {
                Text(status).font(.footnote).foregroundColor(.secondary)
            }
        }
        .fileExporter(
            isPresented: Binding(get: { exportItem != nil }, set: { if !$0 { exportItem = nil } }),
            document: exportItem,
            contentType: .json,
            defaultFilename: "ntfy-backup.json"
        ) { result in
            switch result {
            case .success:
                status = NSLocalizedString("settings_backup_export_ok", comment: "")
            case .failure(let error):
                status = error.localizedDescription
            }
            exportItem = nil
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                do {
                    let data = try Data(contentsOf: url)
                    try Backuper(store: store).importJSON(data)
                    store.applyDarkMode()
                    if store.getRecordLogs() {
                        Log.setRecordingEnabled(true)
                    }
                    status = NSLocalizedString("settings_backup_import_ok", comment: "")
                } catch {
                    status = error.localizedDescription
                }
            case .failure(let error):
                status = error.localizedDescription
            }
        }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct CustomHeadersView: View {
    @EnvironmentObject private var store: Store
    @State private var rows: [(name: String, value: String)] = []

    var body: some View {
        Section(
            header: Text(NSLocalizedString("settings_custom_headers", comment: "")),
            footer: Text(NSLocalizedString("settings_custom_headers_footer", comment: ""))
        ) {
            ForEach(rows.indices, id: \.self) { idx in
                HStack {
                    TextField("Name", text: Binding(
                        get: { rows[idx].name },
                        set: { rows[idx].name = $0; save() }
                    ))
                    TextField("Value", text: Binding(
                        get: { rows[idx].value },
                        set: { rows[idx].value = $0; save() }
                    ))
                }
            }
            .onDelete { indexSet in
                rows.remove(atOffsets: indexSet)
                save()
            }
            Button(NSLocalizedString("settings_custom_headers_add", comment: "")) {
                rows.append(("", ""))
            }
        }
        .onAppear {
            rows = store.getCustomHeaders()
            if rows.isEmpty {
                rows = []
            }
        }
    }

    private func save() {
        store.setCustomHeaders(rows.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty })
    }
}

struct LogsSettingsView: View {
    @EnvironmentObject private var store: Store
    @State private var record = false
    @State private var shareText: String?
    @State private var showShare = false

    var body: some View {
        Section(header: Text(NSLocalizedString("settings_logs", comment: ""))) {
            Toggle(NSLocalizedString("settings_logs_record", comment: ""), isOn: Binding(
                get: { record },
                set: {
                    record = $0
                    store.setRecordLogs($0)
                }
            ))
            Button(NSLocalizedString("settings_logs_export", comment: "")) {
                shareText = Log.recordedLogText()
                showShare = true
            }
            Button(NSLocalizedString("settings_logs_clear", comment: ""), role: .destructive) {
                Log.clearRecordedLogs()
            }
        }
        .onAppear { record = store.getRecordLogs() }
        .sheet(isPresented: $showShare) {
            ActivityView(activityItems: [shareText ?? ""])
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct DarkModePicker: View {
    @EnvironmentObject private var store: Store
    @State private var mode = NotificationPolicy.darkModeFollowSystem

    var body: some View {
        Picker(NSLocalizedString("settings_dark_mode", comment: ""), selection: Binding(
            get: { mode },
            set: {
                mode = $0
                store.setDarkMode($0)
            }
        )) {
            Text(NSLocalizedString("dark_mode_system", comment: "")).tag(NotificationPolicy.darkModeFollowSystem)
            Text(NSLocalizedString("dark_mode_light", comment: "")).tag(NotificationPolicy.darkModeLight)
            Text(NSLocalizedString("dark_mode_dark", comment: "")).tag(NotificationPolicy.darkModeDark)
        }
        .onAppear { mode = store.getDarkMode() }
    }
}

struct LanguagePicker: View {
    @EnvironmentObject private var store: Store
    @State private var language = "zh-Hans"

    private let languages: [(String, String)] = [
        ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁體中文"),
        ("en", "English")
    ]

    var body: some View {
        Picker(NSLocalizedString("settings_language", comment: ""), selection: Binding(
            get: { language },
            set: {
                language = $0
                store.setLanguage($0)
            }
        )) {
            ForEach(languages, id: \.0) { code, name in
                Text(name).tag(code)
            }
        }
        .onAppear { language = store.getLanguage() }
    }
}

struct ConnectionAlertPicker: View {
    @EnvironmentObject private var store: Store
    @State private var seconds: Int64 = 0

    var body: some View {
        Picker(NSLocalizedString("settings_connection_alert", comment: ""), selection: Binding(
            get: { seconds },
            set: {
                seconds = $0
                store.setConnectionAlertSeconds($0)
            }
        )) {
            Text(NSLocalizedString("connection_alert_off", comment: "")).tag(Int64(0))
            Text(NSLocalizedString("connection_alert_3m", comment: "")).tag(Int64(180))
            Text(NSLocalizedString("connection_alert_10m", comment: "")).tag(Int64(600))
            Text(NSLocalizedString("connection_alert_1h", comment: "")).tag(Int64(3600))
        }
        .onAppear { seconds = store.getConnectionAlertSeconds() }
    }
}
