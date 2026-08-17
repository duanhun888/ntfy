package io.heckel.ntfy.ui

import android.app.Activity
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.lifecycleScope
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import io.heckel.ntfy.BuildConfig
import io.heckel.ntfy.R
import io.heckel.ntfy.msg.AppRelease
import io.heckel.ntfy.msg.UpdateChecker
import io.heckel.ntfy.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Shows update dialogs and downloads/installs APKs from [UpdateChecker].
 */
object AppUpdateUi {
    private const val TAG = "NtfyAppUpdateUi"

    fun check(
        activity: Activity,
        lifecycleOwner: LifecycleOwner,
        manual: Boolean,
        toastIfUpToDate: Boolean = manual
    ) {
        val checker = UpdateChecker(activity)
        if (!checker.isConfigured()) {
            if (manual) {
                Toast.makeText(activity, R.string.update_not_configured, Toast.LENGTH_LONG).show()
            }
            return
        }
        if (!manual && !checker.shouldAutoCheck()) {
            return
        }
        lifecycleOwner.lifecycleScope.launch {
            var checkError: Exception? = null
            val release = withContext(Dispatchers.IO) {
                try {
                    checker.fetchNewerRelease()
                } catch (e: Exception) {
                    Log.w(TAG, "Update check error: ${e.message}", e)
                    checkError = e
                    null
                }
            }
            if (activity.isFinishing) return@launch
            checker.markChecked()
            if (checkError != null) {
                if (manual) {
                    Toast.makeText(activity, R.string.update_download_failed, Toast.LENGTH_LONG).show()
                }
                return@launch
            }
            if (release == null) {
                if (toastIfUpToDate) {
                    Toast.makeText(activity, R.string.update_up_to_date, Toast.LENGTH_SHORT).show()
                }
                return@launch
            }
            showUpdateDialog(activity, lifecycleOwner, checker, release)
        }
    }

    private fun showUpdateDialog(
        activity: Activity,
        lifecycleOwner: LifecycleOwner,
        checker: UpdateChecker,
        release: AppRelease
    ) {
        val notes = release.body.ifBlank { activity.getString(R.string.update_no_notes) }
        val message = activity.getString(
            R.string.update_dialog_message,
            BuildConfig.VERSION_NAME,
            release.version,
            notes.take(800)
        )
        MaterialAlertDialogBuilder(activity)
            .setTitle(R.string.update_dialog_title)
            .setMessage(message)
            .setPositiveButton(R.string.update_now) { _, _ ->
                startUpdate(activity, lifecycleOwner, checker, release)
            }
            .setNegativeButton(R.string.update_later) { _, _ ->
                checker.postpone()
            }
            .show()
    }

    private fun startUpdate(
        activity: Activity,
        lifecycleOwner: LifecycleOwner,
        checker: UpdateChecker,
        release: AppRelease
    ) {
        val apkUrl = release.apkDownloadUrl
        if (apkUrl.isNullOrBlank()) {
            if (release.htmlUrl.isNotBlank()) {
                try {
                    activity.startActivity(
                        android.content.Intent(
                            android.content.Intent.ACTION_VIEW,
                            android.net.Uri.parse(release.htmlUrl)
                        )
                    )
                } catch (_: Exception) {
                    Toast.makeText(activity, R.string.update_download_failed, Toast.LENGTH_LONG).show()
                }
            } else {
                Toast.makeText(activity, R.string.update_no_apk, Toast.LENGTH_LONG).show()
            }
            return
        }
        if (!checker.canInstallPackages()) {
            MaterialAlertDialogBuilder(activity)
                .setTitle(R.string.update_install_permission_title)
                .setMessage(R.string.update_install_permission_message)
                .setPositiveButton(R.string.update_install_permission_open) { _, _ ->
                    try {
                        activity.startActivity(checker.intentOpenInstallPermissionSettings())
                    } catch (_: Exception) {
                        Toast.makeText(activity, R.string.update_download_failed, Toast.LENGTH_LONG).show()
                    }
                }
                .setNegativeButton(R.string.update_later, null)
                .show()
            return
        }

        var progressDialog: AlertDialog? = null
        progressDialog = MaterialAlertDialogBuilder(activity)
            .setTitle(R.string.update_downloading_title)
            .setMessage(activity.getString(R.string.update_downloading_message, 0))
            .setCancelable(false)
            .create()
        progressDialog.show()

        lifecycleOwner.lifecycleScope.launch {
            try {
                val file = withContext(Dispatchers.IO) {
                    checker.downloadApk(apkUrl) { downloaded, total ->
                        if (total > 0) {
                            val pct = ((downloaded * 100) / total).toInt().coerceIn(0, 100)
                            activity.runOnUiThread {
                                progressDialog?.setMessage(
                                    activity.getString(R.string.update_downloading_message, pct)
                                )
                            }
                        }
                    }
                }
                progressDialog?.dismiss()
                if (activity.isFinishing) return@launch
                activity.startActivity(checker.intentInstallApk(file))
            } catch (e: Exception) {
                Log.w(TAG, "APK download/install failed: ${e.message}", e)
                progressDialog?.dismiss()
                if (!activity.isFinishing) {
                    Toast.makeText(activity, R.string.update_download_failed, Toast.LENGTH_LONG).show()
                }
            }
        }
    }
}
