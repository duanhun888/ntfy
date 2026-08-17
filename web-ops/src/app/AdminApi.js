import { fetchOrThrow } from "./errors";
import config from "./config";
import session from "./Session";
import { withBearerAuth } from "./utils";

const base = () => config.base_url.replace(/\/$/, "");

const usersUrl = () => `${base()}/v1/users`;
const groupsUrl = () => `${base()}/v1/groups`;
const groupUrl = (id) => `${base()}/v1/groups/${id}`;
const groupMembersUrl = (id) => `${base()}/v1/groups/${id}/members`;
const groupMemberUrl = (id, userKey) => `${base()}/v1/groups/${id}/members/${encodeURIComponent(userKey)}`;
const groupBotsUrl = (id) => `${base()}/v1/groups/${id}/bots`;
const groupBotUrl = (id, botId) => `${base()}/v1/groups/${id}/bots/${botId}`;
const alertRoutesUrl = () => `${base()}/v1/alert-routes`;
const alertRouteUrl = (id) => `${base()}/v1/alert-routes/${id}`;

const authHeaders = (extra = {}) => withBearerAuth({ "Content-Type": "application/json", ...extra }, session.token());

class AdminApi {
  async listUsers() {
    const response = await fetchOrThrow(usersUrl(), { headers: authHeaders() });
    return response.json();
  }

  async createUser(username, password) {
    await fetchOrThrow(usersUrl(), {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ username, password }),
    });
  }

  async updateUserPassword(username, password) {
    await fetchOrThrow(usersUrl(), {
      method: "PUT",
      headers: authHeaders(),
      body: JSON.stringify({ username, password }),
    });
  }

  async deleteUser(username) {
    await fetchOrThrow(usersUrl(), {
      method: "DELETE",
      headers: authHeaders(),
      body: JSON.stringify({ username }),
    });
  }

  async listGroups() {
    const response = await fetchOrThrow(groupsUrl(), { headers: authHeaders() });
    return response.json();
  }

  async getGroup(id) {
    const response = await fetchOrThrow(groupUrl(id), { headers: authHeaders() });
    return response.json();
  }

  async createGroup(name) {
    const response = await fetchOrThrow(groupsUrl(), {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ name }),
    });
    return response.json();
  }

  async deleteGroup(id) {
    await fetchOrThrow(groupUrl(id), {
      method: "DELETE",
      headers: authHeaders(),
    });
  }

  async listMembers(groupId) {
    const response = await fetchOrThrow(groupMembersUrl(groupId), { headers: authHeaders() });
    return response.json();
  }

  async addMember(groupId, username) {
    await fetchOrThrow(groupMembersUrl(groupId), {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ username }),
    });
  }

  async removeMember(groupId, userKey) {
    await fetchOrThrow(groupMemberUrl(groupId, userKey), {
      method: "DELETE",
      headers: authHeaders(),
    });
  }

  async listBots(groupId) {
    const response = await fetchOrThrow(groupBotsUrl(groupId), { headers: authHeaders() });
    return response.json();
  }

  async createBot(groupId, name) {
    const response = await fetchOrThrow(groupBotsUrl(groupId), {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ name }),
    });
    return response.json();
  }

  async deleteBot(groupId, botId) {
    await fetchOrThrow(groupBotUrl(groupId, botId), {
      method: "DELETE",
      headers: authHeaders(),
    });
  }

  async listAlertRoutes() {
    const response = await fetchOrThrow(alertRoutesUrl(), { headers: authHeaders() });
    return response.json();
  }

  async createAlertRoute({ biz_type, name, group_id, wecom_webhook }) {
    const response = await fetchOrThrow(alertRoutesUrl(), {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ biz_type, name, group_id, wecom_webhook }),
    });
    return response.json();
  }

  async updateAlertRoute(id, { name, group_id, wecom_webhook, enabled }) {
    const response = await fetchOrThrow(alertRouteUrl(id), {
      method: "PUT",
      headers: authHeaders(),
      body: JSON.stringify({ name, group_id, wecom_webhook, enabled }),
    });
    return response.json();
  }

  async deleteAlertRoute(id) {
    await fetchOrThrow(alertRouteUrl(id), {
      method: "DELETE",
      headers: authHeaders(),
    });
  }

  async updateMemberRole(groupId, userKey, role) {
    await fetchOrThrow(groupMemberUrl(groupId, userKey), {
      method: "PUT",
      headers: authHeaders(),
      body: JSON.stringify({ role }),
    });
  }

  async allowAccess(username, topic, permission) {
    await fetchOrThrow(`${base()}/v1/users/access`, {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ username, topic, permission }),
    });
  }

  async resetAccess(username, topic) {
    await fetchOrThrow(`${base()}/v1/users/access`, {
      method: "DELETE",
      headers: authHeaders(),
      body: JSON.stringify({ username, topic }),
    });
  }

  async listDeliveries({ limit = 100, biz_type } = {}) {
    const q = new URLSearchParams();
    if (limit) q.set("limit", String(limit));
    if (biz_type) q.set("biz_type", biz_type);
    const response = await fetchOrThrow(`${base()}/v1/alert-deliveries?${q}`, { headers: authHeaders() });
    return response.json();
  }

  async deliveryStats() {
    const response = await fetchOrThrow(`${base()}/v1/alert-deliveries/stats`, { headers: authHeaders() });
    return response.json();
  }
}

const adminApi = new AdminApi();
export default adminApi;
