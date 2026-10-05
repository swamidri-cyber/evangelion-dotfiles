// ─────────────────────────────────────────────────────────────────────────────
//  rice-static — estática de computadora vieja en el brillo naranja que rodea
//  a la ventana activa (la sombra ámbar de Hyprland, decorations.lua).
//
//  Una capa transparente encima de todo dibuja cuatro franjas de grano animado
//  pegadas al borde de la ventana activa; cada franja se desvanece hacia afuera
//  como el brillo. No toma clics ni teclado. Se esconde en pantalla completa,
//  en escritorios vacíos y mientras no hay ventana activa.
//
//  Perillas: BAND (ancho, = range de la sombra), FPS, STRENGTH (opacidad).
//  Corre en segundo plano (autostart.lua). Reiniciar:
//    qs kill -c rice-static; uwsm app -- qs -c rice-static
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: root
    readonly property int band: 9           // ancho de la franja (px): entra en el hueco entre ventanas (12)
    readonly property int fps: 12           // cuadros por segundo de la estática
    readonly property real strength: 0.75   // opacidad general
    // Interferencias tipo tracking de VHS: cada tanto una perturbación toma
    // 1–3 franjas finas de la ventana activa y las corre de costado con una
    // ondulación suave mientras se deslizan juntas. Solo gasta mientras dura.
    readonly property int glitchMinMs: 5000   // pausa mínima entre perturbaciones
    readonly property int glitchMaxMs: 14000  // pausa máxima
    readonly property real glitchShift: 7     // desplazamiento lateral máximo (px)
    // Ruido blanco animado (igual que el del fondo, rice-noise) encima de las
    // apps del sistema. Clases de ventana (regex); las demás quedan limpias.
    readonly property real appNoise: 0.12    // grano muy suave dentro de las apps del sistema (el fondo usa 0.40)
    readonly property string noiseSrc: "file://" + Quickshell.env("HOME") + "/.config/quickshell/rice-noise/specks-apps.png"   // puntitos del fondo, más espaciados (4% vs 9%)
    readonly property var systemApps: /^(kitty|Alacritty|rice-float|rice-launcher|org\.kde\..*|org\.gnome\..*|org\.pulseaudio\.pavucontrol|com\.github\.wwmm\.easyeffects|com\.interversehq\.qView|nwg-look|qt[56]ct|kvantummanager|blueman-.*|nm-.*|dev\.lemmy\.swash|.*cachyos.*|org\.cachyos\..*|btop)$/
    readonly property string grainSrc: "file://" + Quickshell.shellDir + "/grain.png"

    // Super+F12 (shader.lua) apaga/prende el ruido de las apps junto con el CRT:
    //   qs -c rice-static ipc call static setNoise false
    // Al arrancar lee el último estado de $XDG_RUNTIME_DIR/rice-crt-state.
    property bool noiseOn: true
    IpcHandler {
        target: "static"
        function setNoise(on: bool): void { root.noiseOn = on }
    }
    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/rice-crt-state"
        onLoaded: root.noiseOn = text().trim() !== "off"
    }

    // Datos de la ventana activa (Hyprland IPC)
    readonly property var win: Hyprland.activeToplevel?.lastIpcObject ?? null
    readonly property bool active: {
        const w = win;
        if (!w || !w.at || !w.size || w.fullscreen > 0 || w.hidden) return false;
        const ws = Hyprland.focusedMonitor?.activeWorkspace;
        return ws !== null && ws !== undefined && w.workspace && w.workspace.id === ws.id;
    }

    // La geometría cambia sin evento propio (arrastrar, animaciones): se
    // refresca con cada evento de Hyprland y, mientras se ve, cada 250 ms.
    Connections {
        target: Hyprland
        function onRawEvent(ev) { Hyprland.refreshToplevels(); }
    }
    Timer { interval: 250; running: true; repeat: true; onTriggered: Hyprland.refreshToplevels() }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: panel
            required property var modelData
            screen: modelData
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "rice-static"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            mask: Region {}

            // Rectángulo de la ventana en coordenadas de este monitor
            readonly property bool here: root.active && root.win.monitor === Hyprland.monitorFor(modelData)?.id
            readonly property real wx: here ? root.win.at[0] - modelData.x : 0
            readonly property real wy: here ? root.win.at[1] - modelData.y : 0
            readonly property real ww: here ? root.win.size[0] : 0
            readonly property real wh: here ? root.win.size[1] : 0

            property int tick: 0
            Timer {
                interval: Math.round(1000 / root.fps); running: panel.here; repeat: true
                onTriggered: panel.tick++
            }

            // ── Perturbación (estado compartido por sus franjas) ──
            property bool glitching: false
            property real gT: 0            // 0..1 a lo largo de la perturbación
            property real gDur: 800        // ms
            property real gY: 0            // altura base (fracción de la ventana)
            property real gDrift: 0        // cuánto se desliza en total (fracción)
            property real gFreq: 8         // ondulaciones por segundo
            property real gDir: 1          // hacia qué lado empuja
            property int gBands: 1
            property var gOff: [0, 0, 0]   // separación vertical de cada franja (px)
            property var gH: [8, 8, 8]     // alto de cada franja (px)

            function startGlitch() {
                if (!panel.here || panel.wh < 60) return;
                gDur = 500 + Math.random() * 800;
                gY = 0.05 + Math.random() * 0.85;
                gDrift = (Math.random() < 0.5 ? -1 : 1) * (0.02 + Math.random() * 0.08);
                gFreq = 5 + Math.random() * 6;
                gDir = Math.random() < 0.5 ? -1 : 1;
                gBands = 1 + Math.floor(Math.random() * Math.random() * 3.2);   // casi siempre 1, a veces 2–3
                gOff = [0, 9 + Math.random() * 20, 26 + Math.random() * 30];
                gH = [3 + Math.random() * 14, 2 + Math.random() * 8, 2 + Math.random() * 5];
                gT = 0;
                glitching = true;
            }
            Timer {
                id: scheduler
                running: panel.here
                interval: root.glitchMinMs + Math.random() * (root.glitchMaxMs - root.glitchMinMs)
                onTriggered: {
                    panel.startGlitch();
                    interval = root.glitchMinMs + Math.random() * (root.glitchMaxMs - root.glitchMinMs);
                    restart();
                }
            }
            FrameAnimation {
                running: panel.glitching
                onTriggered: {
                    panel.gT += frameTime * 1000 / panel.gDur;
                    if (panel.gT >= 1) { panel.gT = 1; panel.glitching = false; }
                }
            }

            Item {
                anchors.fill: parent
                visible: panel.here

                // Una franja: grano tileado, recortado, con degradé hacia afuera
                component Strip: Item {
                    id: strip
                    property bool vertical: false
                    property bool outerFirst: true   // el lado de afuera es el inicio del degradé
                    clip: true
                    opacity: root.strength           // (solo el grano; las franjas van al 100%)
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: fade
                        maskThresholdMin: 0.0
                        maskSpreadAtMin: 0.0
                    }
                    Image {
                        source: root.grainSrc
                        fillMode: Image.Tile
                        smooth: false
                        width: strip.width + 256; height: strip.height + 256
                        // cada cuadro, otra posición del grano = estática que se mueve
                        x: -((panel.tick * 97 + strip.x * 3) % 256)
                        y: -((panel.tick * 61 + strip.y * 7) % 256)
                    }
                    Rectangle {
                        id: fade
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        gradient: Gradient {
                            orientation: strip.vertical ? Gradient.Horizontal : Gradient.Vertical
                            GradientStop { position: 0.0; color: strip.outerFirst ? "#00000000" : "#ff000000" }
                            GradientStop { position: 0.55; color: "#66000000" }
                            GradientStop { position: 1.0; color: strip.outerFirst ? "#ff000000" : "#00000000" }
                        }
                    }
                }

                Strip {   // arriba
                    x: panel.wx; y: panel.wy - root.band - 1
                    width: panel.ww; height: root.band
                    outerFirst: true
                }
                Strip {   // abajo
                    x: panel.wx; y: panel.wy + panel.wh + 1
                    width: panel.ww; height: root.band
                    outerFirst: false
                }
                Strip {   // izquierda (con esquinas)
                    vertical: true
                    x: panel.wx - root.band - 1; y: panel.wy - root.band
                    width: root.band; height: panel.wh + root.band * 2
                    outerFirst: true
                }
                Strip {   // derecha (con esquinas)
                    vertical: true
                    x: panel.wx + panel.ww + 1; y: panel.wy - root.band
                    width: root.band; height: panel.wh + root.band * 2
                    outerFirst: false
                }

                // Ruido sobre cada app del sistema visible en este monitor
                Repeater {
                    model: (root.appNoise <= 0 || !root.noiseOn) ? [] : Hyprland.toplevels.values.filter(t => {
                        const o = t.lastIpcObject;
                        return o && o.at && o.size && root.systemApps.test(o.class || "")
                            && !o.hidden && o.fullscreen === 0 && o.workspace
                            && o.monitor === Hyprland.monitorFor(panel.modelData)?.id
                            && o.workspace.id === Hyprland.monitorFor(panel.modelData)?.activeWorkspace?.id;
                    })
                    Item {
                        required property var modelData
                        readonly property var o: modelData.lastIpcObject
                        x: o.at[0] - panel.modelData.x; y: o.at[1] - panel.modelData.y
                        width: o.size[0]; height: o.size[1]
                        clip: true
                        opacity: root.appNoise
                        Image {
                            width: parent.width + 512; height: parent.height + 512
                            source: root.noiseSrc
                            fillMode: Image.Tile
                            smooth: true                 // escalado suave: sin bordes filosos
                            transform: Scale { xScale: 2; yScale: 2 }
                            // cambia cada 2 cuadros (6 por segundo): más calmo
                            x: -((Math.floor(panel.tick / 2) * 173 + parent.x) % 256) * 2
                            y: -((Math.floor(panel.tick / 2) * 89 + parent.y) % 256) * 2
                        }
                    }
                }

                // Franjas desplazadas: copia en vivo de la ventana (solo durante
                // la perturbación), recortada a una franja y corrida de costado
                Repeater {
                    model: 3
                    Item {
                        id: gb
                        required property int index
                        readonly property real env: Math.sin(Math.PI * panel.gT)       // entra y sale suave
                        readonly property real wob: Math.sin(panel.gT * panel.gDur / 1000 * panel.gFreq * 6.2832 + index * 1.3)
                        readonly property real bandY: (panel.gY + panel.gDrift * panel.gT) * panel.wh + panel.gOff[index]
                        visible: panel.glitching && index < panel.gBands
                        x: panel.wx + panel.gDir * root.glitchShift * env * (0.55 + 0.45 * wob) * (index === 0 ? 1 : 0.6)
                        y: panel.wy + Math.max(0, Math.min(bandY, panel.wh - height))
                        width: panel.ww
                        height: panel.gH[index]
                        clip: true
                        ScreencopyView {
                            x: 0
                            y: -(gb.y - panel.wy)
                            width: panel.ww; height: panel.wh
                            captureSource: gb.visible ? (Hyprland.activeToplevel?.wayland ?? null) : null
                            live: true
                        }
                        // tinte ámbar leve y filo brillante arriba de la franja
                        Rectangle { anchors.fill: parent; color: "#fe8019"; opacity: 0.07 * gb.env }
                        Rectangle { width: parent.width; height: 1; color: "#fabd2f"; opacity: 0.35 * gb.env }
                    }
                }
            }
        }
    }
}
