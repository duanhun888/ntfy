import { AppBar, Toolbar, IconButton, Typography, Box, MenuItem, Button, Divider, ListItemIcon, useTheme } from "@mui/material";
import MenuIcon from "@mui/icons-material/Menu";
import * as React from "react";
import { useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import MoreVertIcon from "@mui/icons-material/MoreVert";
import NotificationsIcon from "@mui/icons-material/Notifications";
import NotificationsOffIcon from "@mui/icons-material/NotificationsOff";
import RefreshIcon from "@mui/icons-material/Refresh";
import { useTranslation } from "react-i18next";
import AccountCircleIcon from "@mui/icons-material/AccountCircle";
import Logout from "@mui/icons-material/Logout";
import Person from "@mui/icons-material/Person";
import Settings from "@mui/icons-material/Settings";
import session from "../app/Session";
import logo from "../img/ntfy.svg";
import subscriptionManager from "../app/SubscriptionManager";
import routes from "./routes";
import db from "../app/db";
import { topicDisplayName } from "../app/utils";
import { fadeNavigate } from "../app/transition";
import Navigation from "./Navigation";
import accountApi from "../app/AccountApi";
import PopupMenu from "./PopupMenu";
import { SubscriptionPopup } from "./SubscriptionPopup";
import { useIsLaunchedPWA } from "./hooks";

const ActionBar = (props) => {
  const theme = useTheme();
  const { t } = useTranslation();
  const location = useLocation();
  const isLaunchedPWA = useIsLaunchedPWA();

  let title = "ntfy";
  if (props.selected) {
    title = topicDisplayName(props.selected);
  } else if (location.pathname === routes.settings) {
    title = t("action_bar_settings");
  } else if (location.pathname === routes.help) {
    title = t("action_bar_help");
  } else if (location.pathname === routes.account) {
    title = t("action_bar_account");
  } else if (location.pathname.startsWith(routes.groups)) {
    title = t("action_bar_groups");
  } else if (location.pathname === routes.notifications) {
    title = t("nav_button_all_notifications");
  }

  const getActionBarBackground = () => {
    if (isLaunchedPWA) {
      return "#317f6f";
    }

    switch (theme.palette.mode) {
      case "dark":
        return "linear-gradient(150deg, #203631 0%, #2a6e60 100%)";

      case "light":
      default:
        return "linear-gradient(150deg, #338574 0%, #56bda8 100%)";
    }
  };

  return (
    <AppBar
      position="fixed"
      sx={{
        width: "100%",
        zIndex: { sm: 1250 }, // > Navigation (1200), but < Dialog (1300)
        ml: { sm: `${Navigation.width}px` },
      }}
    >
      <Toolbar
        sx={{
          pr: "24px",
          background: getActionBarBackground(),
        }}
      >
        <IconButton
          color="inherit"
          edge="start"
          aria-label={t("action_bar_show_menu")}
          onClick={props.onMobileDrawerToggle}
          sx={{ mr: 2, display: { sm: "none" } }}
        >
          <MenuIcon />
        </IconButton>
        <Box
          component="img"
          src={logo}
          alt={t("action_bar_logo_alt")}
          sx={{
            display: { xs: "none", sm: "block" },
            marginRight: "10px",
            height: "28px",
          }}
        />
        <Typography variant="h6" noWrap component="div" sx={{ flexGrow: 1 }}>
          {title}
        </Typography>
        {isLaunchedPWA && <ReloadIcon />}
        {props.selected && <SettingsIcons subscription={props.selected} onUnsubscribe={props.onUnsubscribe} />}
        <LanguageToggle />
        <ProfileIcon />
      </Toolbar>
    </AppBar>
  );
};

const SettingsIcons = (props) => {
  const { t } = useTranslation();
  const [anchorEl, setAnchorEl] = useState(null);
  const { subscription } = props;

  const handleToggleMute = async () => {
    const mutedUntil = subscription.mutedUntil ? 0 : 1; // Make this a timestamp in the future
    await subscriptionManager.setMutedUntil(subscription.id, mutedUntil);
  };

  return (
    <>
      <IconButton color="inherit" size="large" edge="end" onClick={handleToggleMute} aria-label={t("action_bar_toggle_mute")}>
        {subscription.mutedUntil ? <NotificationsOffIcon /> : <NotificationsIcon />}
      </IconButton>
      <IconButton
        color="inherit"
        size="large"
        edge="end"
        onClick={(ev) => setAnchorEl(ev.currentTarget)}
        aria-label={t("action_bar_toggle_action_menu")}
      >
        <MoreVertIcon />
      </IconButton>
      <SubscriptionPopup subscription={subscription} anchor={anchorEl} placement="right" onClose={() => setAnchorEl(null)} />
    </>
  );
};

// ReloadIcon hard-refreshes the app. A plain reload would just serve the precached PWA shell,
// so we first purge the service worker caches to force fresh assets from the network.
const ReloadIcon = () => {
  const { t } = useTranslation();

  const handleReload = async () => {
    try {
      if ("caches" in window) {
        const keys = await caches.keys();
        await Promise.all(keys.map((key) => caches.delete(key)));
      }
    } catch (e) {
      console.warn("[ActionBar] Error clearing caches during reload", e);
    } finally {
      window.location.reload();
    }
  };

  return (
    <IconButton color="inherit" size="large" edge="end" onClick={handleReload} aria-label={t("action_bar_reload")}>
      <RefreshIcon />
    </IconButton>
  );
};

const LanguageToggle = () => {
  const { t, i18n } = useTranslation();
  const lang = (i18n.resolvedLanguage || i18n.language || "zh_Hans").toLowerCase();
  const isZh = lang.startsWith("zh");

  const setLang = async (code) => {
    await i18n.changeLanguage(code);
    try {
      if (session.exists()) {
        await accountApi.updateSettings({ language: code });
      }
    } catch (e) {
      console.warn("[ActionBar] Failed to persist language", e);
    }
  };

  return (
    <Box sx={{ display: "flex", alignItems: "center", mr: 0.5 }}>
      <Button
        color="inherit"
        size="small"
        onClick={() => setLang("en")}
        sx={{ minWidth: 0, px: 1, opacity: isZh ? 0.7 : 1, fontWeight: isZh ? 400 : 700 }}
      >
        {t("action_bar_language_en")}
      </Button>
      <Typography component="span" sx={{ opacity: 0.5 }}>
        |
      </Typography>
      <Button
        color="inherit"
        size="small"
        onClick={() => setLang("zh_Hans")}
        sx={{ minWidth: 0, px: 1, opacity: isZh ? 1 : 0.7, fontWeight: isZh ? 700 : 400 }}
      >
        {t("action_bar_language_zh")}
      </Button>
    </Box>
  );
};

const ProfileIcon = () => {
  const { t } = useTranslation();
  const [anchorEl, setAnchorEl] = useState(null);
  const open = Boolean(anchorEl);
  const navigate = useNavigate();

  const handleClick = (event) => {
    setAnchorEl(event.currentTarget);
  };

  const handleClose = () => {
    setAnchorEl(null);
  };

  const handleLogout = async () => {
    try {
      await accountApi.logout();
      await db().delete();
    } finally {
      await session.resetAndRedirect(routes.app, { fade: true });
    }
  };

  return (
    <>
      {session.exists() && (
        <IconButton color="inherit" size="large" edge="end" onClick={handleClick} aria-label={t("action_bar_profile_title")}>
          <AccountCircleIcon />
        </IconButton>
      )}
      {!session.exists() && config.enable_login && (
        <Button
          color="inherit"
          variant="text"
          onClick={() => fadeNavigate(navigate, routes.login)}
          sx={{ m: 1 }}
          aria-label={t("action_bar_sign_in")}
        >
          {t("action_bar_sign_in")}
        </Button>
      )}
      {!session.exists() && config.enable_signup && (
        <Button
          color="inherit"
          variant="outlined"
          onClick={() => fadeNavigate(navigate, routes.signup)}
          aria-label={t("action_bar_sign_up")}
        >
          {t("action_bar_sign_up")}
        </Button>
      )}
      <PopupMenu horizontal="right" anchorEl={anchorEl} open={open} onClose={handleClose}>
        <MenuItem onClick={() => navigate(routes.account)}>
          <ListItemIcon>
            <Person />
          </ListItemIcon>
          <b>{session.username()}</b>
        </MenuItem>
        <Divider />
        <MenuItem onClick={() => navigate(routes.settings)}>
          <ListItemIcon>
            <Settings fontSize="small" />
          </ListItemIcon>
          {t("action_bar_profile_settings")}
        </MenuItem>
        <MenuItem onClick={handleLogout}>
          <ListItemIcon>
            <Logout fontSize="small" />
          </ListItemIcon>
          {t("action_bar_profile_logout")}
        </MenuItem>
      </PopupMenu>
    </>
  );
};

export default ActionBar;
