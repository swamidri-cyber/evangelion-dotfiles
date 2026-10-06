// La escena del arranque, en GRISES (shaders/post.frag pone el color).
// Diseñada en 1920×1080 y escalada con u.
import QtQuick
import QtQuick.Shapes

Item {
    id: sc
    property var r                       // root de shell.qml
    readonly property real t: r.t
    readonly property real u: Math.min(width / 1920, height / 1080)
    readonly property real cx: width / 2
    readonly property real cy: height / 2 + 10 * u
    readonly property real side: 330 * u     // ancho de las columnas laterales
    readonly property real m: 50 * u         // margen

    function fmtT(ms) { const s = ms / 1000; return "T+" + String(Math.floor(s / 60)).padStart(2, "0") + ":" + (s % 60).toFixed(2).padStart(5, "0"); }
    function rng(n) { let x = (n * 2654435761) >>> 0; x ^= x >>> 15; x = (x * 2246822519) >>> 0; x ^= x >>> 13; return x >>> 0; }
    function hex(n, digits) { return (n >>> 0).toString(16).toUpperCase().padStart(digits, "0").slice(-digits); }

    // ── Retícula de fondo: crucecitas tenues ──────────────────────────────
    Repeater {
        model: 13 * 7
        Item {
            required property int index
            x: (index % 13 + 0.5) * sc.width / 13; y: (Math.floor(index / 13) + 0.5) * sc.height / 7
            opacity: sc.r.at(800, 1400) * 0.9
            Rectangle { x: -6 * sc.u; width: 12 * sc.u; height: 1; color: sc.r.g(0.13) }
            Rectangle { y: -6 * sc.u; width: 1; height: 12 * sc.u; color: sc.r.g(0.13) }
        }
    }

    // ── Encabezado ─────────────────────────────────────────────────────────
    Text {
        x: sc.m; y: 34 * sc.u
        text: "MAGI SYSTEM  //  第7世代有機コンピュータ".slice(0, Math.floor(sc.r.at(700, 1150) * 34))
        font.family: sc.r.mono; font.pixelSize: 24 * sc.u
        color: sc.r.g(1)
    }
    Text {
        x: sc.m; y: 70 * sc.u
        text: "NERV 本部  ·  SESIÓN: " + sc.r.user + "  ·  " + sc.r.host.toUpperCase() + "  ·  HYPRLAND / UWSM  ·  " + Qt.formatDateTime(new Date(), "yyyy.MM.dd  HH:mm")
        font.family: sc.r.mono; font.pixelSize: 14 * sc.u
        color: sc.r.g(0.45)
        opacity: sc.r.at(950, 1250)
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: sc.m
        y: 26 * sc.u
        text: "提訴"
        font.family: sc.r.jp; font.pixelSize: 48 * sc.u; font.weight: Font.Black
        color: sc.r.g(1)
        opacity: sc.r.at(900, 1150)
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: sc.m + 110 * sc.u
        y: 40 * sc.u
        text: sc.fmtT(sc.t) + "\nCODE 601 · PRIORIDAD AAA"
        horizontalAlignment: Text.AlignRight
        font.family: sc.r.mono; font.pixelSize: 14 * sc.u
        color: sc.r.g(0.55)
        opacity: sc.r.at(900, 1150)
    }
    // Regla con marcas
    Rectangle {
        x: sc.m; y: 104 * sc.u
        width: (sc.width - 2 * sc.m) * sc.r.at(700, 1300); height: 2
        color: sc.r.g(0.9)
    }
    Repeater {
        model: 48
        Rectangle {
            required property int index
            x: sc.m + index * (sc.width - 2 * sc.m) / 47; y: 106 * sc.u
            width: 1; height: (index % 4 === 0 ? 10 : 5) * sc.u
            color: sc.r.g(0.5)
            visible: sc.r.at(700, 1300) * 47 > index
        }
    }

    // ── Columna izquierda: volcado de memoria ─────────────────────────────
    Panel {
        x: sc.m; y: 140 * sc.u; width: sc.side; height: 780 * sc.u
        u: sc.u; r: sc.r; on: sc.r.at(1000, 1300)
        title: "VOLCADO DE MEMORIA  記憶"
        lineMs: 55
        lineFn: function (n) {
            let s = sc.hex(0x7f3a0000 + n * 16, 8) + "  ";
            for (let k = 0; k < 6; k++) s += sc.hex(sc.rng(n * 8 + k) >>> 24, 2) + " ";
            return s;
        }
        hotFn: function (n) { return sc.rng(n) % 9 === 0; }
    }

    // ── Columna derecha: registro del sistema (con datos reales) ──────────
    Panel {
        x: sc.width - sc.m - sc.side; y: 140 * sc.u; width: sc.side; height: 780 * sc.u
        u: sc.u; r: sc.r; on: sc.r.at(1100, 1400)
        title: "REGISTRO  記録"
        lineMs: 190
        readonly property var fixed: [
            "MAGI BOOT SEQUENCE",
            "HOST    " + sc.r.host,
            "KERNEL  " + sc.r.kernel,
            "CPU     " + sc.r.cpu,
            "MEM     " + sc.r.mem,
            "PANTALLA " + Math.round(sc.width) + "×" + Math.round(sc.height),
            "SESIÓN  " + sc.r.user.toLowerCase()
        ]
        readonly property var pool: [
            "MELCHIOR-1 enlace ..... OK", "BALTHASAR-2 enlace .... OK", "CASPER-3 enlace ....... OK",
            "LCL presión ...... nominal", "A.T. FIELD ...... no detect.", "PATTERN ........... ORANGE",
            "red neuronal .... sincron.", "sector 7-G ...... sin daño", "TOKYO-3 enlace .... estable",
            "Dirac sea ........ estable", "S2 engine ........ offline", "umbilical ......... conect.",
            "terminal dogma ... sellado", "Geofront ......... nominal", "proceso #" + "2041 .. iniciado",
            "memoria caché .... limpia", "jaula 7 ......... asegurada", "señal NERV ........ 100%"
        ]
        lineFn: function (n) {
            const ts = "[" + (n * 0.137).toFixed(3).padStart(7, " ") + "] ";
            return ts + (n < fixed.length ? fixed[n] : pool[sc.rng(n) % pool.length]);
        }
        hotFn: function (n) { return n < fixed.length; }
    }

    // ── Conexiones entre los MAGI ─────────────────────────────────────────
    Shape {
        anchors.fill: parent
        opacity: sc.r.at(1300, 1700)
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: sc.r.g(0.38); strokeWidth: 2; fillColor: "transparent"
            strokeStyle: ShapePath.DashLine; dashPattern: [3, 3]
            startX: sc.cx; startY: sc.cy - 135 * sc.u
            PathLine { x: sc.cx - 240 * sc.u; y: sc.cy + 120 * sc.u }
            PathLine { x: sc.cx + 240 * sc.u; y: sc.cy + 120 * sc.u }
            PathLine { x: sc.cx; y: sc.cy - 135 * sc.u }
        }
    }

    // Centro: MAGI
    Text {
        id: magiTxt
        anchors.horizontalCenter: parent.horizontalCenter
        y: sc.cy - 10 * sc.u
        text: "MAGI"
        font.family: sc.r.serif; font.pixelSize: 72 * sc.u; font.weight: Font.Black
        color: sc.r.g(1)
        opacity: sc.r.at(1200, 1600)
        transform: Scale { origin.x: magiTxt.width / 2; xScale: 0.82 }
    }

    // Los tres bloques
    Repeater {
        model: [
            { name: "BALTHASAR", num: 2, dx: 0,    dy: -230, kind: "top"   },
            { name: "CASPER",    num: 3, dx: -335, dy: 120,  kind: "left"  },
            { name: "MELCHIOR",  num: 1, dx: 335,  dy: 120,  kind: "right" }
        ]
        delegate: MagiBlock {
            required property var modelData
            required property int index
            u: sc.u
            x: sc.cx + modelData.dx * sc.u - width / 2
            y: sc.cy + modelData.dy * sc.u - height / 2
            name: modelData.name; num: modelData.num; kind: modelData.kind
            drawIn: sc.r.at(1000 + index * 130, 1450 + index * 130)
            booting: sc.r.at(1500 + index * 150, 2900 + index * 50)
            voted: sc.t >= sc.r.votes[index]
            flash: sc.r.at(sc.r.votes[index], sc.r.votes[index] + 280)
            seed: index * 97 + 13
            t: sc.t
            pal: sc.r
        }
    }

    // ── Deliberación / resultado ──────────────────────────────────────────
    Item {
        id: res
        anchors.horizontalCenter: parent.horizontalCenter
        y: sc.cy + 290 * sc.u
        width: 780 * sc.u; height: 130 * sc.u
        opacity: sc.r.at(1600, 1900)
        readonly property int nv: sc.r.votes.filter(v => sc.t >= v).length
        readonly property bool done: sc.t >= sc.r.tOk
        Rectangle {
            anchors.fill: parent
            color: res.done ? sc.r.g(0.05 + 0.35 * (1 - sc.r.at(sc.r.tOk, sc.r.tOk + 350))) : "transparent"
            border.color: sc.r.g(0.9); border.width: 2
        }
        Row {
            anchors.centerIn: parent
            spacing: 30 * sc.u
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: res.done ? "承認" : "審議中"
                font.family: sc.r.jp; font.pixelSize: (res.done ? 76 : 54) * sc.u; font.weight: Font.Black
                color: sc.r.g(res.done ? 1 : 0.65 + 0.35 * Math.abs(Math.sin(sc.t / 260)))
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6 * sc.u
                Text {
                    text: res.done ? "ACCESO CONCEDIDO" : "DELIBERANDO" + ".".repeat(Math.floor(sc.t / 300) % 4)
                    font.family: sc.r.serif; font.pixelSize: 40 * sc.u; font.weight: Font.Black
                    color: sc.r.g(0.95)
                    transform: Scale { xScale: 0.85 }
                }
                Text {
                    text: res.nv + " / 3 VOTOS  ·  " + (res.done ? "BIENVENIDO, " + sc.r.user : "ESPERANDO A LOS MAGI")
                    font.family: sc.r.mono; font.pixelSize: 16 * sc.u
                    color: sc.r.g(0.6)
                }
            }
        }
    }

    // ── Pie ────────────────────────────────────────────────────────────────
    Rectangle {
        x: sc.m; y: sc.height - 92 * sc.u
        width: (sc.width - 2 * sc.m) * sc.r.at(900, 1500); height: 1
        color: sc.r.g(0.5)
    }
    // Medidores de sincronía
    Row {
        x: sc.m; y: sc.height - 76 * sc.u
        height: 34 * sc.u
        spacing: 4 * sc.u
        opacity: sc.r.at(1100, 1400)
        Text {
            text: "SINCRONÍA"
            font.family: sc.r.mono; font.pixelSize: 12 * sc.u
            color: sc.r.g(0.5)
            anchors.bottom: parent.bottom
        }
        Item { width: 10 * sc.u; height: 1 }
        Repeater {
            model: 22
            Rectangle {
                required property int index
                readonly property real lv: 0.25 + 0.75 * Math.abs(Math.sin(sc.t / (180 + index * 23) + index * 1.3)) * (0.6 + 0.4 * ((sc.rng(Math.floor(sc.t / 90) + index * 31) % 100) / 100))
                anchors.bottom: parent.bottom
                width: 7 * sc.u; height: 34 * sc.u * lv
                color: sc.r.g(lv > 0.85 ? 1 : 0.55)
            }
        }
    }
    // Cinta de texto que corre
    Item {
        x: sc.m + 420 * sc.u; y: sc.height - 70 * sc.u
        width: sc.width - 2 * sc.m - 420 * sc.u - 300 * sc.u; height: 24 * sc.u
        clip: true
        opacity: sc.r.at(1200, 1500)
        Text {
            id: ticker
            readonly property string msg: "第3新東京市  //  NERV 本部  //  MAGI SYSTEM ver 7.2  //  特務機関  //  人類補完計画  //  SISTEMA EN LÍNEA  //  "
            text: msg + msg + msg
            x: -((sc.t * 0.11 * sc.u) % (ticker.implicitWidth / 3))
            font.family: sc.r.jp; font.pixelSize: 15 * sc.u
            color: sc.r.g(0.5)
        }
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: sc.m
        y: sc.height - 72 * sc.u
        text: "CUALQUIER TECLA PARA SALTAR"
        font.family: sc.r.mono; font.pixelSize: 13 * sc.u
        color: sc.r.g(0.35 + 0.25 * Math.sin(sc.t / 300))
        opacity: sc.r.at(1300, 1600)
    }
}
