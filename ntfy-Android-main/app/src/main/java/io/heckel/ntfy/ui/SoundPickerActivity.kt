package io.heckel.ntfy.ui

import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.ListView
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.lifecycleScope
import com.google.android.material.appbar.AppBarLayout
import io.heckel.ntfy.R
import io.heckel.ntfy.db.Repository
import io.heckel.ntfy.msg.NotificationService
import io.heckel.ntfy.msg.NotificationSounds
import io.heckel.ntfy.util.isDarkThemeOn
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * WeChat-style in-app picker for incoming-message reminder sounds.
 */
class SoundPickerActivity : AppCompatActivity() {
    private lateinit var repository: Repository
    private lateinit var options: List<NotificationSounds.Option>
    private var subscriptionId: Long = 0L
    private var preview: Ringtone? = null

    override fun attachBaseContext(newBase: android.content.Context) {
        super.attachBaseContext(io.heckel.ntfy.app.AppLocale.wrap(newBase))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_sound_picker)

        repository = Repository.getInstance(this)
        subscriptionId = intent.getLongExtra(EXTRA_SUBSCRIPTION_ID, 0L)

        val toolbarLayout = findViewById<AppBarLayout>(R.id.app_bar_drawer)
        val dynamicColors = repository.getDynamicColorsEnabled()
        val darkMode = isDarkThemeOn(this)
        val statusBarColor = Colors.statusBarNormal(this, dynamicColors, darkMode)
        val toolbarTextColor = Colors.toolbarTextColor(this, dynamicColors, darkMode)
        toolbarLayout.setBackgroundColor(statusBarColor)

        val toolbar = toolbarLayout.findViewById<com.google.android.material.appbar.MaterialToolbar>(R.id.toolbar)
        toolbar.setTitleTextColor(toolbarTextColor)
        toolbar.setNavigationIconTint(toolbarTextColor)
        setSupportActionBar(toolbar)
        WindowInsetsControllerCompat(window, window.decorView).isAppearanceLightStatusBars =
            Colors.shouldUseLightStatusBar(dynamicColors, darkMode)
        title = getString(R.string.settings_notifications_sound_picker_title)
        supportActionBar?.setDisplayHomeAsUpEnabled(true)

        val forGroup = subscriptionId != 0L
        val listed = NotificationSounds.listOptions(this, includeFollowGlobal = forGroup).toMutableList()
        val current = repository.getNotificationSound(subscriptionId.takeIf { it != 0L })
        if (listed.none { it.key == current } && current.isNotEmpty()) {
            listed.add(NotificationSounds.Option(current, NotificationSounds.displayName(this, current)))
        }
        options = listed
        val checked = options.indexOfFirst { it.key == current }.let { if (it >= 0) it else 0 }

        val list = findViewById<ListView>(R.id.sound_list)
        list.adapter = ArrayAdapter(this, android.R.layout.simple_list_item_single_choice, options.map { it.title })
        list.choiceMode = ListView.CHOICE_MODE_SINGLE
        list.setItemChecked(checked, true)
        list.setOnItemClickListener { _, _, position, _ ->
            val option = options[position]
            persistAndApply(option.key)
            preview(option.key)
        }
    }

    override fun onSupportNavigateUp(): Boolean {
        finish()
        return true
    }

    override fun onPause() {
        super.onPause()
        stopPreview()
    }

    override fun onDestroy() {
        stopPreview()
        super.onDestroy()
    }

    private fun persistAndApply(key: String) {
        val subId = subscriptionId.takeIf { it != 0L }
        repository.setNotificationSound(subId, key)
        lifecycleScope.launch(Dispatchers.IO) {
            val service = NotificationService(this@SoundPickerActivity)
            if (subId == null) {
                service.recreateDefaultNotificationChannels()
                repository.getSubscriptions().forEach { sub ->
                    if (sub.dedicatedChannels && repository.followsGlobalNotificationSound(sub.id)) {
                        service.recreateSubscriptionNotificationChannels(sub)
                    }
                }
            } else {
                var sub = repository.getSubscription(subId) ?: return@launch
                val custom = !NotificationSounds.followsGlobal(key)
                if (custom && !sub.dedicatedChannels) {
                    sub = sub.copy(dedicatedChannels = true)
                    repository.updateSubscription(sub)
                }
                if (sub.dedicatedChannels) {
                    service.recreateSubscriptionNotificationChannels(sub)
                }
            }
        }
    }

    private fun preview(key: String) {
        stopPreview()
        if (key == NotificationSounds.KEY_SILENT) {
            return
        }
        val resolved = if (NotificationSounds.followsGlobal(key)) {
            repository.getNotificationSound(null)
        } else {
            key
        }
        val uri = NotificationSounds.uriFor(this, resolved) ?: return
        try {
            preview = RingtoneManager.getRingtone(this, uri)
            preview?.play()
        } catch (_: Exception) {
            // Ignore devices that cannot play the selected tone.
        }
    }

    private fun stopPreview() {
        try {
            preview?.stop()
        } catch (_: Exception) {
            // Ignore
        }
        preview = null
    }

    companion object {
        const val EXTRA_SUBSCRIPTION_ID = "subscriptionId"
    }
}
