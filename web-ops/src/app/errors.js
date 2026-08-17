export class UnauthorizedError extends Error {
  constructor(message) {
    super(message || "Unauthorized");
    this.name = "UnauthorizedError";
  }
}

export const fetchOrThrow = async (url, options = {}) => {
  const response = await fetch(url, options);
  if (response.status === 401 || response.status === 403) {
    let message = response.statusText;
    try {
      const json = await response.json();
      message = json.error || json.message || message;
    } catch {
      /* ignore */
    }
    throw new UnauthorizedError(message);
  }
  if (!response.ok) {
    let message = response.statusText;
    try {
      const json = await response.json();
      message = json.error || json.message || message;
    } catch {
      /* ignore */
    }
    throw new Error(message || `HTTP ${response.status}`);
  }
  return response;
};
