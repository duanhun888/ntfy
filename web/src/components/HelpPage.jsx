import * as React from "react";
import { useEffect } from "react";
import { Box, Divider, Link, Stack, Typography } from "@mui/material";
import { useTranslation } from "react-i18next";
import hideSplash from "../app/splash";
import routes from "./routes";
import { Link as RouterLink } from "react-router-dom";

const Section = ({ title, children }) => (
  <Box sx={{ mb: 3 }}>
    <Typography variant="h6" sx={{ mb: 1, fontWeight: 600 }}>
      {title}
    </Typography>
    {children}
  </Box>
);

const Code = ({ children }) => (
  <Box
    component="pre"
    sx={{
      m: 0,
      mt: 1,
      mb: 1.5,
      p: 1.5,
      bgcolor: "action.hover",
      borderRadius: 1,
      overflow: "auto",
      fontSize: "0.8rem",
      fontFamily: "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace",
      whiteSpace: "pre-wrap",
      wordBreak: "break-all",
    }}
  >
    {children}
  </Box>
);

const HelpPage = () => {
  const { t } = useTranslation();
  useEffect(() => hideSplash(), []);

  return (
    <Box sx={{ p: { xs: 2, sm: 3 }, maxWidth: 860, mx: "auto", width: "100%" }}>
      <Typography variant="h5" sx={{ mb: 0.5, fontWeight: 700 }}>
        {t("help_title")}
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
        {t("help_subtitle")}
      </Typography>

      <Section title={t("help_section_quick")}>
        <Typography variant="body2" paragraph>
          {t("help_quick_body")}
        </Typography>
        <Stack spacing={0.5}>
          <Typography variant="body2">
            · <Link component={RouterLink} to={routes.groups}>{t("nav_button_groups")}</Link>
            {" — "}
            {t("help_link_groups")}
          </Typography>
          <Typography variant="body2">
            · <Link component={RouterLink} to={routes.notifications}>{t("nav_button_all_notifications")}</Link>
            {" — "}
            {t("help_link_notifications")}
          </Typography>
        </Stack>
      </Section>

      <Divider sx={{ my: 2 }} />

      <Section title={t("help_section_groups")}>
        <Typography variant="body2" paragraph>
          {t("help_groups_body")}
        </Typography>
        <Code>{`curl -X POST "http://HOST:2586/hook/wh_xxxx" \\
  -H "Content-Type: application/json" \\
  -d '{"msgtype":"text","text":{"content":"hello"}}'`}</Code>
      </Section>

      <Section title={t("help_section_alerts")}>
        <Typography variant="body2" paragraph>
          {t("help_alerts_body")}
        </Typography>
        <Code>{`curl -X POST "http://HOST:2586/alert/disk_full" \\
  -H "X-Alert-Token: at_xxxx" \\
  -H "Content-Type: application/json" \\
  -d '{"msgtype":"text","text":{"content":"disk almost full"}}'`}</Code>
      </Section>

      <Section title={t("help_section_upstream")}>
        <Typography variant="body2">
          {t("help_upstream_body")}{" "}
          <Link href="https://docs.ntfy.sh" target="_blank" rel="noopener noreferrer">
            docs.ntfy.sh
          </Link>
        </Typography>
      </Section>
    </Box>
  );
};

export default HelpPage;
