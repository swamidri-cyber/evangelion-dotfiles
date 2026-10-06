#!/usr/bin/env python3
# Genera el limine.conf con estética MAGI a partir del limine.conf ACTUAL
# (entrada estándar → salida estándar). Mantiene intacto el bloque que maneja
# limine-entry-tool (lo encuentra por "comment: machine-id=") y lo deja dentro
# de la carpeta cerrada "- avanzado -".
import sys
src = sys.stdin.read().split('\n')
if any(l.startswith(('/   LINUX', '/LINUX')) for l in src):
    sys.exit("ya tiene la config del rice: no hago nada")
i0 = next(i for i, l in enumerate(src) if l.startswith('comment: machine-id'))
mid = src[i0].split('=', 1)[1].strip()
i1 = next(i for i in range(i0 + 1, len(src)) if src[i].startswith('/') and not src[i].startswith('//'))  # cabecera del SO
end = next((i for i in range(i1 + 1, len(src)) if src[i].startswith('/') and not src[i].startswith('//')), len(src))
tool = src[i0:end]
tool[i1 - i0] = '/ - avanzado -'
rest = src[end:]
# Windows: se reutiliza la entrada que ya existe (efi_chainload a bootmgfw.efi)
win_img = next(l.strip() for l in src if 'bootmgfw.efi' in l)
cmd = next(l.strip() for l in tool if l.strip().startswith('cmdline:'))
# EFI fallback (si está) va adentro de "avanzado"
extra = []
k = 0
while k < len(rest):
    l = rest[k]
    if l.startswith('/EFI fallback'):
        extra.append('//EFI fallback')
        k += 1
        while k < len(rest) and not rest[k].startswith('/'):
            extra.append(('  ' + rest[k]) if rest[k].strip() else rest[k]); k += 1
        continue
    k += 1
head = f"""# ─────────────────────────────────────────────────────────────────────────────
#  Limine — menú con la estética MAGI del rice (~/.config/rice-limine)
#  Solo dos opciones: LINUX y WINDOWS. Lo demás (kernel LTS, copias de
#  Snapper, arranque de emergencia) queda en "- avanzado -", cerrada.
#  El bloque de "avanzado" lo mantiene limine-entry-tool (lo reconoce por el
#  machine-id): no hace falta tocarlo.
#  Config anterior: /boot/limine.conf.antes-rice
# ─────────────────────────────────────────────────────────────────────────────
timeout: 5
default_entry: 1
remember_last_entry: no
terse: yes

graphics: yes
interface_resolution: 1920x1080
interface_branding:
interface_help_hidden: yes
interface_help_colour: 7c4a1c
interface_help_colour_bright: ffd9a0
wallpaper: boot():/rice-limine.png
wallpaper_style: stretched
term_font: boot():/rice-limine-font.f16
term_font_size: 8x16
term_font_scale: 2x2
term_font_spacing: 0
term_palette: 140a05;ff3020;ffb347;fabd2f;ff8a1c;fe8019;ffd9a0;ffb347
term_palette_bright: 7c4a1c;ff5040;ffd9a0;ffe08a;ffb04a;ffa040;fff0d8;fff4e0
term_background: ff000000
term_foreground: ffb347
term_background_bright: 3a1a08
term_foreground_bright: ffd9a0
term_margin: 64
term_margin_gradient: 0

/LINUX
  comment: ARRANCAR CACHYOS
  protocol: linux
  path: boot():/{mid}/linux-cachyos/vmlinuz
  module_path: boot():/{mid}/linux-cachyos/initramfs
  {cmd}

/WINDOWS
  comment: ARRANCAR WINDOWS
  protocol: efi_chainload
  {win_img}
"""
sys.stdout.write(head + '\n' + '\n'.join(tool).rstrip() + '\n' + '\n'.join(extra).rstrip() + '\n')
