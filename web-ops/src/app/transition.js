export const fadeNavigate = (navigate, to) => {
  navigate(to);
};

export const fadeOut = () => Promise.resolve();
export const fadeReload = (to) => {
  window.location.href = to || "/";
};
