/** Console (工作台) visual tokens — ink / cinnabar / celadon, not generic SaaS. */
export const consoleTokens = {
  ink: "#1c1c1c",
  inkMuted: "#5c5c5c",
  paper: "#f4f6f4",
  panel: "#fcfdfb",
  line: "rgba(28, 28, 28, 0.12)",
  lineStrong: "rgba(28, 28, 28, 0.22)",
  celadon: "#2f6f5e",
  celadonSoft: "rgba(47, 111, 94, 0.1)",
  cinnabar: "#b42318",
  cinnabarSoft: "rgba(180, 35, 24, 0.08)",
  seal: "#9e2a22",
  fontDisplay: '"Noto Serif SC", "Source Han Serif SC", "Songti SC", "STSong", serif',
  fontBody: '"Noto Sans SC", "Source Han Sans SC", "PingFang SC", "Microsoft YaHei", sans-serif',
  latticeBg: `url("data:image/svg+xml,%3Csvg width='48' height='48' viewBox='0 0 48 48' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M0 24h48M24 0v48' stroke='%231c1c1c' stroke-opacity='0.04' fill='none'/%3E%3C/svg%3E")`,
};

export const consoleStyles = {
  fontFamily: consoleTokens.fontBody,
  color: consoleTokens.ink,
  "& .MuiTypography-root": {
    fontFamily: "inherit",
  },
  "& .MuiTypography-h4, & .MuiTypography-h5, & .MuiTypography-h6": {
    fontFamily: consoleTokens.fontDisplay,
    fontWeight: 600,
    letterSpacing: "0.04em",
  },
  "& .MuiButton-containedPrimary": {
    bgcolor: consoleTokens.celadon,
    boxShadow: "none",
    borderRadius: "2px",
    "&:hover": { bgcolor: "#275e50", boxShadow: "none" },
  },
  "& .MuiButton-outlinedPrimary": {
    borderColor: consoleTokens.lineStrong,
    color: consoleTokens.ink,
    borderRadius: "2px",
    "&:hover": { borderColor: consoleTokens.celadon, bgcolor: consoleTokens.celadonSoft },
  },
  "& .MuiTableCell-head": {
    fontFamily: consoleTokens.fontDisplay,
    fontWeight: 600,
    color: consoleTokens.inkMuted,
    borderBottomColor: consoleTokens.lineStrong,
    bgcolor: "rgba(47, 111, 94, 0.04)",
  },
  "& .MuiTableCell-body": {
    borderBottomColor: consoleTokens.line,
  },
  "& .MuiTableRow-hover:hover": {
    bgcolor: consoleTokens.celadonSoft,
  },
  "& .MuiListSubheader-root": {
    fontFamily: consoleTokens.fontDisplay,
    color: consoleTokens.inkMuted,
    fontSize: "0.75rem",
    letterSpacing: "0.12em",
  },
  "& .MuiListItemButton-root.Mui-selected": {
    bgcolor: consoleTokens.celadonSoft,
    borderLeft: `3px solid ${consoleTokens.cinnabar}`,
    "&:hover": { bgcolor: consoleTokens.celadonSoft },
  },
  "& .MuiListItemButton-root:not(.Mui-selected)": {
    borderLeft: "3px solid transparent",
  },
};
