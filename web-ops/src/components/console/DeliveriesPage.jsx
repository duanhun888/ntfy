import * as React from "react";
import { useCallback, useEffect, useState } from "react";
import {
  Alert,
  Box,
  Chip,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from "@mui/material";
import { useTranslation } from "react-i18next";
import adminApi from "../../app/AdminApi";
import { formatDateTime } from "../../app/utils";
import PageHeader from "./PageHeader";
import { consoleTokens } from "./consoleTheme";

const boolChip = (v, t) => {
  if (v === true) {
    return (
      <Chip
        size="small"
        label={t("console_delivery_ok")}
        sx={{ bgcolor: consoleTokens.celadonSoft, color: consoleTokens.celadon, borderRadius: "2px" }}
      />
    );
  }
  if (v === false) {
    return (
      <Chip
        size="small"
        label={t("console_delivery_fail")}
        sx={{ bgcolor: consoleTokens.cinnabarSoft, color: consoleTokens.cinnabar, borderRadius: "2px" }}
      />
    );
  }
  return <Chip size="small" variant="outlined" label="—" sx={{ borderRadius: "2px" }} />;
};

const DeliveriesPage = () => {
  const { t } = useTranslation();
  const [rows, setRows] = useState([]);
  const [error, setError] = useState("");
  const [bizType, setBizType] = useState("");

  const load = useCallback(async () => {
    setError("");
    try {
      const list = await adminApi.listDeliveries({ limit: 100, biz_type: bizType.trim() || undefined });
      setRows(list || []);
    } catch (e) {
      setError(e.message || String(e));
    }
  }, [bizType]);

  useEffect(() => {
    const timer = setTimeout(load, 200);
    return () => clearTimeout(timer);
  }, [load]);

  return (
    <Box sx={{ width: "100%", minWidth: 0 }}>
      <PageHeader
        title={t("console_deliveries_title")}
        subtitle={t("console_deliveries_subtitle")}
        actions={
          <TextField
            size="small"
            label={t("alerts_col_biz")}
            value={bizType}
            onChange={(e) => setBizType(e.target.value)}
            sx={{ minWidth: { xs: "100%", sm: 200 } }}
          />
        }
      />
      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError("")}>
          {error}
        </Alert>
      )}
      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>{t("console_delivery_col_time")}</TableCell>
            <TableCell>{t("alerts_col_biz")}</TableCell>
            <TableCell>{t("console_delivery_col_message")}</TableCell>
            <TableCell>App</TableCell>
            <TableCell>{t("console_delivery_col_wecom")}</TableCell>
            <TableCell>{t("console_delivery_col_error")}</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {rows.map((r) => (
            <TableRow key={r.id}>
              <TableCell>{r.created ? formatDateTime(r.created) : "—"}</TableCell>
              <TableCell sx={{ fontFamily: "monospace" }}>{r.biz_type}</TableCell>
              <TableCell sx={{ maxWidth: 280, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                {r.message || "—"}
              </TableCell>
              <TableCell>{boolChip(r.app_ok, t)}</TableCell>
              <TableCell>{boolChip(r.wecom_ok, t)}</TableCell>
              <TableCell sx={{ maxWidth: 200, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                {r.wecom_error || "—"}
              </TableCell>
            </TableRow>
          ))}
          {rows.length === 0 && (
            <TableRow>
              <TableCell colSpan={6}>
                <Typography color="text.secondary">{t("console_deliveries_empty")}</Typography>
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>
    </Box>
  );
};

export default DeliveriesPage;
