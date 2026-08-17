import Foundation
import UIKit

/// Checks GitHub/Gitea Releases for a newer app version.
/// Release tag: `1.2.3` or `v1.2.3` (compared to CFBundleShortVersionString).
/// On update, opens the release `html_url` in the browser (IPA cannot be installed in-app).
enum UpdateChecker {
    private static let tag = "UpdateChecker"
    private static let nextCheckKey = "app_update_next_check_at"
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    struct AppRelease {
        let version: String
        let tagName: String
        let body: String
        let htmlUrl: String
    }

    static var isConfigured: Bool {
        let repo = Config.updateRepo.trimmingCharacters(in: .whitespacesAndNewlines)
        return !repo.isEmpty && !repo.contains("YOUR_ORG") && !repo.contains("YOUR_REPO")
    }

    static func shouldAutoCheck() -> Bool {
        guard isConfigured else { return false }
        let next = UserDefaults.standard.double(forKey: nextCheckKey)
        return Date().timeIntervalSince1970 >= next
    }

    static func markChecked() {
        UserDefaults.standard.set(Date().timeIntervalSince1970 + checkInterval, forKey: nextCheckKey)
    }

    static func postpone() {
        markChecked()
    }

    static func fetchNewerRelease(completion: @escaping (Result<AppRelease?, Error>) -> Void) {
        guard isConfigured else {
            completion(.success(nil))
            return
        }
        let apiBase = Config.updateApiBase.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let repo = Config.updateRepo.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(apiBase)/repos/\(repo)/releases/latest") else {
            completion(.failure(URLError(.badURL)))
            return
        }
        Log.d(tag, "Checking updates: \(url.absoluteString)")
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json, application/json", forHTTPHeaderField: "Accept")
        request.setValue("ntfy-ios-update/\(Config.version)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(URLError(.badServerResponse)))
                }
                return
            }
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let tagName = (json?["tag_name"] as? String) ?? (json?["name"] as? String) ?? ""
                let remote = normalizeVersion(tagName)
                let local = normalizeVersion(Config.version)
                guard !remote.isEmpty, isNewer(remote: remote, local: local) else {
                    Log.d(tag, "No newer release (local=\(local) remote=\(remote))")
                    DispatchQueue.main.async { completion(.success(nil)) }
                    return
                }
                let body = (json?["body"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let htmlUrl = (json?["html_url"] as? String) ?? ""
                let release = AppRelease(version: remote, tagName: tagName, body: body, htmlUrl: htmlUrl)
                DispatchQueue.main.async { completion(.success(release)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    static func openReleasePage(_ release: AppRelease) {
        guard let url = URL(string: release.htmlUrl), !release.htmlUrl.isEmpty else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    static func normalizeVersion(_ raw: String) -> String {
        var v = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if v.lowercased().hasPrefix("v") {
            v = String(v.dropFirst())
        }
        if let dash = v.firstIndex(of: "-") {
            v = String(v[..<dash])
        }
        if let space = v.firstIndex(of: " ") {
            v = String(v[..<space])
        }
        return v.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isNewer(remote: String, local: String) -> Bool {
        let r = parseParts(remote)
        let l = parseParts(local)
        let len = max(r.count, l.count)
        for i in 0..<len {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv != lv { return rv > lv }
        }
        return false
    }

    private static func parseParts(_ version: String) -> [Int] {
        let normalized = normalizeVersion(version)
        let parts = normalized.split(separator: ".").map { part -> Int in
            let digits = part.filter { $0.isNumber }
            return Int(digits) ?? 0
        }
        return parts.isEmpty ? [0] : parts
    }
}
