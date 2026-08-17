package io.heckel.ntfy.msg

import android.content.Context
import android.media.RingtoneManager
import android.net.Uri
import io.heckel.ntfy.R
import io.heckel.ntfy.db.Repository

/**
 * In-app notification sound keys, similar to WeChat:
 * default / silent / a system ringtone URI. Per-group "global" follows the app default.
 */
object NotificationSounds {
    const val KEY_DEFAULT = "default"
    const val KEY_SILENT = "silent"
    const val KEY_GLOBAL = "global"
    private const val URI_PREFIX = "uri:"

    data class Option(val key: String, val title: String)

    fun encodeUri(uri: Uri): String = URI_PREFIX + uri.toString()

    fun uriFor(context: Context, key: String): Uri? {
        return when {
            key == KEY_SILENT -> null
            key == KEY_DEFAULT || key == KEY_GLOBAL || key.isEmpty() -> defaultNotificationUri(context)
            key.startsWith(URI_PREFIX) -> Uri.parse(key.removePrefix(URI_PREFIX))
            else -> defaultNotificationUri(context)
        }
    }

    /** Prefer system notification default; fall back if OEM returns null/empty. */
    private fun defaultNotificationUri(context: Context): Uri? {
        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)?.let { return it }
        try {
            val manager = RingtoneManager(context)
            manager.setType(RingtoneManager.TYPE_NOTIFICATION)
            val cursor = manager.cursor
            if (cursor.moveToFirst()) {
                val uri = manager.getRingtoneUri(cursor.position)
                cursor.close()
                if (uri != null) return uri
            } else {
                cursor.close()
            }
        } catch (_: Exception) {
            // ignore
        }
        return RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
    }

    fun displayName(context: Context, key: String): String {
        return when {
            key == KEY_SILENT -> context.getString(R.string.settings_notifications_sound_silent)
            key == KEY_DEFAULT || key.isEmpty() -> context.getString(R.string.settings_notifications_sound_default)
            key == KEY_GLOBAL -> context.getString(R.string.settings_notifications_sound_follow_global)
            key.startsWith(URI_PREFIX) -> {
                val uri = Uri.parse(key.removePrefix(URI_PREFIX))
                try {
                    RingtoneManager.getRingtone(context, uri)?.getTitle(context)
                        ?: context.getString(R.string.settings_notifications_sound_custom)
                } catch (_: Exception) {
                    context.getString(R.string.settings_notifications_sound_custom)
                }
            }
            else -> context.getString(R.string.settings_notifications_sound_default)
        }
    }

    fun summary(context: Context, repository: Repository, subscriptionId: Long?): String {
        val stored = repository.getNotificationSound(subscriptionId)
        if (subscriptionId != null && subscriptionId != 0L && followsGlobal(stored)) {
            val globalName = displayName(context, repository.getNotificationSound(null))
            return context.getString(R.string.settings_notifications_sound_summary_follow_global, globalName)
        }
        return displayName(context, stored)
    }

    fun followsGlobal(key: String): Boolean = key == KEY_GLOBAL || key.isEmpty()

    fun listOptions(context: Context, includeFollowGlobal: Boolean): List<Option> {
        val options = mutableListOf<Option>()
        if (includeFollowGlobal) {
            options.add(Option(KEY_GLOBAL, context.getString(R.string.settings_notifications_sound_follow_global)))
        }
        options.add(Option(KEY_DEFAULT, context.getString(R.string.settings_notifications_sound_default)))
        options.add(Option(KEY_SILENT, context.getString(R.string.settings_notifications_sound_silent)))
        try {
            val manager = RingtoneManager(context)
            manager.setType(RingtoneManager.TYPE_NOTIFICATION)
            val cursor = manager.cursor
            while (cursor.moveToNext()) {
                val title = cursor.getString(RingtoneManager.TITLE_COLUMN_INDEX) ?: continue
                val uri = manager.getRingtoneUri(cursor.position) ?: continue
                options.add(Option(encodeUri(uri), title))
            }
            cursor.close()
        } catch (_: Exception) {
            // Some devices fail to enumerate ringtones; default/silent still work.
        }
        return options
    }
}
