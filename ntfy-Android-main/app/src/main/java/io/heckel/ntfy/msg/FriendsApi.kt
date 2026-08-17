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
import java.net.URLEncoder

/**
 * Client for /v1/friends mutual-friend APIs.
 */
class FriendsApi(private val context: Context) {
    private val gson = Gson()
    private val jsonMedia = "application/json; charset=utf-8".toMediaType()

    suspend fun listFriends(baseUrl: String, user: User): List<Friend> {
        val url = "${baseUrl.trimEnd('/')}/v1/friends"
        val request = HttpUtil.requestBuilder(url, user).get().build()
        HttpUtil.defaultClient(context, baseUrl).newCall(request).execute().use { response ->
            val body = response.body.string()
            if (response.code == 401 || response.code == 403) {
                throw ApiService.UnauthorizedException(user)
            }
            if (!response.isSuccessful) {
                throw apiError(response.code, body, "list friends")
            }
            val type = object : TypeToken<List<Friend>>() {}.type
            return gson.fromJson(body, type) ?: emptyList()
        }
    }

    suspend fun sendRequest(baseUrl: String, user: User, username: String): FriendRequest {
        val url = "${baseUrl.trimEnd('/')}/v1/friends/requests"
        val body = gson.toJson(mapOf("username" to username)).toRequestBody(jsonMedia)
        val request = HttpUtil.requestBuilder(url, user).post(body).build()
        Log.d(TAG, "Sending friend request to $username")
        HttpUtil.defaultClient(context, baseUrl).newCall(request).execute().use { response ->
            val responseBody = response.body.string()
            if (response.code == 401 || response.code == 403) {
                throw ApiService.UnauthorizedException(user)
            }
            if (!response.isSuccessful) {
                throw apiError(response.code, responseBody, "send friend request")
            }
            return gson.fromJson(responseBody, FriendRequest::class.java)
        }
    }

    suspend fun listRequests(baseUrl: String, user: User, box: String, status: String? = null): List<FriendRequest> {
        val qs = buildString {
            append("box=").append(URLEncoder.encode(box, "UTF-8"))
            if (!status.isNullOrBlank()) {
                append("&status=").append(URLEncoder.encode(status, "UTF-8"))
            }
        }
        val url = "${baseUrl.trimEnd('/')}/v1/friends/requests?$qs"
        val request = HttpUtil.requestBuilder(url, user).get().build()
        HttpUtil.defaultClient(context, baseUrl).newCall(request).execute().use { response ->
            val body = response.body.string()
            if (response.code == 401 || response.code == 403) {
                throw ApiService.UnauthorizedException(user)
            }
            if (!response.isSuccessful) {
                throw apiError(response.code, body, "list friend requests")
            }
            val type = object : TypeToken<List<FriendRequest>>() {}.type
            return gson.fromJson(body, type) ?: emptyList()
        }
    }

    suspend fun acceptRequest(baseUrl: String, user: User, requestId: String) {
        actionRequest(baseUrl, user, requestId, "accept")
    }

    suspend fun rejectRequest(baseUrl: String, user: User, requestId: String) {
        actionRequest(baseUrl, user, requestId, "reject")
    }

    private suspend fun actionRequest(baseUrl: String, user: User, requestId: String, action: String) {
        val url = "${baseUrl.trimEnd('/')}/v1/friends/requests/$requestId/$action"
        val request = HttpUtil.requestBuilder(url, user)
            .post("".toRequestBody(null))
            .build()
        HttpUtil.defaultClient(context, baseUrl).newCall(request).execute().use { response ->
            val body = response.body.string()
            if (response.code == 401 || response.code == 403) {
                throw ApiService.UnauthorizedException(user)
            }
            if (!response.isSuccessful) {
                throw apiError(response.code, body, "$action friend request")
            }
        }
    }

    suspend fun removeFriend(baseUrl: String, user: User, userKey: String) {
        val encoded = URLEncoder.encode(userKey, "UTF-8")
        val url = "${baseUrl.trimEnd('/')}/v1/friends/$encoded"
        val request = HttpUtil.requestBuilder(url, user).delete().build()
        HttpUtil.defaultClient(context, baseUrl).newCall(request).execute().use { response ->
            val body = response.body.string()
            if (response.code == 401 || response.code == 403) {
                throw ApiService.UnauthorizedException(user)
            }
            if (!response.isSuccessful) {
                throw apiError(response.code, body, "remove friend")
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

    data class Friend(
        @SerializedName("user_id") val userId: String? = "",
        val username: String? = "",
        val topic: String? = "",
        val created: Long = 0,
    ) {
        fun safeUserId(): String = userId.orEmpty()
        fun safeUsername(): String = username.orEmpty().ifBlank { safeUserId() }
        fun safeTopic(): String = topic.orEmpty()
    }

    data class FriendRequest(
        val id: String? = "",
        @SerializedName("from_user_id") val fromUserId: String? = "",
        @SerializedName("from_username") val fromUsername: String? = "",
        @SerializedName("to_user_id") val toUserId: String? = "",
        @SerializedName("to_username") val toUsername: String? = "",
        val status: String? = "",
        val created: Long = 0,
    )

    companion object {
        private const val TAG = "NtfyFriendsApi"
    }
}
