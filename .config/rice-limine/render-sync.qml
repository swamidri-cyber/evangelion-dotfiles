// ─────────────────────────────────────────────────────────────────────────────
//  Diseño "SINCRONÍA" (cabina de prueba de sincronización) para el menú de
//  Limine y la pantalla de carga de Plymouth. Se cierra solo.
//    qs -p render-sync.qml
//  Genera:
//    limine-wallpaper.png             fondo del menú (dial lleno, ondas quietas)
//    plymouth/rice-magi/bg.png        fondo de la carga (dial apagado, sin ondas)
//    plymouth/rice-magi/*.png         piezas que anima el script
//  Las escenas se dibujan en grises y el shader del arranque las revela en
//  fósforo ámbar; las piezas animadas son PNG transparentes ámbar con brillo.
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
    WlrLayershell.namespace: "rice-sync-art"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true }
    implicitWidth: 1920; implicitHeight: 1080
    color: "black"

    readonly property string dir: Quickshell.shellDir + "/"
    readonly property string ply: dir + "plymouth/rice-magi/"
    readonly property string mono:  "DepartureMono Nerd Font"
    readonly property string serif: "Noto Serif"
    readonly property string jp:    "Noto Sans CJK JP"
    readonly property color amber: "#ff8a1c"
    readonly property color hot:   "#ffd9a0"
    function g(v) { v = Math.max(0, Math.min(1, v)); return Qt.rgba(v, v, v, 1); }

    // ── Geometría compartida (el script de Plymouth usa los mismos números) ──
    readonly property real cx: 960
    readonly property real cy: 540
    readonly property int  segs: 50          // segmentos del dial
    readonly property real a0: 135           // ángulo inicial (abajo a la izquierda), sentido horario
    readonly property real sweep: 270
    readonly property real segR: 300         // radio de los segmentos
    function segAngle(i) { return w.a0 + w.sweep * (i + 0.5) / w.segs; }
    // Osciloscopios (izquierda)
    readonly property var scopes: [
        { x: 60, y: 170, t: "PILOTO · 01", v: "±0,02" },
        { x: 60, y: 400, t: "UNIDAD · EVA", v: "±0,05" },
        { x: 60, y: 630, t: "SINCRONÍA · Δ", v: "Δ 0,2" }
    ]
    readonly property int scW: 540
    readonly property int scH: 170
    // Barras A10 (derecha)
    readonly property int barX: 1340
    readonly property int barY: 200
    readonly property int barH: 200
    readonly property int bars: 24
    readonly property int barW: 14
    readonly property int barGap: 8

    // Onda de un canal en la fase ph (0..2π); en el canal 2 van dos ondas que casi coinciden
    function wave(ch, ph, x) {
        const k = x / w.scW * Math.PI * 2;
        if (ch === 0) return 0.55 * Math.sin(3 * k + ph) + 0.25 * Math.sin(7 * k - 2 * ph) + 0.12 * Math.sin(17 * k + 3 * ph);
        if (ch === 1) return 0.45 * Math.sin(2 * k - ph) + 0.35 * Math.sin(5 * k + 2 * ph) + 0.15 * Math.sin(11 * k - 4 * ph);
        return 0.6 * Math.sin(4 * k + ph) + 0.18 * Math.sin(9 * k + 2 * ph);
    }
    function wavePts(ch, ph, off) {
        const pts = [];
        for (let x = 0; x <= w.scW; x += 3) pts.push(Qt.point(x, w.scH / 2 - w.wave(ch, ph, x) * w.scH * 0.36 + off));
        return pts;
    }
    function a10(i, t) { return 0.35 + 0.6 * Math.abs(Math.sin(i * 0.9 + t * (1.3 + (i % 5) * 0.21)) * Math.cos(i * 0.37 + t * 0.7)); }

    // ── Escena (en grises). full = Limine (todo dibujado); si no, Plymouth ──
    component Scene: Item {
        id: sc
        property bool full: true
        width: 1920; height: 1080

        // Retícula fina de fondo
        Repeater {
            model: 16 * 9
            Rectangle {
                required property int index
                x: (index % 16 + 0.5) * 120 - 1; y: (Math.floor(index / 16) + 0.5) * 120 - 1
                width: 2; height: 2; color: w.g(0.16)
            }
        }
        // Encabezado (doble línea)
        Text { x: 50; y: 32; text: "SINCRONIZACIÓN  //  シンクロテスト"; font.family: w.mono; font.pixelSize: 24; color: w.g(1) }
        Text { x: 50; y: 68; text: "NERV 本部  ·  PRUEBA DE ARRANQUE  ·  PILOTO: " + (Quickshell.env("USER") || "").toUpperCase(); font.family: w.mono; font.pixelSize: 14; color: w.g(0.45) }
        Text { anchors.right: parent.right; anchors.rightMargin: 50; y: 24; text: "接続"; font.family: w.jp; font.pixelSize: 48; font.weight: Font.Black; color: w.g(1) }
        Rectangle { x: 50; y: 104; width: 1820; height: 2; color: w.g(0.9) }
        Rectangle { x: 50; y: 110; width: 1820; height: 1; color: w.g(0.4) }

        // Osciloscopios
        Repeater {
            model: w.scopes
            Item {
                required property var modelData
                required property int index
                x: modelData.x; y: modelData.y; width: w.scW; height: w.scH
                Text { y: -26; text: modelData.t; font.family: w.jp; font.pixelSize: 15; font.bold: true; color: w.g(0.85) }
                Text { anchors.right: parent.right; y: -24; text: modelData.v; font.family: w.mono; font.pixelSize: 13; color: w.g(0.45) }
                Rectangle { anchors.fill: parent; color: w.g(0.03); border.color: w.g(0.6); border.width: 1.5 }
                Repeater { model: 17; Rectangle { required property int index; x: index * w.scW / 18 + w.scW / 18; width: 1; height: w.scH; color: w.g(0.1) } }
                Repeater { model: 5;  Rectangle { required property int index; y: (index + 1) * w.scH / 6; width: w.scW; height: 1; color: index === 2 ? w.g(0.28) : w.g(0.1) } }
                Shape {
                    visible: sc.full
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath { strokeColor: w.g(1); strokeWidth: 2; fillColor: "transparent"; PathPolyline { path: w.wavePts(index, 0.8, 0) } }
                    ShapePath { strokeColor: w.g(0.55); strokeWidth: 1.5; fillColor: "transparent"; PathPolyline { path: index === 2 ? w.wavePts(2, 1.0, 6) : [] } }
                }
            }
        }
        Text { x: 60; y: 830; text: "FRECUENCIA  60 Hz   ·   RUIDO  0,3 %   ·   FASE  ESTABLE"; font.family: w.mono; font.pixelSize: 13; color: w.g(0.45) }

        // Barras A10
        Text { x: w.barX; y: w.barY - 30; text: "CONEXIÓN NERVIOSA A10"; font.family: w.jp; font.pixelSize: 15; font.bold: true; color: w.g(0.85) }
        Rectangle { x: w.barX - 10; y: w.barY - 6; width: w.bars * (w.barW + w.barGap) + 12; height: w.barH + 12; color: w.g(0.03); border.color: w.g(0.6); border.width: 1.5 }
        Repeater {
            model: w.bars
            Item {
                required property int index
                x: w.barX + index * (w.barW + w.barGap); y: w.barY
                Rectangle { width: w.barW; height: w.barH; color: w.g(0.025) }
                Rectangle { visible: sc.full; y: w.barH * (1 - w.a10(index, 0.6)); width: w.barW; height: w.barH * w.a10(index, 0.6); color: w.g(0.9) }
            }
        }
        // Armónicos
        Text { x: w.barX; y: 450; text: "ARMÓNICOS  調和"; font.family: w.jp; font.pixelSize: 15; font.bold: true; color: w.g(0.85) }
        Rectangle { x: w.barX; y: 476; width: 520; height: 1; color: w.g(0.4) }
        Repeater {
            model: 9
            Item {
                required property int index
                readonly property real v: [0.98, 0.97, 0.99, 0.94, 0.96, 0.91, 0.99, 0.95, 0.97][index]
                x: w.barX; y: 490 + index * 30
                Text { text: "ARMÓNICO 0" + (index + 1) + "  ........  " + v.toFixed(2).replace(".", ","); font.family: w.mono; font.pixelSize: 14; color: w.g(0.55) }
                Rectangle { x: 380; y: 6; width: 140; height: 6; color: w.g(0.1) }
                Rectangle { x: 380; y: 6; width: 140 * (v - 0.8) / 0.2; height: 6; color: w.g(0.75) }
            }
        }
        Text { x: w.barX; y: 780; text: "LCL  98 %   ·   PRESIÓN  NOMINAL"; font.family: w.mono; font.pixelSize: 13; color: w.g(0.45) }
        Text { x: w.barX; y: 804; text: "PROFUNDIDAD DE ENCHUFE  ·  TOPE"; font.family: w.mono; font.pixelSize: 13; color: w.g(0.45) }

        // ── Dial de sincronía ────────────────────────────────────────────────
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {   // arco exterior (abierto abajo)
                strokeColor: w.g(0.55); strokeWidth: 1.5; fillColor: "transparent"
                PathAngleArc { centerX: w.cx; centerY: w.cy; radiusX: 345; radiusY: 345; startAngle: w.a0; sweepAngle: w.sweep }
            }
            ShapePath {   // arco interior
                strokeColor: w.g(0.4); strokeWidth: 2; fillColor: "transparent"
                PathAngleArc { centerX: w.cx; centerY: w.cy; radiusX: 262; radiusY: 262; startAngle: w.a0; sweepAngle: w.sweep }
            }
            ShapePath {   // arcos punteados de afuera (en Plymouth giran aparte)
                strokeColor: w.g(sc.full ? 0.35 : 0); strokeWidth: 3; fillColor: "transparent"
                strokeStyle: ShapePath.DashLine; dashPattern: [2, 6]
                PathAngleArc { centerX: w.cx; centerY: w.cy; radiusX: 372; radiusY: 372; startAngle: 150; sweepAngle: 110 }
            }
            ShapePath {
                strokeColor: w.g(sc.full ? 0.35 : 0); strokeWidth: 3; fillColor: "transparent"
                strokeStyle: ShapePath.DashLine; dashPattern: [2, 6]
                PathAngleArc { centerX: w.cx; centerY: w.cy; radiusX: 372; radiusY: 372; startAngle: 290; sweepAngle: 110 }
            }
        }
        // marcas del arco interior
        Repeater {
            model: 31
            Rectangle {
                required property int index
                readonly property real a: (w.a0 + w.sweep * index / 30) * Math.PI / 180
                x: w.cx + 250 * Math.cos(a) - 1; y: w.cy + 250 * Math.sin(a) - (index % 5 === 0 ? 8 : 4)
                width: 2; height: index % 5 === 0 ? 16 : 8
                color: w.g(index % 5 === 0 ? 0.6 : 0.3)
                transform: Rotation { origin.x: 1; origin.y: index % 5 === 0 ? 8 : 4; angle: w.a0 + w.sweep * index / 30 + 90 }
            }
        }
        // segmentos (Limine: encendidos hasta 99,8 %; Plymouth: apagados, el script prende sus copias)
        Repeater {
            model: w.segs
            Rectangle {
                required property int index
                readonly property real a: w.segAngle(index)
                x: w.cx + w.segR * Math.cos(a * Math.PI / 180) - 5
                y: w.cy + w.segR * Math.sin(a * Math.PI / 180) - 17
                width: 10; height: 34; radius: 2
                color: sc.full && index < 49 ? w.g(index > 44 ? 1 : 0.85) : w.g(0.045)
                transform: Rotation { origin.x: 5; origin.y: 17; angle: a + 90 }
            }
        }
        // números del dial
        Repeater {
            model: [[0, "0"], [0.5, "50"], [1, "100"]]
            Text {
                required property var modelData
                readonly property real a: (w.a0 + w.sweep * modelData[0]) * Math.PI / 180
                x: w.cx + 395 * Math.cos(a) - width / 2; y: w.cy + 395 * Math.sin(a) - height / 2
                text: modelData[1]
                font.family: w.mono; font.pixelSize: 16; color: w.g(0.6)
            }
        }
        // cruz fina del centro
        Rectangle { x: w.cx - 232; y: w.cy; width: 70; height: 1; color: w.g(0.3) }
        Rectangle { x: w.cx + 162; y: w.cy; width: 70; height: 1; color: w.g(0.3) }
        // rótulo de arriba dentro del dial
        Text {
            anchors.horizontalCenter: parent.horizontalCenter; y: w.cy - 215
            text: sc.full ? "SELECCIÓN DE NÚCLEO" : "シンクロ率"
            font.family: sc.full ? w.mono : w.jp; font.pixelSize: sc.full ? 15 : 22; font.bold: !sc.full
            color: w.g(0.7)
        }
        Text {
            visible: !sc.full
            anchors.horizontalCenter: parent.horizontalCenter; y: w.cy + 120
            text: "TASA DE SINCRONIZACIÓN"
            font.family: w.mono; font.pixelSize: 15; color: w.g(0.5)
        }
        Text {
            visible: sc.full
            anchors.horizontalCenter: parent.horizontalCenter; y: w.cy + 175
            text: "SYNC 99,8 %"
            font.family: w.mono; font.pixelSize: 15; color: w.g(0.6)
        }

        // Pie
        Rectangle { x: 50; y: 985; width: 1820; height: 1; color: w.g(0.5) }
        Text { x: 50; y: 1004; text: "ENTRY PLUG 挿入   ·   ENLACE: ESTABLE"; font.family: w.jp; font.pixelSize: 15; color: w.g(0.55) }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 50; y: 1004
            text: sc.full ? "↑ ↓  ELEGIR   ·   ENTER  ARRANCAR   ·   MOUSE  CLIC" : "第3新東京市  //  NERV 本部  //  MAGI SYSTEM ver 7.2"
            font.family: sc.full ? w.mono : w.jp; font.pixelSize: 14; color: w.g(0.5)
        }
    }

    Scene { id: sceneL; full: true }
    Scene { id: sceneP; full: false }
    ShaderEffectSource { id: texL; sourceItem: sceneL; hideSource: true; mipmap: true; smooth: true; visible: false }
    ShaderEffectSource { id: texP; sourceItem: sceneP; hideSource: true; mipmap: true; smooth: true; visible: false }
    ShaderEffect {   // Limine: con grano
        id: bgL; width: 1920; height: 1080
        property var src: texL
        property real time: 9.37; property real power: 1; property real glitch: 0; property real outp: 0
        property size res: Qt.size(width, height)
        fragmentShader: "file://" + w.dir + "limine.frag.qsb"
    }
    ShaderEffect {   // Plymouth: sin grano (pesa menos)
        id: bgP; width: 1920; height: 1080; x: 2500
        property var src: texP
        property real time: 9.37; property real power: 1; property real glitch: 0; property real outp: 0
        property size res: Qt.size(width, height)
        fragmentShader: "file://" + w.dir + "still-clean.frag.qsb"
    }

    // ── Piezas animadas (ámbar con brillo, transparentes) ───────────────────
    component Glow: MultiEffect {
        shadowEnabled: true; shadowColor: w.amber; shadowBlur: 0.55; shadowOpacity: 0.95
        shadowHorizontalOffset: 0; shadowVerticalOffset: 0
        autoPaddingEnabled: false
        x: 2500
    }
    // Ondas: un cuadro por fase (el script los alterna)
    readonly property int waveFrames: 30
    property int wch: 0
    property int wfr: 0
    Item {
        id: waveItem; width: w.scW; height: w.scH; visible: false
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath { strokeColor: w.hot; strokeWidth: 2; fillColor: "transparent"; PathPolyline { path: w.wavePts(w.wch, w.wfr / w.waveFrames * Math.PI * 2, 0) } }
            ShapePath { strokeColor: Qt.rgba(1, 0.55, 0.12, 0.8); strokeWidth: 1.5; fillColor: "transparent"
                        PathPolyline { path: w.wch === 2 ? w.wavePts(2, w.wfr / w.waveFrames * Math.PI * 2 + 0.25, 6 * Math.cos(w.wfr / w.waveFrames * Math.PI * 2)) : [] } }
        }
    }
    Glow { id: waveFx; source: waveItem; width: w.scW; height: w.scH }
    // Segmento encendido (una imagen por ángulo: el script no tiene que rotar nada)
    property int segI: 0
    Item {
        id: segItem; width: 60; height: 60; visible: false
        Rectangle {
            x: 25; y: 13; width: 10; height: 34; radius: 2; color: w.hot
            transform: Rotation { origin.x: 5; origin.y: 17; angle: w.segAngle(w.segI) + 90 }
        }
    }
    Glow { id: segFx; source: segItem; width: 60; height: 60 }
    // Anillo punteado que gira
    Item {
        id: ringItem; width: 800; height: 800; visible: false
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath { strokeColor: w.amber; strokeWidth: 3; fillColor: "transparent"; strokeStyle: ShapePath.DashLine; dashPattern: [2, 6]
                        PathAngleArc { centerX: 400; centerY: 400; radiusX: 372; radiusY: 372; startAngle: 150; sweepAngle: 110 } }
            ShapePath { strokeColor: w.amber; strokeWidth: 3; fillColor: "transparent"; strokeStyle: ShapePath.DashLine; dashPattern: [2, 6]
                        PathAngleArc { centerX: 400; centerY: 400; radiusX: 372; radiusY: 372; startAngle: 330; sweepAngle: 110 } }
            ShapePath { strokeColor: w.hot; strokeWidth: 5; fillColor: "transparent"; capStyle: ShapePath.FlatCap
                        PathAngleArc { centerX: 400; centerY: 400; radiusX: 383; radiusY: 383; startAngle: 260; sweepAngle: 18 } }
        }
    }
    Glow { id: ringFx; source: ringItem; width: 800; height: 800 }
    // Dígitos del porcentaje
    property string glyph: "0"
    Item {
        id: glyphItem; width: glyphText.implicitWidth + 8; height: 150; visible: false
        Text { id: glyphText; x: 4; anchors.verticalCenter: parent.verticalCenter; text: w.glyph; font.family: w.mono; font.pixelSize: w.glyph === "%" ? 64 : 112; color: w.hot }
    }
    Glow { id: glyphFx; source: glyphItem; width: glyphItem.width; height: 150 }
    // Rótulos de modo (abajo, en el hueco del dial)
    component Label: Item {
        id: lb
        property string kanji
        property string txt
        width: 640; height: 110; visible: false
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: lb.kanji; font.family: w.jp; font.pixelSize: 46; font.weight: Font.Black; color: w.hot }
        Text { anchors.horizontalCenter: parent.horizontalCenter; y: 66; text: lb.txt; font.family: w.mono; font.pixelSize: 24; color: w.amber }
    }
    Label { id: lBoot; kanji: "接続開始"; txt: "SINCRONIZANDO CACHYOS" }
    Label { id: lOff;  kanji: "接続解除"; txt: "DESCONECTANDO" }
    Label { id: lRe;   kanji: "再接続";   txt: "REINICIANDO" }
    Glow { id: lBootFx; source: lBoot; width: 640; height: 110 }
    Glow { id: lOffFx;  source: lOff;  width: 640; height: 110 }
    Glow { id: lReFx;   source: lRe;   width: 640; height: 110 }
    Item {
        id: online; width: 300; height: 30; visible: false
        Text { anchors.centerIn: parent; text: "●  ENLACE ESTABLE"; font.family: w.mono; font.pixelSize: 16; font.bold: true; color: w.hot }
    }
    Glow { id: onlineFx; source: online; width: 300; height: 30 }

    // ── Cola de grabación ────────────────────────────────────────────────────
    property var jobs: []
    function save(item, path, before) { jobs.push([item, path, before]); }
    Component.onCompleted: {
        save(bgL, w.dir + "limine-wallpaper.png");
        save(bgP, w.ply + "bg.png");
        save(ringFx, w.ply + "ring.png");
        save(lBootFx, w.ply + "label-boot.png");
        save(lOffFx, w.ply + "label-shutdown.png");
        save(lReFx, w.ply + "label-reboot.png");
        save(onlineFx, w.ply + "online.png");
        for (let c = 0; c < 3; c++)
            for (let f = 0; f < w.waveFrames; f++)
                save(waveFx, w.ply + "wave" + c + "-" + String(f).padStart(2, "0") + ".png", ((c, f) => () => { w.wch = c; w.wfr = f; })(c, f));
        for (let i = 0; i < w.segs; i++)
            save(segFx, w.ply + "seg" + String(i).padStart(2, "0") + ".png", ((i) => () => { w.segI = i; })(i));
        const gl = "0123456789,%";
        const names = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "comma", "pct"];
        for (let i = 0; i < gl.length; i++)
            save(glyphFx, w.ply + "d-" + names[i] + ".png", ((s) => () => { w.glyph = s; })(gl[i]));
    }
    property int job: 0
    function next() {
        if (job >= jobs.length) { Qt.quit(); return; }
        const j = jobs[job++];
        if (j[2]) j[2]();
        // un par de cuadros para que el cambio se dibuje antes de grabar
        settle.item = j[0]; settle.path = j[1]; settle.restart();
    }
    Timer {
        id: settle; interval: 60
        property var item; property string path
        onTriggered: item.grabToImage(function (r) { r.saveToFile(settle.path); w.next(); })
    }
    Timer { interval: 1500; running: true; onTriggered: w.next() }
}
}
