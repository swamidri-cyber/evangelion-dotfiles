// ─────────────────────────────────────────────────────────────────────────────
//  Keys.js — la lista de atajos que muestra la hoja (Super+F1).
//  Es solo texto para mostrar: los atajos de verdad están en
//  ~/.config/hypr/config/binds.lua (y shader.lua). Si cambiás uno allá,
//  actualizalo acá. Al guardar, la hoja se recarga sola.
//
//  Formato: cada sección tiene kanji, título y filas [teclas, descripción].
//  Las teclas se separan con "+"; cada parte se dibuja como una teclita.
//  "col" = en qué columna va la sección (0, 1 o 2).
// ─────────────────────────────────────────────────────────────────────────────
.pragma library

var sections = [
    { col: 0, kanji: "起動", title: "ABRIR APPS", rows: [
        ["Super+Espacio",    "Lanzador de apps"],
        ["Super+Enter",      "Terminal (kitty)"],
        ["Super+W",          "Navegador (Zen)"],
        ["Super+E",          "Archivos (Dolphin)"],
        ["Super+T",          "Editor de texto"],
        ["Super+C",          "Calculadora"],
        ["Ctrl+Shift+Esc",   "Monitor del sistema (btop)"],
        ["Super+Z",          "Ajustes de tema GTK"],
    ]},
    { col: 0, kanji: "道具", title: "HERRAMIENTAS", rows: [
        ["Super+Shift+S",    "Menú de capturas (lazo, ventana…)"],
        ["Super+Shift+D",    "Grabar pantalla (MIC en la barra)"],
        ["Impr",             "Captura de un recorte"],
        ["Super+Impr",       "Captura de pantalla completa"],
        ["Super+P",          "Selector de color (copia el código)"],
        ["Super+V",          "Historial del portapapeles"],
        ["Super+A",          "Notificaciones"],
        ["Super+Shift+W",    "Cambiar fondo de pantalla"],
        ["Super+Menos / Más", "Lupa: alejar / acercar"],
        ["Ctrl+Alt+Q",       "Escribir @"],
    ]},
    { col: 1, kanji: "窓", title: "VENTANAS", rows: [
        ["Super+Q",            "Cerrar ventana"],
        ["Super+F",            "Pantalla completa"],
        ["Super+D",            "Maximizar (con barra)"],
        ["Super+Alt+Espacio",  "Flotante / en mosaico"],
        ["Super+J",            "Girar la división"],
        ["Super+Ctrl+Flechas", "Mover el foco"],
        ["Super+Shift+Flechas","Mover la ventana"],
        ["Alt+Tab",            "Siguiente ventana"],
        ["Super+Clic izq",     "Arrastrar ventana"],
        ["Super+Clic der",     "Cambiar tamaño"],
        ["Super+Esc",          "Forzar cierre (clic en la ventana)"],
    ]},
    { col: 1, kanji: "効果", title: "EFECTO CRT", rows: [
        ["Super+F12",          "Prender / apagar el efecto"],
        ["Super+F11",          "Prender / apagar la curvatura"],
    ]},
    { col: 2, kanji: "移動", title: "ESCRITORIOS", rows: [
        ["Super+1…6",          "Ir al escritorio"],
        ["Super+← / →",        "Escritorio anterior / siguiente"],
        ["Super+↓",            "Ir a un escritorio vacío"],
        ["Super+Rueda",        "Recorrer escritorios"],
        ["Super+Ctrl+Shift+1…6", "Llevar ventana e ir"],
        ["Super+Shift+Alt+1…6",  "Mandar ventana sin ir"],
        ["Super+Ctrl+Shift+← / →", "Ventana al de al lado"],
        ["Super+S",            "Mostrar / ocultar el cajón"],
        ["Super+Alt+S",        "Guardar la ventana en el cajón"],
    ]},
    { col: 2, kanji: "系統", title: "SISTEMA", rows: [
        ["Super+F1",           "Esta hoja de atajos"],
        ["Super+L",            "Bloquear pantalla"],
        ["Super+Alt+C",        "Apagar / reiniciar / salir"],
        ["Teclas de volumen",  "Volumen ±5 · silenciar"],
        ["Teclas multimedia",  "Play/pausa · pistas"],
    ]},
];
