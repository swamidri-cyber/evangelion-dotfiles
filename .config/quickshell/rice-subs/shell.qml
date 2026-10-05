// ─────────────────────────────────────────────────────────────────────────────
//  rice-subs — subtítulos del escritorio, como en una película vieja.
//
//  Cada tanto se "tipea" una frase al azar abajo al centro (Phrases.js), letra
//  por letra con cursor de bloque ámbar, igual que la info del lanzador. Queda
//  visible hasta completar SHOW_MS, se apaga y espera HIDE_MS hasta la próxima.
//
//  Look: Departure Mono grande, núcleo quemado a blanco (sobreexpuesto), halo
//  dorado + halo ámbar, grano animado (grain.png) y parpadeo leve de tubo.
//
//  Va en la capa "bottom": encima del fondo y DEBAJO de las ventanas (solo se
//  ve con el escritorio despejado). No toma clics ni teclado.
//  Corre en segundo plano (autostart.lua). Reiniciar:
//    qs kill -c rice-subs; uwsm app -- qs -c rice-subs
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "Phrases.js" as PhraseList

ShellRoot {
    id: root

    readonly property int showMs: 5000     // tiempo visible (incluye el tipeo)
    readonly property int hideMs: 10000    // pausa entre frases
    readonly property int fadeMs: 600      // apagado al final
    readonly property int fontPx: 42
    readonly property string dir: Quickshell.shellDir

    property string phrase: ""
    property int typed: 0                  // letras ya escritas
    property bool shown: false
    property bool cursorOn: true
    property real flicker: 1.0
    property var bag: []                   // frases que faltan salir en esta vuelta

    function pick() {
        if (bag.length === 0) {
            // nueva vuelta: mezcla (Fisher–Yates), sin repetir la última al empezar
            const b = PhraseList.list.slice();
            for (let i = b.length - 1; i > 0; i--) {
                const j = Math.floor(Math.random() * (i + 1));
                [b[i], b[j]] = [b[j], b[i]];
            }
            if (b.length > 1 && b[b.length - 1] === phrase) b.unshift(b.pop());
            bag = b;
        }
        const b = bag.slice();
        phrase = b.pop();
        bag = b;
    }

    function esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }

    // Texto visible: lo tipeado + cursor de bloque ámbar (mientras escribe, fijo;
    // después titila hasta que se apaga)
    readonly property string shownText: esc(phrase.substring(0, typed))
        + '<font color="' + (shown && (typed < phrase.length || cursorOn) ? "#fe8019" : "#00000000") + '">█</font>'
    // (el bloque está SIEMPRE: al titilar solo se vuelve transparente, así el
    //  ancho no cambia y la frase no "late")

    // Ciclo: escribir → mostrar hasta SHOW_MS → apagar → HIDE_MS → otra
    Timer {
        id: cycle
        running: true
        interval: 4000                     // la primera sale 4 s después de iniciar
        onTriggered: {
            if (root.shown) {
                root.shown = false;
                interval = root.hideMs + root.fadeMs;
            } else {
                root.pick();
                root.typed = 0;
                root.shown = true;
                typer.interval = 120;      // pausita antes de la primera letra
                typer.start();
                interval = root.showMs;
            }
            restart();
        }
    }

    // Máquina de escribir: ritmo irregular, como alguien tecleando
    Timer {
        id: typer
        repeat: false
        onTriggered: {
            if (root.typed >= root.phrase.length) return;
            root.typed++;
            const ch = root.phrase.charAt(root.typed - 1);
            interval = (ch === " " ? 90 : ".,?!".indexOf(ch) >= 0 ? 160 : 45) + Math.random() * 45;
            restart();
        }
    }

    // Cursor que titila y parpadeo leve del tubo
    Timer { interval: 530; running: root.shown; repeat: true; onTriggered: root.cursorOn = !root.cursorOn }
    Timer {
        interval: 70; running: root.shown; repeat: true
        onTriggered: root.flicker = Math.random() < 0.06 ? 0.72 : 0.92 + Math.random() * 0.08
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "rice-subs"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore    // no empuja ventanas ni la barra
            anchors { bottom: true; left: true; right: true }
            implicitHeight: 260
            color: "transparent"
            mask: Region {}                        // los clics pasan de largo

            Item {
                id: stage
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 60
                width: glyphs.implicitWidth + 160
                height: glyphs.implicitHeight + 160
                opacity: (root.shown ? 1 : 0) * root.flicker
                Behavior on opacity { NumberAnimation { duration: root.shown ? 60 : root.fadeMs; easing.type: Easing.InOutQuad } }

                // Fuente de todo: el texto (invisible, lo dibujan los efectos)
                Item {
                    id: src
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true
                    Text {
                        id: glyphs
                        anchors.centerIn: parent
                        textFormat: Text.StyledText
                        text: root.shownText
                        font.family: "DepartureMono Nerd Font"
                        font.pixelSize: root.fontPx
                        color: "#fff4dc"
                    }
                }

                // Halo ámbar amplio
                MultiEffect {
                    anchors.fill: src; source: src
                    blurEnabled: true; blurMax: 64; blur: 1.0
                    colorization: 1.0; colorizationColor: "#fe8019"
                    brightness: 0.4
                    opacity: 0.95
                }
                // Halo dorado cercano
                MultiEffect {
                    anchors.fill: src; source: src
                    blurEnabled: true; blurMax: 20; blur: 0.85
                    colorization: 1.0; colorizationColor: "#fabd2f"
                    brightness: 0.4
                    opacity: 0.95
                }
                // Núcleo apenas quemado
                MultiEffect {
                    anchors.fill: src; source: src
                    blurEnabled: true; blurMax: 6; blur: 0.4
                    brightness: 0.5
                    opacity: 0.85
                }
                MultiEffect {                      // letra nítida encima (manda la lectura)
                    anchors.fill: src; source: src
                    brightness: 0.25
                }

                // Máscara (oculta) para el grano: la letra con su halo cercano
                Item {
                    id: grainMask
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true
                    MultiEffect {
                        anchors.fill: parent; source: src
                        blurEnabled: true; blurMax: 16; blur: 0.8
                        brightness: 1.0
                    }
                }

                // Grano animado, solo donde hay letra o halo dorado
                Item {
                    anchors.fill: parent
                    clip: true
                    opacity: 0.8                   // grano presente pero sin tapar la letra
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: grainMask
                        maskThresholdMin: 0.06
                        maskSpreadAtMin: 0.0
                    }
                    Image {
                        id: grain
                        width: parent.width + 256; height: parent.height + 256
                        source: "file://" + root.dir + "/grain.png"
                        fillMode: Image.Tile
                        smooth: false
                    }
                    Timer {
                        interval: 60; running: root.shown; repeat: true
                        onTriggered: { grain.x = -Math.floor(Math.random() * 256); grain.y = -Math.floor(Math.random() * 256); }
                    }
                }
            }
        }
    }
}
