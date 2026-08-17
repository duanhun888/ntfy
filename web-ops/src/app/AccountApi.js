import config from "./config";
import session from "./Session";
import { fetchOrThrow, UnauthorizedError } from "./errors";
import { accountLoginUrl, accountUrl, maybeWithBearerAuth, withBasicAuth, withBearerAuth } from "./utils";

export { UnauthorizedError };

export const Role = {
  ADMIN: "admin",
  USER: "user",
};

class AccountApi {
  async login(user) {
    const url = accountLoginUrl(config.base_url);
    const response = await fetchOrThrow(url, {
      method: "POST",
      headers: withBasicAuth({}, user.username, user.password),
    });
    const json = await response.json();
    if (!json.token) {
      throw new Error("Unexpected server response: Cannot find token");
    }
    return { token: json.token, username: json.username || user.username };
  }

  async get() {
    const url = accountUrl(config.base_url);
    const response = await fetchOrThrow(url, {
      headers: maybeWithBearerAuth({}, session.token()),
    });
    return response.json();
  }

  async logout() {
    try {
      await fetchOrThrow(`${config.base_url}/v1/account/token`, {
        method: "DELETE",
        headers: withBearerAuth({}, session.token()),
      });
    } catch {
      /* ignore */
    }
  }
}

const accountApi = new AccountApi();
export default accountApi;
