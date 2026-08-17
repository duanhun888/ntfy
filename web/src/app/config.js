const { config } = window;

if (!config) {
  throw new Error("Missing /config.js");
}

// Separated deploy: set base_url to the API origin in public/config.js.
// Empty base_url still falls back for legacy same-origin embeds only.
if (!config.base_url || config.base_url === "") {
  console.warn("[config] base_url empty; falling back to window.location.origin (not recommended for split deploy)");
  config.base_url = window.location.origin;
}

export default config;
