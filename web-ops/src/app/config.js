const { config } = window;

if (!config) {
  throw new Error("Missing /config.js — ops SPA requires window.config.base_url pointing at the API");
}

// Separated deploy: base_url must be the API origin. Never fall back to the SPA origin.
if (!config.base_url || config.base_url === "") {
  throw new Error("config.base_url is required (API origin, e.g. https://api.example.com)");
}

export default config;
