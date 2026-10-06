// ─────────────────────────────────────────────────────────────────────────────
//  rice-off — apagado de tubo CRT antes de apagar / reiniciar / salir.
//
//  1. Saca una foto de la pantalla (ya con el efecto CRT) y la muestra encima
//     de todo; pide a Hyprland pausar el shader para no aplicarlo dos veces.
//  2. La imagen se aplasta en una línea que se pone blanca, la línea se
//     encoge a un punto y el punto se apaga, como un televisor viejo.
//  3. Corre el comando (RICE_OFF_CMD). Si el comando falla, devuelve la
//     pantalla como estaba (el shader vuelve y la capa desaparece).
//
//  Uso (desde scripts/crt-off.sh):  RICE_OFF_CMD="systemctl poweroff" qs -c rice-off
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root
    readonly property string cmd: Quickshell.env("RICE_OFF_CMD") || ""

    property real squashY: 1      // alto de la imagen (1 → línea)
    property real squashX: 1      // ancho (1 → punto)
    property real white: 0        // cuánto se "quema" a blanco
    property real dot: 0          // brillo del punto final
    property bool started: false

    SequentialAnimation {
        id: anim
        // aplastar a una línea mientras se pone blanca
        ParallelAnimation {
            NumberAnimation { target: root; property: "squashY"; to: 0.006; duration: 300; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "white"; to: 1; duration: 300; easing.type: Easing.InQuad }
        }
        // la línea se encoge a un punto
        ParallelAnimation {
            NumberAnimation { target: root; property: "squashX"; to: 0.004; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "dot"; to: 1; duration: 160 }
        }
        // el punto se apaga despacio
        NumberAnimation { target: root; property: "dot"; to: 0; duration: 650; easing.type: Easing.OutQuad }
        PauseAnimation { duration: 250 }
        ScriptAction { script: root.run() }
    }

    Sfx { id: sfx; names: ["off"] }

    function run() {
        if (cmd === "") { restore(); return; }
        proc.running = true;
    }
    function restore() {
        Quickshell.execDetached(["hyprctl", "dispatch", "riceShaderHold(false)"]);
        Qt.quit();
    }
    // Si el comando vuelve (falló, o era "salir" y algo lo frenó), devolver todo
    Process {
        id: proc
        command: ["sh", "-c", root.cmd]
        onExited: (code) => { if (code !== 0) root.restore(); else quitLater.start(); }
    }
    Timer { id: quitLater; interval: 8000; onTriggered: root.restore() }
    Timer { interval: 15000; running: true; onTriggered: if (!proc.running) root.restore() }   // por las dudas

    PanelWindow {
        id: win
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "rice-off"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive   // que nada reciba teclas mientras se apaga
        color: "black"

        Item {
            anchors.fill: parent
            MouseArea { anchors.fill: parent; cursorShape: Qt.BlankCursor }

            // La foto de la pantalla, aplastándose
            Item {
                id: tube
                anchors.centerIn: parent
                width: parent.width; height: parent.height
                transform: Scale {
                    origin.x: tube.width / 2; origin.y: tube.height / 2
                    xScale: root.squashX; yScale: root.squashY
                }
                ScreencopyView {
                    id: shot
                    anchors.fill: parent
                    captureSource: win.screen
                    live: false
                    onHasContentChanged: if (hasContent && !root.started) {
                        root.started = true;
                        Quickshell.execDetached(["hyprctl", "dispatch", "riceShaderHold(true)"]);
                        sfx.play("off");
                        anim.start();
                    }
                }
                Rectangle { anchors.fill: parent; color: "#fff6e6"; opacity: root.white * 0.85 }
            }

            // Punto final con resplandor
            Rectangle {
                anchors.centerIn: parent
                width: 90; height: 90; radius: 45
                opacity: root.dot
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 0.9, 0.75, 0.55) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 8 + 10 * root.dot; height: width; radius: width / 2
                color: "#ffffff"
                opacity: root.dot
            }
        }
    }

    // Si la foto no llega (raro), arrancar igual
    Timer { interval: 700; running: true; onTriggered: if (!root.started) { root.started = true; anim.start(); } }
}
