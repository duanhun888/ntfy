import * as React from "react";
import { useCallback, useEffect, useState } from "react";
import {
  Alert,
  Box,
  Button,
  Dialog,
  DialogContent,
  DialogTitle,
  FormControl,
  IconButton,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  Switch,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from "@mui/material";
import AddIcon from "@mui/icons-material/Add";
import ContentCopyIcon from "@mui/icons-material/ContentCopy";
import DeleteOutlineIcon from "@mui/icons-material/DeleteOutlineOutlined";
import { useTranslation } from "react-i18next";
import adminApi from "../../app/AdminApi";
import config from "../../app/config";
import DialogFooter from "../DialogFooter";
import { copyToClipboard } from "../../app/utils";
import PageHeader from "../console/PageHeader";

const AlertRoutesPage = () => {
  const { t } = useTranslation();
  const [routes, setRoutes] = useState([]);
  const [groups, setGroups] = useState([]);
  const [error, setError] = useState("");
  const [info, setInfo] = useState("");
  const [busy, setBusy] = useState(false);
  const [createOpen, setCreateOpen] = useState(false);
  const [created, setCreated] = useState(null);
  const [deleteId, setDeleteId] = useState(null);
  const [bizType, setBizType] = useState("");
  const [name, setName] = useState("");
  const [groupId, setGroupId] = useState("");
  const [wecom, setWecom] = useState("");

  const load = useCallback(async () => {
    setError("");
    try {
      const [list, gs] = await Promise.all([adminApi.listAlertRoutes(), adminApi.listGroups()]);
      setRoutes(list || []);
      setGroups(gs || []);
    } catch (e) {
      setError(e.message || String(e));
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const triggerUrl = (biz) => `${config.base_url.replace(/\/$/, "")}/alert/${biz}`;

  const handleCreate = async () => {
    setBusy(true);
    setError("");
    try {
      const r = await adminApi.createAlertRoute({
        biz_type: bizType.trim(),
        name: name.trim() || bizType.trim(),
        group_id: groupId || "",
        wecom_webhook: wecom.trim(),
      });
      setCreateOpen(false);
      setBizType("");
      setName("");
      setGroupId("");
      setWecom("");
      setCreated(r);
      await load();
    } catch (e) {
      setError(e.message || String(e));
    } finally {
      setBusy(false);
    }
  };

  const handleToggle = async (route) => {
    setBusy(true);
    setError("");
    try {
      await adminApi.updateAlertRoute(route.id, {
        name: route.name,
        group_id: route.group_id || "",
        wecom_webhook: route.wecom_webhook || "",
        enabled: !route.enabled,
      });
      await load();
    } catch (e) {
      setError(e.message || String(e));
    } finally {
      setBusy(false);
    }
  };

  const handleDelete = async () => {
    setBusy(true);
    setError("");
    try {
      await adminApi.deleteAlertRoute(deleteId);
      setDeleteId(null);
      await load();
    } catch (e) {
      setError(e.message || String(e));
    } finally {
      setBusy(false);
    }
  };

  const copy = async (text) => {
    await copyToClipboard(text);
    setInfo(t("alerts_copied"));
  };

  const groupName = (id) => groups.find((g) => g.id === id)?.name || id || "—";

  return (
    <Box sx={{ width: "100%", minWidth: 0 }}>
      <PageHeader
        title={t("alerts_title")}
        subtitle={t("alerts_subtitle")}
        actions={
          <Button startIcon={<AddIcon />} variant="contained" onClick={() => setCreateOpen(true)}>
            {t("alerts_create")}
          </Button>
        }
      />

      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError("")}>
          {error}
        </Alert>
      )}
      {info && (
        <Alert severity="success" sx={{ mb: 2 }} onClose={() => setInfo("")}>
          {info}
        </Alert>
      )}

      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>{t("alerts_col_biz")}</TableCell>
            <TableCell>{t("alerts_col_name")}</TableCell>
            <TableCell>{t("alerts_col_group")}</TableCell>
            <TableCell>{t("alerts_col_wecom")}</TableCell>
            <TableCell>{t("alerts_col_enabled")}</TableCell>
            <TableCell align="right">{t("alerts_col_actions")}</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {routes.map((r) => (
            <TableRow key={r.id} hover>
              <TableCell>
                <Typography variant="body2" sx={{ fontFamily: "monospace" }}>
                  {r.biz_type}
                </Typography>
                <Button size="small" onClick={() => copy(triggerUrl(r.biz_type))}>
                  {t("alerts_copy_trigger")}
                </Button>
              </TableCell>
              <TableCell>{r.name}</TableCell>
              <TableCell>{groupName(r.group_id)}</TableCell>
              <TableCell>
                <Typography variant="body2" color="text.secondary" noWrap sx={{ maxWidth: 180 }}>
                  {r.wecom_webhook || "—"}
                </Typography>
              </TableCell>
              <TableCell>
                <Switch size="small" checked={!!r.enabled} onChange={() => handleToggle(r)} disabled={busy} />
              </TableCell>
              <TableCell align="right">
                <IconButton size="small" color="error" onClick={() => setDeleteId(r.id)} aria-label={t("alerts_delete")}>
                  <DeleteOutlineIcon fontSize="small" />
                </IconButton>
              </TableCell>
            </TableRow>
          ))}
          {routes.length === 0 && (
            <TableRow>
              <TableCell colSpan={6}>
                <Typography color="text.secondary">{t("alerts_empty")}</Typography>
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>

      <Dialog open={createOpen} onClose={() => setCreateOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>{t("alerts_create_title")}</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ mt: 1 }}>
            <TextField
              label={t("alerts_biz_label")}
              helperText={t("alerts_biz_hint")}
              value={bizType}
              onChange={(e) => setBizType(e.target.value)}
              fullWidth
              autoFocus
            />
            <TextField label={t("alerts_name_label")} value={name} onChange={(e) => setName(e.target.value)} fullWidth />
            <FormControl fullWidth>
              <InputLabel id="alert-group-label">{t("alerts_group_label")}</InputLabel>
              <Select
                labelId="alert-group-label"
                label={t("alerts_group_label")}
                value={groupId}
                onChange={(e) => setGroupId(e.target.value)}
              >
                <MenuItem value="">
                  <em>{t("alerts_group_none")}</em>
                </MenuItem>
                {groups.map((g) => (
                  <MenuItem key={g.id} value={g.id}>
                    {g.name}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
            <TextField
              label={t("alerts_wecom_label")}
              helperText={t("alerts_wecom_hint")}
              value={wecom}
              onChange={(e) => setWecom(e.target.value)}
              fullWidth
            />
          </Stack>
        </DialogContent>
        <DialogFooter>
          <Button onClick={() => setCreateOpen(false)}>{t("common_cancel")}</Button>
          <Button
            variant="contained"
            disabled={busy || !bizType.trim() || (!groupId && !wecom.trim())}
            onClick={handleCreate}
          >
            {t("alerts_create")}
          </Button>
        </DialogFooter>
      </Dialog>

      <Dialog open={!!created} onClose={() => setCreated(null)} maxWidth="sm" fullWidth>
        <DialogTitle>{t("alerts_created_title")}</DialogTitle>
        <DialogContent>
          <Typography sx={{ mb: 1 }}>{t("alerts_created_once")}</Typography>
          <Stack spacing={1}>
            <Stack direction="row" spacing={1} alignItems="center">
              <TextField fullWidth size="small" label={t("alerts_trigger_url")} value={created?.trigger_url || ""} InputProps={{ readOnly: true }} />
              <IconButton onClick={() => copy(created?.trigger_url || "")}>
                <ContentCopyIcon />
              </IconButton>
            </Stack>
            <Stack direction="row" spacing={1} alignItems="center">
              <TextField fullWidth size="small" label={t("alerts_token")} value={created?.token || ""} InputProps={{ readOnly: true }} />
              <IconButton onClick={() => copy(created?.token || "")}>
                <ContentCopyIcon />
              </IconButton>
            </Stack>
            <Typography variant="body2" color="text.secondary" sx={{ fontFamily: "monospace", whiteSpace: "pre-wrap" }}>
              {`curl -X POST "${created?.trigger_url || ""}" \\\n  -H "X-Alert-Token: ${created?.token || ""}" \\\n  -H "Content-Type: application/json" \\\n  -d '{"msgtype":"text","text":{"content":"hello"}}'`}
            </Typography>
          </Stack>
        </DialogContent>
        <DialogFooter>
          <Button variant="contained" onClick={() => setCreated(null)}>
            OK
          </Button>
        </DialogFooter>
      </Dialog>

      <Dialog open={!!deleteId} onClose={() => setDeleteId(null)} maxWidth="xs" fullWidth>
        <DialogTitle>{t("alerts_delete_title")}</DialogTitle>
        <DialogContent>
          <Typography>{t("alerts_delete_confirm")}</Typography>
        </DialogContent>
        <DialogFooter>
          <Button onClick={() => setDeleteId(null)}>{t("common_cancel")}</Button>
          <Button color="error" variant="contained" disabled={busy} onClick={handleDelete}>
            {t("alerts_delete")}
          </Button>
        </DialogFooter>
      </Dialog>
    </Box>
  );
};

export default AlertRoutesPage;
