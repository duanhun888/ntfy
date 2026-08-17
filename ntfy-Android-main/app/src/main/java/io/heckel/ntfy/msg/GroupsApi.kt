package io.heckel.ntfy.msg

import android.content.Context
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import com.google.gson.reflect.TypeToken
import io.heckel.ntfy.db.User
import io.heckel.ntfy.util.HttpUtil
import io.heckel.ntfy.util.Log
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody

/**
 * Client for DingTalk-style /v1/groups and bot APIs.
 */
class GroupsApi(private val context: Context) {
    private val gson = Gson()
    private val jsonMedia = "application/json; charset=utf-8".toMediaType()

    suspend fun createGroup(baseUrl: String, user: User, name: String): ChatGroup {
        val url = "${baseUrl.trimEnd('/')}/v1/groups"
        val body = gson.toJson(mapOf("name" to name)).toRequestBody(jsonMedia)
        val request = HttpUtil.requestBuilder(url, user).post(body).build()
        Log.d(TAG, "Creating group at $url")
        HttpUtil.defaultClient(context, baseUrl).newCall(request).execute().use { response ->
            val responseBody = response.body.string()
            if (response.code == 401 || response.code == 403) {
                throw ApiService.UnauthorizedException(user)
            }
            if (!response.isSuccessful) {
                throw apiError(response.code, responseBody, "create group")
            }
            return gson.fromJson(responseBody, ChatGroup::class.java)
        }
    }

    suspend fun listGroups(baseUrl: String, user: User): List<ChatGroup> {
        val url = "${baseUrl.trimEnd('/')}/v1/groups"
        val request = HttpUtil.requestBuilder(url, user).get().build()
        HttpUtil.defaultClient(context, baseUrl).newCall(request).execute().use { response ->
            val responseBody = response.body.string()
            if (response.code == 401 || response.code == 403) {
                throw ApiService.UnauthorizedException(user)
            }
            if (!response.isSuccessful) {
                throw apiError(response.code, responseBody, "list groups")
            }
            val type = object : TypeToken<List<ChatGroup>>() {}.type
            return gson.fromJson(responseBody, type) ?: emptyList()
        }
    }

    suspend fun createBot(baseUrl: String, user: User, groupId: String, name: String): BotCreateResponse {
        val url = "${baseUrl.trimEnd('/')}/v1/groups/$groupId/bots"
        val body = gson.toJson(mapOf("name" to name)).toRequestBody(jsonMedia)
        val request = HttpUtil.requestBuilder(url, user).post(body).build()
        Log.d(TAG, "Creating bot at $url")
        HttpUtil.defaultClient(context, baseUrl).newCall(request).execute().use { response ->
            val responseBody = response.body.string()
            if (response.code == 401 || response.code == 403) {
                throw ApiService.UnauthorizedException(user)
            }
            if (!response.isSuccessful) {
                throw apiError(response.code, responseBody, "create bot")
            }
            return gson.fromJson(responseBody, BotCreateResponse::class.java)
        }
    }

    suspend fun listBots(baseUrl: String, user: User, groupId: String): List<ChatBot> {
        val url = "${baseUrl.trimEnd('/')}/v1/groups/$groupId/bots"
        val request = HttpUtil.requestBuilder(url, user).get().build()
        HttpUtil.defaultClient(context, baseUrl).newCall(request).execute().use { response ->
            val responseBody = response.body.string()
            if (!response.isSuccessful) {
                throw apiError(response.code, responseBody, "list bots")
            }
            val type = object : TypeToken<List<ChatBot>>() {}.type
            return gson.fromJson(responseBody, type) ?: emptyList()
        }
    }

    suspend fun deleteBot(baseUrl: String, user: User, groupId: String, botId: String) {
        val url = "${baseUrl.trimEnd('/')}/v1/groups/$groupId/bots/$botId"
        val request = HttpUtil.requestBuilder(url, user).delete().build()
        HttpUtil.defaultClient(context, baseUrl).newCall(request).execute().use { response ->
            val responseBody = response.body.string()
            if (response.code == 401 || response.code == 403) {
                throw ApiService.UnauthorizedException(user)
            }
            if (!response.isSuccessful) {
                throw apiError(response.code, responseBody, "delete bot")
            }
        }
    }

