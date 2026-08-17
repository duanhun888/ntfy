# iOS ↔ Android Feature Parity

**Policy (2026-08):** Android is the product source of truth. iOS is brought up to Android where platform allows.

**Last Updated: 2026-08-13**

## Platform exclusions (cannot fully align)

| Feature | Reason |
|---------|--------|
| UnifiedPush | Android-only |
| Foreground WebSocket / SubscriberService | iOS has no long-lived background socket; delivery = APNs/FCM + NSE + poll |
| Exact alarms / battery exemption banners | Android-only |
| Material You / dynamic colors | Android-only |
| Broadcast intents | Android-only |
| Dedicated notification channels | Android channels; iOS uses categories / interruption levels |
| Critical Alerts | iOS-only (kept) |

## Product checklist (Android → iOS)

| Feature | Android | iOS target |
|---------|---------|------------|
| Groups create / list / delete | Yes | Yes (keep richer members/bots UI) |
| Bots + webhook copy | Yes | Yes |
| Publish composer | Full | Full |
| Mute (global + per topic) | Yes | Yes (banner may still appear without filtering entitlement; silent + no foreground present) |
| Min priority filter | Yes | Yes |
| Auto-delete | Yes | Yes |
| Per-subscription settings | Yes | Yes |
| Share to topic | ShareActivity | Source ready (`ntfyShare/`); embed Share Extension target in Xcode on Mac |
| Deep link `ntfy://` | Yes | Yes |
| Users (Basic auth) | Yes | Yes |
| Default server | Yes | Yes |
| Attachment auto-download | Yes | Yes |
| Backup / restore | Yes | Yes |
| Custom HTTP headers | Yes | Yes |
| Connection alert | Yes | Best-effort (poll failure banner) |
| In-app logs export | Yes | Yes |
| Dark mode override | Yes | Yes |
| Language picker + zh default | Yes | Yes |
| Client / trusted certs | Yes | Deferred (Keychain + custom URLSession; complex) |
| Chinese-style groups empty home | Yes (2026-08) | Yes (aligned) |
| Hide create FAB when empty | Yes (toolbar + when has groups) | Yes (toolbar + when has groups) |
| Battery optimization banner | Yes (instant groups only) | N/A (iOS) |
