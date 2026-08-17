import Dexie from "dexie";

/** Ops session (separate IndexedDB name from C-end web). */
class Session {
  constructor() {
    const db = new Dexie("ops-session-replica");
    db.version(1).stores({ kv: "&key" });
    this.db = db;
    if (typeof localStorage !== "undefined" && this.exists()) {
      const username = this.username();
      const token = this.token();
      this.db.kv.bulkPut([
        { key: "user", value: username },
        { key: "token", value: token },
      ]).catch(() => {});
    }
  }

  async store(username, token) {
    await this.db.kv.bulkPut([
      { key: "user", value: username },
      { key: "token", value: token },
      { key: "lastExtendedAt", value: Date.now() },
    ]);
    localStorage.setItem("user", username);
    localStorage.setItem("token", token);
  }

  exists() {
    return !!this.token();
  }

  username() {
    return localStorage.getItem("user");
  }

  token() {
    return localStorage.getItem("token");
  }

  async reset() {
    localStorage.removeItem("user");
    localStorage.removeItem("token");
    await this.db.kv.clear();
  }
}

const session = new Session();
export default session;
