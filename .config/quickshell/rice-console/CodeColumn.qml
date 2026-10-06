// Columna de código que se escribe sola, letra por letra, y sube como una
// terminal. Las líneas salen de archivos reales del rice (ver shell.qml).
import QtQuick
import QtQuick.Effects

Item {
    id: col
    property var    lines: []          // de dónde sale el texto
    property int    speed: 30          // ms entre teclazos
    property int    maxLines: 60
    property string fontName
    property real   fontSize: 10
    property color  color: "#7fd897"
    property bool   running: true

    property var    done: []           // líneas ya escritas
    property string target: ""         // línea que se está escribiendo
    property string current: ""
    property int    idx: Math.floor(Math.random() * 100000)
    property int    pause: 0           // a veces "piensa" un rato antes de seguir

    clip: true

    // Arranca con la columna ya llena, como si llevara rato escribiendo
    onLinesChanged: if (done.length === 0 && lines.length > 0) {
        const start = Math.floor(Math.random() * lines.length);
        const pre = [];
        for (let i = 0; i < maxLines; i++) pre.push(lines[(start + i) % lines.length]);
        done = pre;
        idx = (start + maxLines) % lines.length;
    }

    Timer {
        interval: col.speed
        repeat: true
        running: col.running && col.visible && col.lines.length > 0
        onTriggered: {
            if (col.pause > 0) { col.pause--; return; }
            if (col.current.length < col.target.length) {
                const n = 1 + Math.floor(Math.random() * 3);        // ráfagas de 1–3 letras
                col.current = col.target.slice(0, col.current.length + n);
                return;
            }
            if (col.target !== "")
                col.done = col.done.concat([col.current]).slice(-col.maxLines);
            col.idx = (col.idx + 1 + (Math.random() < 0.08 ? Math.floor(Math.random() * 40) : 0)) % col.lines.length;
            col.target = col.lines[col.idx];
            col.current = "";
            if (Math.random() < 0.12) col.pause = 8 + Math.floor(Math.random() * 30);
        }
    }

    // Todo en un solo Text (barato de dibujar) pegado abajo; arriba se desvanece
    Item {
        id: body
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: col.done.join("\n") + (col.done.length ? "\n" : "") + col.current + "█"
            font.family: col.fontName
            font.pixelSize: col.fontSize
            color: col.color
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
            lineHeight: 1.15
            textFormat: Text.PlainText
        }
    }
    Rectangle {
        id: fade
        anchors.fill: parent
        visible: false
        layer.enabled: true
        gradient: Gradient {
            GradientStop { position: 0.0;  color: "transparent" }
            GradientStop { position: 0.30; color: "white" }
        }
    }
    MultiEffect {
        anchors.fill: parent
        source: body
        maskEnabled: true
        maskSource: fade
        maskThresholdMin: 0.0
        maskSpreadAtMin: 0.0
    }
}
