// Applies the saved theme and display preferences before the app renders to
// avoid a flash of the wrong look. Kept as an external file so the Content
// Security Policy can stay `script-src 'self'` (no inline scripts).
(function () {
  try {
    var root = document.documentElement;
    var pref = window.localStorage.getItem('montra.theme');
    if (pref === 'light' || pref === 'dark') {
      root.setAttribute('data-theme', pref);
    }
    // The signed-in account's display settings (written by the app):
    // "motion=reduce;contrast=high;scale=125".
    var display = (window.localStorage.getItem('montra.display') || '').split(';');
    for (var i = 0; i < display.length; i++) {
      var pair = display[i].split('=');
      if (pair[0] === 'motion' && pair[1] === 'reduce') root.setAttribute('data-motion', 'reduce');
      if (pair[0] === 'contrast' && pair[1] === 'high') root.setAttribute('data-contrast', 'high');
      if (pair[0] === 'scale' && /^\d{2,3}$/.test(pair[1] || '')) {
        var scale = Math.min(Math.max(Number(pair[1]), 80), 200);
        if (scale !== 100) root.style.fontSize = scale + '%';
      }
    }
  } catch {
    // Storage can be unavailable (private mode, blocked site data): follow the system defaults.
  }
})();
