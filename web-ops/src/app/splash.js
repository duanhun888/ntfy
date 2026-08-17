const hideSplash = () => {
  const el = document.getElementById("splash");
  if (!el) return;
  el.classList.add("splash-hidden");
  setTimeout(() => el.remove(), 200);
};

export default hideSplash;
