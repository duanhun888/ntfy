// Runtime config for the ops SPA (served as static /config.js).
// Set base_url to the API origin (e.g. https://api.example.com). Do not leave empty in production.
var config = {
  base_url: "http://127.0.0.1:2586",
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
  config_hash: "ops-dev",
};
