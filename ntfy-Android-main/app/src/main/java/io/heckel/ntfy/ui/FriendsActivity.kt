package io.heckel.ntfy.ui

import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.Menu
import android.view.MenuItem
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.appbar.AppBarLayout
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import io.heckel.ntfy.R
import io.heckel.ntfy.app.AppLocale
import io.heckel.ntfy.app.AppSession
import io.heckel.ntfy.app.Application
import io.heckel.ntfy.db.Repository
import io.heckel.ntfy.db.Subscription
import io.heckel.ntfy.msg.ApiService
import io.heckel.ntfy.msg.FriendsApi
import io.heckel.ntfy.msg.Poller
import io.heckel.ntfy.service.SubscriberServiceManager
import io.heckel.ntfy.util.Log
import io.heckel.ntfy.util.isDarkThemeOn
import io.heckel.ntfy.util.randomSubscriptionId
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Date

class FriendsActivity : AppCompatActivity() {
    companion object {
        private const val TAG = "NtfyFriendsActivity"
    }
    private val repository by lazy { (application as Application).repository }
    private val friendsApi by lazy { FriendsApi(this) }
    private val api by lazy { ApiService(this) }
    private val poller by lazy { Poller(api, repository) }

    private lateinit var requestsHeader: TextView
    private lateinit var requestsList: RecyclerView
    private lateinit var friendsList: RecyclerView
    private lateinit var emptyView: TextView
    private lateinit var progress: ProgressBar

    private val requestAdapter = FriendRowAdapter(showActions = true)
    private val friendAdapter = FriendRowAdapter(showActions = false)

    override fun attachBaseContext(newBase: android.content.Context) {
        super.attachBaseContext(AppLocale.wrap(newBase))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_friends)

        val toolbarLayout = findViewById<AppBarLayout>(R.id.app_bar_drawer)
        val dynamicColors = repository.getDynamicColorsEnabled()
        val darkMode = isDarkThemeOn(this)
        toolbarLayout.setBackgroundColor(Colors.statusBarNormal(this, dynamicColors, darkMode))
        val toolbar = toolbarLayout.findViewById<com.google.android.material.appbar.MaterialToolbar>(R.id.toolbar)
        val toolbarTextColor = Colors.toolbarTextColor(this, dynamicColors, darkMode)
        toolbar.setTitleTextColor(toolbarTextColor)
        toolbar.setNavigationIconTint(toolbarTextColor)
        setSupportActionBar(toolbar)
        WindowInsetsControllerCompat(window, window.decorView).isAppearanceLightStatusBars =
            Colors.shouldUseLightStatusBar(dynamicColors, darkMode)
        title = getString(R.string.friends_title)
        supportActionBar?.setDisplayHomeAsUpEnabled(true)

        requestsHeader = findViewById(R.id.friends_requests_header)
        requestsList = findViewById(R.id.friends_requests_list)
        friendsList = findViewById(R.id.friends_list)
        emptyView = findViewById(R.id.friends_empty)
        progress = findViewById(R.id.friends_progress)

        requestsList.layoutManager = LinearLayoutManager(this)
        friendsList.layoutManager = LinearLayoutManager(this)
        requestsList.adapter = requestAdapter
        friendsList.adapter = friendAdapter

        requestAdapter.onAccept = { accept(it) }
        requestAdapter.onReject = { reject(it) }
        friendAdapter.onRemove = { removeFriend(it) }
        friendAdapter.onOpen = { openChat(it) }

