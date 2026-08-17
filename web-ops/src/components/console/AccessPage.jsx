import * as React from "react";
import { useCallback, useEffect, useMemo, useState } from "react";
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
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from "@mui/material";
import AddIcon from "@mui/icons-material/Add";
import DeleteOutlineIcon from "@mui/icons-material/DeleteOutlineOutlined";
import { useTranslation } from "react-i18next";
import adminApi from "../../app/AdminApi";
import DialogFooter from "../DialogFooter";
import PageHeader from "./PageHeader";

const AccessPage = () => {
  const { t } = useTranslation();
  const [users, setUsers] = useState([]);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [open, setOpen] = useState(false);
  const [username, setUsername] = useState("");
  const [topic, setTopic] = useState("");
  const [permission, setPermission] = useState("read-only");

  const load = useCallback(async () => {
    setError("");
    try {
      const list = await adminApi.listUsers();
      setUsers(list || []);
    } catch (e) {
      setError(e.message || String(e));
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const rows = useMemo(() => {
    const out = [];
    (users || []).forEach((u) => {
      (u.grants || []).forEach((g) => {
        out.push({ username: u.username, topic: g.topic, permission: g.permission });
      });
    });
    return out;
  }, [users]);

  const handleAdd = async () => {
    setBusy(true);
    setError("");
    try {
      await adminApi.allowAccess(username.trim(), topic.trim(), permission);
      setOpen(false);
      setUsername("");
      setTopic("");
      setPermission("read-only");
      await load();
    } catch (e) {
      setError(e.message || String(e));
    } finally {
      setBusy(false);
    }
  };

  const handleDelete = async (row) => {
    setBusy(true);
    setError("");
    try {
      await adminApi.resetAccess(row.username, row.topic);
      await load();
    } catch (e) {
      setError(e.message || String(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Box sx={{ width: "100%", minWidth: 0 }}>
      <PageHeader
        title={t("console_access_title")}
        subtitle={t("console_access_subtitle")}
        actions={
          <Button startIcon={<AddIcon />} variant="contained" onClick={() => setOpen(true)}>
            {t("console_access_add")}
          </Button>
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
            <TableCell>{t("console_access_col_user")}</TableCell>
            <TableCell>{t("console_access_col_topic")}</TableCell>
            <TableCell>{t("console_access_col_perm")}</TableCell>
            <TableCell align="right">{t("alerts_col_actions")}</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {rows.map((row) => (
            <TableRow key={`${row.username}:${row.topic}:${row.permission}`}>
              <TableCell>{row.username}</TableCell>
              <TableCell sx={{ fontFamily: "monospace" }}>{row.topic}</TableCell>
              <TableCell>{row.permission}</TableCell>
              <TableCell align="right">
                <IconButton size="small" color="error" disabled={busy} onClick={() => handleDelete(row)}>
                  <DeleteOutlineIcon fontSize="small" />
                </IconButton>
              </TableCell>
            </TableRow>
          ))}
          {rows.length === 0 && (
            <TableRow>
              <TableCell colSpan={4}>
                <Typography color="text.secondary">{t("console_access_empty")}</Typography>
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>

      <Dialog open={open} onClose={() => setOpen(false)} maxWidth="xs" fullWidth>
        <DialogTitle>{t("console_access_add")}</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ mt: 1 }}>
            <TextField label={t("console_access_col_user")} value={username} onChange={(e) => setUsername(e.target.value)} fullWidth autoFocus />
            <TextField label={t("console_access_col_topic")} value={topic} onChange={(e) => setTopic(e.target.value)} fullWidth />
            <FormControl fullWidth>
              <InputLabel id="acl-perm">{t("console_access_col_perm")}</InputLabel>
              <Select labelId="acl-perm" label={t("console_access_col_perm")} value={permission} onChange={(e) => setPermission(e.target.value)}>
                <MenuItem value="read-only">read-only</MenuItem>
                <MenuItem value="write-only">write-only</MenuItem>
                <MenuItem value="read-write">read-write</MenuItem>
                <MenuItem value="deny-all">deny-all</MenuItem>
              </Select>
            </FormControl>
          </Stack>
        </DialogContent>
        <DialogFooter>
          <Button onClick={() => setOpen(false)}>{t("common_cancel")}</Button>
          <Button variant="contained" disabled={busy || !username.trim() || !topic.trim()} onClick={handleAdd}>
            {t("common_add")}
          </Button>
        </DialogFooter>
      </Dialog>
    </Box>
  );
};

export default AccessPage;