    suspend fun listMembers(baseUrl: String, user: User, groupId: String): List<ChatMember> {
        val url = "${baseUrl.trimEnd('/')}/v1/groups/$groupId/members"
        val request = HttpUtil.requestBuilder(url, user).get().build()
        HttpUtil.defaultClient(context, baseUrl).newCall(request).execute().use { response ->
            val responseBody = response.body.string()
            if (response.code == 401 || response.code == 403) {
                throw ApiService.UnauthorizedException(user)
            }
            if (!response.isSuccessful) {
                throw apiError(response.code, responseBody, "list members")
            }
            val type = object : TypeToken<List<ChatMember>>() {}.type
            return gson.fromJson(responseBody, type) ?: emptyList()
        }
    }

    suspend fun addMember(baseUrl: String, user: User, groupId: String, username: String) {
        val url = "${baseUrl.trimEnd('/')}/v1/groups/$groupId/members"
        val body = gson.toJson(mapOf("username" to username)).toRequestBody(jsonMedia)
        val request = HttpUtil.requestBuilder(url, user).post(body).build()
        HttpUtil.defaultClient(context, baseUrl).newCall(request).execute().use { response ->
            val responseBody = response.body.string()
            if (response.code == 401 || response.code == 403) {
                throw ApiService.UnauthorizedException(user)
            }
            if (!response.isSuccessful) {
                throw apiError(response.code, responseBody, "add member")
            }
        }
    }

    suspend fun removeMember(baseUrl: String, user: User, groupId: String, userKey: String) {
        val url = "${baseUrl.trimEnd('/')}/v1/groups/$groupId/members/${java.net.URLEncoder.encode(userKey, "UTF-8")}"
        val request = HttpUtil.requestBuilder(url, user).delete().build()
        HttpUtil.defaultClient(context, baseUrl).newCall(request).execute().use { response ->
            val responseBody = response.body.string()
            if (response.code == 401 || response.code == 403) {
                throw ApiService.UnauthorizedException(user)
            }
            if (!response.isSuccessful) {
                throw apiError(response.code, responseBody, "remove member")
            }
        }
    }

    suspend fun deleteGroup(baseUrl: String, user: User, groupId: String) {
        val url = "${baseUrl.trimEnd('/')}/v1/groups/$groupId"
        val request = HttpUtil.requestBuilder(url, user).delete().build()
        HttpUtil.defaultClient(context, baseUrl).newCall(request).execute().use { response ->
            val responseBody = response.body.string()
            if (response.code == 401 || response.code == 403) {
                throw ApiService.UnauthorizedException(user)
            }
            if (!response.isSuccessful) {
                throw apiError(response.code, responseBody, "delete group")
            }
        }
    }

    private fun apiError(code: Int, body: String, action: String): Exception {
        val parsed = try {
            gson.fromJson(body, ApiService.ErrorResponse::class.java)
        } catch (_: Exception) {
            null
        }
        if (parsed?.error != null) {
            return ApiService.ApiException(parsed.error, parsed.code ?: code)
        }
        return Exception("Unexpected response $code when trying to $action")
    }

    data class ChatGroup(
        val id: String = "",
        val name: String = "",
        @SerializedName("owner_user_id") val ownerUserId: String = "",
        val topic: String = "",
        val created: Long = 0,
        @SerializedName("member_count") val memberCount: Long = 0,
        val role: String = "",
    )

    data class ChatBot(
        val id: String = "",
        @SerializedName("group_id") val groupId: String = "",
        val name: String = "",
        @SerializedName("token_hint") val tokenHint: String = "",
        val created: Long = 0,
    )

    data class BotCreateResponse(
        val id: String = "",
        @SerializedName("group_id") val groupId: String = "",
        val name: String = "",
        val token: String = "",
        @SerializedName("webhook_url") val webhookUrl: String = "",
        val created: Long = 0,
    )

    data class ChatMember(
        @SerializedName("user_id") val userId: String = "",
        val username: String = "",
        val role: String = "",
        val joined: Long = 0,
    )

    companion object {
        private const val TAG = "NtfyGroupsApi"
    }
}
