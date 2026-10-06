// ─────────────────────────────────────────────────────────────────────────────
//  Fondo del menú de Limine con la estética del arranque MAGI.
//  La escena se dibuja en grises y ../quickshell/rice-boot/shaders/post.frag
//  la revela como fósforo ámbar sobreexpuesto (mismo look que el arranque).
//
//  Generar:  qs -p wallpaper.qml   (→ limine-wallpaper.png, se cierra solo)
//  La caja del centro es donde Limine dibuja las dos opciones: su lugar sale de
//  term_margin en limine.conf (MARGIN_X/Y abajo tienen que coincidir).
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

ShellRoot {
PanelWindow {
    id: w
    // Capa de fondo (detrás de las ventanas): se ve menos de un segundo
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "rice-limine-art"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true }
    implicitWidth: 1920; implicitHeight: 1080
    color: "black"
    readonly property string mono:  "DepartureMono Nerd Font"
    readonly property string serif: "Noto Serif"
    readonly property string jp:    "Noto Sans CJK JP"
    function g(v) { v = Math.max(0, Math.min(1, v)); return Qt.rgba(v, v, v, 1); }
    function rng(n) { let x = (n * 2654435761) >>> 0; x ^= x >>> 15; x = (x * 2246822519) >>> 0; x ^= x >>> 13; return x >>> 0; }
    function hex(n, d) { return (n >>> 0).toString(16).toUpperCase().padStart(d, "0").slice(-d); }

    // Caja del menú (= zona de la terminal de Limine)
    readonly property int boxW: 760
    readonly property int boxH: 240
    readonly property int boxX: 580
    readonly property int boxY: 420

    Item {
        id: scene
        width: w.width; height: w.height

        // Retícula
        Repeater {
            model: 13 * 7
            Item {
                required property int index
                x: (index % 13 + 0.5) * w.width / 13; y: (Math.floor(index / 13) + 0.5) * w.height / 7
                Rectangle { x: -6; width: 12; height: 1; color: w.g(0.13) }
                Rectangle { y: -6; width: 1; height: 12; color: w.g(0.13) }
            }
        }

        // Encabezado
        Text { x: 50; y: 34; text: "MAGI SYSTEM  //  起動選択"; font.family: w.mono; font.pixelSize: 24; color: w.g(1) }
        Text { x: 50; y: 70; text: "NERV 本部  ·  SELECCIÓN DE SISTEMA  ·  CACHYOS / WINDOWS"; font.family: w.mono; font.pixelSize: 14; color: w.g(0.45) }
        Text { anchors.right: parent.right; anchors.rightMargin: 50; y: 26; text: "選択"; font.family: w.jp; font.pixelSize: 48; font.weight: Font.Black; color: w.g(1) }
        Rectangle { x: 50; y: 104; width: w.width - 100; height: 2; color: w.g(0.9) }
        Repeater {
            model: 48
            Rectangle { required property int index; x: 50 + index * (w.width - 100) / 47; y: 106; width: 1; height: index % 4 === 0 ? 10 : 5; color: w.g(0.5) }
        }

        // Columnas de código (quietas, como una foto del arranque)
        Repeater {
            model: 2
            Item {
                required property int index
                x: index === 0 ? 50 : w.width - 380; y: 140; width: 330; height: 780
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
                Column {
                    x: 12; y: 44
                    Repeater {
                        model: 42
                        Text {
                            required property int index
                            readonly property int col: parent.parent.index
                            readonly property var msgs: ["UEFI ............. OK", "SECURE BOOT ...... OFF", "TPM 2.0 ........ LISTO", "DISCO SDA ........ OK",
                                "DISCO NVME0 ...... OK", "BITLOCKER ....... SELLADO", "LIMINE 12.9 ...... OK", "MELCHIOR-1 ...... ESPERA",
                                "BALTHASAR-2 ..... ESPERA", "CASPER-3 ........ ESPERA", "PATTERN ......... ORANGE", "ELECCIÓN ....... PENDIENTE"]
                            height: 17
                            text: col === 0
                                ? w.hex(0x7f3a0000 + index * 16, 8) + "  " + [0, 1, 2, 3, 4, 5].map(k => w.hex(w.rng(index * 8 + k) >>> 24, 2)).join(" ")
                                : "[" + (index * 0.137).toFixed(3).padStart(7, " ") + "] " + msgs[w.rng(index + 3) % msgs.length]
                            font.family: w.mono; font.pixelSize: 13
                            color: w.rng(index * 7 + col) % 9 === 0 ? w.g(0.85) : w.g(0.32)
                        }
                    }
                }
            }
        }

        // Caja central donde aparecen LINUX / WINDOWS
        Shape {
            x: w.boxX - 24; y: w.boxY - 70
            width: w.boxW + 48; height: w.boxH + 94
            preferredRendererType: Shape.CurveRenderer
            readonly property real c: 34
            ShapePath {
                strokeColor: w.g(0.9); strokeWidth: 2.5; fillColor: w.g(0.03)
                startX: 0; startY: 0
                PathLine { x: w.boxW + 48 - 34; y: 0 }
                PathLine { x: w.boxW + 48; y: 34 }
                PathLine { x: w.boxW + 48; y: w.boxH + 94 }
                PathLine { x: 34; y: w.boxH + 94 }
                PathLine { x: 0; y: w.boxH + 94 - 34 }
                PathLine { x: 0; y: 0 }
            }
        }
        Text {
            x: w.boxX; y: w.boxY - 56
            text: "起動 · ELEGÍ UN SISTEMA"
            font.family: w.jp; font.pixelSize: 26; font.weight: Font.Black
            color: w.g(1)
        }
        Rectangle { x: w.boxX; y: w.boxY - 16; width: w.boxW; height: 1; color: w.g(0.45) }

        // Pie
        Rectangle { x: 50; y: w.height - 92; width: w.width - 100; height: 1; color: w.g(0.5) }
        Text { x: 50; y: w.height - 72; text: "↑ ↓  ELEGIR    ENTER  ARRANCAR    MOUSE  CLIC"; font.family: w.mono; font.pixelSize: 14; color: w.g(0.55) }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter; y: w.height - 72
            text: "第3新東京市  //  NERV 本部  //  MAGI SYSTEM ver 7.2  //  特務機関"
            font.family: w.jp; font.pixelSize: 15; color: w.g(0.5)
        }
        Text { anchors.right: parent.right; anchors.rightMargin: 50; y: w.height - 72; text: "提訴"; font.family: w.jp; font.pixelSize: 16; color: w.g(0.5) }
    }

    ShaderEffectSource { id: tex; sourceItem: scene; hideSource: true; mipmap: true; smooth: true; visible: false }
    ShaderEffect {
        id: fx
        anchors.fill: parent
        property var src: tex
        property real time: 2.37        // instante fijo: franjas de interferencia "congeladas"
        property real power: 1
        property real glitch: 0
        property real outp: 0
        property size res: Qt.size(width, height)
        fragmentShader: "file://" + Quickshell.env("HOME") + "/.config/quickshell/rice-boot/shaders/post.frag.qsb"
    }
    Timer { interval: 800; running: true; onTriggered: fx.grabToImage(function (r) { r.saveToFile(Quickshell.shellDir + "/limine-wallpaper.png"); Qt.quit(); }) }
}
}
