import * as React from "react";
import { Suspense, useContext, useEffect, useMemo, useState } from "react";
import { Backdrop, Box, CircularProgress, CssBaseline, ThemeProvider, createTheme, useMediaQuery } from "@mui/material";
import { BrowserRouter, Navigate, Outlet, Route, Routes } from "react-router-dom";
import { useTranslation } from "react-i18next";
import initI18n from "../app/i18n";
import session from "../app/Session";
import accountApi, { Role } from "../app/AccountApi";
import hideSplash from "../app/splash";
import { getKebabCaseLangStr } from "../app/utils";
import { lightTheme, darkTheme } from "./theme";
import AccountContext from "./AccountContext";
import ErrorBoundary from "./ErrorBoundary";
import RTLCacheProvider from "./RTLCacheProvider";
import routes from "./routes";
import Login from "./Login";
import ConsoleLayout from "./console/ConsoleLayout";
import OverviewPage from "./console/OverviewPage";
import AccessPage from "./console/AccessPage";
import DeliveriesPage from "./console/DeliveriesPage";
import GroupsPage from "./admin/GroupsPage";
import GroupDetailPage from "./admin/GroupDetailPage";
import AlertRoutesPage from "./admin/AlertRoutesPage";
import UsersPage from "./admin/UsersPage";

initI18n();

const App = () => {
  const { i18n } = useTranslation();
  const languageDir = i18n.dir();
  const [account, setAccount] = useState(null);
  const accountMemo = useMemo(() => ({ account, setAccount }), [account, setAccount]);
  const prefersDarkMode = useMediaQuery("(prefers-color-scheme: dark)");
  const theme = React.useMemo(
    () => createTheme({ ...(prefersDarkMode ? darkTheme : lightTheme), direction: languageDir }),
    [prefersDarkMode, languageDir],
  );

  useEffect(() => {
    document.documentElement.setAttribute("lang", getKebabCaseLangStr(i18n.language));
    document.dir = languageDir;
  }, [i18n.language, languageDir]);

  useEffect(() => {
    const timer = setTimeout(() => hideSplash(), 3000);
    return () => clearTimeout(timer);
  }, []);

  return (
    <Suspense fallback={<Loader />}>
      <RTLCacheProvider>
        <BrowserRouter>
          <ThemeProvider theme={theme}>
            <AccountContext.Provider value={accountMemo}>
              <CssBaseline />
              <ErrorBoundary>
                <Routes>
                  <Route path={routes.login} element={<Login />} />
                  <Route element={<AdminGate />}>
                    <Route path={routes.app} element={<ConsoleLayout />}>
                      <Route index element={<OverviewPage />} />
                      <Route path="groups" element={<GroupsPage />} />
                      <Route path="groups/:id" element={<GroupDetailPage />} />
                      <Route path="alerts" element={<AlertRoutesPage />} />
                      <Route path="users" element={<UsersPage />} />
                      <Route path="access" element={<AccessPage />} />
                      <Route path="deliveries" element={<DeliveriesPage />} />
                    </Route>
                  </Route>
                  <Route path="*" element={<Navigate to={routes.app} replace />} />
                </Routes>
              </ErrorBoundary>
            </AccountContext.Provider>
          </ThemeProvider>
        </BrowserRouter>
      </RTLCacheProvider>
    </Suspense>
  );
};

const AdminGate = () => {
  const { account, setAccount } = useContext(AccountContext);
  const [ready, setReady] = useState(false);
  const [denied, setDenied] = useState(false);

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      if (!session.exists()) {
        if (!cancelled) setReady(true);
        return;
      }
      try {
        const a = await accountApi.get();
        if (cancelled) return;
        if (a?.role !== Role.ADMIN) {
          await session.reset();
          setDenied(true);
          setAccount(null);
        } else {
          setAccount(a);
        }
      } catch {
        if (!cancelled) {
          await session.reset();
          setAccount(null);
        }
      } finally {
        if (!cancelled) setReady(true);
      }
    };
    load();
    return () => {
      cancelled = true;
    };
  }, [setAccount]);

  useEffect(() => hideSplash(), []);

  if (!session.exists()) {
    return <Navigate to={routes.login} replace />;
  }
  if (!ready) {
    return <Loader />;
  }
  if (denied || !account || account.role !== Role.ADMIN) {
    return <Navigate to={routes.login} replace state={{ denied: true }} />;
  }
  return <Outlet />;
};

const Loader = () => (
  <Backdrop open sx={{ zIndex: 100000, bgcolor: "grey.100" }}>
    <CircularProgress color="success" disableShrink />
  </Backdrop>
);

export default App;
