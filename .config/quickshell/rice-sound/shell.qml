// ─────────────────────────────────────────────────────────────────────────────
//  rice-sound — sonidos del sistema y música ambiente (autostart.lua).
//
//  · Efectos: los demás componentes los piden por IPC:
//      qs -c rice-sound ipc call sound play nav|select|back|open|close|error|tick|app|channel
//    Además suena "app" solo cuando se abre una ventana.
//  · Música ambiente (sfx/ambient.wav, loop de 60 s): entra despacio cuando el
//    escritorio está vacío y se va sola si abrís una ventana, si algo está
//    sonando (Spotify, videos: MPRIS) o si hay algo en pantalla completa.
//  · Super+F10 silencia / vuelve a activar todo.
//
//  Ajustes: ~/.config/rice-sound/settings.json
//    { "enabled": true, "sfx": 0.6, "ambient": 0.35, "appSound": true }
//  Sonidos: ~/.config/rice-sound/sfx (se regeneran con make-sounds.py)
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris

ShellRoot {
    id: root
    readonly property string dir: Quickshell.env("HOME") + "/.config/rice-sound"

    // ── Ajustes ─────────────────────────────────────────────────────────────
    property var cfg: ({ enabled: true, sfx: 0.6, ambient: 0.35, appSound: true })
    FileView {
        id: cfgFile
        path: root.dir + "/settings.json"
        watchChanges: true
        onFileChanged: reload()
        printErrors: false
        onLoaded: { try { root.cfg = Object.assign({ enabled: true, sfx: 0.6, ambient: 0.35, appSound: true }, JSON.parse(text())); } catch (e) {} }
        onLoadFailed: save()
    }
    function save() {
        cfgFile.setText(JSON.stringify(cfg, null, 2) + "\n");
    }

    // ── Efectos ─────────────────────────────────────────────────────────────
    readonly property var names: ["nav", "select", "back", "open", "close", "error", "tick", "app", "channel"]
    property var fx: ({})
    Instantiator {
        model: root.names
        delegate: SoundEffect {
            required property string modelData
            source: "file://" + root.dir + "/sfx/" + modelData + ".wav"
            volume: root.cfg.sfx
            Component.onCompleted: { const m = root.fx; m[modelData] = this; root.fx = m; }
        }
    }
    function play(name) {
        if (!cfg.enabled || !fx[name]) return;
        fx[name].play();
    }

    IpcHandler {
        target: "sound"
        function play(name: string): void { root.play(name) }
        function toggle(): void {
            const c = Object.assign({}, root.cfg); c.enabled = !c.enabled; root.cfg = c; root.save();
            if (c.enabled) root.play("select");
            Quickshell.execDetached(["notify-send", "-a", "Sonido", "-t", "1500",
                c.enabled ? "Sonidos activados" : "Sonidos silenciados"]);
        }
    }

    // Abrir una ventana → "app" (máx. uno cada 400 ms: hay apps que abren varias)
    property real lastApp: 0
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name === "openwindow" && root.cfg.appSound && Date.now() - root.lastApp > 400) {
                root.lastApp = Date.now();
                root.play("app");
            }
            if (ev.name.startsWith("openwindow") || ev.name.startsWith("closewindow")
                || ev.name.startsWith("workspace") || ev.name.startsWith("movewindow")
                || ev.name.startsWith("fullscreen"))
                Hyprland.refreshWorkspaces();
        }
    }

    // ── Música ambiente ─────────────────────────────────────────────────────
    readonly property var ws: Hyprland.focusedMonitor?.activeWorkspace ?? null
    readonly property bool deskEmpty: (ws?.toplevels.values.length ?? 1) === 0 && !(ws?.hasFullscreen ?? false)
    readonly property bool mediaPlaying: Mpris.players.values.some(p => p.isPlaying)
    readonly property bool ambWanted: cfg.enabled && cfg.ambient > 0 && deskEmpty && !mediaPlaying
    property real ambLevel: 0                         // 0..1, se anima (fundido)
    Behavior on ambLevel { NumberAnimation { duration: root.ambWanted ? 4000 : 1200; easing.type: Easing.InOutSine } }
    onAmbWantedChanged: ambLevel = ambWanted ? 1 : 0
    Component.onCompleted: ambLevel = ambWanted ? 1 : 0

    MediaPlayer {
        id: amb
        source: "file://" + root.dir + "/sfx/ambient.wav"
        loops: MediaPlayer.Infinite
        audioOutput: AudioOutput { volume: root.cfg.ambient * root.ambLevel }
    }
    // Solo reproduce mientras se escucha algo (no gasta en silencio)
    Timer {
        interval: 500; running: true; repeat: true
        onTriggered: {
            if (root.ambLevel > 0.001 && amb.playbackState !== MediaPlayer.PlayingState) amb.play();
            else if (root.ambLevel <= 0.001 && amb.playbackState === MediaPlayer.PlayingState) amb.pause();
        }
    }
}
