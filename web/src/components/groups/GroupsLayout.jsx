import * as React from "react";
import { useEffect } from "react";
import { Box } from "@mui/material";
import { Navigate, Outlet } from "react-router-dom";
import session from "../../app/Session";
import routes from "../routes";
import hideSplash from "../../app/splash";

/** User-facing groups shell. */
const GroupsLayout = () => {
  useEffect(() => hideSplash(), []);

  if (!session.exists()) {
    return <Navigate to={routes.login} replace />;
  }

  return (
    <Box sx={{ p: { xs: 2, sm: 3 }, maxWidth: 1100, mx: "auto", width: "100%" }}>
      <Outlet />
    </Box>
  );
};

export default GroupsLayout;
