# 前后端分离部署（三域名）

C 端与运维是两套独立前端；Go `ntfy` 只做 API。

| 角色 | 示例域名 | 代码目录 | 构建产物 |
|------|----------|----------|----------|
| C 端 Web | `https://b.example.com` | `web/` | `web/build` |
| 运维后台 | `https://a.example.com` | `web-ops/` | `web-ops/build` |
| API | `https://api.example.com` | Go `ntfy serve` | 二进制 |

## 1. 配置前端 API 地址

两套前端的 `public/config.js` 都必须把 `base_url` 指到 API：

```js
base_url: "https://api.example.com"
```

本地开发默认可用 `http://127.0.0.1:2586`。

- C 端开发：`cd web && npm start`（端口 3000）
- 运维开发：`cd web-ops && npm install && npm start`（端口 3002）

## 2. 启动 API（关闭内置 SPA）

```bash
ntfy serve \
  --listen-http 127.0.0.1:2586 \
  --base-url https://api.example.com \
  --web-root disable \
  --enable-login \
  --auth-file /path/to/user.db
```

`web-root: disable`（或空）后，API 进程不再托管前端页面。

CORS 默认 `*`，Bearer token 跨域可用。生产可按需收紧 `access-control-allow-origin`。

## 3. Nginx 示例

见同目录 [`nginx-three-domains.conf.example`](nginx-three-domains.conf.example)。

要点：

- `b.example.com` → 静态 `web/build`，`try_files` 回退 `index.html`
- `a.example.com` → 静态 `web-ops/build`
- `api.example.com` → `proxy_pass http://127.0.0.1:2586`（含 WebSocket）

## 4. 发版

```bash
# C 端
cd web && npm ci && npm run build
# 将 web/build 同步到 b.example.com 站点根

# 运维
cd web-ops && npm ci && npm run build
# 将 web-ops/build 同步到 a.example.com 站点根

# API
go build -o ntfy .
# 部署二进制并重启；无需再嵌入 server/site
```

## 5. 验收

- 打开 `b.example.com`：仅用户功能（群 / 通知等），无运维入口
- 打开 `a.example.com`：运维登录；非 admin 无法进入业务页
- 浏览器网络面板中，两前端请求均打到 `api.example.com/v1/...`
