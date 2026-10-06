// ─────────────────────────────────────────────────────────────────────────────
//  Genera las imágenes del tema de Plymouth "rice-magi" (pantalla de carga de
//  Linux) con el look del arranque MAGI. Se cierra solo.
//    qs -p render-plymouth.qml   → plymouth/rice-magi/*.png
//  bg.png pasa por still.frag (el shader del arranque sin grano); el resto son
//  PNG transparentes en ámbar con brillo, que el script anima encima.
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

ShellRoot {
PanelWindow {
    id: w
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "rice-plymouth-art"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true }
    implicitWidth: 1920; implicitHeight: 1080
    color: "black"

    readonly property string out: Quickshell.shellDir + "/plymouth/rice-magi/"
    readonly property string mono:  "DepartureMono Nerd Font"
    readonly property string serif: "Noto Serif"
    readonly property string jp:    "Noto Sans CJK JP"
    readonly property color amber: "#ff8a1c"
    readonly property color hot:   "#ffd9a0"
    function g(v) { v = Math.max(0, Math.min(1, v)); return Qt.rgba(v, v, v, 1); }
    function rng(n) { let x = (n * 2654435761) >>> 0; x ^= x >>> 15; x = (x * 2246822519) >>> 0; x ^= x >>> 13; return x >>> 0; }
    function hex(n, d) { return (n >>> 0).toString(16).toUpperCase().padStart(d, "0").slice(-d); }

    // Zona de los paneles de código (el script la usa: PANEL_TOP / PANEL_BOTTOM)
    readonly property int panelTop: 184
    readonly property int panelBottom: 900

    // ── Fondo (escena en grises → shader) ────────────────────────────────────
    Item {
        id: scene
        width: 1920; height: 1080
        Repeater {
            model: 13 * 7
            Item {
                required property int index
                x: (index % 13 + 0.5) * 1920 / 13; y: (Math.floor(index / 13) + 0.5) * 1080 / 7
                Rectangle { x: -6; width: 12; height: 1; color: w.g(0.13) }
                Rectangle { y: -6; width: 1; height: 12; color: w.g(0.13) }
            }
        }
        Text { x: 50; y: 34; text: "MAGI SYSTEM  //  起動シーケンス"; font.family: w.mono; font.pixelSize: 24; color: w.g(1) }
        Text { x: 50; y: 70; text: "NERV 本部  ·  CACHYOS  ·  NÚCLEO LINUX"; font.family: w.mono; font.pixelSize: 14; color: w.g(0.45) }
        Text { anchors.right: parent.right; anchors.rightMargin: 50; y: 26; text: "起動"; font.family: w.jp; font.pixelSize: 48; font.weight: Font.Black; color: w.g(1) }
        Rectangle { x: 50; y: 104; width: 1820; height: 2; color: w.g(0.9) }
        Repeater {
            model: 48
            Rectangle { required property int index; x: 50 + index * 1820 / 47; y: 106; width: 1; height: index % 4 === 0 ? 10 : 5; color: w.g(0.5) }
        }
        // Marcos de los paneles laterales (el código lo anima el script)
        Repeater {
            model: 2
            Item {
                required property int index
                x: index === 0 ? 50 : 1540; y: 140; width: 330; height: 780
                Text { x: 12; y: 10; text: index === 0 ? "VOLCADO DE MEMORIA  記憶" : "REGISTRO  記録"; font.family: w.jp; font.pixelSize: 15; font.bold: true; color: w.g(0.85) }
                Rectangle { x: 12; y: 34; width: 306; height: 1; color: w.g(0.4) }
                Repeater {
                    model: 4
                    Item {
                        required property int index
                        readonly property bool rgt: index % 2 === 1
                        readonly property bool bot: index > 1
                        x: rgt ? 330 : 0; y: bot ? 780 : 0
                        Rectangle { x: parent.rgt ? -18 : 0; y: parent.bot ? -2 : 0; width: 18; height: 2; color: w.g(0.8) }
                        Rectangle { x: parent.rgt ? -2 : 0; y: parent.bot ? -18 : 0; width: 2; height: 18; color: w.g(0.8) }
                    }
                }
            }
        }
        // Centro: marco del anillo y barra
        Shape {
            x: 960 - 330; y: 250; width: 660; height: 560
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: w.g(0.85); strokeWidth: 2.5; fillColor: w.g(0.02)
                startX: 0; startY: 0
                PathLine { x: 626; y: 0 }
                PathLine { x: 660; y: 34 }
                PathLine { x: 660; y: 560 }
                PathLine { x: 34; y: 560 }
                PathLine { x: 0; y: 526 }
                PathLine { x: 0; y: 0 }
            }
        }
        Rectangle { x: 960 - 260; y: 700; width: 520; height: 14; color: "transparent"; border.color: w.g(0.7); border.width: 2 }
        Text { x: 960 - 260; y: 726; text: "PROGRESO"; font.family: w.mono; font.pixelSize: 13; color: w.g(0.45) }
        Text { anchors.right: parent.right; anchors.rightMargin: 960 - 260; y: 726; text: "第7世代有機コンピュータ"; font.family: w.jp; font.pixelSize: 13; color: w.g(0.45) }
        // Pie
        Rectangle { x: 50; y: 988; width: 1820; height: 1; color: w.g(0.5) }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter; y: 1008
            text: "第3新東京市  //  NERV 本部  //  MAGI SYSTEM ver 7.2  //  特務機関"
            font.family: w.jp; font.pixelSize: 15; color: w.g(0.5)
        }
    }
    ShaderEffectSource { id: sceneTex; sourceItem: scene; hideSource: true; mipmap: true; smooth: true; visible: false }
    ShaderEffect {
        id: bg
        width: 1920; height: 1080
        property var src: sceneTex
        property real time: 3.1
        property real power: 1
        property real glitch: 0
        property real outp: 0
        property size res: Qt.size(width, height)
        fragmentShader: "file://" + Quickshell.shellDir + "/still.frag.qsb"
    }

    // ── Piezas transparentes (ámbar con brillo) ──────────────────────────────
    component Glow: MultiEffect {
        shadowEnabled: true; shadowColor: w.amber; shadowBlur: 0.6; shadowOpacity: 0.9
        shadowHorizontalOffset: 0; shadowVerticalOffset: 0
        autoPaddingEnabled: false
        x: 2500   // fuera de la ventana: solo se graban
    }

    // Tiras de código (se desplazan hacia arriba en un bucle perfecto: 96 renglones)
    readonly property int stripLines: 96
    Item {
        id: stripL; width: 320; height: 17 * w.stripLines * 2; visible: false
        Column {
            x: 6
            Repeater {
                model: w.stripLines * 2
                Text {
                    required property int index
                    readonly property int n: index % w.stripLines
                    height: 17
                    text: w.hex(0x7f3a0000 + n * 16, 8) + "  " + [0, 1, 2, 3, 4, 5].map(k => w.hex(w.rng(n * 8 + k) >>> 24, 2)).join(" ")
                    font.family: w.mono; font.pixelSize: 13
                    color: w.rng(n * 7) % 9 === 0 ? w.hot : Qt.rgba(1, 0.5, 0.1, 0.55)
                }
            }
        }
    }
    Glow { id: stripLFx; source: stripL; width: stripL.width; height: stripL.height }
    Item {
        id: stripR; width: 320; height: 17 * w.stripLines * 2; visible: false
        readonly property var msgs: ["UEFI ............. OK", "LIMINE 12.9 ...... OK", "NÚCLEO LINUX ..... OK", "INITRAMFS ........ OK",
            "MÓDULOS ......... CARGA", "DISCO SDA ........ OK", "BTRFS @ .......... OK", "SYSTEMD ....... ACTIVO",
            "MELCHIOR-1 ...... ENLACE", "BALTHASAR-2 ..... ENLACE", "CASPER-3 ........ ENLACE", "PATTERN ......... ORANGE",
            "RED ............. ARRIBA", "AUDIO ............ OK", "GPU AMD ......... OK", "SESIÓN ....... PREPARANDO"]
        Column {
            x: 6
            Repeater {
                model: w.stripLines * 2
                Text {
                    required property int index
                    readonly property int n: index % w.stripLines
                    height: 17
                    text: "[" + (n * 0.091).toFixed(3).padStart(7, " ") + "] " + stripR.msgs[w.rng(n + 5) % stripR.msgs.length]
                    font.family: w.mono; font.pixelSize: 13
                    color: w.rng(n * 3 + 1) % 7 === 0 ? w.hot : Qt.rgba(1, 0.5, 0.1, 0.55)
                }
            }
        }
    }
    Glow { id: stripRFx; source: stripR; width: stripR.width; height: stripR.height }

    // Anillo hexagonal que gira
    Item {
        id: ring; width: 360; height: 360; visible: false
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {   // hexágono exterior
                strokeColor: w.amber; strokeWidth: 3; fillColor: "transparent"
                PathPolyline { path: [0, 1, 2, 3, 4, 5, 6].map(i => Qt.point(180 + 165 * Math.cos(Math.PI / 3 * i - Math.PI / 2), 180 + 165 * Math.sin(Math.PI / 3 * i - Math.PI / 2))) }
            }
            ShapePath {   // arcos interiores
                strokeColor: w.hot; strokeWidth: 8; fillColor: "transparent"; capStyle: ShapePath.FlatCap
                PathAngleArc { centerX: 180; centerY: 180; radiusX: 120; radiusY: 120; startAngle: -90; sweepAngle: 70 }
            }
            ShapePath {
                strokeColor: w.amber; strokeWidth: 8; fillColor: "transparent"; capStyle: ShapePath.FlatCap
                PathAngleArc { centerX: 180; centerY: 180; radiusX: 120; radiusY: 120; startAngle: 30; sweepAngle: 70 }
            }
            ShapePath {
                strokeColor: w.amber; strokeWidth: 8; fillColor: "transparent"; capStyle: ShapePath.FlatCap
                PathAngleArc { centerX: 180; centerY: 180; radiusX: 120; radiusY: 120; startAngle: 150; sweepAngle: 70 }
            }
        }
        Repeater {   // marcas
            model: 36
            Rectangle {
                required property int index
                x: 180 - 1; y: 180 - 150; width: 2; height: index % 3 === 0 ? 14 : 7
                color: w.amber
                transform: Rotation { origin.x: 1; origin.y: 150; angle: index * 10 }
            }
        }
    }
    Glow { id: ringFx; source: ring; width: 360; height: 360 }

    // Textos del centro (arranque / apagado / reinicio)
    component Label: Item {
        id: lb
        property string kanji
        property string txt
        width: 620; height: 130; visible: false
        Text { anchors.horizontalCenter: parent.horizontalCenter; y: 0; text: lb.kanji; font.family: w.jp; font.pixelSize: 64; font.weight: Font.Black; color: w.hot }
        Text { anchors.horizontalCenter: parent.horizontalCenter; y: 88; text: lb.txt; font.family: w.serif; font.pixelSize: 30; font.weight: Font.Black; color: w.amber
               transform: Scale { origin.x: 0; xScale: 1 } }
    }
    Label { id: lBoot; kanji: "起動中"; txt: "ARRANCANDO CACHYOS" }
    Label { id: lOff;  kanji: "停止";   txt: "APAGANDO EL SISTEMA" }
    Label { id: lRe;   kanji: "再起動"; txt: "REINICIANDO" }
    Glow { id: lBootFx; source: lBoot; width: 620; height: 130 }
    Glow { id: lOffFx;  source: lOff;  width: 620; height: 130 }
    Glow { id: lReFx;   source: lRe;   width: 620; height: 130 }

    // EN LÍNEA (titila en el script)
    Item {
        id: online; width: 260; height: 30; visible: false
        Text { anchors.centerIn: parent; text: "●  EN LÍNEA"; font.family: w.mono; font.pixelSize: 17; font.bold: true; color: w.hot }
    }
    Glow { id: onlineFx; source: online; width: 260; height: 30 }

    // Línea brillante del encendido
    Rectangle {
        id: line; width: 1920; height: 24; x: 2500
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.42; color: Qt.rgba(1, 0.75, 0.4, 0.5) }
            GradientStop { position: 0.5; color: "#fff4e0" }
            GradientStop { position: 0.58; color: Qt.rgba(1, 0.75, 0.4, 0.5) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // ── Guardar todo ─────────────────────────────────────────────────────────
    property var jobs: [[bg, "bg.png"], [stripLFx, "strip-left.png"], [stripRFx, "strip-right.png"], [ringFx, "ring.png"],
                        [lBootFx, "label-boot.png"], [lOffFx, "label-shutdown.png"], [lReFx, "label-reboot.png"],
                        [onlineFx, "online.png"], [line, "line.png"]]
    property int job: 0
    function next() {
        if (job >= jobs.length) { Qt.quit(); return; }
        const j = jobs[job++];
        j[0].grabToImage(function (r) { r.saveToFile(w.out + j[1]); w.next(); });
    }
    Timer { interval: 1200; running: true; onTriggered: w.next() }
}
}
