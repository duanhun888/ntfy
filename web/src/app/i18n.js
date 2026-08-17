import i18next from "i18next";
import Backend from "i18next-http-backend";
import LanguageDetector from "i18next-browser-languagedetector";
import { initReactI18next } from "react-i18next";

// Default product language: Simplified Chinese (zh_Hans).
// User choice in localStorage / account settings still overrides.

const initI18n = () =>
  i18next
    .use(Backend)
    .use(LanguageDetector)
    .use(initReactI18next)
    .init({
      lng: "zh_Hans",
      fallbackLng: "zh_Hans",
      debug: false,
      detection: {
        // Prefer saved user choice; otherwise keep product default (zh_Hans).
        order: ["localStorage"],
        caches: ["localStorage"],
        convertDetectedLanguage: (lng) => {
          const lower = (lng || "").toLowerCase().replace(/-/g, "_");
          if (lower === "zh_cn" || lower === "zh_sg" || lower === "zh_hans" || lower === "zh") {
            return "zh_Hans";
          }
          if (lower === "zh_tw" || lower === "zh_hk" || lower === "zh_mo" || lower === "zh_hant") {
            return "zh_Hant";
          }
          return lng;
        },
      },
      interpolation: {
        escapeValue: false,
      },
      backend: {
        loadPath: "/static/langs/{{lng}}.json",
      },
    });

export default initI18n;
