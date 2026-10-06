// ─────────────────────────────────────────────────────────────────────────────
//  rice-console — "modo consola": menú de juegos a pantalla completa, entre
//  Linux y Windows. Estética de sistema en hibernación: fósforo verde (el
//  shader CRT pasa a GREEN_MODE mientras está abierto), código escribiéndose
//  de fondo y uno de los fondos verdes al azar en cada entrada.
//
//  · RECIENTES: los últimos jugados primero (fila tipo PlayStation).
//  · BIBLIOTECA: todo lo que tenés, instalado o no, con filtros.
//  · Elegir un juego abre abajo el menú (JUGAR, INSTALAR, TIENDA, OCULTAR).
//  · Juego de Linux → se abre. Juego de Windows → confirma y reinicia en
//    Windows directo a ese juego (console.sh windows …, ver PENDIENTES.md).
//
//  Control (pad.py), teclado y mouse:
//    cruceta/stick/flechas/WASD  mover        A/Enter/clic   elegir
//    B/Esc/clic derecho     volver       LB RB / Q E    cambiar sección
//    X / F                  filtro       Y / R          orden
//    Super+G o botón Xbox: abrir/cerrar el modo
//
//  Datos: ~/.config/rice-console/games.json (scan/scan.py + scan/covers.py)
//  IPC:   qs -c rice-console ipc call console toggle
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string cfg:  home + "/.config/rice-console"
    readonly property string state: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/rice-console"

    // ── Paleta: fósforo verde ──────────────────────────────────────────────
    readonly property var theme: ({
        font:  "DepartureMono Nerd Font",
        bg:    "#010805",
        deep:  "#04130b",
        line:  "#1d4d30",
        dim:   "#4f9466",
        fg:    "#b9f0c2",
        hi:    "#e4ffe2",
        warn:  "#ff6a4a",
        glow:  Qt.rgba(0.47, 1.0, 0.6, 0.55)
    })

    // ── Estado ──────────────────────────────────────────────────────────────
    property bool   open: false
    property bool   shown: false
    property string section: "recent"          // "recent" | "library"
    property int    recentIndex: 0
    property int    libIndex: 0
    property string filter: "todos"
    property string sortBy: "recent"           // "recent" | "played" | "alpha"
    property bool   sheetOpen: false
    property int    sheetIndex: 0
    property var    confirm: null              // { game, action } mientras se pregunta
    property int    confirmIndex: 1            // 0 = seguir, 1 = cancelar (por defecto, cancelar)
    property string toast: ""
    property string padName: ""
    property int    wallIndex: 0
    property var    games: []
    property var    hidden: []

    readonly property var filters: ["todos", "instalados", "steam", "epic", "xbox", "gog", "otros", "ocultos"]
    readonly property var walls: ["angel2_verde", "imagen_verde_sin_cara", "rei_verde", "verde_1", "verde_2", "verde_3"]

    readonly property var visibleGames: games.filter(g => !hidden.includes(g.id))
    readonly property var recent: visibleGames.filter(g => g.lastPlayed > 0 || g.installed)
                                              .slice(0, 24)
    // Búsqueda en la biblioteca (sin mayúsculas, acentos ni signos)
    property string query: ""
    function norm(t) {
        return (t || "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, "");
    }
    function openSearch() {
        if (phase !== "ui") return;
        section = "library"; sheetOpen = false;
        searchInput.forceActiveFocus();
    }
    function closeSearch() {
        libIndex = 0;
        libGrid.positionViewAtBeginning();
        stage.forceActiveFocus();
    }
    readonly property var library: {
        // "ocultos": solo los ocultos (para volver a mostrarlos)
        let l = (filter === "ocultos" ? games.filter(g => hidden.includes(g.id)) : visibleGames).filter(g => {
            switch (filter) {
            case "todos":      return true;
            case "instalados": return g.installed;
            case "ocultos":    return true;
            case "otros":      return !["steam", "epic", "xbox", "gog"].includes(g.store);
            default:           return g.store === filter;
            }
        });
        const q = norm(query);
        if (q !== "")
            l = l.filter(g => norm(g.title).includes(q));
        if (sortBy === "alpha")
            l = l.slice().sort((a, b) => a.title.localeCompare(b.title, undefined, { sensitivity: "base" }));
        else if (sortBy === "played")      // más horas primero (empates: el más reciente)
            l = l.slice().sort((a, b) => (b.playtime - a.playtime) || (b.lastPlayed - a.lastPlayed));
        return l;
    }
    readonly property var current: section === "recent" ? recent[recentIndex] : library[libIndex]

    // ── Datos ───────────────────────────────────────────────────────────────
    FileView {
        id: gamesFile
        path: root.cfg + "/games.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.games = JSON.parse(text()).games; } catch (e) { root.games = []; } }
    }
    FileView {
        id: hiddenFile
        path: root.state + "/hidden.json"
        printErrors: false
        onLoaded: { try { root.hidden = JSON.parse(text()); } catch (e) { root.hidden = []; } }
    }
    function unhideGame(g) {
        hidden = hidden.filter(id => id !== g.id);
        libIndex = Math.max(0, Math.min(library.length - 1, libIndex));
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && printf "%s" "$2" > "$1/hidden.json"',
                                 "sh", state, JSON.stringify(hidden)]);
    }
    function hideGame(g) {
        const ri = recentIndex, li = libIndex;
        hidden = hidden.concat([g.id]);
        // la lista se rearma: quedarse en el mismo lugar (ahora con el juego siguiente)
        recentIndex = Math.max(0, Math.min(recent.length - 1, ri));
        libIndex = Math.max(0, Math.min(library.length - 1, li));
        Qt.callLater(() => {
            row.positionViewAtIndex(recentIndex, ListView.Contain);
            libGrid.positionViewAtIndex(libIndex, GridView.Contain);
        });
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && printf "%s" "$2" > "$1/hidden.json"',
                                 "sh", state, JSON.stringify(hidden)]);
    }

    // Código real del rice para la "lluvia" de fondo
    property var codeLines: []
    Process {
        running: true
        command: ["sh", "-c",
            'cat "$HOME/.config/hypr/shaders/crt.frag" "$HOME/.config/hypr/config/shader.lua" '
            + '"$HOME/.config/quickshell/rice-console/pad.py" "$HOME/.config/rice-console/scan/scan.py" '
            + '"$HOME/.config/hypr/scripts/record.sh" "$HOME/.config/quickshell/rice-launcher/Fuzzy.js" 2>/dev/null '
            + '| sed "s/^[[:space:]]*//" | grep -v "^$" | cut -c1-80']
        stdout: StdioCollector {
            onStreamFinished: root.codeLines = text.split("\n").filter(l => l.length > 2)
        }
    }

    // ── Control ─────────────────────────────────────────────────────────────
    Process {
        id: pad
        running: true
        command: ["python3", "-u", Quickshell.shellDir + "/pad.py"]
        stdout: SplitParser {
            onRead: line => root.padEvent(line)
        }
        onExited: restartPad.start()
    }
    Timer { id: restartPad; interval: 3000; onTriggered: pad.running = true }

    function padEvent(line) {
        const p = line.split(" ");
        if (p[0] === "pad") {
            padName = p[1] === "connected" ? p.slice(2).join(" ") : "";
            return;
        }
        if (p[0] === "press" && p[1] === "guide") { toggle(); return; }
        if (!open) return;
        if (p[0] === "nav") navigate(p[1]);
        else if (p[0] === "press") button(p[1]);
    }

    // ── Abrir / cerrar ──────────────────────────────────────────────────────
    // Al arrancar (o recargarse este archivo) el modo está cerrado: que el
    // shader no quede en verde
    Component.onCompleted: Quickshell.execDetached(["sh", "-c", 'hyprctl dispatch "riceConsole(false)"; hyprctl dispatch "riceCursorHide(false)"'])

    IpcHandler {
        target: "console"
        function toggle(): void { root.toggle() }
        function close(): void  { root.hide() }
        // para pruebas: go("library") / go("recent"), key("down"), key("a")…
        function go(s: string): void { root.section = s; root.sheetOpen = false; }
        function openWall(i: int): void { root.appear(i); }
        function dbg(): string { return JSON.stringify({ phrases: root.phrases.length, recentIndex: root.recentIndex, mouseMode: root.mouseMode, lastMouse: [root.lastMouse.x, root.lastMouse.y], phase: root.phase, first: root.recent[0]?.title, contentX: row.contentX, originX: row.originX }); }
        function search(q: string): void { root.section = "library"; root.query = q; root.libIndex = 0; }
        function key(k: string): void { ["up", "down", "left", "right"].includes(k) ? root.navigate(k) : root.button(k); }
    }
    function toggle() { open ? hide() : appear(); }
    function appear(forceWall) {
        if (open) return;
        gamesFile.reload();
        hiddenFile.reload();
        let w = forceWall;
        if (w === undefined || w < 0 || w >= walls.length)
            do { w = Math.floor(Math.random() * walls.length); } while (walls.length > 1 && w === wallIndex);
        wallIndex = w;
        section = "recent"; recentIndex = 0; libIndex = 0; sheetOpen = false; confirm = null; toast = "";
        query = "";
        mouseMode = false;
        lastMouse = Qt.point(-1, -1);
        resetViews();
        boot.typed = 0;
        open = true;
        // Fase 1: foto del escritorio que se apaga como un tubo (ver offLayer)
        deskPow = 1; tube = 0; uiIn = 0; closing = false;
        phase = "off"; offStarted = false;
        Quickshell.execDetached(["hyprctl", "dispatch", "riceCursorHide(true)"]);   // sin mouse mientras arranca
        shown = true;
        offFallback.restart();
    }
    // La ventana estaba oculta: las vistas no se movieron solas → al principio,
    // con el margen izquierdo incluido (positionViewAtBeginning lo ignora y
    // dejaba el primer juego pegado al borde hasta moverse)
    function resetViews() {
        row.contentX = row.originX - row.leftMargin;
        libGrid.positionViewAtBeginning();
    }
    function hide() {
        if (!open) return;
        open = false;
        sfx.play("close");
        Quickshell.execDetached(["hyprctl", "dispatch", "riceCursorHide(false)"]);
        closeAnim.restart();      // el verde se apaga recién cuando la pantalla quedó negra
    }

    // ── Navegación ──────────────────────────────────────────────────────────
    // El mouse solo elige si se movió de verdad (si la lista pasa por debajo
    // del cursor quieto, no cuenta). Teclado/control → vuelve a modo teclado.
    property bool mouseMode: false
    property point lastMouse: Qt.point(-1, -1)
    function mouseMoved(p) {
        if (lastMouse.x < 0) { lastMouse = p; return; }   // primera vez: solo anotar dónde está
        if (Math.abs(p.x - lastMouse.x) + Math.abs(p.y - lastMouse.y) > 2) { lastMouse = p; mouseMode = true; }
    }
    // Rebote al chocar con el borde de la lista
    property real bumpX: 0
    property real bumpY: 0
    SequentialAnimation {
        id: bumpAnim
        property real dx: 0
        property real dy: 0
        ParallelAnimation {
            NumberAnimation { target: root; property: "bumpX"; to: bumpAnim.dx; duration: 70; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "bumpY"; to: bumpAnim.dy; duration: 70; easing.type: Easing.OutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "bumpX"; to: 0; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 3 }
            NumberAnimation { target: root; property: "bumpY"; to: 0; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 3 }
        }
    }
    function bump(dir) {
        bumpAnim.dx = dir === "left" ? 14 : dir === "right" ? -14 : 0;
        bumpAnim.dy = dir === "up" ? 14 : dir === "down" ? -14 : 0;
        bumpAnim.restart();
    }

    function navigate(dir) {
        if (phase !== "ui") return;      // mientras carga no se toca nada
        mouseMode = false;
        const before = [recentIndex, libIndex, sheetIndex, confirmIndex, sheetOpen].join();
        navigateRaw(dir);
        if ([recentIndex, libIndex, sheetIndex, confirmIndex, sheetOpen].join() !== before) sfx.play("nav");
    }
    function navigateRaw(dir) {
        if (confirm) {
            if (dir === "left" || dir === "right") confirmIndex = 1 - confirmIndex;
            return;
        }
        if (sheetOpen) {
            const n = actions(current).length;
            if (dir === "left")  sheetIndex = Math.max(0, sheetIndex - 1);
            if (dir === "right") sheetIndex = Math.min(n - 1, sheetIndex + 1);
            if (dir === "up" || dir === "down") sheetOpen = dir === "up";
            return;
        }
        if (section === "recent") {
            if (dir === "left")  { if (recentIndex > 0) recentIndex--; else bump(dir); }
            if (dir === "right") { if (recentIndex < recent.length - 1) recentIndex++; else bump(dir); }
            if (dir === "down")  openSheet();
        } else {
            const cols = libGrid.columns, n = library.length;
            let i = libIndex;
            if (dir === "left")  i -= 1;
            if (dir === "right") i += 1;
            if (dir === "up")    i -= cols;
            if (dir === "down")  i = (i + cols < n) ? i + cols
                                   : (Math.floor(i / cols) < Math.floor((n - 1) / cols) ? n - 1 : i + cols); // última fila incompleta
            if (i < 0 || i >= n || (dir === "left" && libIndex % cols === 0) || (dir === "right" && libIndex % cols === cols - 1))
                bump(dir);                                   // borde: rebota, no salta
            else libIndex = i;
        }
    }
    function button(b) {
        if (phase !== "ui") return;      // mientras carga no se toca nada
        mouseMode = false;
        if (b === "a") sfx.play("select");
        else if (b === "b" && (confirm || sheetOpen)) sfx.play("back");
        else if (["lb", "rb", "x", "y"].includes(b)) sfx.play("nav");
        if (confirm) {
            if (b === "a") { confirmIndex === 0 ? doAction(confirm.game, confirm.action, true) : (confirm = null); }
            if (b === "b") confirm = null;
            return;
        }
        if (sheetOpen) {
            if (b === "a") doAction(current, actions(current)[sheetIndex].id, false);
            if (b === "b") sheetOpen = false;
            return;
        }
        switch (b) {
        case "a":  openSheet(); break;
        case "b":  hide(); break;
        case "lb": case "rb": switchSection(); break;
        case "x":  if (section === "library") { filter = filters[(filters.indexOf(filter) + 1) % filters.length]; libIndex = 0; libGrid.positionViewAtBeginning(); } break;
        case "y":  if (section === "library") { sortBy = ({ recent: "played", played: "alpha", alpha: "recent" })[sortBy]; libIndex = 0; libGrid.positionViewAtBeginning(); } break;
        case "menu": hide(); break;
        }
    }
    function switchSection() {
        section = section === "recent" ? "library" : "recent";
        sheetOpen = false;
        stage.forceActiveFocus();
    }
    function openSheet() {
        if (!current) return;
        sheetIndex = 0;
        sheetOpen = true;
    }

    // ── Qué se puede hacer con cada juego ───────────────────────────────────
    function actions(g) {
        if (!g) return [];
        const a = [];
        const onLinux = (g.installedOn ?? []).includes("linux");
        const launch = g.launch ?? {};
        if (onLinux)
            a.push({ id: "play-linux", glyph: "", label: "JUGAR" });
        else if (g.installed)
            a.push({ id: "play-windows", glyph: "", label: "JUGAR EN WINDOWS", note: "reinicia la PC" });
        if (!onLinux && g.store === "steam")
            a.push({ id: "install-linux", glyph: "\u{f01da}", label: g.installed ? "INSTALAR EN LINUX" : "INSTALAR", note: "Steam + Proton" });
        if (!g.installed && launch.windows)
            a.push({ id: "install-windows", glyph: "", label: "INSTALAR EN WINDOWS", note: "reinicia la PC" });
        if (storeUrl(g))
            a.push({ id: "store", glyph: "\u{f04dc}", label: "TIENDA" });
        if (hidden.includes(g.id))
            a.push({ id: "unhide", glyph: "\u{f0208}", label: "MOSTRAR", note: "vuelve a las listas" });
        else
            a.push({ id: "hide", glyph: "\u{f0209}", label: "OCULTAR" });
        return a;
    }
    function storeUrl(g) {
        if (g.steamid && g.store === "steam") return "https://store.steampowered.com/app/" + g.steamid;
        if (g.store === "epic") return "https://store.epicgames.com/browse?q=" + encodeURIComponent(g.title);
        if (g.store === "gog")  return "https://www.gog.com/games?query=" + encodeURIComponent(g.title);
        if (g.steamid) return "https://store.steampowered.com/app/" + g.steamid;
        return "";
    }
    function doAction(g, id, confirmed) {
        if (!g) return;
        const needsConfirm = id === "play-windows" || id === "install-windows" || id === "hide";
        if (needsConfirm && !confirmed) {
            confirm = { game: g, action: id };
            confirmIndex = 1;
            callInfo = "";
            callProc.running = true;      // ¿hay una llamada? (se muestra en el cartel)
            return;
        }
        confirm = null;
        switch (id) {
        case "play-linux":
            Quickshell.execDetached([Quickshell.shellDir + "/console.sh", "linux", g.launch.linux]);
            sheetOpen = false;
            hide();
            break;
        case "install-linux":
            Quickshell.execDetached([Quickshell.shellDir + "/console.sh", "linux", "steam://install/" + g.steamid]);
            sheetOpen = false;
            hide();
            break;
        case "play-windows":
        case "install-windows":
            winProc.command = [Quickshell.shellDir + "/console.sh", "windows", JSON.stringify({
                id: g.id, title: g.title, action: id === "play-windows" ? "play" : "install",
                launch: g.launch.windows, store: g.store, steamid: g.steamid ?? null,
                watch: g.watch ?? { dirs: [], procs: [] } })];
            winProc.running = true;
            toast = "PREPARANDO EL CAMBIO DE SISTEMA…";
            break;
        case "store":
            Quickshell.execDetached(["xdg-open", storeUrl(g)]);
            sheetOpen = false;
            hide();
            break;
        case "hide":
            hideGame(g);
            sheetOpen = false;
            break;
        case "unhide":
            unhideGame(g);
            sheetOpen = false;
            break;
        }
    }
    property string callInfo: ""
    Process {
        id: callProc
        command: [root.cfg + "/calls.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                let c = null; try { c = JSON.parse(text); } catch (e) {}
                const parts = [];
                if (c?.meet) parts.push("GOOGLE MEET");
                if (c?.discord) parts.push("DISCORD (abre la app; el canal lo elegís vos)");
                root.callInfo = parts.length ? "LLAMADA DETECTADA: " + parts.join(" + ") + " → se reconecta en Windows" : "SIN LLAMADA EN CURSO";
            }
        }
    }

    // Si console.sh windows vuelve, algo falló (si sale bien, la PC se reinicia)
    Process {
        id: winProc
        stderr: StdioCollector { id: winErr }
        onExited: (code) => { if (code !== 0) sfx.play("error"); if (code !== 0) root.toast = "NO SE PUDO PASAR A WINDOWS: " + (winErr.text.trim().split("\n").pop() || ("código " + code)); }
    }
    Timer { interval: 6000; running: root.toast !== "" && !winProc.running; onTriggered: root.toast = "" }

    // ── Entrada en tres fases ──────────────────────────────────────────────
    //  "off":   la foto del escritorio (ámbar) se aplasta a una línea y a un
    //           punto, como un tubo que se apaga; el shader CRT se pausa para
    //           no aplicarlo dos veces sobre la foto.
    //  "boot":  a oscuras, Hyprland pasa a verde (GREEN_MODE); el tubo se
    //           prende y el "sistema" piensa: líneas de arranque, spinner,
    //           hexadecimal y barra (~2,5 s).
    //  "ui":    aparece el menú.
    property string phase: "ui"
    // Encendido/apagado de tubo con el shader del arranque MAGI
    // (../rice-fx/crtfx.frag): power 1 = imagen, 0 = tubo apagado
    property real deskPow: 1       // foto del escritorio (al entrar se apaga, al salir se prende)
    property real tube: 1          // la interfaz del modo consola
    property bool closing: false   // saliendo: se ve la foto del escritorio prendiéndose
    property bool offStarted: false
    property real fxTime: 0
    FrameAnimation {
        running: root.shown && (root.tube < 1 || root.phase === "off" || root.closing)
        onTriggered: root.fxTime += frameTime
    }
    function startOff() {
        if (offStarted) return;
        offStarted = true;
        Quickshell.execDetached(["hyprctl", "dispatch", "riceShaderHold(true)"]);
        sfx.play("off");
        offAnim.restart();
    }
    Timer { id: offFallback; interval: 600; onTriggered: root.startOff() }   // si la foto no llega
    SequentialAnimation {
        id: offAnim
        NumberAnimation { target: root; property: "deskPow"; to: 0; duration: 560 }   // imagen → línea → punto
        PauseAnimation { duration: 120 }
        ScriptAction { script: {
            // a oscuras: cambio a verde sin que se vea el salto
            Quickshell.execDetached(["sh", "-c", 'hyprctl dispatch "riceConsole(true)" && hyprctl dispatch "riceShaderHold(false)"']);
        } }
        PauseAnimation { duration: 160 }
        ScriptAction { script: { root.phase = "boot"; sfx.play("open"); openAnim.restart(); } }
    }

    // ── Animación de entrada: el tubo se enciende ──────────────────────────
    property real uiIn: 1          // 0 → 1: aparece la interfaz después del arranque
    SequentialAnimation {
        id: openAnim
        ScriptAction { script: { root.tube = 0; root.uiIn = 0; boot.typed = 0; } }
        NumberAnimation { target: root; property: "tube"; to: 1; duration: 800 }   // punto → línea → imagen con fogonazo
        ScriptAction { script: boot.start() }
    }
    SequentialAnimation {
        id: closeAnim
        NumberAnimation { target: root; property: "tube"; to: 0; duration: 480 }   // la consola se apaga
        // A oscuras: sale el verde y se pausa el CRT (la foto del escritorio ya lo tiene)
        ScriptAction { script: {
            Quickshell.execDetached(["sh", "-c", 'hyprctl dispatch "riceConsole(false)"; hyprctl dispatch "riceShaderHold(true)"']);
            root.deskPow = 0; root.closing = true;
        } }
        PauseAnimation { duration: 140 }
        NumberAnimation { target: root; property: "deskPow"; to: 1; duration: 800 }   // el escritorio se prende
        ScriptAction { script: Quickshell.execDetached(["hyprctl", "dispatch", "riceShaderHold(false)"]) }
        PauseAnimation { duration: 50 }
        ScriptAction { script: { root.shown = false; root.closing = false; } }
    }
    // Líneas de arranque tipo BIOS, después aparece el menú
    Timer {
        id: boot
        property int typed: 0
        readonly property var lines: [
            "> 冬眠モード // HIBERNATION PROTOCOL",
            "> SUSPENDIENDO ENTORNO DE ESCRITORIO .......... OK",
            "> MONTANDO BIBLIOTECA: " + root.games.length + " TÍTULOS ........ OK",
            "> ENLACE CON SISTEMA SECUNDARIO [WINDOWS] ...... EN ESPERA",
            "> CONTROL: " + (root.padName || "NO DETECTADO"),
            "> LISTO."
        ]
        readonly property int thinkTicks: 22          // ~0,9 s "pensando" después de las líneas
        readonly property real progress: Math.max(0, Math.min(1, (typed - lines.length) / thinkTicks))
        interval: 40
        repeat: true
        onTriggered: {
            typed++;
            if (typed > lines.length + thinkTicks + 1) {
                stop(); root.phase = "ui"; root.resetViews(); uiAnim.restart();
                Quickshell.execDetached(["hyprctl", "dispatch", "riceCursorHide(false)"]);   // vuelve el mouse
            }
        }
    }
    NumberAnimation { id: uiAnim; target: root; property: "uiIn"; from: 0; to: 1; duration: 380; easing.type: Easing.OutCubic }
    function hexRow(n, seed) {
        let h = "", x = (n * 7919 + seed * 104729) >>> 0;
        for (let k = 0; k < 8; k++) { x = (x * 1103515245 + 12345) >>> 0; h += ((x >>> 8) & 0xffff).toString(16).padStart(4, "0").toUpperCase() + " "; }
        return h;
    }

    SystemClock { id: clock; precision: SystemClock.Seconds }

    Sfx { id: sfx; names: ["nav", "select", "back", "open", "close", "error", "off", "tick"] }

    // ── Pantalla ────────────────────────────────────────────────────────────
    PanelWindow {
        id: win
        visible: root.shown
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        WlrLayershell.namespace: "rice-console"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        // Transparente mientras se saca la foto del escritorio (si no, la foto
        // sería esta misma ventana en negro); negra apenas empieza el apagado
        color: root.phase === "off" && !root.offStarted ? "transparent" : "black"

        // Mientras el modo está abierto no se bloquea la pantalla por inactividad
        // (hypridle respeta este pedido, como cuando se mira un video)
        IdleInhibitor { window: win; enabled: root.open }

        Item {
            id: stage
            anchors.fill: parent
            visible: root.phase !== "off"
            focus: true
            // Mientras se prende/apaga, todo pasa por el shader del tubo
            layer.enabled: root.tube < 1
            layer.mipmap: true
            layer.samplerName: "src"
            layer.effect: ShaderEffect {
                property real time: root.fxTime
                property real power: root.tube
                property real glitch: 0.15 + 0.5 * (1 - root.tube)
                property real amount: 0.8
                property real bloomAmt: 0.45
                property real expo: 1.0
                property real sat: 1.0
                property size res: Qt.size(width, height)
                fragmentShader: "file://" + Quickshell.env("HOME") + "/.config/quickshell/rice-fx/crtfx.frag.qsb"
            }

            // scenePosition (en la ventana), no position: el escenario se estira
            // al encenderse y eso parecía un movimiento del mouse
            HoverHandler { onPointChanged: root.mouseMoved(point.scenePosition) }
            Keys.onPressed: (e) => {
                const k = e.key;
                // Buscar: "/" o Ctrl+F (antes que la F sola, que cambia el filtro)
                if (k === Qt.Key_Slash || (k === Qt.Key_F && (e.modifiers & Qt.ControlModifier))) {
                    root.openSearch(); e.accepted = true; return;
                }
                // Flechas o WASD
                if (k === Qt.Key_Left || k === Qt.Key_A)  root.navigate("left");
                else if (k === Qt.Key_Right || k === Qt.Key_D) root.navigate("right");
                else if (k === Qt.Key_Up || k === Qt.Key_W)    root.navigate("up");
                else if (k === Qt.Key_Down || k === Qt.Key_S)  root.navigate("down");
                else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) root.button("a");
                else if (k === Qt.Key_Escape || k === Qt.Key_Backspace) root.button("b");
                else if (k === Qt.Key_Q || k === Qt.Key_E || k === Qt.Key_Tab) root.button("rb");
                else if (k === Qt.Key_F) root.button("x");
                else if (k === Qt.Key_R) root.button("y");
                else return;
                e.accepted = true;
            }

            // Fondo: uno de los verdes, con un zoom lentísimo
            Image {
                id: wall
                anchors.fill: parent
                source: "file://" + root.cfg + "/wallpapers/" + root.walls[root.wallIndex] + ".png"
                fillMode: Image.PreserveAspectCrop
                transformOrigin: Item.Center
                opacity: root.uiIn
                NumberAnimation on scale { from: 1.0; to: 1.07; duration: 60000; loops: Animation.Infinite; easing.type: Easing.InOutSine; running: root.shown }
            }
            Rectangle {  // oscurece abajo para que se lean las tarjetas
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0;  color: Qt.rgba(0, 0.02, 0.01, 0.35) }
                    GradientStop { position: 0.55; color: Qt.rgba(0, 0.02, 0.01, 0.30) }
                    GradientStop { position: 1.0;  color: Qt.rgba(0, 0.02, 0.01, 0.88) }
                }
            }

            // Código escribiéndose todo el rato
            CodeColumn {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: 26 }
                width: 380
                lines: root.codeLines; fontName: root.theme.font; fontSize: 11
                color: root.theme.dim; speed: 26; opacity: 0.55; running: root.shown
            }
            CodeColumn {
                anchors { right: parent.right; top: parent.top; bottom: parent.bottom; rightMargin: 26 }
                width: 340
                lines: root.codeLines; fontName: root.theme.font; fontSize: 10
                color: root.theme.dim; speed: 41; opacity: 0.4; running: root.shown
            }
            CodeColumn {
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; bottom: parent.bottom }
                width: 520
                lines: root.codeLines; fontName: root.theme.font; fontSize: 10
                color: root.theme.line; speed: 63; opacity: 0.35; running: root.shown
            }

            // Arranque tipo BIOS
            Column {
                anchors.left: parent.left; anchors.top: parent.top
                anchors.margins: 80
                spacing: 6
                visible: root.uiIn < 1
                opacity: 1 - root.uiIn
                Repeater {
                    model: boot.lines.slice(0, boot.typed)
                    Text {
                        required property string modelData
                        text: modelData
                        font.family: root.theme.font; font.pixelSize: 20
                        color: modelData.includes("ESPERA") ? root.theme.warn : root.theme.fg
                    }
                }
                // "Pensando": spinner, volcado hexadecimal que cambia y barra
                Item { width: 1; height: 18; visible: boot.typed > boot.lines.length }
                Text {
                    visible: boot.typed > boot.lines.length
                    text: "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"[boot.typed % 10] + "  SINCRONIZANDO NÚCLEO MAGI-0" + (1 + Math.floor(boot.progress * 2.99))
                          + " ..... " + Math.round(boot.progress * 100) + "%"
                    font.family: root.theme.font; font.pixelSize: 20
                    color: root.theme.hi
                }
                Repeater {
                    model: boot.typed > boot.lines.length ? 6 : 0
                    Text {
                        required property int index
                        text: "  0x" + (0x7f3a00 + (boot.typed * 6 + index) * 16).toString(16).toUpperCase() + "   " + root.hexRow(boot.typed, index)
                        font.family: root.theme.font; font.pixelSize: 15
                        color: index === 5 ? root.theme.fg : root.theme.line
                    }
                }
                Rectangle {
                    visible: boot.typed > boot.lines.length
                    width: 620; height: 14
                    color: "transparent"; border.color: root.theme.line
                    Rectangle { x: 2; y: 2; height: 10; width: (parent.width - 4) * boot.progress; color: root.theme.fg }
                }
            }

            // ── Interfaz ──────────────────────────────────────────────────
            Item {
                id: ui
                anchors.fill: parent
                opacity: root.uiIn
                visible: root.uiIn > 0

                // Barra de arriba
                Item {
                    id: hud
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 40 }
                    height: 54

                    Row {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        spacing: 14
                        Rectangle {
                            width: warnTxt.implicitWidth + 18; height: 28; radius: 3
                            color: "transparent"; border.color: root.theme.warn; border.width: 1
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                id: warnTxt
                                anchors.centerIn: parent
                                text: "\u{f0026} 冬眠モード"
                                font.family: root.theme.font; font.pixelSize: 15
                                color: root.theme.warn
                            }
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite; running: root.shown
                                NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0;  duration: 900; easing.type: Easing.InOutSine }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "SISTEMA EN HIBERNACIÓN // MODO CONSOLA"
                            font.family: root.theme.font; font.pixelSize: 15
                            color: root.theme.dim
                        }
                    }

                    // Secciones (LB / RB)
                    Row {
                        anchors.centerIn: parent
                        spacing: 34
                        Text { text: "LB"; font.family: root.theme.font; font.pixelSize: 13; color: root.theme.line; anchors.verticalCenter: parent.verticalCenter }
                        Repeater {
                            model: [["recent", "RECIENTES"], ["library", "BIBLIOTECA"]]
                            Text {
                                required property var modelData
                                readonly property bool on: root.section === modelData[0]
                                text: modelData[1]
                                font.family: root.theme.font; font.pixelSize: 24
                                color: on ? root.theme.hi : root.theme.dim
                                font.underline: on
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -8
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.section = parent.modelData[0]; root.sheetOpen = false; }
                                }
                            }
                        }
                        Text { text: "RB"; font.family: root.theme.font; font.pixelSize: 13; color: root.theme.line; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Row {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        spacing: 18
                        Text {
                            text: "\u{f05ba} " + (root.padName ? "CONECTADO" : "SIN CONTROL")
                            font.family: root.theme.font; font.pixelSize: 15
                            color: root.padName ? root.theme.fg : root.theme.line
                        }
                        Text {
                            text: Qt.formatDateTime(clock.date, "hh:mm:ss")
                            font.family: root.theme.font; font.pixelSize: 22
                            color: root.theme.hi
                        }
                    }
                }
                Rectangle { anchors { left: hud.left; right: hud.right; top: hud.bottom; topMargin: 6 } height: 1; color: root.theme.line }

                // ── RECIENTES ─────────────────────────────────────────────
                Item {
                    id: recentView
                    anchors.fill: parent
                    visible: root.section === "recent"

                    // Info del seleccionado
                    Column {
                        anchors { left: parent.left; leftMargin: 90; bottom: row.top; bottomMargin: 60 }
                        width: parent.width - 180
                        spacing: 10
                        Image {
                            id: logo
                            source: root.current?.art?.logo ?? ""
                            visible: status === Image.Ready
                            height: 110
                            width: Math.min(520, implicitWidth * height / Math.max(1, implicitHeight))
                            fillMode: Image.PreserveAspectFit
                            sourceSize.height: 220
                        }
                        Text {
                            visible: !logo.visible
                            text: root.current?.title ?? ""
                            font.family: root.theme.font; font.pixelSize: 54
                            color: root.theme.hi
                            width: parent.width; elide: Text.ElideRight
                        }
                        Text {
                            text: root.gameLine(root.current)
                            font.family: root.theme.font; font.pixelSize: 18
                            color: root.theme.fg
                        }
                    }

                    ListView {
                        id: row
                        transform: Translate { x: root.bumpX }
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 170 }
                        height: 360
                        orientation: ListView.Horizontal
                        spacing: 26
                        leftMargin: 90; rightMargin: 90
                        model: root.recent
                        currentIndex: root.recentIndex
                        highlightRangeMode: ListView.ApplyRange
                        preferredHighlightBegin: 90
                        preferredHighlightEnd: width - 400
                        highlightMoveDuration: 220
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: GameTile {
                            required property int index
                            required property var modelData
                            game: modelData
                            width: 210; height: 315
                            anchors.verticalCenter: parent?.verticalCenter
                            theme: root.theme
                            selected: index === root.recentIndex && !root.confirm
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onPositionChanged: if (root.mouseMode && !root.sheetOpen && !root.confirm) root.recentIndex = parent.index
                                onClicked: (m) => {
                                    if (m.button === Qt.RightButton) { root.button("b"); return; }
                                    root.recentIndex = parent.index; root.openSheet();
                                }
                            }
                        }
                        WheelHandler { onWheel: (w) => root.navigate(w.angleDelta.y > 0 ? "left" : "right") }
                    }

                    // Mensaje del sistema (abajo a la izquierda): se escribe letra
                    // por letra, cambia cada ~7 s; lo tapa el menú al elegir un juego
                    Text {
                        id: sysMsg
                        anchors { left: parent.left; leftMargin: 90; bottom: parent.bottom; bottomMargin: 58 }
                        width: parent.width * 0.62
                        elide: Text.ElideRight
                        property string full: ""
                        property int shownChars: 0
                        text: "> " + full.slice(0, shownChars) + (cursorOn ? "█" : " ")
                        property bool cursorOn: true
                        font.family: root.theme.font; font.pixelSize: 26
                        color: root.theme.fg
                        style: Text.Outline; styleColor: Qt.rgba(0, 0.02, 0.01, 0.8)   // se lee sobre el fondo
                        Timer {   // tipeo
                            interval: 32; repeat: true
                            running: root.shown && root.section === "recent" && sysMsg.shownChars < sysMsg.full.length
                            onTriggered: sysMsg.shownChars++
                        }
                        Timer {   // cursor
                            interval: 530; repeat: true; running: root.shown
                            onTriggered: sysMsg.cursorOn = !sysMsg.cursorOn
                        }
                        Timer {   // siguiente mensaje
                            interval: 7000; repeat: true; triggeredOnStart: true
                            running: root.shown && root.phase === "ui" && root.section === "recent"
                            onTriggered: { sysMsg.full = root.nextMessage(); sysMsg.shownChars = 0; }
                        }
                    }
                }

                // ── BIBLIOTECA ────────────────────────────────────────────
                Item {
                    id: libView
                    anchors { fill: parent; topMargin: 130; leftMargin: 90; rightMargin: 90; bottomMargin: 90 }
                    visible: root.section === "library"

                    Row {
                        id: filterRow
                        spacing: 10
                        Text { text: "X"; font.family: root.theme.font; font.pixelSize: 13; color: root.theme.line; anchors.verticalCenter: parent.verticalCenter }
                        Repeater {
                            model: root.filters
                            Rectangle {
                                required property string modelData
                                readonly property bool on: root.filter === modelData
                                width: ft.implicitWidth + 22; height: 30; radius: 3
                                color: on ? root.theme.fg : "transparent"
                                border.color: on ? root.theme.fg : root.theme.line
                                Text {
                                    id: ft
                                    anchors.centerIn: parent
                                    text: parent.modelData.toUpperCase()
                                    font.family: root.theme.font; font.pixelSize: 14
                                    color: parent.on ? root.theme.bg : root.theme.fg
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.filter = parent.modelData; root.libIndex = 0; } }
                            }
                        }
                        Item { width: 30; height: 1 }
                        // Barra de búsqueda: clic, "/" o Ctrl+F. Enter/↓ = ir a los
                        // resultados · Esc = borrar (o salir si ya está vacía)
                        Rectangle {
                            id: searchBox
                            anchors.verticalCenter: parent.verticalCenter
                            width: 300; height: 32; radius: 3
                            color: searchInput.activeFocus ? Qt.rgba(0.02, 0.1, 0.05, 0.9) : "transparent"
                            border.color: searchInput.activeFocus ? root.theme.hi : root.theme.line
                            Text {
                                id: searchIcon
                                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                                text: ""
                                font.family: root.theme.font; font.pixelSize: 14
                                color: searchInput.activeFocus ? root.theme.hi : root.theme.dim
                            }
                            TextInput {
                                id: searchInput
                                anchors { left: searchIcon.right; leftMargin: 10; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                text: root.query
                                onTextEdited: { root.query = text; root.libIndex = 0; libGrid.positionViewAtBeginning(); }
                                font.family: root.theme.font; font.pixelSize: 15
                                color: root.theme.hi
                                selectionColor: root.theme.dim
                                cursorVisible: activeFocus
                                clip: true
                                Keys.onPressed: (e) => {
                                    if (e.key === Qt.Key_Escape) {
                                        if (text !== "") { root.query = ""; text = ""; }
                                        else root.closeSearch();
                                        e.accepted = true;
                                    } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Down || e.key === Qt.Key_Tab) {
                                        root.closeSearch();
                                        e.accepted = true;
                                    }
                                }
                            }
                            Text {
                                anchors { left: searchInput.left; verticalCenter: parent.verticalCenter }
                                visible: searchInput.text === "" && !searchInput.activeFocus
                                text: "BUSCAR   ( / )"
                                font.family: root.theme.font; font.pixelSize: 14
                                color: root.theme.line
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.IBeamCursor
                                onClicked: root.openSearch()
                            }
                        }
                        Item { width: 20; height: 1 }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Y  ORDEN: " + ({ recent: "RECIENTES", played: "MÁS JUGADO", alpha: "A-Z" })[root.sortBy] + "   ·   " + root.library.length + " JUEGOS"
                            font.family: root.theme.font; font.pixelSize: 14
                            color: root.theme.dim
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.button("y") }
                        }
                    }

                    GridView {
                        id: libGrid
                        transform: Translate { x: root.bumpX; y: root.bumpY }
                        readonly property int columns: Math.max(1, Math.floor(width / cellWidth))
                        anchors { left: parent.left; right: parent.right; top: filterRow.bottom; topMargin: 26; bottom: libInfo.top; bottomMargin: 14 }
                        cellWidth: 158; cellHeight: 232
                        clip: true
                        model: root.library
                        currentIndex: root.libIndex
                        highlightRangeMode: GridView.ApplyRange
                        preferredHighlightBegin: 40; preferredHighlightEnd: height - 40
                        highlightMoveDuration: 180
                        delegate: Item {
                            required property int index
                            required property var modelData
                            width: libGrid.cellWidth; height: libGrid.cellHeight
                            GameTile {
                                anchors.centerIn: parent
                                width: 138; height: 207
                                game: parent.modelData
                                compact: true
                                theme: root.theme
                                selected: parent.index === root.libIndex && !root.confirm
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onPositionChanged: if (root.mouseMode && !root.sheetOpen && !root.confirm) root.libIndex = parent.index
                                onClicked: (m) => {
                                    if (m.button === Qt.RightButton) { root.button("b"); return; }
                                    root.libIndex = parent.index; root.openSheet();
                                }
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: libGrid
                        visible: root.library.length === 0
                        text: "SIN RESULTADOS" + (root.query ? " PARA \"" + root.query.toUpperCase() + "\"" : "")
                        font.family: root.theme.font; font.pixelSize: 20
                        color: root.theme.dim
                    }
                    Text {
                        id: libInfo
                        anchors { left: parent.left; bottom: parent.bottom }
                        text: (root.current?.title ?? "") + "   " + root.gameLine(root.current)
                        font.family: root.theme.font; font.pixelSize: 18
                        color: root.theme.fg
                    }
                }

                // Ayuda de botones (abajo)
                Text {
                    anchors { right: parent.right; bottom: parent.bottom; margins: 40 }
                    text: root.confirm ? "A CONFIRMAR   B CANCELAR"
                        : root.sheetOpen ? "A ELEGIR   B VOLVER"
                        : "A ELEGIR   B SALIR   LB/RB SECCIÓN" + (root.section === "library" ? "   X FILTRO   Y ORDEN" : "")
                    font.family: root.theme.font; font.pixelSize: 15
                    color: root.theme.dim
                }


                // ── Menú de abajo (al elegir un juego) ─────────────────────
                Rectangle {
                    id: sheet
                    anchors { left: parent.left; right: parent.right }
                    height: 150
                    y: root.sheetOpen ? parent.height - height : parent.height + 10
                    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    color: Qt.rgba(0.0, 0.03, 0.015, 0.94)
                    Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: root.theme.fg }

                    Text {
                        anchors { left: parent.left; leftMargin: 90; top: parent.top; topMargin: 14 }
                        text: (root.current?.title ?? "").toUpperCase()
                        font.family: root.theme.font; font.pixelSize: 15
                        color: root.theme.dim
                    }
                    Row {
                        anchors { left: parent.left; leftMargin: 90; verticalCenter: parent.verticalCenter; verticalCenterOffset: 12 }
                        spacing: 18
                        Repeater {
                            model: root.sheetOpen ? root.actions(root.current) : []
                            Rectangle {
                                required property var modelData
                                required property int index
                                readonly property bool on: index === root.sheetIndex
                                width: Math.max(170, act.implicitWidth + 40); height: 62; radius: 4
                                color: on ? root.theme.fg : "transparent"
                                border.color: on ? root.theme.hi : root.theme.line
                                Column {
                                    id: act
                                    anchors.centerIn: parent
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.glyph + "  " + modelData.label
                                        font.family: root.theme.font; font.pixelSize: 19
                                        color: on ? root.theme.bg : root.theme.fg
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        visible: !!modelData.note
                                        text: modelData.note ?? ""
                                        font.family: root.theme.font; font.pixelSize: 12
                                        color: on ? root.theme.deep : root.theme.dim
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPositionChanged: if (root.mouseMode) root.sheetIndex = index
                                    onClicked: root.doAction(root.current, modelData.id, false)
                                }
                            }
                        }
                    }
                }

                // ── Confirmación: pasar a Windows ──────────────────────────
                Rectangle {
                    anchors.fill: parent
                    visible: !!root.confirm
                    color: Qt.rgba(0, 0.01, 0.005, 0.78)
                    MouseArea { anchors.fill: parent; onClicked: root.confirm = null }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 860; height: 310; radius: 6
                        color: root.theme.deep
                        border.color: root.theme.warn; border.width: 1
                        MouseArea { anchors.fill: parent }   // que el clic no cierre
                        Column {
                            anchors { fill: parent; margins: 34 }
                            spacing: 16
                            Text {
                                text: root.confirm?.action === "hide" ? "\u{f0209}  OCULTAR JUEGO" : "\u{f0026}  CAMBIO DE SISTEMA"
                                font.family: root.theme.font; font.pixelSize: 26
                                color: root.theme.warn
                            }
                            Text {
                                width: parent.width; wrapMode: Text.WordWrap
                                text: root.confirm?.action === "hide"
                                    ? "¿Seguro que querés ocultar " + (root.confirm?.game?.title ?? "") + "?\n"
                                      + "Lo saca de RECIENTES y de la BIBLIOTECA. No lo desinstala ni borra nada: "
                                      + "lo podés volver a mostrar desde BIBLIOTECA → filtro OCULTOS → MOSTRAR."
                                    : "La PC se va a reiniciar en Windows y va a " +
                                      (root.confirm?.action === "install-windows" ? "abrir la tienda para instalar " : "abrir ") +
                                      (root.confirm?.game?.title ?? "") + ".\nAl cerrar el juego vas a poder elegir volver a Linux."
                                font.family: root.theme.font; font.pixelSize: 18
                                color: root.theme.fg
                                lineHeight: 1.2
                            }
                            Text {
                                width: parent.width; wrapMode: Text.WordWrap
                                text: root.confirm?.action === "hide" ? "" : root.callInfo
                                font.family: root.theme.font; font.pixelSize: 15
                                color: root.callInfo.startsWith("LLAMADA") ? root.theme.hi : root.theme.dim
                            }
                            Row {
                                spacing: 20
                                Repeater {
                                    model: root.confirm?.action === "hide" ? ["\u{f0209}  OCULTAR", "CANCELAR"] : ["\u{f0709}  REINICIAR EN WINDOWS", "CANCELAR"]
                                    Rectangle {
                                        required property string modelData
                                        required property int index
                                        readonly property bool on: index === root.confirmIndex
                                        width: ct.implicitWidth + 44; height: 52; radius: 4
                                        color: on ? (index === 0 ? root.theme.warn : root.theme.fg) : "transparent"
                                        border.color: index === 0 ? root.theme.warn : root.theme.line
                                        Text {
                                            id: ct
                                            anchors.centerIn: parent
                                            text: parent.modelData
                                            font.family: root.theme.font; font.pixelSize: 18
                                            color: parent.on ? root.theme.bg : (parent.index === 0 ? root.theme.warn : root.theme.fg)
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onPositionChanged: if (root.mouseMode) root.confirmIndex = index
                                            onClicked: { root.confirmIndex = index; root.button("a"); }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Avisos (errores al pasar a Windows, etc.): arriba de todo
                Rectangle {
                    z: 50
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 118 }
                    visible: root.toast !== ""
                    width: toastTxt.implicitWidth + 40; height: 44; radius: 4
                    color: Qt.rgba(0.0, 0.02, 0.01, 0.92)
                    border.color: root.theme.warn
                    Text {
                        id: toastTxt
                        anchors.centerIn: parent
                        text: "\u{f0026} " + root.toast
                        font.family: root.theme.font; font.pixelSize: 17
                        color: root.theme.warn
                    }
                }
            }

        }

        // Foto del escritorio (se saca al entrar): en la fase "off" se apaga
        // como un tubo, y al salir se vuelve a prender antes de mostrar el real
        Loader {
            anchors.fill: parent
            active: root.shown
            visible: root.phase === "off" || root.closing
            sourceComponent: Item {
                MouseArea { anchors.fill: parent; cursorShape: Qt.BlankCursor; visible: root.phase === "off" }
                ScreencopyView {
                    id: shot
                    anchors.fill: parent
                    captureSource: win.screen
                    live: false
                    onHasContentChanged: if (hasContent) root.startOff()
                }
                ShaderEffectSource { id: shotTex; sourceItem: shot; hideSource: true; mipmap: true; smooth: true; visible: false }
                ShaderEffect {
                    anchors.fill: parent
                    visible: root.offStarted || root.closing   // antes de la foto, nada (si no, saldría en la foto)
                    property var src: shotTex
                    property real time: root.fxTime
                    property real power: root.deskPow
                    property real glitch: 0.15 + 0.5 * (1 - root.deskPow)
                    property real amount: 0.8
                    property real bloomAmt: 0.0
                    property real expo: 1.0
                    property real sat: 1.0
                    property size res: Qt.size(width, height)
                    fragmentShader: "file://" + Quickshell.env("HOME") + "/.config/quickshell/rice-fx/crtfx.frag.qsb"
                }
            }
        }
    }

    // ── Botón flotante en el escritorio vacío ──────────────────────────────
    //  Ventanita debajo de la Waybar, arriba a la derecha. Aparece (encendido
    //  de tubo) solo cuando el escritorio del monitor no tiene ventanas y el
    //  modo no está abierto; un clic entra al modo consola.
    Connections {
        target: Hyprland
        function onRawEvent(ev) { Hyprland.refreshWorkspaces(); }
    }
    readonly property var  btnMon: Hyprland.focusedMonitor
    readonly property bool btnWanted: !root.shown
        && (btnMon?.activeWorkspace?.toplevels.values.length ?? 1) === 0
        && !(btnMon?.activeWorkspace?.hasFullscreen ?? false)
    property real btnPop: 0                      // 0 = apagado, 1 = encendido
    // Cada animación frena a la otra: si cambiás rápido de escritorio/app, la
    // de aparecer (que espera 250 ms) no puede ganarle a la de desaparecer
    onBtnWantedChanged: {
        if (btnWanted) { btnOut.stop(); btnIn.restart(); }
        else { btnIn.stop(); btnOut.restart(); }
    }
    // Red de seguridad: si quedó visible donde no corresponde, apagarla
    Timer {
        interval: 500; repeat: true
        running: root.btnPop > 0
        onTriggered: {
            Hyprland.refreshWorkspaces();
            if (!root.btnWanted && !btnOut.running) { btnIn.stop(); btnOut.restart(); }
        }
    }
    SequentialAnimation {
        id: btnIn
        PauseAnimation { duration: 250 }         // que no parpadee al pasar entre ventanas
        NumberAnimation { target: root; property: "btnPop"; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
    }
    NumberAnimation { id: btnOut; target: root; property: "btnPop"; to: 0; duration: 140; easing.type: Easing.InCubic }

    PanelWindow {
        id: btnWin
        visible: root.btnPop > 0.001
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        WlrLayershell.namespace: "rice-console-button"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; right: true }
        margins { top: 50; right: 14 }
        implicitWidth: 260; implicitHeight: 96   // con lugar para el brillo
        color: "transparent"

        Item {
            id: btn
            readonly property bool hot: btnMouse.containsMouse
            width: 232; height: 64
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.top: parent.top; anchors.topMargin: 10
            // encendido de tubo: se abre de una línea al tamaño completo
            transform: Scale { origin.x: btn.width / 2; origin.y: btn.height / 2
                               xScale: Math.min(1, 0.3 + root.btnPop); yScale: Math.max(0.02, root.btnPop) }
            opacity: Math.min(1, root.btnPop * 1.5)

            Rectangle {
                id: btnBox
                anchors.fill: parent
                radius: 8
                color: btn.hot ? Qt.rgba(0.01, 0.07, 0.035, 0.82) : Qt.rgba(0x1c / 255, 0x12 / 255, 0x0a / 255, 0.72)
                border.width: 1
                border.color: btn.hot ? "#8ec07c" : "#d79921"
                Behavior on color { ColorAnimation { duration: 180 } }
                Behavior on border.color { ColorAnimation { duration: 180 } }
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: btn.hot ? Qt.rgba(0.56, 0.75, 0.49, 0.6) : Qt.rgba(0xfe / 255, 0x80 / 255, 0x19 / 255, 0.45)
                    shadowBlur: 0.8; blurMax: 24
                    shadowHorizontalOffset: 0; shadowVerticalOffset: 0
                }
            }
            Text {
                id: btnIcon
                anchors.left: parent.left; anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "\u{f05ba}"
                font.family: root.theme.font; font.pixelSize: 30
                color: btn.hot ? "#b9f0c2" : "#fabd2f"
            }
            Column {
                anchors.left: btnIcon.right; anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    text: btn.hot ? "遊 ENTRAR" : "MODO CONSOLA"
                    font.family: root.theme.font; font.pixelSize: 17
                    color: btn.hot ? "#e4ffe2" : "#ebdbb2"
                }
                Text {
                    text: "SUPER+G"
                    font.family: root.theme.font; font.pixelSize: 10
                    color: btn.hot ? "#4f9466" : "#928374"
                }
            }
            MouseArea {
                id: btnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.appear()
            }
        }
    }

    // Mensaje de abajo a la izquierda (sección RECIENTES): las mismas frases
    // de los subtítulos del escritorio (rice-subs/Phrases.js), en bolsa
    // aleatoria sin repetir hasta pasar por todas
    // Quickshell no deja importar archivos de otro componente: se lee como
    // texto y se sacan las frases entre comillas
    property var phrases: []
    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/rice-subs/Phrases.js"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const out = [];
            for (const line of text().split("\n")) {
                const m = line.match(/^\s*"((?:[^"\\]|\\.)*)"\s*,?\s*$/);
                if (m) out.push(m[1].replace(/\\"/g, '"'));
            }
            root.phrases = out;
        }
    }
    property var msgBag: []
    function nextMessage() {
        if (msgBag.length === 0)
            msgBag = (phrases.length ? phrases : ["OK computer."]).slice().sort(() => Math.random() - 0.5);
        const m = msgBag[0];
        msgBag = msgBag.slice(1);
        return m;
    }

    // "Steam · Windows · jugado hace 3 días · 126 h"
    function gameLine(g) {
        if (!g) return "";
        const names = { steam: "STEAM", epic: "EPIC GAMES", xbox: "XBOX", gog: "GOG", ea: "EA",
                        ubisoft: "UBISOFT", riot: "RIOT", roblox: "ROBLOX", local: "SIN TIENDA" };
        const parts = [names[g.store] ?? g.store];
        const where = (g.installedOn ?? []).includes("linux") ? " LINUX" : g.installed ? " WINDOWS" : "NO INSTALADO";
        parts.push(where);
        if (g.lastPlayed > 0) parts.push(ago(g.lastPlayed));
        if (g.playtime >= 60) parts.push(Math.round(g.playtime / 60) + " H");
        return parts.join("   ·   ");
    }
    function ago(t) {
        clock.date;
        const d = Math.floor((Date.now() / 1000 - t) / 86400);
        if (d <= 0) return "JUGADO HOY";
        if (d === 1) return "JUGADO AYER";
        if (d < 30) return "HACE " + d + " DÍAS";
        if (d < 365) return "HACE " + Math.floor(d / 30) + (Math.floor(d / 30) === 1 ? " MES" : " MESES");
        return "HACE " + Math.floor(d / 365) + (Math.floor(d / 365) === 1 ? " AÑO" : " AÑOS");
    }
}
