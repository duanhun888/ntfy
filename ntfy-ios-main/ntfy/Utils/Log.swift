import Foundation

struct Log {
    private static let dateFormat = "yy-MM-dd hh:mm:ss.SSS"
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        formatter.locale = .current
        formatter.timeZone = .current
        return formatter
    }()

    private static let maxEntries = 2000
    private static let lock = NSLock()
    private static var recording = false
    private static var entries: [String] = []

    static func setRecordingEnabled(_ enabled: Bool) {
        lock.lock()
        recording = enabled
        if !enabled {
            entries.removeAll()
        }
        lock.unlock()
    }

    static func recordedLogText() -> String {
        lock.lock()
        defer { lock.unlock() }
        return entries.joined(separator: "\n")
    }

    static func clearRecordedLogs() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
    }

    static func d(_ tag: String, _ message: String, _ other: Any?...) {
        log(.debug, tag, message, other)
    }

    static func i(_ tag: String, _ message: String, _ other: Any?...) {
        log(.info, tag, message, other)
    }

    static func w(_ tag: String, _ message: String, _ other: Any?...) {
        log(.warning, tag, message, other)
    }

    static func e(_ tag: String, _ message: String, _ other: Any?...) {
        log(.error, tag, message, other)
    }

    private static func log(_ level: LogLevel, _ tag: String, _ message: String, _ other: Any?...) {
        let line = "\(dateStr()) ntfyApp [\(levelStr(level))] \(tag): \(message)"
        print(line)
        appendRecorded(line)
        if !other.isEmpty {
            other.forEach { o in
                if let o = o {
                    let extra = "  \(String(describing: o))"
                    print(extra)
                    appendRecorded(extra)
                }
            }
        }
    }

    private static func appendRecorded(_ line: String) {
        lock.lock()
        defer { lock.unlock() }
        guard recording else { return }
        entries.append(line)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    private static func dateStr() -> String {
        dateFormatter.string(from: Date())
    }

    private static func levelStr(_ level: LogLevel) -> String {
        switch level {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING ⚠️"
        case .error: return "ERROR ‼️"
        }
    }
}

private enum LogLevel {
    case debug
    case info
    case warning
    case error
}
