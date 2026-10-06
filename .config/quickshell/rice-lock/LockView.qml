// Lo que se ve en la pantalla de bloqueo (una por monitor). Todo pasa por el
// shader del arranque MAGI (../rice-fx/crtfx.frag): encendido de tubo al
// aparecer, interferencia, halo, grano. Al desbloquear, la interfaz se apaga
// y la foto del escritorio se prende como un tubo.
import QtQuick
import QtQuick.Effects
import Quickshell

Item {
    id: v
    property var r                         // root de shell.qml
    readonly property real u: Math.min(width / 1920, height / 1080)
    readonly property string fx: "file://" + Quickshell.env("HOME") + "/.config/quickshell/rice-fx/crtfx.frag.qsb"
    readonly property color amber: "#fe8019"
    readonly property color gold:  "#fabd2f"
    readonly property color cream: "#ebdbb2"
    readonly property color dim:   "#7c4a1c"
    readonly property color red:   "#ff3020"

    // Foto del escritorio (la saca lock.sh con grim antes de bloquear)
    Image {
        id: shot
        anchors.fill: parent
        source: v.r.shotUrl
        fillMode: Image.PreserveAspectCrop
        cache: false
        visible: false
    }

    // ── Interfaz ─────────────────────────────────────────────────────────────
    Item {
        id: ui
        anchors.fill: parent
        visible: !v.r.showDesk
        layer.enabled: true
        layer.mipmap: true
        layer.samplerName: "src"
        layer.effect: ShaderEffect {
            property real time: v.r.t / 1000
            property real power: v.r.uiPow
            property real glitch: v.r.glitch
            property real amount: 0.45
            property real bloomAmt: 1.3
            property real expo: 1.2
            property real sat: 1.15
            property size res: Qt.size(width, height)
            fragmentShader: v.fx
        }

        Rectangle { anchors.fill: parent; color: "#070302" }
        // Fondo: el escritorio desenfocado y oscuro
        MultiEffect {
            anchors.fill: parent
            source: shot
            visible: shot.status === Image.Ready
            blurEnabled: true; blur: 1.0; blurMax: 48
            brightness: -0.32
            saturation: 0.5
        }

        // Encabezado
        Text {
            x: 50 * v.u; y: 34 * v.u
            text: "NERV  //  施錠  SISTEMA BLOQUEADO"
            font.family: v.r.mono; font.pixelSize: 22 * v.u
            color: v.gold
        }
        Text {
            x: 50 * v.u; y: 66 * v.u
            text: "SESIÓN: " + v.r.user + "  ·  MAGI EN ESPERA  ·  ACCESO RESTRINGIDO"
            font.family: v.r.mono; font.pixelSize: 13 * v.u
            color: v.dim
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 50 * v.u
            y: 24 * v.u
            text: "封印"
            font.family: v.r.jp; font.pixelSize: 48 * v.u; font.weight: Font.Black
            color: v.amber
        }
        Rectangle { x: 50 * v.u; y: 100 * v.u; width: v.width - 100 * v.u; height: 2; color: v.amber; opacity: 0.8 }

        // Columnas de código a los costados
        Panel {
            x: 50 * v.u; y: 140 * v.u; width: 300 * v.u; height: 760 * v.u
            u: v.u; r: v.r; on: 0.8
            title: "VOLCADO  記憶"
            lineMs: 90
            lineFn: function (n) {
                let x = (n * 2654435761) >>> 0, s = (0x7f3a0000 + n * 16).toString(16).toUpperCase() + "  ";
                for (let k = 0; k < 6; k++) { x = (x * 1103515245 + 12345) >>> 0; s += ((x >>> 24) & 255).toString(16).toUpperCase().padStart(2, "0") + " "; }
                return s;
            }
        }
        Panel {
            x: v.width - 350 * v.u; y: 140 * v.u; width: 300 * v.u; height: 760 * v.u
            u: v.u; r: v.r; on: 0.8
            title: "VIGILANCIA  監視"
            lineMs: 260
            readonly property var pool: ["MELCHIOR-1 ...... vigilando", "BALTHASAR-2 ..... vigilando", "CASPER-3 ........ vigilando",
                "terminal ........ sellada", "entrada ....... bloqueada", "intentos ......... " + v.r.fails, "A.T. FIELD ....... activo",
                "sesión ........ suspendida", "LCL ............. nominal", "puerta 7-G ...... cerrada"]
            lineFn: function (n) { return "[" + (n * 0.26).toFixed(2).padStart(6, " ") + "] " + pool[((n * 2654435761) >>> 0) % pool.length]; }
        }

        // Hora y fecha
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: v.height * 0.22
            spacing: 4 * v.u
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(v.r.now, "HH:mm")
                font.family: v.r.mono; font.pixelSize: 150 * v.u
                color: v.amber
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.locale("es_AR").toString(v.r.now, "dddd dd/MM").toUpperCase()
                font.family: v.r.mono; font.pixelSize: 20 * v.u
                color: v.gold
            }
        }

        // Caja de contraseña
        Item {
            id: box
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: v.r.shake
            y: v.height * 0.58
            width: 460 * v.u; height: 150 * v.u
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "施錠 ─ BLOQUEADO"
                font.family: v.r.jp; font.pixelSize: 16 * v.u; font.bold: true
                color: v.gold
            }
            Rectangle {
                y: 34 * v.u
                width: parent.width; height: 58 * v.u
                color: Qt.rgba(0.05, 0.03, 0.02, 0.85)
                border.width: 2
                border.color: v.r.state === "fail" ? v.red : v.r.state === "ok" ? v.cream : v.gold
                Text {
                    anchors.centerIn: parent
                    text: v.r.pwLen > 0 ? "●  ".repeat(Math.min(v.r.pwLen, 14)).trim() : "CONTRASEÑA"
                    font.family: v.r.mono; font.pixelSize: (v.r.pwLen > 0 ? 18 : 16) * v.u
                    color: v.r.pwLen > 0 ? v.cream : v.dim
                }
                // cursor que titila
                Rectangle {
                    visible: v.r.state === "idle" && Math.floor(v.r.t / 500) % 2 === 0
                    anchors.right: parent.right; anchors.rightMargin: 16 * v.u
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10 * v.u; height: 22 * v.u
                    color: v.amber
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 108 * v.u
                text: v.r.state === "check" ? "VERIFICANDO" + ".".repeat(Math.floor(v.r.t / 250) % 4)
                    : v.r.state === "fail"  ? "拒否 · CLAVE INCORRECTA (" + v.r.fails + ")"
                    : v.r.state === "ok"    ? "承認 · ACCESO CONCEDIDO"
                    : v.r.message !== ""    ? v.r.message
                    : "INTRODUCÍ LA CLAVE Y ENTER"
                font.family: v.r.state === "fail" || v.r.state === "ok" ? v.r.jp : v.r.mono
                font.pixelSize: 15 * v.u; font.bold: v.r.state === "fail" || v.r.state === "ok"
                color: v.r.state === "fail" ? v.red : v.r.state === "ok" ? v.cream : v.dim
            }
        }

        // Pie
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: v.height - 70 * v.u
            text: "第3新東京市  //  NERV 本部  //  MAGI SYSTEM  //  " + Qt.formatDateTime(v.r.now, "yyyy.MM.dd")
            font.family: v.r.jp; font.pixelSize: 14 * v.u
            color: v.dim
        }
    }

    // ── Escritorio prendiéndose (al desbloquear) ─────────────────────────────
    ShaderEffectSource { id: shotTex; sourceItem: shot; mipmap: true; smooth: true; visible: false }
    ShaderEffect {
        anchors.fill: parent
        visible: v.r.showDesk
        property var src: shotTex
        property real time: v.r.t / 1000
        property real power: v.r.deskPow
        property real glitch: 0.15 + 0.5 * (1 - v.r.deskPow)
        property real amount: 0.8
        property real bloomAmt: 0.0
        property real expo: 1.0
        property real sat: 1.0
        property size res: Qt.size(width, height)
        fragmentShader: v.fx
    }
}
