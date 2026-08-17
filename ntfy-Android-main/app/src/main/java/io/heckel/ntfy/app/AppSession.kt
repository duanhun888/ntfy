package io.heckel.ntfy.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import io.heckel.ntfy.R
import io.heckel.ntfy.db.Repository
import io.heckel.ntfy.ui.LoginActivity
import io.heckel.ntfy.ui.MainActivity

object AppSession {
    private const val PREFS = "ntfy_session"
    private const val KEY_LOGGED_IN = "logged_in"

    fun serverUrl(context: Context, repository: Repository = Repository.getInstance(context)): String {
        return repository.getDefaultBaseUrl()?.takeIf { it.isNotBlank() }
            ?: context.getString(R.string.app_base_url)
    }

    fun isLoggedIn(context: Context): Boolean {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(KEY_LOGGED_IN, false)
    }

    fun setLoggedIn(context: Context, loggedIn: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_LOGGED_IN, loggedIn)
            .apply()
    }

    fun goMain(activity: Activity) {
        activity.startActivity(Intent(activity, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        })
        activity.finish()
    }

    fun goLogin(activity: Activity) {
        setLoggedIn(activity, false)
        activity.startActivity(Intent(activity, LoginActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        })
        activity.finish()
    }
}
