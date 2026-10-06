// Panel lateral con texto que va entrando por abajo como en una terminal
// (volcado de memoria / registro). lineFn(n) da el renglón n; hotFn(n) los resalta.
import QtQuick

Item {
    id: p
    property real u: 1
    property var r
    property real on: 0              // 0→1 aparece
    property string title
    property int lineMs: 100         // un renglón nuevo cada tantos ms
    property var lineFn: function (n) { return ""; }
    property var hotFn: function (n) { return false; }
    readonly property real lineH: 17 * u
    readonly property real t0: 1100  // desde cuándo empieza a escribir
    readonly property real el: Math.max(0, r.t - t0)
    readonly property int nTop: Math.floor(el / lineMs)
    readonly property real frac: (el % lineMs) / lineMs
    readonly property int rows: Math.max(0, Math.floor((height - 46 * u) / lineH) + 1)

    opacity: on

    // Esquinas de marco
    Repeater {
        model: 4
        Item {
            required property int index
            readonly property bool rgt: index % 2 === 1
            readonly property bool bot: index > 1
            x: rgt ? p.width : 0; y: bot ? p.height : 0
            Rectangle { x: parent.rgt ? -18 * p.u : 0; y: parent.bot ? -2 : 0; width: 18 * p.u; height: 2; color: p.r.g(0.8) }
            Rectangle { x: parent.rgt ? -2 : 0; y: parent.bot ? -18 * p.u : 0; width: 2; height: 18 * p.u; color: p.r.g(0.8) }
        }
    }
    Text {
        x: 12 * p.u; y: 10 * p.u
        text: p.title
        font.family: p.r.jp; font.pixelSize: 15 * p.u; font.weight: Font.Bold
        color: p.r.g(0.9)
    }
    Rectangle { x: 12 * p.u; y: 34 * p.u; width: p.width - 24 * p.u; height: 1; color: p.r.g(0.4) }

    Item {
        x: 12 * p.u; y: 42 * p.u
        width: p.width - 24 * p.u; height: p.height - 50 * p.u
        clip: true
        Column {
            y: -p.frac * p.lineH
            Repeater {
                model: p.rows + 1
                Text {
                    required property int index
                    readonly property int n: p.nTop - p.rows + index
                    height: p.lineH
                    text: n >= 0 ? p.lineFn(n) : ""
                    font.family: p.r.mono; font.pixelSize: 13 * p.u
                    color: n >= 0 && (p.hotFn(n) || index === p.rows) ? p.r.g(0.85) : p.r.g(0.32)
                }
            }
        }
    }
}
