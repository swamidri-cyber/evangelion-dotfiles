// Un bloque MAGI: rectángulo con la esquina (o el borde) que mira al centro
// cortado en diagonal. Se dibuja, "arranca" y vota 承認. El código sigue
// corriendo siempre (también después de votar) y abajo dice EN LÍNEA.
//
// Todo se dibuja en GRISES: el color lo pone shaders/post.frag
// (negro = fondo, gris medio = naranja, blanco = crema sobreexpuesto).
import QtQuick
import QtQuick.Shapes

Item {
    id: b
    property real   u: 1
    property string name
    property int    num
    property string kind: "top"      // "top" | "left" | "right"
    property real   drawIn: 0        // 0→1: aparece el contorno
    property real   booting: 0       // 0→1: progreso del arranque
    property bool   voted: false
    property real   flash: 0         // 0→1 justo al votar
    property int    seed: 0
    property real   t: 0             // reloj (ms)
    property var    pal              // root de shell.qml (fuentes, g())

    width: 390 * u; height: 232 * u
    readonly property real c: 56 * u  // tamaño del corte
    readonly property real lineH: 16 * u

    opacity: drawIn
    transform: Scale { origin.x: b.width / 2; origin.y: b.height / 2; xScale: 0.92 + 0.08 * b.drawIn; yScale: 0.92 + 0.08 * b.drawIn }

    // Colores (intensidades): sobre el relleno de 承認 todo pasa a oscuro
    readonly property color ink:    voted ? pal.g(0.0)  : pal.g(0.95)
    readonly property color inkDim: voted ? pal.g(0.16) : pal.g(0.40)

    // Contorno según la orientación (el corte apunta al centro de los tres)
    readonly property var pts: kind === "top"
        ? [[0, 0], [width, 0], [width, height - c], [width - c, height], [c, height], [0, height - c]]
        : kind === "left"
        ? [[0, 0], [width - c, 0], [width, c], [width, height], [0, height]]
        : [[c, 0], [width, 0], [width, height], [0, height], [0, c]]

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: b.pal.g(0.9)
            strokeWidth: 2.5
            fillColor: b.voted ? b.pal.g(0.36 + 0.5 * (1 - b.flash)) : b.pal.g(0.035)
            startX: b.pts[0][0]; startY: b.pts[0][1]
            PathPolyline { path: b.pts.concat([b.pts[0]]).map(p => Qt.point(p[0], p[1])) }
        }
    }

    // Nombre + identificación
    Text {
        id: title
        x: (b.kind === "right" ? b.c : 0) + 18 * b.u
        y: 12 * b.u
        text: b.name + " · " + b.num
        font.family: b.pal.serif; font.pixelSize: 30 * b.u; font.weight: Font.Black
        color: b.ink
        transform: Scale { xScale: 0.82 }
    }
    Text {
        x: (b.kind === "right" ? b.c : 0) + 20 * b.u
        y: 50 * b.u
        text: "MAGI-0" + b.num + "  ·  NÚCLEO: " + b.core + "  ·  " + b.loadTxt
        font.family: b.pal.mono; font.pixelSize: 12 * b.u
        color: b.inkDim
    }

    // Código corriendo (no se detiene nunca: va subiendo renglón a renglón)
    readonly property int step: Math.floor(t / 110)
    readonly property real frac: (t % 110) / 110
    Item {
        x: 20 * b.u; y: 72 * b.u
        width: b.width - 40 * b.u; height: b.lineH * 4
        clip: true
        visible: b.booting > 0
        Column {
            y: -b.frac * b.lineH
            Repeater {
                model: 5
                Text {
                    required property int index
                    height: b.lineH
                    text: b.logLine(b.step + index)
                    font.family: b.pal.mono; font.pixelSize: 13 * b.u
                    color: index === 3 ? b.ink : b.inkDim
                }
            }
        }
    }

    // Datos que cambian: sincronía, carga, latencia
    Text {
        x: 20 * b.u; y: 142 * b.u
        visible: b.booting > 0
        text: "SYNC " + b.syncTxt + "   CARGA " + b.loadTxt + "   Δt " + (0.3 + 0.2 * Math.sin(b.t / 410 + b.seed)).toFixed(2) + " ms"
        font.family: b.pal.mono; font.pixelSize: 13 * b.u
        color: b.ink
    }
    // Barra de progreso (dentro del bloque, por encima de las esquinas cortadas)
    Rectangle {
        x: 20 * b.u; y: 166 * b.u
        width: b.width - 40 * b.u; height: 6 * b.u
        color: "transparent"; border.color: b.inkDim; border.width: 1
        Rectangle {
            width: parent.width * b.booting; height: parent.height
            color: b.ink
        }
        // pulso que recorre la barra llena
        Rectangle {
            visible: b.booting >= 1
            width: 40 * b.u; height: parent.height
            x: (parent.width - width) * ((b.t / 900 + b.seed * 0.13) % 1)
            color: b.voted ? b.pal.g(0.6) : b.pal.g(1)
        }
    }
    // EN LÍNEA (siempre, centrado para no chocar con los cortes)
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 184 * b.u
        visible: b.drawIn > 0.5
        text: (Math.floor(b.t / 450) % 2 ? "●" : "○") + "  EN LÍNEA"
        font.family: b.pal.mono; font.pixelSize: 15 * b.u; font.bold: true
        color: b.ink
    }

    // Voto
    Text {
        visible: b.voted
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 10 * b.u
        text: "承認"
        font.family: b.pal.jp; font.pixelSize: 70 * b.u; font.weight: Font.Black
        color: b.pal.g(0.0)
        scale: 1 + 0.25 * (1 - b.flash)
    }

    // Personalidades de la Dra. Naoko Akagi
    readonly property string core: ({ MELCHIOR: "CIENTÍFICA", BALTHASAR: "MADRE", CASPER: "MUJER" })[name] ?? ""
    readonly property real syncBase: ({ MELCHIOR: 99.8, BALTHASAR: 100.0, CASPER: 99.4 })[name] ?? 99
    readonly property string syncTxt: (booting < 1 ? syncBase * booting : syncBase - 0.3 * Math.abs(Math.sin(t / 700 + seed))).toFixed(1).replace(".", ",") + "%"
    readonly property string loadTxt: Math.round(30 + 25 * Math.abs(Math.sin(Math.floor(t / 250) * 1.7 + seed))) + "%"

    readonly property var msgs: ({
        MELCHIOR:  ["ANÁLISIS LÓGICO ...... OK", "MODELO PREDICTIVO .... OK", "RED NEURONAL ......... OK", "CÁLCULO 7-G ...... ESTABLE"],
        BALTHASAR: ["PROTOCOLO TUTELA ..... OK", "MEMORIA ............. OK", "RED NEURONAL ......... OK", "ENLACE NERV ...... ESTABLE"],
        CASPER:    ["JUICIO INTUITIVO ..... OK", "PERSONALIDAD ......... OK", "RED NEURONAL ......... OK", "EMOCIÓN .......... ESTABLE"]
    })[name] ?? ["OK"]

    // Renglón n del registro: casi todo hexadecimal, cada tanto un mensaje
    function logLine(n) {
        let x = (n * 7919 + seed * 31337) >>> 0;
        x = (x * 1103515245 + 12345) >>> 0;
        if ((x >>> 4) % 5 === 0) return "> " + msgs[(x >>> 9) % msgs.length];
        let h = (0x1000 + (n * 16) % 0xefff).toString(16).toUpperCase() + "  ";
        for (let k = 0; k < 6; k++) {
            x = (x * 1103515245 + 12345) >>> 0;
            h += ((x >>> 8) & 0xffff).toString(16).padStart(4, "0").toUpperCase() + " ";
        }
        return h;
    }
}
