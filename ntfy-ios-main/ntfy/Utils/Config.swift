import Foundation

enum Config {
    /// Hardcoded self-hosted API (production).
    static var appBaseUrl: String {
        "https://sendmsg.xhsnw.com"
    }

    /// GitHub/Gitea Releases API root. Example Gitea: `https://git.example.com/api/v1`
    static var updateApiBase: String {
        "https://api.github.com"
    }

    /// `owner/repo` for GitHub Releases.
    /// Tag: `1.2.3` or `v1.2.3`; iOS opens release page (no in-app IPA install).
    static var updateRepo: String {
        "duanhun888/ntfy"
    }
    
    static var build: String {
        string(for: "CFBundleVersion")
    }
    
    static var version: String {
        string(for: "CFBundleShortVersionString")
    }
    
    static var osVersion: String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return String(os.majorVersion) + "." + String(os.minorVersion) + "." + String(os.patchVersion)
    }
    
    static private func string(for key: String) -> String {
        Bundle.main.infoDictionary?[key] as! String
    }
}
