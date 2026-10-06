# Modo consola — cosas que tenés que hacer vos (necesitan contraseña o estar en Windows)

Se van sumando a medida que avanza el trabajo. Claude te las recuerda al final.

## 1. Steam: que no se robe el botón Xbox (cuando puedas, sin apuro)
Steam → Configuración → Control → desactivar **"El botón Guía enfoca Steam"**
(en inglés: *Guide Button Focuses Steam*). Si no, al apretar el botón Xbox se abre
Steam en vez del modo consola.

## 2. Ayudante para reiniciar en Windows (en Linux, una vez)
```
sudo bash ~/.config/rice-console/system/install.sh
```
Instala `/usr/local/bin/rice-to-windows` y una regla de sudo que permite correr
**solo ese archivo** sin contraseña (copia el pedido al buzón de Windows,
marca "próximo arranque: Windows" y reinicia; nada más).

## 3. Instalador del agente de Windows — HECHO (windows/install.ps1)
`~/.config/rice-console/windows/agent.ps1` ya está escrito (lee el pedido de
Linux, abre el juego, espera que lo cierres y pregunta VOLVER A LINUX /
QUEDARME). Falta el instalador que lo registra como **tarea programada que
corre al iniciar sesión con permisos de administrador** (los necesita para
leer el buzón en la partición EFI). El sistema de permisos frenó que Claude lo
escriba solo: decidí vos si querés que lo haga.

## 4. En Windows, una vez (cuando esté el instalador)
1. Llevar la carpeta `~/.config/rice-console/windows/` a Windows (pendrive o
   GitHub) y correr el instalador en PowerShell **como administrador**.
2. Inicio de sesión automático: instalar *Autologon* de Sysinternals
   (`winget install Microsoft.Sysinternals.Autologon`), abrirlo y poner tu
   usuario y contraseña. La guarda cifrada; no la escribas en ningún archivo.
3. Emparejar el control de Xbox por Bluetooth en Windows. Después, de vuelta en
   Linux, Claude copia la llave de Windows a Linux para que ande en los dos.

## 5. Opcionales
- **Atajo definitivo** del modo consola (ahora es Super+G, provisorio).
- **Portadas que faltan** (Roblox, Fortnite, Migurinth): crear una clave gratis
  en https://www.steamgriddb.com/profile/preferences/api y guardarla en
  `~/.config/rice-console/steamgriddb.key`. Después: `python3 ~/.config/rice-console/scan/covers.py`
- **Actualizar la biblioteca** con datos nuevos de Windows: montar Windows
  (comando de antes, ver más abajo) y correr `python3 ~/.config/rice-console/scan/scan.py && python3 ~/.config/rice-console/scan/covers.py`.
  ```
  sudo cryptsetup open --type bitlk --readonly /dev/nvme0n1p3 windows && sudo mount -t ntfs3 -o ro,uid=1000,gid=1000 /dev/mapper/windows /mnt/windows
  ```

## 6. Sonido al escribir (todo el sistema)
```
sudo usermod -aG input swami
```
Después cerrar sesión y volver a entrar. Volumen: "typing" en ~/.config/rice-sound/settings.json.
