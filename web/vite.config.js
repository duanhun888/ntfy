/* eslint-disable import/no-extraneous-dependencies */
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { VitePWA } from "vite-plugin-pwa";

// PWA/service-worker build (workbox) segfaults on some Linux hosts.
// Default: off. Enable with: NTFY_ENABLE_PWA=1 npm run build
const enablePwa = process.env.NTFY_ENABLE_PWA === "1";

export default defineConfig(({ mode }) => ({
  build: {
    outDir: "build",
    assetsDir: "static/media",
    sourcemap: true,
    chunkSizeWarningLimit: 1200,
  },
  server: {
    port: 3000,
    proxy: {
      "/v1": "http://127.0.0.1:2586",
      "/hook": "http://127.0.0.1:2586",
      "/alert": "http://127.0.0.1:2586",
    },
  },
  define: {
    __NTFY_ENABLE_PWA__: JSON.stringify(enablePwa),
  },
  plugins: [
    react(),
    ...(enablePwa
      ? [
          VitePWA({
            registerType: "autoUpdate",
            injectRegister: null,
            strategies: "injectManifest",
            devOptions: {
              enabled: true,
              type: "module",
              navigateFallback: "index.html",
            },
            injectManifest: {
              globPatterns: ["**/*.{js,css,html,ico,png,svg,json}"],
              globIgnores: ["config.js"],
              manifestTransforms: [
                (entries) => ({
                  manifest: entries.map((entry) =>
                    entry.url === "index.html"
                      ? {
                          ...entry,
                          url: "app.html",
                        }
                      : entry,
                  ),
                }),
              ],
            },
            manifest: mode === "development" && {
              theme_color: "#317f6f",
              icons: [
                {
                  src: "/static/images/pwa-192x192.png",
                  sizes: "192x192",
                  type: "image/png",
                },
              ],
            },
          }),
        ]
      : []),
  ],
}));
