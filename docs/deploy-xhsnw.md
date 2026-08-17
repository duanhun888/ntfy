# 小红书南网消息 — 三端独立部署清单

对应域名（按你当前线上）：

| 角色 | 域名 | 产物 |
|------|------|------|
| C 端 Web | （你的用户站，如 `msg.xhsnw.com`） | `web/build` |
| 运维 | `https://admin-msg.xhsnw.com` | `web-ops/build` |
| API | `https://sendmsg.xhsnw.com` | `ntfy` 二进制，**不嵌前端** |

---

## 一、API（Go）— 两边前端都依赖它

两边登录都打 `https://sendmsg.xhsnw.com/v1/account/login`。  
若返回 JSON `"page not found"`，几乎一定是 **没开 auth-file**。

### server.yml 最小可用

```yaml
base-url: "https://sendmsg.xhsnw.com"
listen-http: "127.0.0.1:2586"
web-root: disable
auth-file: "/var/lib/ntfy/user.db"
cache-file: "/var/lib/ntfy/cache.db"
enable-login: true
# 若只要管理员能注册可关掉 signup
enable-signup: false
```

### 命令行等价

```bash
./ntfy serve \
  --listen-http 127.0.0.1:2586 \
  --base-url https://sendmsg.xhsnw.com \
  --web-root disable \
  --auth-file /var/lib/ntfy/user.db \
  --cache-file /var/lib/ntfy/cache.db \
  --enable-login
```

### 建管理员（只做一次）

```bash
./ntfy user add --role=admin admin
```

### 自检（在任意机器）

```bash
curl -i -u admin:你的密码 -X POST https://sendmsg.xhsnw.com/v1/account/login
```

- **200** + `token` → API 正常  
- **404** + `page not found` → 仍未加载 auth-file，或 Nginx 没转到 ntfy  
- **401** → 密码错

Nginx 对 `sendmsg.xhsnw.com` 必须 `proxy_pass` 到 `127.0.0.1:2586`（含 WebSocket），**不要**指到静态目录。

---

## 二、两个前端 — 独立 build，线上改 config.js

仓库里 `public/config.js` 默认是 `http://127.0.0.1:2586`，**只能本地开发用**。

正确做法（推荐）：

1. `npm run build`
2. 把 `build/` 整包上传到静态站
3. **在服务器上覆盖** 站点根目录的 `config.js`（见下方模板）

不要指望 Go 再生成 config；分离部署后 config 是静态文件。

### C 端站点根 `config.js`

```js
var config = {
  base_url: "https://sendmsg.xhsnw.com",
  app_root: "/",
  enable_login: true,
  require_login: false,
  enable_signup: false,
  enable_payments: false,
  enable_reservations: true,
  enable_emails: false,
  enable_calls: false,
  enable_web_push: false,
  billing_contact: "",
  web_push_public_key: "",
  disallowed_topics: ["docs","static","file","app","account","settings","signup","login","v1","admin","ops","console","groups","notifications","alert","alerts","help"],
  config_hash: "prod",
};
```

### 运维站 `admin-msg.xhsnw.com` 根目录 `config.js`

```js
var config = {
  base_url: "https://sendmsg.xhsnw.com",
  app_root: "/",
  enable_login: true,
  require_login: true,
  enable_signup: false,
  enable_payments: false,
  enable_reservations: false,
  enable_emails: false,
  enable_calls: false,
  enable_web_push: false,
  billing_contact: "",
  web_push_public_key: "",
  disallowed_topics: [],
  config_hash: "ops-prod",
};
```

浏览器打开：`https://admin-msg.xhsnw.com/config.js`  
确认里面是 `sendmsg.xhsnw.com`，不是 `127.0.0.1`。

静态站 Nginx 必须 SPA 回退：

```nginx
location / {
  try_files $uri $uri/ /index.html;
}
```

---

## 三、发版顺序（每次）

```text
1) 改 Go → go build → 替换二进制 → 重启（带 auth-file）
2) cd web && npm run build → 同步到 C 端静态根 → 覆盖 config.js
3) cd web-ops && npm run build → 同步到 admin-msg 静态根 → 覆盖 config.js
```

三端互不嵌入；**只改前端不必重编 Go**，只改 API 不必重发前端。

---

## 四、两边一起报错时怎么看

| 现象 | 处理 |
|------|------|
| 登录 `page not found` | API 加 `auth-file` + `enable-login`，重建 admin |
| 请求打到 `127.0.0.1` / 错域名 | 线上 `config.js` 的 `base_url` 改成 `https://sendmsg.xhsnw.com` |
| CORS 报错 | 确认响应有 `Access-Control-Allow-Origin`（ntfy 默认 `*`） |
| 刷新子路径 404 | 静态站缺 `try_files ... /index.html` |
| API 根路径还出旧网页 | `web-root: disable`，Nginx 别把 sendmsg 指到静态目录 |

---

## 五、App 从 GitHub/Gitea 检查更新

客户端按 **Releases API** 拉最新版。当前仓库：[`duanhun888/ntfy`](https://github.com/duanhun888/ntfy)。

| 配置位置 | 常量 |
|----------|------|
| Android `app/build.gradle` | `UPDATE_API_BASE=https://api.github.com`、`UPDATE_REPO=duanhun888/ntfy` |
| iOS `Config.swift` | `updateApiBase`、`updateRepo` |

发版约定：

1. 创建 GitHub Release（或兼容 Gitea），**Tag** 用语义化版本：`1.2.3` 或 `v1.2.3`（与 Android `versionName` / iOS `CFBundleShortVersionString` 可比）。
2. **Android**：附件中至少一个 `.apk`（优先匹配文件名含 `fdroid` / `release`）。
3. **iOS**：用户点更新后打开 Release 页（`html_url`）；系统不允许 App 内静默安装 IPA。
4. 公开仓库即可；私有仓鉴权未做。

