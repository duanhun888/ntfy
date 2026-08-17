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
  MenuItem,
  Select,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from "@mui/material";
import ArrowBackIcon from "@mui/icons-material/ArrowBack";
import AddIcon from "@mui/icons-material/Add";
import ContentCopyIcon from "@mui/icons-material/ContentCopy";
import DeleteOutlineIcon from "@mui/icons-material/DeleteOutlineOutlined";
import { useNavigate, useParams } from "react-router-dom";
import { useTranslation } from "react-i18next";
import adminApi from "../../app/AdminApi";
import DialogFooter from "../DialogFooter";
import routes from "../routes";
import { copyToClipboard, formatDateTime } from "../../app/utils";

const GroupDetailPage = () => {
  const { t } = useTranslation();
  const { id } = useParams();
  const navigate = useNavigate();
  const listPath = routes.groups;
  const [group, setGroup] = useState(null);
  const [members, setMembers] = useState([]);
  const [bots, setBots] = useState([]);
  const [error, setError] = useState("");
  const [info, setInfo] = useState("");
  const [busy, setBusy] = useState(false);
  const [memberOpen, setMemberOpen] = useState(false);
  const [botOpen, setBotOpen] = useState(false);
  const [username, setUsername] = useState("");
  const [botName, setBotName] = useState("");
  const [webhookUrl, setWebhookUrl] = useState("");

  const load = useCallback(async () => {
    setError("");
    try {
      const [g, m, b] = await Promise.all([adminApi.getGroup(id), adminApi.listMembers(id), adminApi.listBots(id)]);
      setGroup(g);
      setMembers(m || []);
      setBots(b || []);
    } catch (e) {
      setError(e.message || String(e));
    }
  }, [id]);

  useEffect(() => {
    load();
  }, [load]);

  const handleAddMember = async () => {
    setBusy(true);
    setError("");
    try {
      await adminApi.addMember(id, username.trim());
      setMemberOpen(false);
      setUsername("");
      await load();
    } catch (e) {
      setError(e.message || String(e));
    } finally {
      setBusy(false);
    }
  };

  const handleRemoveMember = async (userKey) => {
    setBusy(true);
    setError("");
    try {
      await adminApi.removeMember(id, userKey);
      await load();
    } catch (e) {
      setError(e.message || String(e));
    } finally {
      setBusy(false);
    }
  };

  const handleChangeRole = async (userKey, role) => {
    setBusy(true);
    setError("");
    try {
      await adminApi.updateMemberRole(id, userKey, role);
      await load();
    } catch (e) {
      setError(e.message || String(e));
    } finally {
      setBusy(false);
    }
  };

  const handleCreateBot = async () => {
    setBusy(true);
    setError("");
    try {
      const bot = await adminApi.createBot(id, botName.trim());
      setBotOpen(false);
      setBotName("");
      setWebhookUrl(bot.webhook_url || "");
      await load();
    } catch (e) {
      setError(e.message || String(e));
    } finally {
      setBusy(false);
    }
  };

  const handleDeleteBot = async (botId) => {
    setBusy(true);
    setError("");
    try {
      await adminApi.deleteBot(id, botId);
      await load();
    } catch (e) {
      setError(e.message || String(e));
    } finally {
      setBusy(false);
    }
  };

  const copyWebhook = async (url) => {
    await copyToClipboard(url);
    setInfo(t("admin_bots_webhook_copied"));
  };

  return (
    <Box>
      <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 2 }}>
        <IconButton onClick={() => navigate(listPath)} aria-label={t("common_back")}>
          <ArrowBackIcon />
        </IconButton>
        <Box>
          <Typography variant="h6">{group?.name || id}</Typography>
          {group && (
            <Typography variant="body2" color="text.secondary" sx={{ fontFamily: "monospace" }}>
              {group.id} · {t("admin_group_topic", { topic: group.topic })}
            </Typography>
          )}
        </Box>
      </Stack>

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
      {webhookUrl && (
        <Alert
          severity="info"
          sx={{ mb: 2 }}
          action={
            <IconButton size="small" onClick={() => copyWebhook(webhookUrl)} aria-label={t("common_copy_to_clipboard")}>
              <ContentCopyIcon fontSize="small" />
            </IconButton>
          }
          onClose={() => setWebhookUrl("")}
        >
          {t("admin_bots_webhook_once")}
          <Typography component="div" sx={{ fontFamily: "monospace", wordBreak: "break-all", mt: 0.5 }}>
            {webhookUrl}
          </Typography>
        </Alert>
      )}

      <Stack
        direction="row"
        flexWrap="wrap"
        useFlexGap
        spacing={1}
        justifyContent="space-between"
        alignItems="center"
        sx={{ mb: 1, mt: 2, width: "100%", gap: 1 }}
      >
        <Typography variant="subtitle1" sx={{ flex: "1 1 auto", minWidth: 0 }}>
          {t("admin_members_title")}
        </Typography>
        <Button size="small" startIcon={<AddIcon />} onClick={() => setMemberOpen(true)} sx={{ flexShrink: 0 }}>
          {t("admin_members_add")}
        </Button>
      </Stack>
      <Table size="small" sx={{ mb: 3 }}>
        <TableHead>
          <TableRow>
            <TableCell>{t("admin_members_col_username")}</TableCell>
            <TableCell>{t("admin_members_col_role")}</TableCell>
            <TableCell>{t("admin_members_col_joined")}</TableCell>
            <TableCell align="right">{t("admin_members_col_actions")}</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {members.map((m) => (
            <TableRow key={m.user_id}>
              <TableCell>{m.username || m.user_id}</TableCell>
              <TableCell>
                {m.role === "owner" ? (
                  m.role
                ) : (
                  <FormControl size="small" sx={{ minWidth: 110 }}>
                    <Select
                      value={m.role === "admin" ? "admin" : "member"}
                      disabled={busy}
                      onChange={(e) => handleChangeRole(m.user_id, e.target.value)}
                    >
                      <MenuItem value="member">{t("console_role_member")}</MenuItem>
                      <MenuItem value="admin">{t("console_role_admin")}</MenuItem>
                    </Select>
                  </FormControl>
                )}
              </TableCell>
              <TableCell>{m.joined ? formatDateTime(m.joined) : "—"}</TableCell>
              <TableCell align="right">
                {m.role !== "owner" && (
                  <IconButton size="small" color="error" disabled={busy} onClick={() => handleRemoveMember(m.user_id)}>
                    <DeleteOutlineIcon fontSize="small" />
                  </IconButton>
                )}
              </TableCell>
            </TableRow>
          ))}
          {members.length === 0 && (
            <TableRow>
              <TableCell colSpan={4}>
                <Typography color="text.secondary">{t("admin_members_empty")}</Typography>
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>

      <Stack
        direction="row"
        flexWrap="wrap"
        useFlexGap
        spacing={1}
        justifyContent="space-between"
        alignItems="center"
        sx={{ mb: 1, width: "100%", gap: 1 }}
      >
        <Typography variant="subtitle1" sx={{ flex: "1 1 auto", minWidth: 0 }}>
          {t("admin_bots_title")}
        </Typography>
        <Button size="small" startIcon={<AddIcon />} onClick={() => setBotOpen(true)} sx={{ flexShrink: 0 }}>
          {t("admin_bots_create")}
        </Button>
      </Stack>
      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>{t("admin_bots_col_name")}</TableCell>
            <TableCell>{t("admin_bots_col_token_hint")}</TableCell>
            <TableCell>{t("admin_bots_col_created")}</TableCell>
            <TableCell align="right">{t("admin_bots_col_actions")}</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {bots.map((b) => (
            <TableRow key={b.id}>
              <TableCell>{b.name}</TableCell>
              <TableCell sx={{ fontFamily: "monospace" }}>{b.token_hint || "—"}</TableCell>
              <TableCell>{b.created ? formatDateTime(b.created) : "—"}</TableCell>
              <TableCell align="right">
                <IconButton size="small" color="error" disabled={busy} onClick={() => handleDeleteBot(b.id)}>
                  <DeleteOutlineIcon fontSize="small" />
                </IconButton>
              </TableCell>
            </TableRow>
          ))}
          {bots.length === 0 && (
            <TableRow>
              <TableCell colSpan={4}>
                <Typography color="text.secondary">{t("admin_bots_empty")}</Typography>
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>

      <Dialog open={memberOpen} onClose={() => setMemberOpen(false)} maxWidth="xs" fullWidth>
        <DialogTitle>{t("admin_members_add_title")}</DialogTitle>
        <DialogContent>
          <TextField
            sx={{ mt: 1 }}
            label={t("admin_members_col_username")}
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            fullWidth
            autoFocus
          />
        </DialogContent>
        <DialogFooter>
          <Button onClick={() => setMemberOpen(false)}>{t("common_cancel")}</Button>
          <Button variant="contained" disabled={busy || !username.trim()} onClick={handleAddMember}>
            {t("common_add")}
          </Button>
        </DialogFooter>
      </Dialog>

      <Dialog open={botOpen} onClose={() => setBotOpen(false)} maxWidth="xs" fullWidth>
        <DialogTitle>{t("admin_bots_create_title")}</DialogTitle>
        <DialogContent>
          <TextField
            sx={{ mt: 1 }}
            label={t("admin_bots_name_label")}
            value={botName}
            onChange={(e) => setBotName(e.target.value)}
            fullWidth
            autoFocus
          />
        </DialogContent>
        <DialogFooter>
          <Button onClick={() => setBotOpen(false)}>{t("common_cancel")}</Button>
          <Button variant="contained" disabled={busy || !botName.trim()} onClick={handleCreateBot}>
            {t("admin_bots_create")}
          </Button>
        </DialogFooter>
      </Dialog>
    </Box>
  );
};

export default GroupDetailPage;
