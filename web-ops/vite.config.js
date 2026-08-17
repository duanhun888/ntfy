/* eslint-disable import/no-extraneous-dependencies */
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  build: {
    outDir: "build",
    assetsDir: "static/media",
    sourcemap: true,
  },
  server: {
    port: 3002,
    proxy: {
      "/v1": "http://127.0.0.1:2586",
      "/hook": "http://127.0.0.1:2586",
      "/alert": "http://127.0.0.1:2586",
    },
  },
  plugins: [react()],
});
