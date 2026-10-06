// Sonidos propios (sin pasar por IPC, para que no haya demora). Respeta los
// ajustes de rice-sound: ~/.config/rice-sound/settings.json (enabled, sfx).
import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io

Item {
    id: sfx
    property var names: []
    readonly property string dir: Quickshell.env("HOME") + "/.config/rice-sound"
    property var cfg: ({ enabled: true, sfx: 0.6 })
    property var fx: ({})
    FileView {
        path: sfx.dir + "/settings.json"
        watchChanges: true
        onFileChanged: reload()
        printErrors: false
        onLoaded: { try { sfx.cfg = Object.assign({ enabled: true, sfx: 0.6 }, JSON.parse(text())); } catch (e) {} }
    }
    Instantiator {
        model: sfx.names
        delegate: SoundEffect {
            required property string modelData
            source: "file://" + sfx.dir + "/sfx/" + modelData + ".wav"
            volume: sfx.cfg.sfx
            Component.onCompleted: { const m = sfx.fx; m[modelData] = this; sfx.fx = m; }
        }
    }
    function play(name) { if (cfg.enabled && fx[name]) fx[name].play(); }
}
