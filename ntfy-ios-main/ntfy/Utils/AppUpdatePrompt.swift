import SwiftUI

/// Shared alert state for GitHub release update prompts (launch + Settings).
final class AppUpdatePrompt: ObservableObject {
    @Published var showAlert = false
    @Published var showUpToDate = false
    @Published var showError = false
    @Published var release: UpdateChecker.AppRelease?

    func check(manual: Bool) {
        if !UpdateChecker.isConfigured {
            if manual {
                showError = true
            }
            return
        }
        if !manual && !UpdateChecker.shouldAutoCheck() {
            return
        }
        UpdateChecker.fetchNewerRelease { [weak self] result in
            guard let self = self else { return }
            UpdateChecker.markChecked()
            switch result {
            case .failure:
                if manual {
                    self.showError = true
                }
            case .success(let release):
                if let release = release {
                    self.release = release
                    self.showAlert = true
                } else if manual {
                    self.showUpToDate = true
                }
            }
        }
    }

    func openUpdate() {
        if let release = release {
            UpdateChecker.openReleasePage(release)
        }
    }

    func postpone() {
        UpdateChecker.postpone()
        release = nil
    }
}
