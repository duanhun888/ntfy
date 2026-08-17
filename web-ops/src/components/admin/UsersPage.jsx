import * as React from "react";
import { useCallback, useEffect, useState } from "react";
import {
  Alert,
  Box,
  Button,
  Dialog,
  DialogContent,
  DialogTitle,
  IconButton,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from "@mui/material";
import DeleteOutlineIcon from "@mui/icons-material/DeleteOutlineOutlined";
import AddIcon from "@mui/icons-material/Add";
import { useTranslation } from "react-i18next";
import adminApi from "../../app/AdminApi";
import DialogFooter from "../DialogFooter";
import PageHeader from "../console/PageHeader";

const UsersPage = () => {
  const { t } = useTranslation();
  const [users, setUsers] = useState([]);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [createOpen, setCreateOpen] = useState(false);
  const [passwordOpen, setPasswordOpen] = useState(null);
  const [deleteOpen, setDeleteOpen] = useState(null);
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");

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

  const handleCreate = async () => {
    setBusy(true);
    setError("");
    try {
      await adminApi.createUser(username.trim(), password);
      setCreateOpen(false);
      setUsername("");
      setPassword("");
      await load();
    } catch (e) {
      setError(e.message || String(e));
    } finally {
      setBusy(false);
    }
  };

  const handlePassword = async () => {
    setBusy(true);
    setError("");
    try {
      await adminApi.updateUserPassword(passwordOpen, password);
      setPasswordOpen(null);
      setPassword("");
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
      await adminApi.deleteUser(deleteOpen);
      setDeleteOpen(null);
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
        title={t("admin_users_title")}
        actions={
          <Button startIcon={<AddIcon />} variant="contained" onClick={() => setCreateOpen(true)}>
            {t("admin_users_create")}
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
            <TableCell>{t("admin_users_col_username")}</TableCell>
            <TableCell>{t("admin_users_col_role")}</TableCell>
            <TableCell>{t("admin_users_col_tier")}</TableCell>
            <TableCell align="right">{t("admin_users_col_actions")}</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {users.map((u) => (
            <TableRow key={u.username}>
              <TableCell>{u.username}</TableCell>
              <TableCell>{u.role}</TableCell>
              <TableCell>{u.tier || "—"}</TableCell>
              <TableCell align="right">
                {u.role !== "admin" && (
                  <>
                    <Button size="small" onClick={() => { setPassword(""); setPasswordOpen(u.username); }}>
                      {t("admin_users_password")}
                    </Button>
                    <IconButton size="small" color="error" onClick={() => setDeleteOpen(u.username)} aria-label={t("admin_users_delete")}>
                      <DeleteOutlineIcon fontSize="small" />
                    </IconButton>
                  </>
                )}
              </TableCell>
            </TableRow>
          ))}
          {users.length === 0 && (
            <TableRow>
              <TableCell colSpan={4}>
                <Typography color="text.secondary">{t("admin_users_empty")}</Typography>
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>

      <Dialog open={createOpen} onClose={() => setCreateOpen(false)} maxWidth="xs" fullWidth>
        <DialogTitle>{t("admin_users_create_title")}</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ mt: 1 }}>
            <TextField label={t("admin_users_col_username")} value={username} onChange={(e) => setUsername(e.target.value)} autoFocus fullWidth />
            <TextField label={t("admin_users_password")} type="password" value={password} onChange={(e) => setPassword(e.target.value)} fullWidth />
          </Stack>
        </DialogContent>
        <DialogFooter>
          <Button onClick={() => setCreateOpen(false)}>{t("common_cancel")}</Button>
          <Button variant="contained" disabled={busy || !username.trim() || !password} onClick={handleCreate}>
            {t("admin_users_create")}
          </Button>
        </DialogFooter>
      </Dialog>

      <Dialog open={!!passwordOpen} onClose={() => setPasswordOpen(null)} maxWidth="xs" fullWidth>
        <DialogTitle>{t("admin_users_change_password_title", { username: passwordOpen })}</DialogTitle>
        <DialogContent>
          <TextField
            sx={{ mt: 1 }}
            label={t("admin_users_new_password")}
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            fullWidth
            autoFocus
          />
        </DialogContent>
        <DialogFooter>
          <Button onClick={() => setPasswordOpen(null)}>{t("common_cancel")}</Button>
          <Button variant="contained" disabled={busy || !password} onClick={handlePassword}>
            {t("common_save")}
          </Button>
        </DialogFooter>
      </Dialog>

      <Dialog open={!!deleteOpen} onClose={() => setDeleteOpen(null)} maxWidth="xs" fullWidth>
        <DialogTitle>{t("admin_users_delete_title")}</DialogTitle>
        <DialogContent>
          <Typography>{t("admin_users_delete_confirm", { username: deleteOpen })}</Typography>
        </DialogContent>
        <DialogFooter>
          <Button onClick={() => setDeleteOpen(null)}>{t("common_cancel")}</Button>
          <Button color="error" variant="contained" disabled={busy} onClick={handleDelete}>
            {t("admin_users_delete")}
          </Button>
        </DialogFooter>
      </Dialog>
    </Box>
  );
};

export default UsersPage;
