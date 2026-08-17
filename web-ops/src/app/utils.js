import config from "./config";

export const accountUrl = (baseUrl) => `${baseUrl}/v1/account`;
export const accountLoginUrl = (baseUrl) => `${baseUrl}/v1/account/login`;

export const withBasicAuth = (headers, username, password) => ({
  ...headers,
  Authorization: `Basic ${btoa(`${username}:${password}`)}`,
});

export const withBearerAuth = (headers, token) => {
  if (!token) return headers;
  return { ...headers, Authorization: `Bearer ${token}` };
};

export const maybeWithBearerAuth = (headers, token) => withBearerAuth(headers, token);

export const formatDateTime = (ts) => {
  if (!ts) return "";
  const d = typeof ts === "number" ? new Date(ts * (ts < 1e12 ? 1000 : 1)) : new Date(ts);
  if (Number.isNaN(d.getTime())) return String(ts);
  return d.toLocaleString();
};

export const copyToClipboard = async (text) => {
  await navigator.clipboard.writeText(text);
};

export const getKebabCaseLangStr = (lng) => (lng || "zh-Hans").replace(/_/g, "-");

// silence unused in some bundles
void config;
