package io.heckel.ntfy.ui

import android.os.Bundle
import android.view.View
import android.view.inputmethod.EditorInfo
import android.widget.ProgressBar
import android.widget.TextView
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.core.view.updatePadding
import androidx.lifecycle.lifecycleScope
import com.google.android.material.button.MaterialButton
import com.google.android.material.textfield.TextInputEditText
import com.google.android.material.textfield.TextInputLayout
import io.heckel.ntfy.R
import io.heckel.ntfy.app.AppLocale
import io.heckel.ntfy.app.AppSession
import io.heckel.ntfy.app.Application
import io.heckel.ntfy.db.User
import io.heckel.ntfy.msg.ApiService
import io.heckel.ntfy.util.Log
import io.heckel.ntfy.util.isDarkThemeOn
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class LoginActivity : AppCompatActivity() {
    private val repository by lazy { (application as Application).repository }
    private val api by lazy { ApiService(this) }

    private lateinit var subtitle: TextView
    private lateinit var usernameText: TextInputEditText
    private lateinit var emailLayout: TextInputLayout
    private lateinit var emailText: TextInputEditText
    private lateinit var passwordText: TextInputEditText
    private lateinit var passwordConfirmLayout: TextInputLayout
    private lateinit var passwordConfirmText: TextInputEditText
    private lateinit var loginButton: MaterialButton
    private lateinit var switchModeButton: MaterialButton
    private lateinit var progress: ProgressBar
    private lateinit var errorRow: View
    private lateinit var errorText: TextView

    private var signupMode = false

    override fun attachBaseContext(newBase: android.content.Context) {
        super.attachBaseContext(AppLocale.wrap(newBase))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        if (AppSession.isLoggedIn(this)) {
            AppSession.goMain(this)
            return
        }

        setContentView(R.layout.activity_login)
        WindowInsetsControllerCompat(window, window.decorView).isAppearanceLightStatusBars =
            !isDarkThemeOn(this)

        val root = findViewById<View>(android.R.id.content)
        ViewCompat.setOnApplyWindowInsetsListener(root) { v, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            v.updatePadding(top = bars.top, bottom = bars.bottom)
            insets
        }

        subtitle = findViewById(R.id.login_subtitle)
        usernameText = findViewById(R.id.login_username)
        emailLayout = findViewById(R.id.login_email_layout)
        emailText = findViewById(R.id.login_email)
        passwordText = findViewById(R.id.login_password)
        passwordConfirmLayout = findViewById(R.id.login_password_confirm_layout)
        passwordConfirmText = findViewById(R.id.login_password_confirm)
        loginButton = findViewById(R.id.login_button)
        switchModeButton = findViewById(R.id.login_switch_mode)
        progress = findViewById(R.id.login_progress)
        errorRow = findViewById(R.id.login_error_row)
        errorText = findViewById(R.id.login_error)

        val serverUrl = AppSession.serverUrl(this, repository)
        findViewById<TextView>(R.id.login_server_tip).text =
            getString(R.string.login_server_tip, serverUrl)

        lifecycleScope.launch {
            val existing = withContext(Dispatchers.IO) { repository.getUser(serverUrl) }
            if (existing != null && usernameText.text.isNullOrBlank()) {
                usernameText.setText(existing.username)
            }
        }

        loginButton.setOnClickListener { submit() }
        switchModeButton.setOnClickListener { toggleMode() }
        passwordText.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_DONE && !signupMode) {
                submit()
                true
            } else {
                false
            }
        }
        passwordConfirmText.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_DONE) {
                submit()
                true
            } else {
                false
            }
        }
        applyMode()
    }

    private fun toggleMode() {
        signupMode = !signupMode
        errorRow.visibility = View.GONE
        applyMode()
    }

    private fun applyMode() {
        emailLayout.visibility = if (signupMode) View.VISIBLE else View.GONE
        passwordConfirmLayout.visibility = if (signupMode) View.VISIBLE else View.GONE
        subtitle.setText(if (signupMode) R.string.signup_subtitle else R.string.login_subtitle)
        loginButton.setText(if (signupMode) R.string.signup_action else R.string.login_action)
        switchModeButton.setText(
            if (signupMode) R.string.signup_switch_to_login else R.string.login_switch_to_signup
        )
        passwordText.imeOptions =
            if (signupMode) EditorInfo.IME_ACTION_NEXT else EditorInfo.IME_ACTION_DONE
    }

    private fun submit() {
        val username = usernameText.text?.toString()?.trim().orEmpty()
        val password = passwordText.text?.toString().orEmpty()
        if (username.isEmpty() || password.isEmpty()) {
            showError(getString(R.string.login_error_empty))
            return
        }
        if (signupMode) {
            val confirm = passwordConfirmText.text?.toString().orEmpty()
            if (password != confirm) {
                showError(getString(R.string.signup_error_password_mismatch))
                return
            }
            if (password.length < 8) {
                showError(getString(R.string.signup_error_password_short))
                return
            }
        }

        val serverUrl = AppSession.serverUrl(this, repository)
        val email = emailText.text?.toString()?.trim().orEmpty()
        setLoading(true)
        lifecycleScope.launch {
            try {
                withContext(Dispatchers.IO) {
                    if (signupMode) {
                        api.signup(serverUrl, username, password, email.ifBlank { null })
                    }
                    val login = api.login(serverUrl, username, password)
                    val canonical = login.username?.takeIf { it.isNotBlank() } ?: username
                    repository.addUser(User(serverUrl, canonical, password))
                }
                AppSession.setLoggedIn(this@LoginActivity, true)
                AppSession.goMain(this@LoginActivity)
            } catch (e: ApiService.UnauthorizedException) {
                Log.w(TAG, "Login unauthorized: ${e.message}", e)
                showError(getString(R.string.login_error_unauthorized))
            } catch (e: ApiService.ApiException) {
                Log.w(TAG, "Auth API error: ${e.message}", e)
                showError(mapApiError(e))
            } catch (e: Exception) {
                Log.w(TAG, "Auth failed: ${e.message}", e)
                showError(e.message ?: getString(R.string.login_error_generic))
            } finally {
                setLoading(false)
            }
        }
    }

    private fun mapApiError(e: ApiService.ApiException): String {
        val msg = e.error.lowercase()
        return when {
            e.code == 40901 || msg.contains("already exists") ->
                getString(R.string.signup_error_username_taken)
            e.code == 40022 || msg.contains("signup not enabled") ->
                getString(R.string.signup_error_disabled)
            msg.contains("username") && msg.contains("invalid") ->
                getString(R.string.signup_error_invalid_username)
            else -> e.error.ifBlank { getString(R.string.login_error_generic) }
        }
    }

    private fun setLoading(loading: Boolean) {
        loginButton.isEnabled = !loading
        switchModeButton.isEnabled = !loading
        usernameText.isEnabled = !loading
        emailText.isEnabled = !loading
        passwordText.isEnabled = !loading
        passwordConfirmText.isEnabled = !loading
        progress.visibility = if (loading) View.VISIBLE else View.GONE
        if (loading) {
            errorRow.visibility = View.GONE
        }
    }

    private fun showError(message: String) {
        errorText.text = message
        errorRow.visibility = View.VISIBLE
    }

    companion object {
        private const val TAG = "NtfyLogin"
    }
}
