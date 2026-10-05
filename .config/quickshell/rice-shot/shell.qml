// ─────────────────────────────────────────────────────────────────────────────
//  rice-shot — menú de capturas de pantalla (Super+Shift+S)
//
//  Un menú chico a la izquierda, con la estética del lanzador:
//    1 · 範囲 Rectángulo: de una punta a la otra
//    2 · 全画面 Pantalla completa
//    3 · 投縄 Lazo: dibujás la forma con el mouse (la pantalla se congela)
//    4 · 窓  Ventana: clic en una ventana
//  Teclas 1–4, ↑↓ + Enter, o clic. Esc cierra.
//  Las capturas las hace capture.sh y terminan en el editor swash.
//
//  Corre en segundo plano (autostart.lua); se abre con:
//      qs -c rice-shot ipc call shot toggle
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: root

    readonly property string fontName: "DepartureMono Nerd Font"
    readonly property real   fontSize: 11
    readonly property int    radius:   8
    readonly property int    glow:     18
    readonly property color cBg:     Qt.rgba(0x1c / 255, 0x12 / 255, 0x0a / 255, 0.55)
    readonly property color cFg:     "#ebdbb2"
    readonly property color cDim:    "#a89984"
    readonly property color cAmber:  "#fe8019"
    readonly property color cGold:   "#fabd2f"
    readonly property color cOchre:  "#d79921"
    readonly property color cMuted:  "#665c54"
    readonly property color cSelBg:  "#3c3836"
    readonly property color cGlow:   Qt.rgba(0xfe / 255, 0x80 / 255, 0x19 / 255, 0x55 / 255)
    readonly property string home:   Quickshell.env("HOME")
    readonly property string script: home + "/.config/quickshell/rice-shot/capture.sh"
    readonly property string frozen: Quickshell.env("XDG_RUNTIME_DIR") + "/rice-shot-frozen.png"

    readonly property var options: [
        { mode: "rect",   kanji: "範囲",   title: "RECTÁNGULO",        desc: "De una punta a la otra" },
        { mode: "full",   kanji: "全画面", title: "PANTALLA COMPLETA", desc: "Toda la pantalla" },
        { mode: "lasso",  kanji: "投縄",   title: "LAZO",              desc: "Dibujá la forma con el mouse" },
        { mode: "window", kanji: "窓",     title: "VENTANA",           desc: "Clic en una ventana" },
    ]

    property bool open:  false
    property bool shown: false
    property int  current: 0

    IpcHandler {
        target: "shot"
        function toggle(): void { root.open ? root.hide() : root.appear() }
    }

    function appear() {
        closeAnim.stop();
        current = 0;
        randomizeBounce();
        crtX = 0.02; crtY = 0.006; flash = 1; bt = 0;
        open = true; shown = true;
        openAnim.restart();
        menuKeys.forceActiveFocus();
    }
    function hide() {
        if (!open) return;
        open = false;
        openAnim.stop();
        closeAnim.restart();
    }

    // Elegir: el menú desaparece al instante (para que no salga en la foto)
    // y la captura arranca un instante después.
    property string pending: ""
    function choose(i) {
        pending = options[i].mode;
        openAnim.stop(); closeAnim.stop();
        open = false; shown = false;
        startTimer.restart();
    }
    Timer {
        id: startTimer
        interval: 180
        onTriggered: {
            if (root.pending === "lasso") freeze.running = true;
            else Quickshell.execDetached([root.script, root.pending]);
        }
    }

    // ── Lazo: congelar la pantalla y mostrarla para dibujar encima ─────────
    Process {
        id: freeze
        command: [root.script, "freeze", root.frozen]
        onExited: (code) => {
            if (code !== 0) return;
            lasso.stamp = Date.now();          // fuerza a recargar la imagen
            lasso.points = [];
            lasso.visible = true;
        }
    }

    PanelWindow {
        id: lasso
        visible: false
        property var  points: []
        property real stamp: 0
        property size shotSize: Qt.size(0, 0)    // tamaño real de la foto congelada
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors { left: true; right: true; top: true; bottom: true }
        WlrLayershell.namespace: "rice-shot-lasso"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore
        color: "black"

        onVisibleChanged: if (visible) lassoKeys.forceActiveFocus()

        Image {
            id: frozenImg
            anchors.fill: parent
            source: lasso.visible ? "file://" + root.frozen + "?" + lasso.stamp : ""
            cache: false
            smooth: true
            onStatusChanged: if (status === Image.Ready) lasso.shotSize = Qt.size(implicitWidth, implicitHeight)
        }
        Rectangle { anchors.fill: parent; color: "#0d0b09"; opacity: 0.45 }   // oscurece lo de afuera

        // La forma que se va dibujando: relleno ámbar tenue + trazo ámbar.
        // Shape la dibuja la GPU (un Canvas a pantalla completa con sombra
        // borrosa redibujado en cada movimiento del mouse iba muy lagueado).
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            visible: lasso.points.length > 1
            ShapePath {
                fillColor: Qt.rgba(254 / 255, 128 / 255, 25 / 255, 0.12)
                strokeColor: root.cAmber
                strokeWidth: 2
                joinStyle: ShapePath.RoundJoin
                PathPolyline { path: lasso.points.length > 1 ? lasso.points.concat([lasso.points[0]]) : [] }
            }
        }

        Text {
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 60 }
            text: "投縄 ─ DIBUJÁ LA ZONA CON EL MOUSE · Esc para cancelar"
            color: root.cGold
            font.family: root.fontName
            font.pointSize: root.fontSize + 1
            style: Text.Outline
            styleColor: "#0d0b09"
        }

        Item {
            id: lassoKeys
            focus: true
            Keys.onPressed: event => { if (event.key === Qt.Key_Escape) { lasso.visible = false; event.accepted = true; } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.CrossCursor
            onPressed: mouse => { lasso.points = [Qt.point(mouse.x, mouse.y)]; }
            onPositionChanged: mouse => {
                const p = lasso.points;
                const last = p[p.length - 1];
                if (!last || Math.abs(last.x - mouse.x) + Math.abs(last.y - mouse.y) >= 4)
                    lasso.points = p.concat([Qt.point(mouse.x, mouse.y)]);
            }
            onReleased: {
                const p = lasso.points;
                // Escala pantalla → píxeles de la foto: se calcula ANTES de ocultar
                // la ventana (al ocultarla la imagen se descarga y mide 0 → foto vacía).
                const w = lasso.shotSize.width  || lasso.width;
                const h = lasso.shotSize.height || lasso.height;
                const sx = w / lasso.width, sy = h / lasso.height;
                lasso.visible = false;
                lasso.points = [];
                if (p.length < 3) return;
                const poly = p.map(q => Math.round(q.x * sx) + "," + Math.round(q.y * sy)).join(" ");
                Quickshell.execDetached([root.script, "lasso", root.frozen, poly]);
            }
        }
    }

    // ── Animación del menú: encendido CRT + rebote (igual que el lanzador) ──
    property real crtX: 1
    property real crtY: 1
    property real flash: 0
    property real bt: 1
    property var  bp: ({ ay: 0, ax: 0, rot: 0, sc: 0, w1: 3, w2: 2, k: 0.4, ph: 0, ph2: 0, decay: 5 })
    function rnd(a, b) { return a + Math.random() * (b - a); }
    function sign()    { return Math.random() < 0.5 ? -1 : 1; }
    function randomizeBounce() {
        bp = {
            ay: rnd(6, 16) * sign(), ax: rnd(0, 7) * sign(), rot: rnd(0, 1.4) * sign(),
            sc: rnd(0, 0.03) * sign(), w1: rnd(2.2, 4.2), w2: rnd(1.35, 2.8), k: rnd(0.15, 0.6),
            ph: rnd(0, Math.PI * 2), ph2: rnd(0, Math.PI * 2), decay: rnd(3.2, 6.0)
        };
        bounceAnim.duration = Math.round(rnd(600, 950));
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
        NumberAnimation { target: root; property: "crtX"; to: 1; duration: 100; easing.type: Easing.OutCubic }
        ParallelAnimation {
            NumberAnimation { target: root; property: "crtY"; to: 1; duration: 150; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "flash"; to: 0; duration: 300; easing.type: Easing.OutQuad }
            SequentialAnimation {
                PauseAnimation { duration: 50 }
                NumberAnimation { id: bounceAnim; target: root; property: "bt"; from: 0; to: 1; duration: 800 }
            }
        }
    }
    SequentialAnimation {
        id: closeAnim
        ScriptAction { script: root.bt = 1 }
        ParallelAnimation {
            NumberAnimation { target: root; property: "crtY"; to: 0.006; duration: 110; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "flash"; to: 0.9; duration: 90 }
        }
        NumberAnimation { target: root; property: "crtX"; to: 0; duration: 80; easing.type: Easing.InCubic }
        ScriptAction { script: root.shown = false }
    }

    // ── Menú (a la izquierda, centrado en vertical) ─────────────────────────
    PanelWindow {
        id: menu
        visible: root.shown
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors.left: true
        margins.left: 14
        WlrLayershell.namespace: "rice-shot"           // blur en windowrules.lua
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        readonly property int slack: 26
        FontMetrics { id: fm; font.family: root.fontName; font.pointSize: root.fontSize }
        readonly property real rowH: Math.round(fm.height * 2.6)
        implicitWidth:  330 + (root.glow + slack) * 2
        implicitHeight: 44 + root.options.length * rowH + 14 + (root.glow + slack) * 2

        Item {
            id: menuKeys
            focus: true
            Keys.onPressed: event => {
                const n = root.options.length;
                if (event.key === Qt.Key_Escape) root.hide();
                else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_4) root.choose(event.key - Qt.Key_1);
                else if (event.key === Qt.Key_Down) root.current = (root.current + 1) % n;
                else if (event.key === Qt.Key_Up)   root.current = (root.current - 1 + n) % n;
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.choose(root.current);
                else return;
                event.accepted = true;
            }
        }

        Item {
            id: stage
            anchors.fill: parent
            anchors.margins: menu.slack
            transform: [
                Scale { origin.x: stage.width / 2; origin.y: stage.height / 2
                        xScale: root.crtX * (1 + root.bSc); yScale: root.crtY * (1 + root.bSc) },
                Rotation { origin.x: stage.width / 2; origin.y: stage.height / 2; angle: root.bRot },
                Translate { x: root.bX; y: root.bY }
            ]

            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect { maskEnabled: true; maskInverted: true; maskSource: pMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                RectangularShadow { anchors.fill: parent; anchors.margins: root.glow; radius: root.radius; blur: root.glow; spread: 0; color: root.cGlow }
            }
            Item {
                id: pMask
                anchors.fill: parent; visible: false; layer.enabled: true
                Rectangle { anchors.fill: parent; anchors.margins: root.glow; radius: root.radius; color: "black" }
            }

            Item {
                id: panel
                anchors.fill: parent
                anchors.margins: root.glow

                Rectangle { anchors.fill: parent; radius: root.radius; color: root.cBg }
                Item {
                    anchors.fill: parent
                    layer.enabled: true
                    layer.effect: MultiEffect { maskEnabled: true; maskSource: nMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                    Image { anchors.fill: parent; source: "file://" + root.home + "/.config/rice-launcher/noise.png"; fillMode: Image.Tile; smooth: false }
                }
                Item {
                    id: nMask
                    anchors.fill: parent; visible: false; layer.enabled: true
                    Rectangle { anchors.fill: parent; radius: root.radius; color: "black" }
                }
                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d"); ctx.reset();
                        const g = ctx.createLinearGradient(0, 0, width, height);
                        g.addColorStop(0, root.cGold); g.addColorStop(1, root.cAmber);
                        ctx.strokeStyle = g; ctx.lineWidth = 1;
                        ctx.roundedRect(0.5, 0.5, width - 1, height - 1, root.radius, root.radius);
                        ctx.stroke();
                    }
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                }

                Column {
                    anchors { fill: parent; margins: 14 }
                    spacing: 0

                    Text {
                        height: 30
                        verticalAlignment: Text.AlignVCenter
                        text: "撮影 ─ CAPTURA"
                        color: root.cGold
                        font.family: root.fontName
                        font.pointSize: root.fontSize + 1
                    }

                    Repeater {
                        model: root.options
                        Rectangle {
                            id: opt
                            required property var modelData
                            required property int index
                            readonly property bool sel: root.current === index
                            width: parent.width
                            height: menu.rowH
                            radius: 4
                            color: sel ? root.cSelBg : "transparent"

                            Rectangle {          // marca ▌ de la seleccionada
                                visible: opt.sel
                                width: 3; radius: 1
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 6 }
                                color: root.cAmber
                            }
                            Rectangle {          // teclita con el número
                                id: num
                                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                                width: 22; height: 22; radius: 3
                                color: "#0d0b09"
                                border.width: 1
                                border.color: opt.sel ? root.cAmber : "#504945"
                                Text {
                                    anchors.centerIn: parent
                                    text: opt.index + 1
                                    color: root.cGold
                                    font.family: root.fontName
                                    font.pointSize: root.fontSize - 1
                                }
                            }
                            Column {
                                anchors { left: num.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                spacing: 2
                                Text {
                                    textFormat: Text.RichText
                                    font.family: root.fontName
                                    font.pointSize: root.fontSize
                                    text: '<span style="color:' + root.cAmber + '">' + opt.modelData.kanji + '</span>&nbsp;'
                                        + '<span style="color:' + (opt.sel ? root.cGold : root.cFg) + '">' + opt.modelData.title + '</span>'
                                }
                                Text {
                                    text: opt.modelData.desc
                                    color: opt.sel ? root.cDim : root.cMuted
                                    font.family: root.fontName
                                    font.pointSize: root.fontSize - 1
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: root.current = opt.index
                                onClicked: root.choose(opt.index)
                            }
                        }
                    }
                }

                Rectangle {              // destello del encendido
                    anchors.fill: parent; radius: root.radius; color: "#ffd9a0"
                    opacity: root.flash * 0.75; visible: opacity > 0
                }
            }
        }
    }
}
