import * as React from "react";
import { useCallback, useEffect, useState } from "react";
import { Alert, Box, Button, CardActionArea, Typography } from "@mui/material";
import { Link } from "react-router-dom";
import { useTranslation } from "react-i18next";
import adminApi from "../../app/AdminApi";
import routes from "../routes";
import PageHeader from "./PageHeader";
import { consoleTokens } from "./consoleTheme";

const OverviewPage = () => {
  const { t } = useTranslation();
  const [error, setError] = useState("");
  const [groups, setGroups] = useState(0);
  const [routesCount, setRoutesCount] = useState(0);
  const [total24h, setTotal24h] = useState(0);
  const [failed24h, setFailed24h] = useState(0);

  const load = useCallback(async () => {
    setError("");
    try {
      const [gs, rs, stats] = await Promise.all([adminApi.listGroups(), adminApi.listAlertRoutes(), adminApi.deliveryStats()]);
      setGroups((gs || []).length);
      setRoutesCount((rs || []).length);
      setTotal24h(stats?.total || 0);
      setFailed24h(stats?.failed || 0);
    } catch (e) {
      setError(e.message || String(e));
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const cards = [
    { label: t("console_stat_groups"), value: groups, to: routes.groups, tone: "celadon" },
    { label: t("console_stat_routes"), value: routesCount, to: routes.alerts, tone: "celadon" },
    { label: t("console_stat_triggers_24h"), value: total24h, to: routes.deliveries, tone: "ink" },
    { label: t("console_stat_failed_24h"), value: failed24h, to: routes.deliveries, tone: "cinnabar" },
  ];

  return (
    <Box sx={{ width: "100%", minWidth: 0 }}>
      <PageHeader
        title={t("console_overview_title")}
        subtitle={t("console_overview_subtitle")}
        actions={
          <Button component={Link} to={routes.alerts} variant="outlined" size="small">
            {t("console_nav_alerts")}
          </Button>
        }
      />
      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError("")}>
          {error}
        </Alert>
      )}
      <Box
        sx={{
          display: "grid",
          gap: 1.75,
          gridTemplateColumns: { xs: "1fr", sm: "1fr 1fr", md: "repeat(4, 1fr)" },
        }}
      >
        {cards.map((c) => (
          <Box
            key={c.label}
            sx={{
              border: `1px solid ${consoleTokens.lineStrong}`,
              borderRadius: "2px",
              bgcolor: consoleTokens.panel,
              overflow: "hidden",
              position: "relative",
              "&::before": {
                content: '""',
                position: "absolute",
                left: 0,
                top: 0,
                bottom: 0,
                width: 3,
                bgcolor:
                  c.tone === "cinnabar" ? consoleTokens.cinnabar : c.tone === "ink" ? consoleTokens.ink : consoleTokens.celadon,
              },
            }}
          >
            <CardActionArea component={Link} to={c.to} sx={{ p: 2, pl: 2.5 }}>
              <Typography
                variant="body2"
                sx={{
                  color: consoleTokens.inkMuted,
                  fontFamily: consoleTokens.fontDisplay,
                  letterSpacing: "0.08em",
                }}
              >
                {c.label}
              </Typography>
              <Typography
                variant="h4"
                sx={{
                  mt: 1,
                  fontFamily: consoleTokens.fontDisplay,
                  fontWeight: 700,
                  color: c.tone === "cinnabar" ? consoleTokens.cinnabar : consoleTokens.ink,
                }}
              >
                {c.value}
              </Typography>
            </CardActionArea>
          </Box>
        ))}
      </Box>
    </Box>
  );
};

export default OverviewPage;
