// Runtime config for the C-end SPA.
// For three-domain deploy, set base_url to the API origin (e.g. https://api.example.com).
var config = {
  base_url: "http://127.0.0.1:2586",
  app_root: "/",
  enable_login: true,
  require_login: false,
  enable_signup: true,
  enable_payments: false,
  enable_reservations: true,
  enable_emails: true,
  enable_calls: true,
  enable_web_push: true,
  billing_contact: "",
  web_push_public_key: "",
  disallowed_topics: ["docs", "static", "file", "app", "account", "settings", "signup", "login", "v1", "admin", "ops", "console", "groups", "notifications", "alert", "alerts", "help"],
  config_hash: "web-dev",
};
