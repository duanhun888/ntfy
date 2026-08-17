# Share Extension setup (Mac / Xcode)

Source is ready under `ntfyShare/`. On a Mac, add the target:

1. File → New → Target → Share Extension → name `ntfyShare`
2. Replace generated files with `ntfyShare/ShareViewController.swift`, `Info.plist`, `ntfyShare.entitlements`
3. Enable App Group `group.io.heckel.ntfy` (same as app + NSE)
4. Add shared sources to the target: `Store.swift`, `Store+Preferences.swift`, `ApiService.swift`, `Helpers.swift`, `Config.swift`, `Log.swift`, `Subscription.swift`, `User.swift`, `NotificationPolicy.swift`, `ntfy.xcdatamodeld`
5. Embed the extension in the `ntfy` app target

Until the target is embedded, sharing from other apps will not show ntfy; in-app publish and `ntfy://` deep links still work.
