// ─────────────────────────────────────────────────────────────────────────────
//  rice-boot — secuencia de arranque MAGI al iniciar sesión (autostart.lua).
//
//  Pantalla negra → el tubo se enciende (punto → línea → imagen) → encabezado
//  NERV, volcado de memoria y registro del sistema a los costados → se dibujan
//  los tres MAGI (BALTHASAR·2, CASPER·3, MELCHIOR·1), cada uno con su código
//  corriendo sin parar → votan uno por uno 承認 → ACCESO CONCEDIDO → interferencia
//  fuerte y el fósforo se apaga: el fondo se va primero y lo brillante queda
//  brillando un instante sobre el escritorio (que ya cargó detrás).
//  Cualquier tecla o clic lo saltea. Se cierra solo (seguro a 10 s).
//
//  La escena se dibuja en GRISES y shaders/post.frag la "revela" como fósforo
//  ámbar sobreexpuesto + grano + interferencia VHS. Si editás el shader:
//    /usr/lib/qt6/bin/qsb --qt6 -o shaders/post.frag.qsb shaders/post.frag
//  Sonidos: ~/.config/rice-sound/make-boot-sounds.py
//
//  Probar:  qs -c rice-boot
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property string mono:   "DepartureMono Nerd Font"
    readonly property string serif:  "Noto Serif"
    readonly property string jp:     "Noto Sans CJK JP"
    readonly property string user:   (Quickshell.env("USER") || "usuario").toUpperCase()
    function g(v) { v = Math.max(0, Math.min(1, v)); return Qt.rgba(v, v, v, 1); }   // intensidad → gris

    // ── Línea de tiempo (ms desde el inicio) ───────────────────────────────
    readonly property int tEnd: 6300
    readonly property int tOut: 5000        // empieza a apagarse el fósforo
    readonly property int tBurst: 4850      // ráfaga de interferencia antes de abrir
    readonly property var votes: [3100, 3450, 3800]
    readonly property int tOk: 4100
    property real t: 0
    NumberAnimation on t {
        id: clock
        from: 0; to: root.tEnd; duration: root.tEnd
        running: true
    }
    function at(a, b) { return Math.max(0, Math.min(1, (t - a) / (b - a))); }   // 0→1 entre a y b
    function kick(a, len) { return t >= a ? Math.exp(-(t - a) / len) : 0; }     // golpe que decae

    readonly property real power: at(150, 950)
    readonly property real outp: at(tOut, tEnd - 100)
    readonly property real glitch: Math.min(1,
          0.7 * kick(700, 260)                                   // al terminar de encender
        + 0.3 * (kick(votes[0], 160) + kick(votes[1], 160) + kick(votes[2], 160))
        + 0.45 * kick(tOk, 220)
        + (t >= tBurst ? 0.9 * at(tBurst, tBurst + 120) * (1 - at(tOut + 150, tOut + 700)) : 0))

    // Sonidos: PC vieja prendiendo, relé por voto, acorde de 承認, chasquido al abrir
    Sfx { id: sfx; names: ["boot-power", "boot-vote", "boot-ok", "boot-out"] }
    property int cue: 0
    onTChanged: {
        const cues = [[0, "boot-power"], [votes[0], "boot-vote"], [votes[1], "boot-vote"], [votes[2], "boot-vote"], [tOk, "boot-ok"], [tBurst, "boot-out"]];
        while (cue < cues.length && t >= cues[cue][0]) { if (t - cues[cue][0] < 400) sfx.play(cues[cue][1]); cue++; }
        if (t >= tEnd - 50) Qt.quit();
    }

    function skip() { if (t < tBurst) { clock.stop(); clock.from = tBurst; clock.duration = tEnd - tBurst; clock.start(); } }
    Timer { interval: 10000; running: true; onTriggered: Qt.quit() }   // por las dudas

    // ── Datos reales del sistema (para el registro) ────────────────────────
    property string host: "cachyos"
    property string kernel: ""
    property string cpu: ""
    property string mem: ""
    FileView { path: "/etc/hostname"; onLoaded: root.host = text().trim() }
    FileView { path: "/proc/sys/kernel/osrelease"; onLoaded: root.kernel = text().trim() }
    FileView {
        path: "/proc/cpuinfo"
        onLoaded: {
            const s = text(), m = s.match(/model name\s*:\s*(.*)/);
            if (m) root.cpu = m[1].replace(/ with .*/, "").replace(/\s+/g, " ").toUpperCase() + " ×" + (s.match(/^processor/gm) || []).length;
        }
    }
    FileView {
        path: "/proc/meminfo"
        onLoaded: { const m = text().match(/MemTotal:\s*(\d+)/); if (m) root.mem = (m[1] / 1048576).toFixed(1).replace(".", ",") + " GiB"; }
    }

    PanelWindow {
        id: win
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "rice-boot"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        // Negro opaco hasta que empieza la salida: así no se ve nada de atrás
        // aunque el shader tarde un cuadro en cargar
        color: root.t < root.tOut - 10 ? "black" : "transparent"

        Item {
            id: stage
            anchors.fill: parent
            focus: true
            Keys.onPressed: (e) => { root.skip(); e.accepted = true; }
            MouseArea { anchors.fill: parent; cursorShape: Qt.BlankCursor; onClicked: root.skip() }   // sin cursor durante el arranque

            Scene { id: scene; anchors.fill: parent; r: root }

            ShaderEffectSource {
                id: sceneTex
                sourceItem: scene
                hideSource: true
                mipmap: true          // los niveles chicos hacen el halo
                smooth: true
                visible: false
            }
            ShaderEffect {
                anchors.fill: parent
                property var src: sceneTex
                property real time: root.t / 1000
                property real power: root.power
                property real glitch: root.glitch
                property real outp: root.outp
                property size res: Qt.size(width, height)
                fragmentShader: Qt.resolvedUrl("shaders/post.frag.qsb")
            }
        }
    }
}
