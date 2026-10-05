// ─────────────────────────────────────────────────────────────────────────────
//  Zen — ajustes del rice retro (Gruvbox ámbar). Zen lee este archivo al
//  arrancar y pisa lo que diga la configuración. Para deshacer: borrá este
//  archivo y la carpeta chrome/userChrome.css + userContent.css.
// ─────────────────────────────────────────────────────────────────────────────
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true); // usar chrome/userChrome.css
user_pref("zen.theme.accent-color", "#fe8019");          // acento ámbar, como el resto del sistema
user_pref("zen.theme.border-radius", 8);                 // mismo redondeo que las ventanas de Hyprland
user_pref("zen.widget.linux.transparency", true);        // fondo transparente → blur de Hyprland detrás
user_pref("ui.systemUsesDarkTheme", 1);                  // interfaz oscura
user_pref("layout.css.prefers-color-scheme.content-override", 0); // pedirle a las páginas su versión oscura
user_pref("browser.display.use_system_colors", false);

// Ruedita del mouse (clic del medio) en una página = desplazamiento automático
// como en Windows: aparece el ícono de flechas y la página sube/baja según
// hacia dónde muevas el mouse. En campos de texto el clic del medio sigue pegando.
user_pref("general.autoScroll", true);
