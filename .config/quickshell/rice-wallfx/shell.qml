// ─────────────────────────────────────────────────────────────────────────────
//  rice-wallfx — el fondo de pantalla con el mismo look que el arranque MAGI:
//  glitch digital a ráfagas (sin tocar exposición ni saturación: a pedido),
//  grano animado y barra de refresco (shader compartido ../rice-fx/crtfx.frag).
//
//  Capa "background", arrancada DESPUÉS de awww (queda encima de él) y debajo
//  de los subtítulos, el ruido y las ventanas. No toma
//  clics. Lee la imagen elegida de ~/.local/state/rice/wallpaper (la escribe
//  wallpaper.sh); con un fondo animado de Wallpaper Engine ("we:…") se esconde.
//  Se anima SOLO con el escritorio vacío: con ventanas encima queda quieto y
//  no gasta. Al cambiar de fondo hace una ráfaga de interferencia.
//
//  Perillas: AMOUNT, BLOOM, EXPO, SAT.
//  Reiniciar:  qs kill -c rice-wallfx; uwsm app -- qs -c rice-wallfx
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: root
    readonly property real amount: 0.6     // distorsión + grano (1 = como el arranque; bajado a pedido)
    readonly property real bloom: 0.0      // halo de lo brillante (0 = colores originales, a pedido)
    readonly property real expo: 1.0       // exposición
    readonly property real sat: 1.0        // saturación (1 = original)

    property string wall: ""
    readonly property bool isImage: wall !== "" && !wall.startsWith("we:")
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/rice/wallpaper"
        watchChanges: true
        onFileChanged: reload()
        printErrors: false
        onLoaded: {
            const w = text().trim();
            if (w === root.wall) return;
            if (root.wall === "") root.wall = w;          // primera vez: directo
            else { root.next = w; burst.restart(); }      // cambio: ráfaga y cambia en el pico
        }
    }
    property string next: ""
    property real glitch: 0
    SequentialAnimation {
        id: burst
        NumberAnimation { target: root; property: "glitch"; to: 1; duration: 250; easing.type: Easing.InQuad }
        ScriptAction { script: root.wall = root.next }
        NumberAnimation { target: root; property: "glitch"; to: 0; duration: 650; easing.type: Easing.OutCubic }
    }

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
            WlrLayershell.layer: WlrLayer.Background   // encima de awww (arranca después), debajo de subtítulos y ruido
            WlrLayershell.namespace: "rice-wallfx"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            mask: Region {}
            visible: root.isImage

            readonly property var mon: Hyprland.monitorFor(modelData)
            readonly property bool fullscreen: mon?.activeWorkspace?.hasFullscreen ?? false
            readonly property bool empty: (mon?.activeWorkspace?.toplevels.values.length ?? 1) === 0
            readonly property bool animate: (empty || burst.running) && !fullscreen

            // Reloj propio: solo avanza mientras se anima (si no, la imagen queda quieta)
            property real time: 0
            FrameAnimation {
                running: panel.animate && panel.visible
                onTriggered: panel.time += frameTime
            }

            Image {
                id: img
                anchors.fill: parent
                source: root.isImage ? "file://" + root.wall : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(panel.width, panel.height)
                asynchronous: true
                cache: false
                visible: false
            }
            ShaderEffectSource {
                id: tex
                sourceItem: img
                mipmap: true
                smooth: true
                visible: false
            }
            ShaderEffect {
                anchors.fill: parent
                visible: img.status === Image.Ready
                property var src: tex
                property real time: panel.time
                property real power: 1
                property real glitch: root.glitch
                property real amount: root.amount
                property real bloomAmt: root.bloom
                property real expo: root.expo
                property real sat: root.sat
                property size res: Qt.size(width, height)
                property real style: 1      // 1 = glitch digital (0 = interferencia VHS, la de antes)
                fragmentShader: "file://" + Quickshell.env("HOME") + "/.config/quickshell/rice-fx/crtfx.frag.qsb"
            }
        }
    }
}
