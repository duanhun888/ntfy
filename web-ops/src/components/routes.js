const routes = {
  app: "/",
  login: "/login",
  groups: "/groups",
  group: "/groups/:id",
  alerts: "/alerts",
  users: "/users",
  access: "/access",
  deliveries: "/deliveries",
  forGroup: (id) => `/groups/${id}`,
};

export default routes;
