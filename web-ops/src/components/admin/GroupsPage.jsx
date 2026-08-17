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
import { useNavigate, useSearchParams } from "react-router-dom";
import { useTranslation } from "react-i18next";
import adminApi from "../../app/AdminApi";
import DialogFooter from "../DialogFooter";
import routes from "../routes";
import { formatDateTime } from "../../app/utils";
import PageHeader from "../console/PageHeader";

const GroupsPage = () => {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const detailPath = (id) => routes.forGroup(id);
  const [groups, setGroups] = useState([]);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [createOpen, setCreateOpen] = useState(false);
  const [name, setName] = useState("");
  const [deleteOpen, setDeleteOpen] = useState(null);

  const load = useCallback(async () => {
    setError("");
    try {
      const list = await adminApi.listGroups();
      setGroups(list || []);
    } catch (e) {
      setError(e.message || String(e));
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    if (searchParams.get("create") === "1") {
      setCreateOpen(true);
      const next = new URLSearchParams(searchParams);
      next.delete("create");
      setSearchParams(next, { replace: true });
    }
  }, [searchParams, setSearchParams]);

  const handleCreate = async () => {
    setBusy(true);
    setError("");
    try {
      const g = await adminApi.createGroup(name.trim());
      setCreateOpen(false);
      setName("");
      navigate(detailPath(g.id));
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
      await adminApi.deleteGroup(deleteOpen);
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
        title={t("admin_groups_title")}
        actions={
          <Button startIcon={<AddIcon />} variant="contained" onClick={() => setCreateOpen(true)}>
            {t("admin_groups_create")}
          </Button>
        }
      />
      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError("")}>
          {error}
        </Alert>
      )}
      <Table size="small" sx={{ width: "100%", tableLayout: "auto" }}>
        <TableHead>
          <TableRow>
            <TableCell>{t("admin_groups_col_name")}</TableCell>
            <TableCell>{t("admin_groups_col_id")}</TableCell>
            <TableCell>{t("admin_groups_col_members")}</TableCell>
            <TableCell>{t("admin_groups_col_created")}</TableCell>
            <TableCell align="right">{t("admin_groups_col_actions")}</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {groups.map((g) => (
            <TableRow key={g.id} hover sx={{ cursor: "pointer" }} onClick={() => navigate(detailPath(g.id))}>
              <TableCell>{g.name}</TableCell>
              <TableCell>
                <Typography variant="body2" color="text.secondary" sx={{ fontFamily: "monospace" }}>
                  {g.id}
                </Typography>
              </TableCell>
              <TableCell>{g.member_count ?? "—"}</TableCell>
              <TableCell>{g.created ? formatDateTime(g.created) : "—"}</TableCell>
              <TableCell align="right" onClick={(e) => e.stopPropagation()}>
                <IconButton size="small" color="error" onClick={() => setDeleteOpen(g.id)} aria-label={t("admin_groups_delete")}>
                  <DeleteOutlineIcon fontSize="small" />
                </IconButton>
              </TableCell>
            </TableRow>
          ))}
          {groups.length === 0 && (
            <TableRow>
              <TableCell colSpan={5}>
                <Typography color="text.secondary">{t("admin_groups_empty")}</Typography>
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>

      <Dialog open={createOpen} onClose={() => setCreateOpen(false)} maxWidth="xs" fullWidth>
        <DialogTitle>{t("admin_groups_create_title")}</DialogTitle>
        <DialogContent>
          <TextField
            sx={{ mt: 1 }}
            label={t("admin_groups_name_label")}
            value={name}
            onChange={(e) => setName(e.target.value)}
            fullWidth
            autoFocus
          />
        </DialogContent>
        <DialogFooter>
          <Button onClick={() => setCreateOpen(false)}>{t("common_cancel")}</Button>
          <Button variant="contained" disabled={busy || !name.trim()} onClick={handleCreate}>
            {t("admin_groups_create")}
          </Button>
        </DialogFooter>
      </Dialog>

      <Dialog open={!!deleteOpen} onClose={() => setDeleteOpen(null)} maxWidth="xs" fullWidth>
        <DialogTitle>{t("admin_groups_delete_title")}</DialogTitle>
        <DialogContent>
          <Typography>{t("admin_groups_delete_confirm", { id: deleteOpen })}</Typography>
        </DialogContent>
        <DialogFooter>
          <Button onClick={() => setDeleteOpen(null)}>{t("common_cancel")}</Button>
          <Button color="error" variant="contained" disabled={busy} onClick={handleDelete}>
            {t("admin_groups_delete")}
          </Button>
        </DialogFooter>
      </Dialog>
    </Box>
  );
};

export default GroupsPage;
