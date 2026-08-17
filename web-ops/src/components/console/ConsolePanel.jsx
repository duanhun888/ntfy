import * as React from "react";
import { Box } from "@mui/material";
import { consoleTokens } from "./consoleTheme";

/** Framed content panel (scroll / window feel). */
const ConsolePanel = ({ children, sx }) => (
  <Box
    sx={{
      bgcolor: consoleTokens.panel,
      border: `1px solid ${consoleTokens.lineStrong}`,
      borderRadius: "2px",
      boxShadow: `inset 0 0 0 1px ${consoleTokens.line}`,
      p: { xs: 2, sm: 2.5 },
      minWidth: 0,
      width: "100%",
      overflow: "auto",
      ...sx,
    }}
  >
    {children}
  </Box>
);

export default ConsolePanel;
