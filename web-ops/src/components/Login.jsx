import * as React from "react";
import { useState } from "react";
import { Typography, TextField, Button, Box, IconButton, InputAdornment, Alert } from "@mui/material";
import WarningAmberIcon from "@mui/icons-material/WarningAmber";
import Visibility from "@mui/icons-material/Visibility";
import VisibilityOff from "@mui/icons-material/VisibilityOff";
import { useLocation, useNavigate } from "react-router-dom";
import { useTranslation } from "react-i18next";
import accountApi, { Role, UnauthorizedError } from "../app/AccountApi";
import config from "../app/config";
import AvatarBox from "./AvatarBox";
import session from "../app/Session";
import routes from "./routes";
import hideSplash from "../app/splash";

const Login = () => {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const location = useLocation();
  const [error, setError] = useState(location.state?.denied ? t("ops_login_denied") : "");
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [busy, setBusy] = useState(false);

  React.useEffect(() => hideSplash(), []);

  const canSubmit = username.trim() !== "" && password !== "" && !busy && config.enable_login;

  const handleSubmit = async (event) => {
    event.preventDefault();
    if (!canSubmit) return;
    setError("");
    setBusy(true);
    try {
      const { token, username: canonicalUsername } = await accountApi.login({
        username: username.trim(),
        password,
      });
      await session.store(canonicalUsername, token);
      const account = await accountApi.get();
      if (account?.role !== Role.ADMIN) {
        await session.reset();
        setError(t("ops_login_denied"));
        return;
      }
      // Full reload so account gate picks up the new session cleanly
      window.location.href = routes.app;
    } catch (e) {
      if (e instanceof UnauthorizedError) {
        setError(t("Login failed: Invalid username/email or password"));
      } else {
        setError(e.message || String(e));
      }
    } finally {
      setBusy(false);
    }
  };

  if (!config.enable_login) {
    return (
      <AvatarBox>
        <Typography sx={{ typography: "h6" }}>{t("login_disabled")}</Typography>
      </AvatarBox>
    );
  }

  return (
    <AvatarBox>
      <Typography sx={{ typography: "h6" }}>{t("ops_login_title")}</Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mt: 1, mb: 1 }}>
        {t("ops_login_hint")}
      </Typography>
      <Box component="form" onSubmit={handleSubmit} noValidate sx={{ mt: 1, width: "100%" }}>
        <TextField
          margin="dense"
          required
          fullWidth
          id="username"
          label={t("login_form_username_label")}
          name="username"
          value={username}
          onChange={(ev) => setUsername(ev.target.value)}
          autoFocus
          autoComplete="username"
        />
        <TextField
          margin="dense"
          required
          fullWidth
          name="password"
          label={t("signup_form_password")}
          type={showPassword ? "text" : "password"}
          id="password"
          value={password}
          onChange={(ev) => setPassword(ev.target.value)}
          autoComplete="current-password"
          slotProps={{
            input: {
              endAdornment: (
                <InputAdornment position="end">
                  <IconButton onClick={() => setShowPassword(!showPassword)} onMouseDown={(ev) => ev.preventDefault()} edge="end">
                    {showPassword ? <VisibilityOff /> : <Visibility />}
                  </IconButton>
                </InputAdornment>
              ),
            },
          }}
        />
        <Button type="submit" fullWidth variant="contained" disabled={!canSubmit} sx={{ mt: 2, mb: 2 }}>
          {busy ? "…" : t("login_form_button_submit")}
        </Button>
        {error && (
          <Box sx={{ mb: 1, display: "flex", justifyContent: "center" }}>
            <WarningAmberIcon color="error" sx={{ mr: 1 }} />
            <Typography sx={{ color: "error.main" }}>{error}</Typography>
          </Box>
        )}
        {!username.trim() || !password ? (
          <Alert severity="info" sx={{ mt: 1 }}>
            请输入用户名和密码后点击登录
          </Alert>
        ) : null}
      </Box>
    </AvatarBox>
  );
};

export default Login;
