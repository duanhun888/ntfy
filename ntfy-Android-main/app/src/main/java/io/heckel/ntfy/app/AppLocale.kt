package io.heckel.ntfy.app

import android.content.Context
import android.content.res.Configuration
import android.os.LocaleList
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import java.util.Locale

/**
 * Product default is Simplified Chinese. Per-app locales set in
 * [Application.onCreate] are applied too late for the first Activity on
 * API 33+, so every context is wrapped here before inflation.
 */
object AppLocale {
    const val DEFAULT_TAG = "zh-CN"

    fun wrap(base: Context): Context {
        val tag = desiredTag(base) ?: return base
        val locale = Locale.forLanguageTag(tag)
        if (locale.language.isEmpty()) {
            return base
        }
        Locale.setDefault(locale)
        val locales = LocaleList(locale)
        LocaleList.setDefault(locales)
        val config = Configuration(base.resources.configuration)
        config.setLocales(locales)
        return base.createConfigurationContext(config)
    }

    fun seedDefaultIfNeeded(base: Context) {
        if (userChoseLanguage(base)) {
            return
        }
        val current = AppCompatDelegate.getApplicationLocales().toLanguageTags()
        if (!isSimplifiedChinese(current)) {
            AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags(DEFAULT_TAG))
        }
    }

    private fun desiredTag(base: Context): String? {
        if (!userChoseLanguage(base)) {
            return DEFAULT_TAG
        }
        val stored = AppCompatDelegate.getApplicationLocales()
        if (stored.isEmpty) {
            return null
        }
        return stored.toLanguageTags()
    }

    private fun userChoseLanguage(base: Context): Boolean {
        return base.getSharedPreferences(Application.PREFS_LOCALE, Context.MODE_PRIVATE)
            .getBoolean(Application.PREFS_USER_CHOSE_LANGUAGE, false)
    }

    private fun isSimplifiedChinese(tags: String): Boolean {
        return tags == DEFAULT_TAG || tags.startsWith("zh-CN") || tags.startsWith("zh-Hans")
    }
}
