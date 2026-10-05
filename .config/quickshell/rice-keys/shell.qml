// ─────────────────────────────────────────────────────────────────────────────
//  rice-keys — hoja de atajos del sistema (Super+F1)
//
//  Misma estética que el lanzador (~/.config/quickshell/rice-launcher):
//  panel translúcido con grano, borde dorado → ámbar, brillo, y se prende
//  como un tubo CRT con un rebote distinto cada vez.
//
//  Corre en segundo plano (hypr/config/autostart.lua) y se abre/cierra con:
//      qs -c rice-keys ipc call keys toggle
//  Se cierra también con Esc, con Super+F1 otra vez o haciendo clic.
//
//  La lista de atajos está en Keys.js (al guardar se recarga sola).
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "Keys.js" as KeyList   // (no "Keys": ese nombre ya lo usa QML para el teclado)

ShellRoot {
    id: root

    // ── Ajustes ─────────────────────────────────────────────────────────────
    readonly property real   widthPct:  0.78
    readonly property real   heightPct: 0.62
    readonly property int    padding:   30
    readonly property int    radius:    8
    readonly property int    glow:      18
    readonly property string fontName:  "DepartureMono Nerd Font"
    readonly property real   fontSize:  11

    // Paleta del rice (iguales al lanzador)
    readonly property color cBg:     Qt.rgba(0x1c / 255, 0x12 / 255, 0x0a / 255, 0.55)
    readonly property color cFg:     "#ebdbb2"
    readonly property color cDim:    "#a89984"
    readonly property color cAmber:  "#fe8019"
    readonly property color cGold:   "#fabd2f"
    readonly property color cOchre:  "#d79921"
    readonly property color cMuted:  "#665c54"
    readonly property color cKeyBg:  Qt.rgba(0x0d / 255, 0x0b / 255, 0x09 / 255, 0.75)
    readonly property color cKeyLine:"#504945"
    readonly property color cGlow:   Qt.rgba(0xfe / 255, 0x80 / 255, 0x19 / 255, 0x55 / 255)
    readonly property string home:   Quickshell.env("HOME")

    property bool open:  false
    property bool shown: false

    IpcHandler {
        target: "keys"
        function toggle(): void { root.open ? root.hide() : root.appear() }
    }

    function appear() {
        closeAnim.stop();
        randomizeBounce();
        crtX = 0.02; crtY = 0.006; flash = 1; bt = 0;
        open = true;
        shown = true;
        openAnim.restart();
        keyCatcher.forceActiveFocus();
    }
    function hide() {
        if (!open) return;
        open = false;
        openAnim.stop();
        closeAnim.restart();
    }

    // ── Animación: encendido CRT + rebote irregular (igual que el lanzador) ─
    property real crtX: 1
    property real crtY: 1
    property real flash: 0
    property real bt: 1
    property var  bp: ({ ay: 0, ax: 0, rot: 0, sc: 0, w1: 3, w2: 2, k: 0.4, ph: 0, ph2: 0, decay: 5 })

    function rnd(a, b) { return a + Math.random() * (b - a); }
    function sign()    { return Math.random() < 0.5 ? -1 : 1; }
    function randomizeBounce() {
        bp = {
            ay: rnd(8, 20) * sign(), ax: rnd(0, 8) * sign(), rot: rnd(0, 1.0) * sign(),
            sc: rnd(0, 0.025) * sign(), w1: rnd(2.2, 4.2), w2: rnd(1.35, 2.8), k: rnd(0.15, 0.6),
            ph: rnd(0, Math.PI * 2), ph2: rnd(0, Math.PI * 2), decay: rnd(3.2, 6.0)
        };
        bounceAnim.duration = Math.round(rnd(650, 1050));
    }
    function wob(amp, w, ph) {
        const t = bt, env = Math.exp(-bp.decay * t) * (1 - t);
        return amp * env * (Math.sin(2 * Math.PI * w * t + ph) + bp.k * Math.sin(2 * Math.PI * w * bp.w2 * t + bp.ph2));
    }
    readonly property real bY:   wob(bp.ay,  bp.w1,       0)
    readonly property real bX:   wob(bp.ax,  bp.w1 * 0.7, bp.ph)
    readonly property real bRot: wob(bp.rot, bp.w1 * 1.1, bp.ph2)
    readonly property real bSc:  wob(bp.sc,  bp.w1 * 0.9, bp.ph)

    SequentialAnimation {
        id: openAnim
        NumberAnimation { target: root; property: "crtX"; to: 1; duration: 110; easing.type: Easing.OutCubic }
        ParallelAnimation {
            NumberAnimation { target: root; property: "crtY"; to: 1; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "flash"; to: 0; duration: 320; easing.type: Easing.OutQuad }
            SequentialAnimation {
                PauseAnimation { duration: 50 }
                NumberAnimation { id: bounceAnim; target: root; property: "bt"; from: 0; to: 1; duration: 850 }
            }
        }
    }
    SequentialAnimation {
        id: closeAnim
        ScriptAction { script: root.bt = 1 }
        ParallelAnimation {
            NumberAnimation { target: root; property: "crtY"; to: 0.006; duration: 120; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "flash"; to: 0.9; duration: 100 }
        }
        NumberAnimation { target: root; property: "crtX"; to: 0; duration: 90; easing.type: Easing.InCubic }
        ScriptAction { script: root.shown = false }
    }

    // ── Ventana ─────────────────────────────────────────────────────────────
    PanelWindow {
        id: win
        visible: root.shown
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

        WlrLayershell.namespace: "rice-keys"            // reglas de blur en windowrules.lua
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        readonly property int slack: 34
        implicitWidth:  Math.round(screen.width  * root.widthPct)  + (root.glow + slack) * 2
        implicitHeight: Math.round(screen.height * root.heightPct) + (root.glow + slack) * 2

        // Esc cierra
        Item {
            id: keyCatcher
            focus: true
            Keys.onPressed: event => { if (event.key === Qt.Key_Escape) { root.hide(); event.accepted = true; } }
        }

        Item {
            id: stage
            anchors.fill: parent
            anchors.margins: win.slack
            transform: [
                Scale {
                    origin.x: stage.width / 2; origin.y: stage.height / 2
                    xScale: root.crtX * (1 + root.bSc); yScale: root.crtY * (1 + root.bSc)
                },
                Rotation { origin.x: stage.width / 2; origin.y: stage.height / 2; angle: root.bRot },
                Translate { x: root.bX; y: root.bY }
            ]

            // Brillo ámbar alrededor, recortado para no teñir el interior
            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true; maskInverted: true; maskSource: panelMask
                    maskThresholdMin: 0.5; maskSpreadAtMin: 1.0
                }
                RectangularShadow {
                    anchors.fill: parent; anchors.margins: root.glow
                    radius: root.radius; blur: root.glow; spread: 0; color: root.cGlow
                }
            }
            Item {
                id: panelMask
                anchors.fill: parent; visible: false; layer.enabled: true
                Rectangle { anchors.fill: parent; anchors.margins: root.glow; radius: root.radius; color: "black" }
            }

            Item {
                id: panel
                anchors.fill: parent
                anchors.margins: root.glow

                // Fondo marrón translúcido + grano
                Rectangle { anchors.fill: parent; radius: root.radius; color: root.cBg }
                Item {
                    anchors.fill: parent
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true; maskSource: noiseMask
                        maskThresholdMin: 0.5; maskSpreadAtMin: 1.0
                    }
                    Image {
                        anchors.fill: parent
                        source: "file://" + root.home + "/.config/rice-launcher/noise.png"
                        fillMode: Image.Tile; smooth: false
                    }
                }
                Item {
                    id: noiseMask
                    anchors.fill: parent; visible: false; layer.enabled: true
                    Rectangle { anchors.fill: parent; radius: root.radius; color: "black" }
                }

                // Borde dorado → ámbar
                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const g = ctx.createLinearGradient(0, 0, width, height);
                        g.addColorStop(0, root.cGold); g.addColorStop(1, root.cAmber);
                        ctx.strokeStyle = g; ctx.lineWidth = 1;
                        ctx.roundedRect(0.5, 0.5, width - 1, height - 1, root.radius, root.radius);
                        ctx.stroke();
                    }
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                }

                // Clic en cualquier parte = cerrar
                MouseArea { anchors.fill: parent; onClicked: root.hide() }

                // ── Contenido ──
                Item {
                    id: content
                    anchors.fill: parent
                    anchors.margins: root.padding

                    FontMetrics { id: fm; font.family: root.fontName; font.pointSize: root.fontSize }
                    readonly property real lineH: Math.round(fm.height * 1.25)

                    // Título
                    Row {
                        id: title
                        spacing: 0
                        Text {
                            text: "鍵 ─ ATAJOS DEL SISTEMA"
                            color: root.cGold
                            font.family: root.fontName
                            font.pointSize: root.fontSize + 3
                        }
                    }
                    Text {
                        anchors { right: parent.right; verticalCenter: title.verticalCenter }
                        text: "Super+F1 · Esc para cerrar"
                        color: root.cMuted
                        font.family: root.fontName
                        font.pointSize: root.fontSize
                    }
                    Rectangle {                      // línea bajo el título
                        id: rule
                        anchors { left: parent.left; right: parent.right; top: title.bottom; topMargin: 10 }
                        height: 1
                        color: root.cOchre
                        opacity: 0.35
                    }

                    // Tres columnas de secciones
                    Row {
                        anchors { left: parent.left; right: parent.right; top: rule.bottom; topMargin: 18; bottom: parent.bottom }
                        spacing: 36

                        Repeater {
                            model: 3
                            Column {
                                id: col
                                required property int index
                                width: (parent.width - 2 * 36) / 3
                                spacing: 22

                                Repeater {
                                    model: KeyList.sections.filter(s => s.col === col.index)
                                    Column {
                                        id: sec
                                        required property var modelData
                                        width: col.width
                                        spacing: 2

                                        // Encabezado: kanji + título
                                        Text {
                                            height: content.lineH
                                            verticalAlignment: Text.AlignVCenter
                                            textFormat: Text.RichText
                                            font.family: root.fontName
                                            font.pointSize: root.fontSize
                                            text: '<span style="color:' + root.cAmber + '">' + sec.modelData.kanji + "</span>"
                                                + '&nbsp;<span style="color:' + root.cMuted + '">─</span>&nbsp;'
                                                + '<span style="color:' + root.cOchre + '">' + sec.modelData.title + "</span>"
                                        }

                                        // Filas: teclitas + descripción
                                        Repeater {
                                            model: sec.modelData.rows
                                            Item {
                                                id: row
                                                required property var modelData
                                                width: sec.width
                                                height: content.lineH

                                                Row {
                                                    id: keysRow
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    spacing: 3
                                                    Repeater {
                                                        model: row.modelData[0].split("+")
                                                        Row {
                                                            id: part
                                                            required property string modelData
                                                            required property int index
                                                            spacing: 3
                                                            Text {             // el "+" entre teclas
                                                                visible: part.index > 0
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                text: "+"
                                                                color: root.cMuted
                                                                font.family: root.fontName
                                                                font.pointSize: root.fontSize - 1
                                                            }
                                                            Rectangle {        // la teclita
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                width: keyText.implicitWidth + 10
                                                                height: content.lineH - 4
                                                                radius: 3
                                                                color: root.cKeyBg
                                                                border.width: 1
                                                                border.color: root.cKeyLine
                                                                Text {
                                                                    id: keyText
                                                                    anchors.centerIn: parent
                                                                    text: part.modelData
                                                                    color: root.cGold
                                                                    font.family: root.fontName
                                                                    font.pointSize: root.fontSize - 1
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                                Text {                         // descripción, alineada a la derecha
                                                    anchors { left: keysRow.right; leftMargin: 10; right: parent.right; verticalCenter: parent.verticalCenter }
                                                    horizontalAlignment: Text.AlignRight
                                                    elide: Text.ElideLeft
                                                    text: row.modelData[1]
                                                    color: root.cFg
                                                    font.family: root.fontName
                                                    font.pointSize: root.fontSize
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Destello del encendido
                Rectangle {
                    anchors.fill: parent
                    radius: root.radius
                    color: "#ffd9a0"
                    opacity: root.flash * 0.75
                    visible: opacity > 0
                }
            }
        }
    }
}
