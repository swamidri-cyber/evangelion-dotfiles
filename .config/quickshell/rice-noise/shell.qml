// ─────────────────────────────────────────────────────────────────────────────
//  rice-noise — grano de película sobre el FONDO de pantalla, como la captura
//  de inspiración: puntitos claros y finos que solo suman luz, animados.
//
//  Capa "bottom": encima del fondo y DEBAJO de las ventanas (las apps quedan
//  limpias, a pedido). No toma clics. Se anima solo con el escritorio vacío.
//
//  Perillas: STRENGTH, FPS, PIXEL. La textura sale de make-specks.py.
//  Reiniciar:  qs kill -c rice-noise; uwsm app -- qs -c rice-noise
//  (Versiones anteriores: shell.qml.fondo = ruido gris; shell.qml.global = encima de todo)
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: root
    readonly property real strength: 0.40   // opacidad de los puntitos
    readonly property int fps: 12
    readonly property int pixel: 2          // tamaño de cada puntito

    Connections {
        target: Hyprland
        function onRawEvent(ev) { Hyprland.refreshWorkspaces(); }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: panel
            required property var modelData
            screen: modelData
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "rice-noise"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            mask: Region {}

            readonly property var mon: Hyprland.monitorFor(modelData)
            readonly property bool fullscreen: mon?.activeWorkspace?.hasFullscreen ?? false
            // ¿El escritorio visible está vacío? (con ventanas encima no hace falta animar)
            readonly property bool empty: (mon?.activeWorkspace?.toplevels.values.length ?? 1) === 0

            Item {
                anchors.fill: parent
                visible: !panel.fullscreen
                opacity: root.strength
                Image {
                    id: specks
                    width: parent.width + 256 * root.pixel
                    height: parent.height + 256 * root.pixel
                    source: "file://" + Quickshell.shellDir + "/specks.png"
                    fillMode: Image.Tile
                    smooth: true                       // puntitos de borde suave, no cuadrados
                    transform: Scale { xScale: root.pixel; yScale: root.pixel }
                }
            }

            Timer {
                interval: Math.round(1000 / root.fps); running: panel.empty && !panel.fullscreen; repeat: true
                onTriggered: {
                    specks.x = -Math.floor(Math.random() * 256) * root.pixel;
                    specks.y = -Math.floor(Math.random() * 256) * root.pixel;
                }
            }
        }
    }
}
