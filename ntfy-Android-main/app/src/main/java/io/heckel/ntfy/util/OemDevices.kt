package io.heckel.ntfy.util

import android.os.Build

/**
 * OEM quirks: Huawei/Honor (and several other Chinese brands) often mute or ignore
 * NotificationChannel sounds. We play the ringtone ourselves as a fallback.
 */
object OemDevices {
    fun needsExplicitNotificationSound(): Boolean {
        val m = Build.MANUFACTURER.orEmpty().lowercase()
        val b = Build.BRAND.orEmpty().lowercase()
        return listOf(m, b).any { name ->
            name.contains("huawei") ||
                name.contains("honor") ||
                name.contains("xiaomi") ||
                name.contains("redmi") ||
                name.contains("oppo") ||
                name.contains("vivo") ||
                name.contains("realme") ||
                name.contains("oneplus") ||
                name.contains("meizu")
        }
    }
}
