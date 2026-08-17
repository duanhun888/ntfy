import * as React from "react";
import { Box, Stack, Typography } from "@mui/material";
import { consoleTokens } from "./consoleTheme";

/**
 * Page title + actions. Always wraps; actions never cover the title.
 */
const PageHeader = ({ title, subtitle, actions, sx }) => (
  <Stack
    direction="row"
    flexWrap="wrap"
    useFlexGap
    spacing={1.5}
    alignItems={{ xs: "stretch", sm: "flex-start" }}
    justifyContent="space-between"
    sx={{
      mb: 2.5,
      width: "100%",
      gap: 1.5,
      ...sx,
    }}
  >
    <Box sx={{ flex: "1 1 220px", minWidth: 0, pr: { sm: 1 } }}>
      <Typography
        variant="h5"
        component="h1"
        sx={{
          fontFamily: consoleTokens.fontDisplay,
          fontWeight: 600,
          letterSpacing: "0.06em",
          color: consoleTokens.ink,
          lineHeight: 1.35,
          position: "relative",
          pl: 1.5,
          "&::before": {
            content: '""',
            position: "absolute",
            left: 0,
            top: "0.2em",
            bottom: "0.2em",
            width: 3,
            bgcolor: consoleTokens.cinnabar,
            borderRadius: 1,
          },
        }}
      >
        {title}
      </Typography>
      {subtitle ? (
        <Typography
          variant="body2"
          sx={{
            mt: 0.75,
            pl: 1.5,
            color: consoleTokens.inkMuted,
            lineHeight: 1.6,
            maxWidth: 560,
          }}
        >
          {subtitle}
        </Typography>
      ) : null}
    </Box>
    {actions ? (
      <Box
        sx={{
          flex: "0 0 auto",
          display: "flex",
          flexWrap: "wrap",
          alignItems: "center",
          gap: 1,
          ml: { xs: 1.5, sm: 0 },
        }}
      >
        {actions}
      </Box>
    ) : null}
  </Stack>
);

export default PageHeader;
