package io.heckel.ntfy.msg

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import io.heckel.ntfy.BuildConfig
import io.heckel.ntfy.util.Log
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.TimeUnit

/**
 * Checks GitHub/Gitea Releases for a newer app version and downloads the APK for install.
 *
 * Release convention: tag `1.2.3` or `v1.2.3` comparable to [BuildConfig.VERSION_NAME];
 * attach a `.apk` (prefer asset names containing `fdroid` or `release`).
 * Configure [BuildConfig.UPDATE_REPO] and [BuildConfig.UPDATE_API_BASE].
 */
class UpdateChecker(context: Context) {
    private val appContext = context.applicationContext
    private val prefs: SharedPreferences =
        appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val gson = Gson()
    private val client = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .callTimeout(5, TimeUnit.MINUTES)
        .build()

    fun isConfigured(): Boolean {
        val repo = BuildConfig.UPDATE_REPO.trim()
        return repo.isNotEmpty() && !repo.contains("YOUR_ORG") && !repo.contains("YOUR_REPO")
    }

    fun shouldAutoCheck(): Boolean {
        if (!isConfigured()) return false
        val next = prefs.getLong(KEY_NEXT_CHECK_AT, 0L)
        return System.currentTimeMillis() >= next
    }

    fun markChecked() {
        prefs.edit().putLong(KEY_NEXT_CHECK_AT, System.currentTimeMillis() + CHECK_INTERVAL_MS).apply()
    }

    fun postpone() {
        prefs.edit().putLong(KEY_NEXT_CHECK_AT, System.currentTimeMillis() + CHECK_INTERVAL_MS).apply()
    }

    /**
     * Fetches latest release. Returns null if unavailable, not newer, or not configured.
     */
    fun fetchNewerRelease(localVersionName: String = BuildConfig.VERSION_NAME): AppRelease? {
        if (!isConfigured()) {
            Log.d(TAG, "Update check skipped: UPDATE_REPO not configured")
            return null
        }
        val apiBase = BuildConfig.UPDATE_API_BASE.trimEnd('/')
        val repo = BuildConfig.UPDATE_REPO.trim().trimStart('/')
        val url = "$apiBase/repos/$repo/releases/latest"
        Log.d(TAG, "Checking updates: $url")
        val request = Request.Builder()
            .url(url)
            .header("Accept", "application/vnd.github+json, application/json")
            .header("User-Agent", "ntfy-android-update/${BuildConfig.VERSION_NAME}")
            .get()
            .build()
        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                Log.w(TAG, "Update check failed: HTTP ${response.code}")
                return null
            }
            val body = response.body.string()
            val release = gson.fromJson(body, GithubRelease::class.java) ?: return null
            val remoteVersion = normalizeVersion(release.tagName ?: release.name ?: "")
            val localVersion = normalizeVersion(localVersionName)
            if (remoteVersion.isEmpty() || !isNewer(remoteVersion, localVersion)) {
                Log.d(TAG, "No newer release (local=$localVersion remote=$remoteVersion)")
                return null
            }
            val apkUrl = pickApkUrl(release.assets)
            return AppRelease(
                version = remoteVersion,
                tagName = release.tagName ?: remoteVersion,
                body = release.body?.trim().orEmpty(),
                htmlUrl = release.htmlUrl.orEmpty(),
                apkDownloadUrl = apkUrl
            )
        }
    }

    fun downloadApk(downloadUrl: String, onProgress: ((downloaded: Long, total: Long) -> Unit)? = null): File {
        val request = Request.Builder()
            .url(downloadUrl)
            .header("User-Agent", "ntfy-android-update/${BuildConfig.VERSION_NAME}")
            .get()
            .build()
        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                throw IllegalStateException("Download failed: HTTP ${response.code}")
            }
            val body = response.body
            val total = body.contentLength()
            val outFile = File(appContext.cacheDir, "ntfy-update.apk")
            body.byteStream().use { input ->
                FileOutputStream(outFile).use { output ->
                    val buffer = ByteArray(8192)
                    var downloaded = 0L
                    while (true) {
                        val read = input.read(buffer)
                        if (read < 0) break
                        output.write(buffer, 0, read)
                        downloaded += read
                        onProgress?.invoke(downloaded, total)
                    }
                    output.flush()
                }
            }
            return outFile
        }
    }

    fun canInstallPackages(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            appContext.packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    fun intentOpenInstallPermissionSettings(): Intent {
        return Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:${appContext.packageName}")
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }

    fun intentInstallApk(apkFile: File): Intent {
        val authority = "${appContext.packageName}.provider"
        val uri = FileProvider.getUriForFile(appContext, authority, apkFile)
        return Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
    }

    private fun pickApkUrl(assets: List<GithubAsset>?): String? {
        val apks = assets.orEmpty().filter { (it.name ?: "").endsWith(".apk", ignoreCase = true) }
        if (apks.isEmpty()) return null
        val preferred = apks.firstOrNull { name ->
            val n = (name.name ?: "").lowercase()
            n.contains("fdroid") || n.contains("release")
        }
        return (preferred ?: apks.first()).browserDownloadUrl
    }

    companion object {
        private const val TAG = "NtfyUpdateChecker"
        private const val PREFS_NAME = "app_update_checker"
        private const val KEY_NEXT_CHECK_AT = "next_check_at"
        private const val CHECK_INTERVAL_MS = 24L * 60L * 60L * 1000L

        fun normalizeVersion(raw: String): String {
            var v = raw.trim()
            if (v.startsWith("v", ignoreCase = true)) {
                v = v.substring(1)
            }
            // Strip flavor / debug suffixes: 1.25.2-debug, 1.25.2 (fdroid)
            v = v.substringBefore('-').substringBefore(' ').trim()
            return v
        }

        /** True if [remote] is strictly newer than [local] (semver major.minor.patch). */
        fun isNewer(remote: String, local: String): Boolean {
            val r = parseParts(remote)
            val l = parseParts(local)
            val len = maxOf(r.size, l.size)
            for (i in 0 until len) {
                val rv = r.getOrElse(i) { 0 }
                val lv = l.getOrElse(i) { 0 }
                if (rv != lv) return rv > lv
            }
            return false
        }

        private fun parseParts(version: String): List<Int> {
            return normalizeVersion(version)
                .split('.')
                .map { part -> part.filter { it.isDigit() }.toIntOrNull() ?: 0 }
                .ifEmpty { listOf(0) }
        }
    }
}

data class AppRelease(
    val version: String,
    val tagName: String,
    val body: String,
    val htmlUrl: String,
    val apkDownloadUrl: String?
)

private data class GithubRelease(
    @SerializedName("tag_name") val tagName: String? = null,
    val name: String? = null,
    val body: String? = null,
    @SerializedName("html_url") val htmlUrl: String? = null,
    val assets: List<GithubAsset>? = null
)

private data class GithubAsset(
    val name: String? = null,
    @SerializedName("browser_download_url") val browserDownloadUrl: String? = null
)