        refresh()
    }

    override fun onSupportNavigateUp(): Boolean {
        finish()
        return true
    }

    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        menuInflater.inflate(R.menu.menu_friends, menu)
        return true
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        return when (item.itemId) {
            R.id.friends_menu_add -> {
                showAddDialog()
                true
            }
            R.id.friends_menu_refresh -> {
                refresh()
                true
            }
            else -> super.onOptionsItemSelected(item)
        }
    }

    private fun refresh() {
        val baseUrl = AppSession.serverUrl(this, repository)
        progress.visibility = View.VISIBLE
        lifecycleScope.launch {
            try {
                val user = withContext(Dispatchers.IO) { repository.getUser(baseUrl) }
                    ?: throw IllegalStateException(getString(R.string.friends_error_not_logged_in))
                val (friends, requests) = withContext(Dispatchers.IO) {
                    friendsApi.listFriends(baseUrl, user) to
                        friendsApi.listRequests(baseUrl, user, "incoming", "pending")
                }
                requestAdapter.submitRequests(requests)
                friendAdapter.submitFriends(friends)
                val hasRequests = requests.isNotEmpty()
                requestsHeader.visibility = if (hasRequests) View.VISIBLE else View.GONE
                requestsList.visibility = if (hasRequests) View.VISIBLE else View.GONE
                emptyView.visibility = if (friends.isEmpty() && requests.isEmpty()) View.VISIBLE else View.GONE
            } catch (e: Exception) {
                Toast.makeText(this@FriendsActivity, e.message ?: getString(R.string.friends_error_generic), Toast.LENGTH_LONG).show()
            } finally {
                progress.visibility = View.GONE
            }
        }
    }

    private fun showAddDialog() {
        val input = EditText(this).apply {
            hint = getString(R.string.friends_add_hint)
            setSingleLine()
        }
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.friends_add)
            .setView(input)
            .setPositiveButton(R.string.friends_send_request) { _, _ ->
                val username = input.text?.toString()?.trim().orEmpty()
                if (username.isNotEmpty()) {
                    sendRequest(username)
                }
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private fun sendRequest(username: String) {
        val baseUrl = AppSession.serverUrl(this, repository)
        progress.visibility = View.VISIBLE
        lifecycleScope.launch {
            try {
                val user = withContext(Dispatchers.IO) { repository.getUser(baseUrl) }
                    ?: throw IllegalStateException(getString(R.string.friends_error_not_logged_in))
                withContext(Dispatchers.IO) { friendsApi.sendRequest(baseUrl, user, username) }
                Toast.makeText(this@FriendsActivity, R.string.friends_request_sent, Toast.LENGTH_SHORT).show()
                refresh()
            } catch (e: Exception) {
                Toast.makeText(this@FriendsActivity, e.message ?: getString(R.string.friends_error_generic), Toast.LENGTH_LONG).show()
                progress.visibility = View.GONE
            }
        }
    }

    private fun accept(request: FriendsApi.FriendRequest) {
        val baseUrl = AppSession.serverUrl(this, repository)
        lifecycleScope.launch {
            try {
                val user = withContext(Dispatchers.IO) { repository.getUser(baseUrl) } ?: return@launch
                withContext(Dispatchers.IO) { friendsApi.acceptRequest(baseUrl, user, request.id.orEmpty()) }
                refresh()
            } catch (e: Exception) {
                Toast.makeText(this@FriendsActivity, e.message ?: getString(R.string.friends_error_generic), Toast.LENGTH_LONG).show()
            }
        }
    }

    private fun reject(request: FriendsApi.FriendRequest) {
        val baseUrl = AppSession.serverUrl(this, repository)
        lifecycleScope.launch {
            try {
                val user = withContext(Dispatchers.IO) { repository.getUser(baseUrl) } ?: return@launch
                withContext(Dispatchers.IO) { friendsApi.rejectRequest(baseUrl, user, request.id.orEmpty()) }
                refresh()
            } catch (e: Exception) {
                Toast.makeText(this@FriendsActivity, e.message ?: getString(R.string.friends_error_generic), Toast.LENGTH_LONG).show()
            }
        }
    }

    private fun removeFriend(friend: FriendsApi.Friend) {
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.friends_remove)
            .setMessage(getString(R.string.friends_remove_confirm, friend.safeUsername()))
            .setPositiveButton(R.string.friends_remove) { _, _ ->
                val baseUrl = AppSession.serverUrl(this, repository)
                lifecycleScope.launch {
                    try {
                        val user = withContext(Dispatchers.IO) { repository.getUser(baseUrl) } ?: return@launch
                        withContext(Dispatchers.IO) {
                            friendsApi.removeFriend(baseUrl, user, friend.safeUserId())
                            val topic = friend.safeTopic()
                            if (topic.isNotBlank()) {
                                repository.getSubscription(baseUrl, topic)?.let { repository.removeSubscription(it) }
                            }
                        }
                        refresh()
                    } catch (e: Exception) {
                        Toast.makeText(this@FriendsActivity, e.message ?: getString(R.string.friends_error_generic), Toast.LENGTH_LONG).show()
                    }
                }
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private fun openChat(friend: FriendsApi.Friend) {
        val topic = friend.safeTopic()
        if (topic.isBlank()) {
            Toast.makeText(this, R.string.friends_error_no_topic, Toast.LENGTH_LONG).show()
            refresh()
            return
        }
        val baseUrl = AppSession.serverUrl(this, repository)
        progress.visibility = View.VISIBLE
        lifecycleScope.launch {
            try {
                val subscription = withContext(Dispatchers.IO) {
                    ensureFriendSubscription(baseUrl, friend)
                }
                val display = subscription.displayName ?: friend.safeUsername()
                // DetailActivity.loadView() reads MainActivity.EXTRA_* keys.
                startActivity(Intent(this@FriendsActivity, DetailActivity::class.java).apply {
                    putExtra(MainActivity.EXTRA_SUBSCRIPTION_ID, subscription.id)
                    putExtra(MainActivity.EXTRA_SUBSCRIPTION_BASE_URL, subscription.baseUrl)
                    putExtra(MainActivity.EXTRA_SUBSCRIPTION_TOPIC, subscription.topic)
                    putExtra(MainActivity.EXTRA_SUBSCRIPTION_DISPLAY_NAME, display)
                    putExtra(MainActivity.EXTRA_SUBSCRIPTION_INSTANT, subscription.instant)
                    putExtra(MainActivity.EXTRA_SUBSCRIPTION_MUTED_UNTIL, subscription.mutedUntil)
                })
            } catch (e: Exception) {
                Log.e(TAG, "openChat failed", e)
                Toast.makeText(
                    this@FriendsActivity,
                    e.message ?: getString(R.string.friends_error_generic),
                    Toast.LENGTH_LONG
                ).show()
            } finally {
                progress.visibility = View.GONE
            }
        }
    }

    private suspend fun ensureFriendSubscription(baseUrl: String, friend: FriendsApi.Friend): Subscription {
        val topic = friend.safeTopic()
        val displayName = friend.safeUsername()
        val existing = repository.getSubscription(baseUrl, topic)
        if (existing != null) {
            if (existing.displayName.isNullOrBlank() && displayName.isNotBlank()) {
                val updated = existing.copy(displayName = displayName)
                repository.updateSubscription(updated)
                return updated
            }
            return existing
        }
        val subscription = Subscription(
            id = randomSubscriptionId(),
            baseUrl = baseUrl,
            topic = topic,
            instant = true,
            dedicatedChannels = false,
            mutedUntil = 0,
            minPriority = Repository.MIN_PRIORITY_USE_GLOBAL,
            autoDelete = Repository.AUTO_DELETE_USE_GLOBAL,
            insistent = Repository.INSISTENT_MAX_PRIORITY_USE_GLOBAL,
            lastNotificationId = null,
            icon = null,
            upAppId = null,
            upConnectorToken = null,
            displayName = displayName,
            totalCount = 0,
            newCount = 0,
            lastActive = Date().time / 1000
        )
        repository.addSubscription(subscription)
        try {
            poller.poll(subscription)
        } catch (_: Exception) {
            // still open chat even if first poll fails
        }
        SubscriberServiceManager.refresh(this)
        return subscription
    }

    private class FriendRowAdapter(private val showActions: Boolean) :
        RecyclerView.Adapter<FriendRowAdapter.VH>() {
        private val friends = mutableListOf<FriendsApi.Friend>()
        private val requests = mutableListOf<FriendsApi.FriendRequest>()

        var onAccept: ((FriendsApi.FriendRequest) -> Unit)? = null
        var onReject: ((FriendsApi.FriendRequest) -> Unit)? = null
        var onRemove: ((FriendsApi.Friend) -> Unit)? = null
        var onOpen: ((FriendsApi.Friend) -> Unit)? = null

        fun submitFriends(items: List<FriendsApi.Friend>) {
            friends.clear()
            friends.addAll(items)
            notifyDataSetChanged()
        }

        fun submitRequests(items: List<FriendsApi.FriendRequest>) {
            requests.clear()
            requests.addAll(items)
            notifyDataSetChanged()
        }

        override fun getItemCount(): Int = if (showActions) requests.size else friends.size

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
            val view = LayoutInflater.from(parent.context).inflate(R.layout.item_friend_row, parent, false)
            return VH(view)
        }

        override fun onBindViewHolder(holder: VH, position: Int) {
            if (showActions) {
                val req = requests[position]
                holder.name.text = req.fromUsername.orEmpty().ifBlank { req.fromUserId.orEmpty() }
                holder.accept.visibility = View.VISIBLE
                holder.reject.visibility = View.VISIBLE
                holder.remove.visibility = View.GONE
                holder.itemView.setOnClickListener(null)
                holder.accept.setOnClickListener { onAccept?.invoke(req) }
                holder.reject.setOnClickListener { onReject?.invoke(req) }
            } else {
                val friend = friends[position]
                holder.name.text = friend.safeUsername()
                holder.accept.visibility = View.GONE
                holder.reject.visibility = View.GONE
                holder.remove.visibility = View.VISIBLE
                holder.remove.setOnClickListener { onRemove?.invoke(friend) }
                holder.itemView.setOnClickListener { onOpen?.invoke(friend) }
            }
        }

        class VH(view: View) : RecyclerView.ViewHolder(view) {
            val name: TextView = view.findViewById(R.id.friend_row_name)
            val accept: View = view.findViewById(R.id.friend_row_accept)
            val reject: View = view.findViewById(R.id.friend_row_reject)
            val remove: View = view.findViewById(R.id.friend_row_remove)
        }
    }
}
