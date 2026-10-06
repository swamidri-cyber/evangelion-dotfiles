// ─────────────────────────────────────────────────────────────────────────────
//  rice-lock — pantalla de bloqueo con el look del arranque MAGI (reemplaza a
//  hyprlock, que queda de RESPALDO: lo lanza lock.sh si esto falla).
//
//  Aparece con encendido de tubo (punto → línea → imagen), interferencia VHS,
//  halo y grano. Contraseña por PAM (config "hyprlock", la misma de antes).
//  Error → 拒否 en rojo + sacudón. Correcta → 承認, la pantalla de bloqueo se
//  apaga y el escritorio se prende como un tubo (con la foto que sacó lock.sh),
//  y recién ahí se desbloquea.
//  3 s de gracia: si movés el mouse apenas se bloqueó, se desbloquea solo.
//
//  NO lanzar a mano: usar  ~/.config/hypr/scripts/lock.sh  (o Super+L).
//  Probar sin bloquear de verdad:  RICE_LOCK_TEST=1 qs -c rice-lock
//    (ventana común; la clave es "test")
//  Si quedara trabada: Ctrl+Alt+F3 → loguearte → pkill -f "qs -c rice-lock"
//    → lock.sh lanza hyprlock y desbloqueás con tu contraseña.
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

