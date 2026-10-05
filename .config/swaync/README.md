# swaync — notificaciones del rice

- `config.json` → comportamiento (JSON no admite comentarios, por eso van acá)
  - `positionX/Y`: esquina donde aparecen (arriba a la derecha)
  - `control-center-margin-*`: separación del panel lateral respecto de los bordes
  - `timeout`, `timeout-low`, `timeout-critical`: segundos visibles según urgencia (0 = hasta cerrarla)
  - `widgets`: qué muestra el centro de notificaciones, en orden
- `style.css` → colores y bordes (paleta ámbar del rice)

Atajos: **Super+A** o **Super+X** abren/cierran el centro de notificaciones.
Recargar tras editar: `swaync-client -R -rs`
Probar una notificación: `notify-send "Hola" "Esto es una prueba"`
