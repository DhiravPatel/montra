// Applies the saved theme preference before the app renders to avoid a
// flash of the wrong theme. Kept as an external file so the Content
// Security Policy can stay `script-src 'self'` (no inline scripts).
(function () {
  try {
    var pref = window.localStorage.getItem('montra.theme');
    if (pref === 'light' || pref === 'dark') {
      document.documentElement.setAttribute('data-theme', pref);
    }
  } catch {
    // Storage can be unavailable (private mode, blocked site data): follow the system theme.
  }
})();
