import * as React from "react";
import { useContext, useEffect } from "react";
import { Box, Tab, Tabs, Typography } from "@mui/material";
import { Link, Navigate, Outlet, useLocation, useNavigate } from "react-router-dom";
import { useTranslation } from "react-i18next";
import AccountContext from "../AccountContext";
import { Role } from "../../app/AccountApi";
import session from "../../app/Session";
import routes from "../routes";
import hideSplash from "../../app/splash";

const AdminLayout = () => {
  const { t } = useTranslation();
  const { account } = useContext(AccountContext);
  const location = useLocation();
  const navigate = useNavigate();

  useEffect(() => hideSplash(), []);

  if (!session.exists()) {
    return <Navigate to={routes.login} replace />;
  }
  if (account && account.role !== Role.ADMIN) {
    return <Navigate to={routes.app} replace />;
  }
  if (!account) {
    return (
      <Box sx={{ p: 3 }}>
        <Typography color="text.secondary">{t("admin_loading")}</Typography>
      </Box>
    );
  }

  let tab = 0;
  if (location.pathname.startsWith(routes.adminGroups)) tab = 1;
  else if (location.pathname.startsWith(routes.adminAlerts)) tab = 2;

  return (
    <Box sx={{ p: { xs: 2, sm: 3 }, maxWidth: 1100, mx: "auto", width: "100%" }}>
      <Typography variant="h5" sx={{ mb: 2 }}>
        {t("admin_title")}
      </Typography>
      <Tabs
        value={tab}
        onChange={(_, v) => navigate(v === 0 ? routes.adminUsers : v === 1 ? routes.adminGroups : routes.adminAlerts)}
        sx={{ mb: 2, borderBottom: 1, borderColor: "divider" }}
      >
        <Tab label={t("admin_tab_users")} component={Link} to={routes.adminUsers} />
        <Tab label={t("admin_tab_groups")} component={Link} to={routes.adminGroups} />
        <Tab label={t("admin_tab_alerts")} component={Link} to={routes.adminAlerts} />
      </Tabs>
      <Outlet />
    </Box>
  );
};

export default AdminLayout;
