// PWA is optional (see vite.config.js NTFY_ENABLE_PWA=1).
// Default builds skip the service worker to avoid workbox segfaults on some hosts.

const intervalMS = 60 * 60 * 1000;

const registerSW = async () => {
  if (!__NTFY_ENABLE_PWA__) {
    console.log("[ServiceWorker] PWA disabled for this build");
    return;
  }
  if (!("serviceWorker" in navigator)) {
    console.warn("[ServiceWorker] Service workers not supported");
    return;
  }

  try {
    // eslint-disable-next-line import/no-unresolved
    const { registerSW: viteRegisterSW } = await import("virtual:pwa-register");
    console.log("[ServiceWorker] Registering service worker");
    viteRegisterSW({
      onRegisteredSW(swUrl, registration) {
        console.log("[ServiceWorker] Registered:", { swUrl, registration });
        if (!registration) return;
        setInterval(async () => {
          if (registration.installing || navigator?.onLine === false) return;
          const resp = await fetch(swUrl, {
            cache: "no-store",
            headers: { "cache-control": "no-cache" },
          });
          if (resp?.status === 200) {
            await registration.update();
          }
        }, intervalMS);
      },
      onRegisterError(error) {
        console.error("[ServiceWorker] Registration error:", error);
      },
    });
  } catch (e) {
    console.warn("[ServiceWorker] PWA register unavailable", e);
  }
};

export default registerSW;
