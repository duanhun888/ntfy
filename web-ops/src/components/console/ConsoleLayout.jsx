import * as React from "react";
import { useContext, useEffect, useMemo } from "react";
import {
  Box,
  Divider,
  List,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  ListSubheader,
  Typography,
} from "@mui/material";
import DashboardIcon from "@mui/icons-material/Dashboard";
import GroupsIcon from "@mui/icons-material/Groups";
import RouteIcon from "@mui/icons-material/AltRoute";
import PeopleIcon from "@mui/icons-material/People";
import LockIcon from "@mui/icons-material/Lock";
import HistoryIcon from "@mui/icons-material/History";
import { Link, Outlet, useLocation } from "react-router-dom";
import { useTranslation } from "react-i18next";
import AccountContext from "../AccountContext";
import routes from "../routes";
import hideSplash from "../../app/splash";
import { consoleTokens, consoleStyles } from "./consoleTheme";
import ConsolePanel from "./ConsolePanel";

const FONT_HREF =
  "https://fonts.googleapis.com/css2?family=Noto+Sans+SC:wght@400;500;600&family=Noto+Serif+SC:wght@500;600;700&display=swap";

const ConsoleLayout = () => {
  const { t } = useTranslation();
  const { account } = useContext(AccountContext);
  const location = useLocation();

  useEffect(() => hideSplash(), []);

  useEffect(() => {
    const id = "console-cn-fonts";
    if (document.getElementById(id)) return undefined;
    const link = document.createElement("link");
    link.id = id;
    link.rel = "stylesheet";
    link.href = FONT_HREF;
    document.head.appendChild(link);
    return undefined;
  }, []);

  useEffect(() => {
    document.title = t("console_title");
  }, [t]);

  const navItems = useMemo(
    () => [
      { key: "overview", to: routes.app, icon: <DashboardIcon fontSize="small" />, label: t("console_nav_overview"), exact: true },
      { key: "groups", to: routes.groups, icon: <GroupsIcon fontSize="small" />, label: t("console_nav_groups") },
      { key: "alerts", to: routes.alerts, icon: <RouteIcon fontSize="small" />, label: t("console_nav_alerts") },
      { key: "users", to: routes.users, icon: <PeopleIcon fontSize="small" />, label: t("console_nav_users") },
      { key: "access", to: routes.access, icon: <LockIcon fontSize="small" />, label: t("console_nav_access") },
      { key: "deliveries", to: routes.deliveries, icon: <HistoryIcon fontSize="small" />, label: t("console_nav_deliveries") },
    ],
    [t],
  );

  if (!account) {
    return (
      <Box sx={{ p: 3, fontFamily: consoleTokens.fontBody }}>
        <Typography color="text.secondary">{t("admin_loading")}</Typography>
      </Box>
    );
  }

  const selected = (path) => location.pathname === path || location.pathname.startsWith(`${path}/`);

  const NavSection = ({ label, children }) => (
    <>
      <ListSubheader disableSticky sx={{ bgcolor: "transparent", lineHeight: 2.2, px: 1.5 }}>
        {label}
      </ListSubheader>
      {children}
    </>
  );

  const NavItem = ({ item }) => (
    <ListItemButton
      component={Link}
      to={item.to}
      selected={item.exact ? location.pathname === item.to : selected(item.to)}
      sx={{ mx: 0.5, mb: 0.25, borderRadius: "2px", py: 0.75 }}
    >
      <ListItemIcon sx={{ minWidth: 34, color: "inherit" }}>{item.icon}</ListItemIcon>
      <ListItemText primary={item.label} primaryTypographyProps={{ fontSize: "0.9rem", fontWeight: 500 }} />
    </ListItemButton>
  );

  return (
    <Box
      sx={{
        ...consoleStyles,
        minHeight: "100dvh",
        height: "100dvh",
        overflow: "auto",
        backgroundColor: consoleTokens.paper,
        backgroundImage: consoleTokens.latticeBg,
        px: { xs: 1.5, sm: 2 },
        py: { xs: 2, sm: 2.5 },
        width: "100%",
        boxSizing: "border-box",
        overflowX: "hidden",
      }}
    >
      <Box
        sx={{
          display: "flex",
          flexDirection: { xs: "column", md: "row" },
          gap: 2,
          maxWidth: 1180,
          mx: "auto",
          width: "100%",
        }}
      >
        <Box
          sx={{
            width: { xs: "100%", md: 228 },
            flexShrink: 0,
            bgcolor: consoleTokens.panel,
            border: `1px solid ${consoleTokens.lineStrong}`,
            borderRadius: "2px",
            p: 1.25,
            alignSelf: "flex-start",
            position: { md: "sticky" },
            top: { md: 16 },
          }}
        >
          <Typography
            sx={{
              fontFamily: consoleTokens.fontDisplay,
              fontWeight: 700,
              letterSpacing: "0.18em",
              fontSize: "1.05rem",
              px: 1.25,
              pt: 0.5,
              pb: 1,
              color: consoleTokens.ink,
            }}
          >
            {t("console_title")}
          </Typography>
          <List dense component="nav" disablePadding>
            <NavSection label={t("console_section_overview")}>
              {navItems.filter((i) => i.key === "overview").map((item) => (
                <NavItem key={item.key} item={item} />
              ))}
            </NavSection>
            <Divider sx={{ my: 1, borderColor: consoleTokens.line }} />
            <NavSection label={t("console_section_resources")}>
              {navItems.filter((i) => i.key === "groups" || i.key === "alerts").map((item) => (
                <NavItem key={item.key} item={item} />
              ))}
            </NavSection>
            <Divider sx={{ my: 1, borderColor: consoleTokens.line }} />
            <NavSection label={t("console_section_permissions")}>
              {navItems.filter((i) => i.key === "users" || i.key === "access").map((item) => (
                <NavItem key={item.key} item={item} />
              ))}
            </NavSection>
            <Divider sx={{ my: 1, borderColor: consoleTokens.line }} />
            <NavSection label={t("console_section_ops")}>
              {navItems.filter((i) => i.key === "deliveries").map((item) => (
                <NavItem key={item.key} item={item} />
              ))}
            </NavSection>
          </List>
        </Box>
        <ConsolePanel sx={{ flex: 1 }}>
          <Outlet />
        </ConsolePanel>
      </Box>
    </Box>
  );
};

export default ConsoleLayout;
