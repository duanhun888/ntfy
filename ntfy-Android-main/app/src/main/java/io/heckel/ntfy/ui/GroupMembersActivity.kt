package io.heckel.ntfy.ui

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
import io.heckel.ntfy.msg.FriendsApi
import io.heckel.ntfy.msg.GroupsApi
import io.heckel.ntfy.util.isDarkThemeOn
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class GroupMembersActivity : AppCompatActivity() {
    private val repository by lazy { (application as Application).repository }
    private val groupsApi by lazy { GroupsApi(this) }
    private val friendsApi by lazy { FriendsApi(this) }

    private lateinit var list: RecyclerView
    private lateinit var empty: TextView
    private lateinit var progress: ProgressBar
    private val adapter = MemberAdapter()

    private var groupId: String = ""
    private var baseUrl: String = ""
    private var canManage = false

    override fun attachBaseContext(newBase: android.content.Context) {
        super.attachBaseContext(AppLocale.wrap(newBase))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_group_members)

        groupId = intent.getStringExtra(EXTRA_GROUP_ID).orEmpty()
        baseUrl = intent.getStringExtra(EXTRA_BASE_URL).orEmpty()
        val displayName = intent.getStringExtra(EXTRA_DISPLAY_NAME).orEmpty()
        if (groupId.isEmpty() || baseUrl.isEmpty()) {
            finish()
            return
        }

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
        title = displayName.ifBlank { getString(R.string.members_title) }
        supportActionBar?.setDisplayHomeAsUpEnabled(true)

        list = findViewById(R.id.members_list)
        empty = findViewById(R.id.members_empty)
        progress = findViewById(R.id.members_progress)
        list.layoutManager = LinearLayoutManager(this)
        list.adapter = adapter
        adapter.onRemove = { removeMember(it) }

        refresh()
    }

    override fun onSupportNavigateUp(): Boolean {
        finish()
        return true
    }

    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        menuInflater.inflate(R.menu.menu_group_members, menu)
        return true
    }

    override fun onPrepareOptionsMenu(menu: Menu): Boolean {
        menu.findItem(R.id.members_menu_invite)?.isVisible = canManage
        menu.findItem(R.id.members_menu_invite_username)?.isVisible = canManage
        return super.onPrepareOptionsMenu(menu)
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        return when (item.itemId) {
            R.id.members_menu_invite -> {
                inviteFromFriends()
                true
            }
            R.id.members_menu_invite_username -> {
                inviteByUsername()
                true
            }
            else -> super.onOptionsItemSelected(item)
        }
    }

    private fun refresh() {
        progress.visibility = View.VISIBLE
        lifecycleScope.launch {
            try {
                val user = withContext(Dispatchers.IO) { repository.getUser(baseUrl) }
                    ?: throw IllegalStateException(getString(R.string.friends_error_not_logged_in))
                val members = withContext(Dispatchers.IO) {
                    groupsApi.listMembers(baseUrl, user, groupId)
                }
                val me = members.firstOrNull { it.username.equals(user.username, ignoreCase = true) }
                canManage = me?.role == "owner" || me?.role == "admin"
                adapter.canManage = canManage
                adapter.submit(members)
                empty.visibility = if (members.isEmpty()) View.VISIBLE else View.GONE
                invalidateOptionsMenu()
            } catch (e: Exception) {
                Toast.makeText(this@GroupMembersActivity, e.message ?: getString(R.string.members_error_generic), Toast.LENGTH_LONG).show()
            } finally {
                progress.visibility = View.GONE
            }
        }
    }

    private fun inviteByUsername() {
        val input = EditText(this).apply {
            hint = getString(R.string.members_invite_hint)
            setSingleLine()
        }
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.members_invite_username)
            .setView(input)
            .setPositiveButton(R.string.members_invite) { _, _ ->
                val username = input.text?.toString()?.trim().orEmpty()
                if (username.isNotEmpty()) {
                    addMember(username)
                }
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private fun inviteFromFriends() {
        progress.visibility = View.VISIBLE
        lifecycleScope.launch {
            try {
                val user = withContext(Dispatchers.IO) { repository.getUser(baseUrl) }
                    ?: throw IllegalStateException(getString(R.string.friends_error_not_logged_in))
                val friends = withContext(Dispatchers.IO) { friendsApi.listFriends(baseUrl, user) }
                progress.visibility = View.GONE
                if (friends.isEmpty()) {
                    Toast.makeText(this@GroupMembersActivity, R.string.members_no_friends, Toast.LENGTH_LONG).show()
                    return@launch
                }
                val labels = friends.map { it.safeUsername() }.toTypedArray()
                val checked = BooleanArray(labels.size)
                MaterialAlertDialogBuilder(this@GroupMembersActivity)
                    .setTitle(R.string.members_invite)
                    .setMultiChoiceItems(labels, checked) { _, which, isChecked ->
                        checked[which] = isChecked
                    }
                    .setPositiveButton(R.string.members_invite) { _, _ ->
                        friends.forEachIndexed { index, friend ->
                            if (checked[index]) {
                                addMember(friend.safeUsername())
                            }
                        }
                    }
                    .setNegativeButton(android.R.string.cancel, null)
                    .show()
            } catch (e: Exception) {
                progress.visibility = View.GONE
                Toast.makeText(this@GroupMembersActivity, e.message ?: getString(R.string.members_error_generic), Toast.LENGTH_LONG).show()
            }
        }
    }

    private fun addMember(username: String) {
        progress.visibility = View.VISIBLE
        lifecycleScope.launch {
            try {
                val user = withContext(Dispatchers.IO) { repository.getUser(baseUrl) } ?: return@launch
                withContext(Dispatchers.IO) { groupsApi.addMember(baseUrl, user, groupId, username) }
                Toast.makeText(this@GroupMembersActivity, getString(R.string.members_invited, username), Toast.LENGTH_SHORT).show()
                refresh()
            } catch (e: Exception) {
                Toast.makeText(this@GroupMembersActivity, e.message ?: getString(R.string.members_error_generic), Toast.LENGTH_LONG).show()
                progress.visibility = View.GONE
            }
        }
    }

    private fun removeMember(member: GroupsApi.ChatMember) {
        if (member.role == "owner") {
            Toast.makeText(this, R.string.members_cannot_remove_owner, Toast.LENGTH_SHORT).show()
            return
        }
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.members_remove)
            .setMessage(getString(R.string.members_remove_confirm, member.username.ifBlank { member.userId }))
            .setPositiveButton(R.string.members_remove) { _, _ ->
                lifecycleScope.launch {
                    try {
                        val user = withContext(Dispatchers.IO) { repository.getUser(baseUrl) } ?: return@launch
                        withContext(Dispatchers.IO) {
                            groupsApi.removeMember(baseUrl, user, groupId, member.userId)
                        }
                        refresh()
                    } catch (e: Exception) {
                        Toast.makeText(this@GroupMembersActivity, e.message ?: getString(R.string.members_error_generic), Toast.LENGTH_LONG).show()
                    }
                }
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private class MemberAdapter : RecyclerView.Adapter<MemberAdapter.VH>() {
        private val items = mutableListOf<GroupsApi.ChatMember>()
        var canManage = false
        var onRemove: ((GroupsApi.ChatMember) -> Unit)? = null

        fun submit(list: List<GroupsApi.ChatMember>) {
            items.clear()
            items.addAll(list)
            notifyDataSetChanged()
        }

        override fun getItemCount(): Int = items.size

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
            val view = LayoutInflater.from(parent.context).inflate(R.layout.item_friend_row, parent, false)
            return VH(view)
        }

        override fun onBindViewHolder(holder: VH, position: Int) {
            val member = items[position]
            val label = buildString {
                append(member.username.ifBlank { member.userId })
                if (member.role.isNotBlank()) {
                    append(" (")
                    append(member.role)
                    append(")")
                }
            }
            holder.name.text = label
            holder.accept.visibility = View.GONE
            holder.reject.visibility = View.GONE
            val showRemove = canManage && member.role != "owner"
            holder.remove.visibility = if (showRemove) View.VISIBLE else View.GONE
            (holder.remove as? com.google.android.material.button.MaterialButton)?.setText(R.string.members_remove)
            holder.remove.setOnClickListener { onRemove?.invoke(member) }
        }

        class VH(view: View) : RecyclerView.ViewHolder(view) {
            val name: TextView = view.findViewById(R.id.friend_row_name)
            val accept: View = view.findViewById(R.id.friend_row_accept)
            val reject: View = view.findViewById(R.id.friend_row_reject)
            val remove: View = view.findViewById(R.id.friend_row_remove)
        }
    }

    companion object {
        const val EXTRA_GROUP_ID = "groupId"
        const val EXTRA_BASE_URL = "baseUrl"
        const val EXTRA_DISPLAY_NAME = "displayName"
    }
}
