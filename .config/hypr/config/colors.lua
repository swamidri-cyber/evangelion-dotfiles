-- ─────────────────────────────────────────────────────────────────────────────
--  Paleta del rice: Gruvbox cálido, ámbar y dorado sobre negro.
--  Cambiá un color acá y se actualiza en todo Hyprland (bordes, sombras, etc.).
--  Formato: "rgba(RRGGBBAA)" → los últimos 2 dígitos son la opacidad (ff = opaco).
-- ─────────────────────────────────────────────────────────────────────────────

-- Fondos (de más oscuro a más claro)
RICE_BG0    = "rgba(0d0b09ff)"  -- negro cálido, casi puro (fondo general)
RICE_BG1    = "rgba(1d2021ff)"  -- gruvbox bg0_h
RICE_BG2    = "rgba(3c3836ff)"  -- gruvbox bg1 (bordes inactivos)

-- Acentos
RICE_AMBER  = "rgba(fe8019ff)"  -- naranja ámbar (acento principal)
RICE_GOLD   = "rgba(fabd2fff)"  -- dorado
RICE_OCHRE  = "rgba(d79921ff)"  -- dorado oscuro / ocre
RICE_RUST   = "rgba(d65d0eff)"  -- naranja quemado
RICE_RED    = "rgba(fb4934ff)"  -- rojo (alertas)

-- Texto
RICE_FG     = "rgba(ebdbb2ff)"  -- crema (texto principal)
RICE_GRAY   = "rgba(928374ff)"  -- gris cálido (texto secundario)

-- Brillos semitransparentes (para sombras tipo "glow" de fósforo)
RICE_GLOW        = "rgba(fe801955)"  -- ámbar al ~33%
RICE_GLOW_FAINT  = "rgba(00000099)"  -- sombra oscura para ventanas sin foco

-- ── Colores originales de CachyOS ──────────────────────────────────────────
-- Se dejan definidos porque otros archivos todavía los usan; si en el futuro
-- nadie los referencia, se pueden borrar.
CACHYLGREEN = "rgba(82dcccff)"
CACHYMGREEN = "rgba(00aa84ff)"
CACHYDGREEN = "rgba(007d6fff)"
CACHYLBLUE  = "rgba(01ccffff)"
CACHYMBLUE  = "rgba(182545ff)"
CACHYDBLUE  = "rgba(111826ff)"
CACHYWHITE  = "rgba(ffffffff)"
CACHYGREY   = "rgba(ddddddff)"
CACHYGRAY   = "rgba(798bb2ff)"
