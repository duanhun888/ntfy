import i18next from "i18next";
import Backend from "i18next-http-backend";
import LanguageDetector from "i18next-browser-languagedetector";
import { initReactI18next } from "react-i18next";

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
        order: ["localStorage"],
        caches: ["localStorage"],
      },
      interpolation: { escapeValue: false },
      backend: { loadPath: "/static/langs/{{lng}}.json" },
    });

export default initI18n;