ShellRoot {
    id: root
    readonly property bool test: Quickshell.env("RICE_LOCK_TEST") === "1"
    readonly property string runDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string shotUrl: "file://" + runDir + "/rice-lock-shot.png"
    readonly property string mono: "DepartureMono Nerd Font"
    readonly property string jp:   "Noto Sans CJK JP"
    readonly property string user: (Quickshell.env("USER") || "usuario").toUpperCase()
    function g(v) { v = Math.max(0, Math.min(1, v)); return Qt.rgba(1.0 * v, 0.55 * v, 0.12 * v, 1); }   // intensidad → ámbar (Panel.qml)

    // ── Reloj ────────────────────────────────────────────────────────────────
    property real t: 0                       // ms desde que apareció
    FrameAnimation { running: true; onTriggered: root.t += frameTime * 1000 }
    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    // ── Estado ───────────────────────────────────────────────────────────────
    property string state: "idle"            // idle | check | fail | ok
    property int fails: 0
    property int pwLen: 0
    property string message: ""
    property real uiPow: 0
    property real deskPow: 0
    property bool showDesk: false
    property real shake: 0
    property real glitch: 0.05
    property real lockedAt: 0

    NumberAnimation { id: powerOn; target: root; property: "uiPow"; from: 0; to: 1; duration: 800 }
    SequentialAnimation {
        id: kick                              // ráfaga de interferencia
        NumberAnimation { target: root; property: "glitch"; to: 0.6; duration: 60 }
        NumberAnimation { target: root; property: "glitch"; to: 0.05; duration: 420; easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
        id: shakeAnim
        loops: 3
        NumberAnimation { target: root; property: "shake"; to: 14; duration: 40 }
        NumberAnimation { target: root; property: "shake"; to: -14; duration: 80 }
        NumberAnimation { target: root; property: "shake"; to: 0; duration: 40 }
    }
    // Desbloqueo: la interfaz se apaga → el escritorio se prende → se libera
    SequentialAnimation {
        id: unlockAnim
        PauseAnimation { duration: 350 }      // que se lea 承認
        NumberAnimation { target: root; property: "uiPow"; to: 0; duration: 480 }
        ScriptAction { script: {
            // a oscuras: se pausa el CRT de Hyprland (la foto ya lo tiene)
            Quickshell.execDetached(["hyprctl", "dispatch", "riceShaderHold(true)"]);
            root.deskPow = 0; root.showDesk = true;
        } }
        PauseAnimation { duration: 140 }
        ScriptAction { script: sfx.play("boot-out") }
        NumberAnimation { target: root; property: "deskPow"; to: 1; duration: 800 }
        ScriptAction { script: Quickshell.execDetached(["hyprctl", "dispatch", "riceShaderHold(false)"]) }
        PauseAnimation { duration: 50 }
        ScriptAction { script: root.release() }
    }
    function release() {
        if (!test) lock.locked = false;
        Qt.callLater(Qt.quit);
    }

    Sfx { id: sfx; names: ["boot-out", "boot-ok", "error", "tick"] }

    function appeared() {
        lockedAt = t;
        sfx.play("boot-out");
        powerOn.restart();
        kick.restart();
        if (!test) Quickshell.execDetached(["touch", runDir + "/rice-lock-ready"]);   // lock.sh: quedó bloqueado
    }

    // ── Contraseña ───────────────────────────────────────────────────────────
    property string pending: ""
    function submit(pw) {
        if (state === "check" || state === "ok" || pw === "") return;
        state = "check"; message = "";
        if (test) { pw === "test" ? succeed() : fail(); return; }
        pending = pw;
        if (!pam.start()) { message = "PAM NO RESPONDE"; fail(); }
    }
    function succeed() {
        state = "ok";
        sfx.play("boot-ok");
        kick.restart();
        unlockAnim.restart();
    }
    function fail() {
        state = "fail"; fails++;
        sfx.play("error");
        kick.restart(); shakeAnim.restart();
        failReset.restart();
    }
    Timer { id: failReset; interval: 2200; onTriggered: if (root.state === "fail") root.state = "idle" }

    PamContext {
        id: pam
        config: "hyprlock"
        onPamMessage: {
            if (responseRequired) { respond(root.pending); root.pending = ""; }
            else if (message !== "") root.message = message.toUpperCase();
        }
        onCompleted: (result) => { result === PamResult.Success ? root.succeed() : root.fail(); }
        onError: (err) => { root.message = "ERROR DE PAM"; root.fail(); }
    }

    // Gracia: mover el mouse en los primeros 3 s desbloquea sin clave
    function graceMove() {
        if (state === "idle" && t - lockedAt < 3000 && uiPow > 0) { state = "ok"; unlockAnim.restart(); }
    }

    // ── Superficies ──────────────────────────────────────────────────────────
    component Surface: Item {
        anchors.fill: parent
        LockView { anchors.fill: parent; r: root }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.BlankCursor
            property point first: Qt.point(-1, -1)
            onPositionChanged: (m) => {
                if (first.x < 0) { first = Qt.point(m.x, m.y); return; }
                if (Math.abs(m.x - first.x) + Math.abs(m.y - first.y) > 8) root.graceMove();
            }
        }
        TextInput {
            id: pw
            opacity: 0
            focus: true
            echoMode: TextInput.Password
            onTextChanged: { root.pwLen = text.length; if (root.state === "fail") root.state = "idle"; }
            Keys.onEscapePressed: text = ""
            onAccepted: { const s = text; text = ""; root.submit(s); }
            Component.onCompleted: forceActiveFocus()
        }
    }

    WlSessionLock {
        id: lock
        locked: false
        onSecureChanged: if (secure) root.appeared()
        WlSessionLockSurface {
            color: "black"
            Surface {}
        }
    }

    // Modo prueba: ventana común encima de todo (no bloquea nada)
    Loader {
        active: root.test
        sourceComponent: PanelWindow {
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "rice-lock-test"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "black"
            Surface {}
            Component.onCompleted: root.appeared()
        }
    }

    Component.onCompleted: if (!test) lock.locked = true
    // Solo en modo prueba: tipear por IPC (qs -c rice-lock ipc call lock attempt "test")
    IpcHandler {
        target: "lock"
        enabled: root.test
        function attempt(pw: string): void { root.pwLen = pw.length; Qt.callLater(() => { root.pwLen = 0; root.submit(pw); }); }
        function len(n: int): void { root.pwLen = n; }
    }
    // Seguro: si en modo prueba algo se traba, salir a los 60 s
    Timer { interval: 60000; running: root.test; onTriggered: Qt.quit() }
}
