//@ pragma IconTheme Colloid-Orange-Dark
// (↑ mismo tema de íconos que las apps GTK; Quickshell lee esa línea al arrancar)
// ─────────────────────────────────────────────────────────────────────────────
//  rice-launcher — lanzador de apps estilo panel retro (versión 2: Quickshell)
//
//  Misma pinta y mismo comportamiento que la versión kitty + fzf
//  (~/.config/rice-launcher/launcher.sh), pero como panel propio:
//  abre al instante, se puede usar con el mouse y muestra íconos.
//
//   ┌──────────────────────────────┬──────────────────────┐
//   │  logo + info del sistema     │                      │
//   │  (fastfetch)                 │  検索 ─ buscar        │
//   │                              │  ❯ _                 │
//   │  ● ● ● ● ● ● ● ●             │  ★ apps más usadas   │
//   └──────────────────────────────┴──────────────────────┘
//
//  Corre siempre en segundo plano (lo arranca hypr/config/autostart.lua) y
//  Super+Espacio lo muestra u oculta con:
//      qs -c rice-launcher ipc call launcher toggle
//
//  Teclas: escribir = buscar · ↑↓ (o Ctrl+K/J, Ctrl+P/N) = moverse ·
//          Enter = abrir · Esc = cerrar.  Mouse: clic = abrir, rueda = moverse.
//
//  Comparte datos con la versión kitty (podés alternar sin perder nada):
//   ~/.local/share/rice-launcher/counts.tsv → "veces<TAB>app.desktop" (las ★)
//   ~/.cache/rice-launcher/info.ansi        → copia de la salida de fastfetch
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "Ansi.js" as Ansi
import "Fuzzy.js" as Fuzzy

ShellRoot {
    id: root

    // ── Ajustes ─────────────────────────────────────────────────────────────
    readonly property int    topN:      5        // cuántas ★ mostrar (3–5 queda bien)
    readonly property real   widthPct:  0.60     // tamaño del panel respecto de la pantalla
    readonly property real   heightPct: 0.56
    readonly property real   logoPct:   0.46     // ancho de la columna del logo (izquierda)
    readonly property string logoFile:  home + "/.config/rice-logo/logo.png"
    readonly property string noiseFile: home + "/.config/quickshell/rice-noise/noise-soft.png"
    readonly property real   noiseStrength: 0.0  // apagado: el grano lo pone rice-noise en toda la pantalla
    readonly property int    padding:   26
    readonly property int    radius:    8        // igual que las ventanas (decorations.lua)
    readonly property int    glow:      18       // alcance del brillo ámbar (shadow range)
    readonly property string fontName:  "DepartureMono Nerd Font"
    readonly property real   fontSize:  12

    // Paleta del rice (hypr/config/colors.lua y kitty/themes/rice-gruvbox.conf)
    readonly property color cBg:     Qt.rgba(0x1c / 255, 0x12 / 255, 0x0a / 255, 0.28) // marrón cálido al 28%
    readonly property color cFg:     "#ebdbb2"   // crema (texto escrito)
    readonly property color cDim:    "#a89984"   // apps no seleccionadas
    readonly property color cSel:    "#fabd2f"   // app seleccionada (dorado)
    readonly property color cSelBg:  "#3c3836"   // fondo de la seleccionada
    readonly property color cAmber:  "#fe8019"   // acento: prompt, ★, letras que coinciden
    readonly property color cOchre:  "#d79921"   // título
    readonly property color cMuted:  "#665c54"   // "· 4x"
    readonly property color cGold:   "#fabd2f"   // borde (degradé dorado → ámbar)
    readonly property color cGlow:   Qt.rgba(0xfe / 255, 0x80 / 255, 0x19 / 255, 0x55 / 255)

    readonly property string home:     Quickshell.env("HOME")
    readonly property string dataDir:  (Quickshell.env("XDG_DATA_HOME") || home + "/.local/share") + "/rice-launcher"
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/rice-launcher"

    // ── Estado ──────────────────────────────────────────────────────────────
    property bool   open:    false    // abierto (lógicamente)
    property bool   shown:   false    // ventana en pantalla (sigue un ratito al cerrar, por la animación)
    property string query:   ""
    property var    counts:  ({})     // { "app.desktop": veces }
    property var    entries: []       // lo que se ve en la lista

    // ── Atajo (Super+Espacio llama a esto) ─────────────────────────────────
    IpcHandler {
        target: "launcher"
        function toggle(): void { root.open ? root.hide() : root.show() }
        function show(): void   { root.show() }
        function hide(): void   { root.hide() }
    }

    Sfx { id: sfx; names: ["open", "close", "select"] }

    function show() {
        closeAnim.stop();
        sfx.play("open");
        query = "";
        countsFile.reload();
        rebuild();
        refreshInfo.running = true;     // fastfetch en segundo plano; se ve la copia previa al toque
        uptimeFile.reload();
        typed = 0;                      // la info se vuelve a "tipear"
        randomizeBounce();
        crtX = 0.02; crtY = 0.006; flash = 1; bt = 0;
        open = true;
        shown = true;
        openAnim.restart();
        input.forceActiveFocus();       // que el teclado vaya directo al buscador
    }
    function hide() {
        if (!open) return;
        open = false;
        sfx.play("close");
        openAnim.stop();
        typer.stop();
        closeAnim.restart();            // se apaga como un tubo y recién ahí desaparece
    }

    // ── Animación: encendido CRT + rebote irregular ─────────────────────────
    //  1. Un punto se estira en una línea ámbar brillante (crtX)
    //  2. La línea se abre hacia arriba y abajo hasta ser el panel (crtY)
    //  3. Rebote amortiguado: mezcla de dos oscilaciones con frecuencias que
    //     no encajan entre sí (por eso es irregular), con dirección, fuerza,
    //     inclinación y duración sorteadas en cada apertura → nunca se repite.
    //  Al cerrar: se aplasta en una línea y la línea se encoge a un punto.
    property real crtX:  1          // escala horizontal del "tubo"
    property real crtY:  1          // escala vertical
    property real flash: 0          // brillo del encendido (0–1)
    property real bt:    1          // avance del rebote (0 → 1)
    property var  bp: ({ ay: 0, ax: 0, rot: 0, sc: 0, w1: 3, w2: 5, k: 0.4, ph: 0, ph2: 0, decay: 5 })

    function rnd(a, b) { return a + Math.random() * (b - a); }
    function sign()    { return Math.random() < 0.5 ? -1 : 1; }
    function randomizeBounce() {
        bp = {
            ay:  rnd(8, 22) * sign(),       // px de salto vertical
            ax:  rnd(0, 9) * sign(),        // px de corrimiento lateral
            rot: rnd(0, 1.3) * sign(),      // grados de inclinación
            sc:  rnd(0, 0.03) * sign(),     // "respiración" de tamaño
            w1:  rnd(2.2, 4.2),             // oscilaciones durante el rebote
            w2:  rnd(1.35, 2.8),            // relación de la segunda (no armónica)
            k:   rnd(0.15, 0.6),            // peso de la segunda
            ph:  rnd(0, Math.PI * 2),
            ph2: rnd(0, Math.PI * 2),
            decay: rnd(3.2, 6.0)            // qué tan rápido se calma
        };
        bounceAnim.duration = Math.round(rnd(650, 1050));
    }
    // Desplazamiento del rebote en el instante bt (todo tiende a 0 al final)
    function wob(amp, w, ph) {
        const t = bt, env = Math.exp(-bp.decay * t) * (1 - t);
        return amp * env * (Math.sin(2 * Math.PI * w * t + ph) + bp.k * Math.sin(2 * Math.PI * w * bp.w2 * t + bp.ph2));
    }
    readonly property real bY:   wob(bp.ay,  bp.w1,        0)
    readonly property real bX:   wob(bp.ax,  bp.w1 * 0.7,  bp.ph)
    readonly property real bRot: wob(bp.rot, bp.w1 * 1.1,  bp.ph2)
    readonly property real bSc:  wob(bp.sc,  bp.w1 * 0.9,  bp.ph)

    SequentialAnimation {
        id: openAnim
        NumberAnimation { target: root; property: "crtX"; to: 1; duration: 110; easing.type: Easing.OutCubic }
        ParallelAnimation {
            NumberAnimation { target: root; property: "crtY"; to: 1; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "flash"; to: 0; duration: 320; easing.type: Easing.OutQuad }
            SequentialAnimation {
                PauseAnimation { duration: 90 }
                ScriptAction { script: typer.start() }      // la info empieza a tipearse
            }
            SequentialAnimation {                           // el rebote arranca mientras el tubo
                PauseAnimation { duration: 50 }             // todavía se está abriendo (antes: al final)
                NumberAnimation { id: bounceAnim; target: root; property: "bt"; from: 0; to: 1; duration: 850 }
            }
        }
    }
    SequentialAnimation {
        id: closeAnim
        ScriptAction { script: root.bt = 1 }
        ParallelAnimation {
            NumberAnimation { target: root; property: "crtY"; to: 0.006; duration: 120; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "flash"; to: 0.9; duration: 100 }
        }
        NumberAnimation { target: root; property: "crtX"; to: 0; duration: 90; easing.type: Easing.InCubic }
        ScriptAction { script: root.shown = false }
    }

    // ── Info tipo máquina de escribir ──────────────────────────────────────
    property int typed: 0                        // cuántas líneas de info se ven
    readonly property var infoLines: Ansi.toHtml(infoFile.text()).split("<br>")
    Timer {
        id: typer
        interval: 22                             // ms por línea (12 líneas ≈ 0,3 s)
        repeat: true
        onTriggered: { root.typed++; if (root.typed >= root.infoLines.length) stop(); }
    }

    // ── Datos para la barra HUD ────────────────────────────────────────────
    SystemClock { id: clock; precision: SystemClock.Minutes }
    FileView { id: uptimeFile; path: "/proc/uptime"; printErrors: false }
    function uptimeText() {
        clock.date;                               // (se recalcula cada minuto)
        const secs = parseFloat(uptimeFile.text()) || 0;
        const h = Math.floor(secs / 3600), m = Math.floor(secs % 3600 / 60);
        return (h ? h + "h" : "") + m + "m";
    }

    // ── Datos ───────────────────────────────────────────────────────────────
    // ID de la app tal como lo guarda counts.tsv ("zen.desktop")
    function appId(e) { return e.id.endsWith(".desktop") ? e.id : e.id + ".desktop"; }

    // Apps visibles, ordenadas alfabéticamente (como la versión kitty)
    function allApps() {
        return DesktopEntries.applications.values
            .filter(e => !e.noDisplay && e.name)
            .slice()
            .sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base" }));
    }

    // Arma la lista: ★ más usadas arriba; con el buscador vacío se ven solo
    // ellas, al escribir se busca en todas (si no hay historial, todas).
    function rebuild() {
        const apps = allApps();
        const top = apps.filter(e => counts[appId(e)] > 0)
                        .sort((a, b) => counts[appId(b)] - counts[appId(a)])
                        .slice(0, topN);
        const topIds = top.map(appId);
        const rest = apps.filter(e => !topIds.includes(appId(e)));
        const all = top.map(e => ({ entry: e, star: true, count: counts[appId(e)] }))
                       .concat(rest.map(e => ({ entry: e, star: false, count: 0 })));

        if (query === "") {
            entries = top.length ? all.slice(0, top.length) : all;
        } else {
            const scored = [];
            all.forEach((it, i) => {
                const m = Fuzzy.match(query, it.entry.name);
                if (m) scored.push(Object.assign({ score: m.score, hits: m.hits, index: i }, it));
            });
            // mayor puntaje primero; si empatan, el orden de la lista (como --tiebreak=index)
            scored.sort((a, b) => (b.score - a.score) || (a.index - b.index));
            entries = scored;
        }
        list.currentIndex = 0;
    }

    function launch(item) {
        if (!item) return;
        const id = appId(item.entry);
        // +1 en counts.tsv (mismo formato que la versión kitty)
        const c = Object.assign({}, counts);
        c[id] = (c[id] || 0) + 1;
        counts = c;
        countsFile.setText(Object.keys(c).map(k => c[k] + "\t" + k).join("\n") + "\n");
        // Lanzar desacoplado, con UWSM como el resto del sistema
        Quickshell.execDetached(["uwsm", "app", "--", id]);
        sfx.play("select");
        hide();
    }

    FileView {
        id: countsFile
        path: root.dataDir + "/counts.tsv"
        blockLoading: true
        printErrors: false
        onLoaded: {
            const c = {};
            text().split("\n").forEach(line => {
                const p = line.split("\t");
                if (p.length >= 2 && p[1]) c[p[1]] = parseInt(p[0]) || 0;
            });
            root.counts = c;
        }
        onLoadFailed: root.counts = {}
    }

    FileView {
        id: infoFile
        path: root.cacheDir + "/info.ansi"
        watchChanges: true                  // se actualiza solo cuando fastfetch termina
        onFileChanged: reload()
        printErrors: false
    }

    // Igual que make_info en launcher.sh: fastfetch con logo chico, vía fish
    // para que el módulo "shell" diga fish. Como acá no corre dentro de una
    // terminal, fastfetch pone "qs" como terminal: sed lo cambia por kitty.
    Process {
        id: refreshInfo
        command: ["sh", "-c",
            'mkdir -p "$1" && kv=$(kitty --version | cut -d" " -f2) && '
            + 'fish -c "fastfetch --pipe false --logo none" 2>/dev/null '
            + '| sed "s/m\\(qs\\|quickshell\\)\\(\x1b\\[m\\)\\?$/mkitty $kv\\2/" '
            + '> "$1/info.ansi.tmp" && mv "$1/info.ansi.tmp" "$1/info.ansi"',
            "sh", root.cacheDir]
    }

    // Si se instala o desinstala algo mientras está abierto, refrescar
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { if (root.open) root.rebuild(); }
    }

    // ── Ventana ─────────────────────────────────────────────────────────────
    PanelWindow {
        id: win
        visible: root.shown
        // en el monitor que tiene el foco
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

        WlrLayershell.namespace: "rice-launcher"         // para las reglas de blur (windowrules.lua)
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        // La superficie es más grande que el panel para que entren el brillo y el rebote
        readonly property int slack: 34
        implicitWidth:  Math.round(screen.width  * root.widthPct)  + (root.glow + slack) * 2
        implicitHeight: Math.round(screen.height * root.heightPct) + (root.glow + slack) * 2

        // Escena: todo lo que se anima (encendido CRT + rebote) va acá adentro
        Item {
        id: stage
        anchors.fill: parent
        anchors.margins: win.slack
        transform: [
            Scale {
                origin.x: stage.width / 2; origin.y: stage.height / 2
                xScale: root.crtX * (1 + root.bSc)
                yScale: root.crtY * (1 + root.bSc)
            },
            Rotation { origin.x: stage.width / 2; origin.y: stage.height / 2; angle: root.bRot },
            Translate { x: root.bX; y: root.bY }
        ]

        // Brillo ámbar alrededor (como la sombra de las ventanas activas),
        // recortado para que no tiña el interior transparente del panel.
        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskInverted: true
                maskSource: panelMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
            RectangularShadow {
                anchors.fill: parent
                anchors.margins: root.glow
                radius: root.radius
                blur: root.glow
                spread: 0
                color: root.cGlow
            }
        }
        Item {
            id: panelMask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            Rectangle { anchors.fill: parent; anchors.margins: root.glow; radius: root.radius; color: "black" }
        }

        // Panel
        Item {
            id: panel
            anchors.fill: parent
            anchors.margins: root.glow

            // Fondo: marrón al 28% (el blur lo pone Hyprland) + grano de noise.png
            Rectangle { anchors.fill: parent; radius: root.radius; color: root.cBg }
            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: noiseMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }
                Image {
                    anchors.fill: parent
                    source: "file://" + root.home + "/.config/rice-launcher/noise.png"
                    fillMode: Image.Tile
                    smooth: false
                }
            }
            Item {
                id: noiseMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Rectangle { anchors.fill: parent; radius: root.radius; color: "black" }
            }

            // Borde fino con degradé dorado → ámbar (como col.active_border)
            Canvas {
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const g = ctx.createLinearGradient(0, 0, width, height);
                    g.addColorStop(0, root.cGold);
                    g.addColorStop(1, root.cAmber);
                    ctx.strokeStyle = g;
                    ctx.lineWidth = 1;
                    ctx.roundedRect(0.5, 0.5, width - 1, height - 1, root.radius, root.radius);
                    ctx.stroke();
                }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }

            // Destello del encendido (la "línea" brillante del tubo)
            Rectangle {
                anchors.fill: parent
                radius: root.radius
                color: "#ffd9a0"
                opacity: root.flash * 0.75
                visible: opacity > 0
                z: 10
            }

            // Contenido
            Item {
                id: content
                anchors.fill: parent
                anchors.margins: root.padding

                // Medidas de una "celda" de terminal, para copiar el layout de fzf
                FontMetrics { id: fm; font.family: root.fontName; font.pointSize: root.fontSize }
                readonly property real lineH: Math.round(fm.height * 1.1)   // kitty: cell_height 110%

                // ── Abajo: barra HUD ──
                Item {
                    id: hud
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: content.lineH + 10

                    Rectangle {                     // línea divisoria fina
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        height: 1
                        color: root.cOchre
                        opacity: 0.35
                    }
                    Row {
                        anchors { left: parent.left; bottom: parent.bottom }
                        height: content.lineH
                        Text {                      // luz de estado que late
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: "●&nbsp;"
                            textFormat: Text.RichText
                            color: root.cAmber
                            font.family: root.fontName
                            font.pointSize: root.fontSize
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: root.shown
                                NumberAnimation { to: 0.25; duration: 900; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0;  duration: 900; easing.type: Easing.InOutSine }
                            }
                        }
                        Text {
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            textFormat: Text.RichText
                            font.family: root.fontName
                            font.pointSize: root.fontSize
                            color: root.cDim
                            readonly property string sep: '&nbsp;<span style="color:' + root.cMuted + '">─</span>&nbsp;'
                            text: '<span style="color:' + root.cOchre + '">システム正常</span>' + sep + "SYS OK"
                                + sep + Qt.formatTime(clock.date, "HH:mm")
                                + sep + '<span style="color:' + root.cOchre + '">起動</span>&nbsp;' + root.uptimeText()
                        }
                    }
                    Text {                          // a la derecha: cantidad de apps y fecha
                        anchors { right: parent.right; bottom: parent.bottom }
                        height: content.lineH
                        verticalAlignment: Text.AlignVCenter
                        textFormat: Text.RichText
                        font.family: root.fontName
                        font.pointSize: root.fontSize
                        color: root.cMuted
                        text: '<span style="color:' + root.cOchre + '">アプリ</span>&nbsp;' + DesktopEntries.applications.values.filter(e => !e.noDisplay).length
                            + "&nbsp;─&nbsp;" + Qt.formatDate(clock.date, "yyyy.MM.dd")
                    }
                }

                // ── Izquierda: logo grande con ruido animado (como el fondo) ──
                Item {
                    id: logoBox
                    anchors { left: parent.left; top: parent.top; bottom: hud.top; bottomMargin: 8 }
                    width: parent.width * root.logoPct

                    Image {
                        id: logo
                        anchors.centerIn: parent
                        width: parent.width - 16
                        height: parent.height - 16
                        source: "file://" + root.logoFile
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        visible: false              // lo dibuja el efecto de abajo (con ruido)
                        layer.enabled: true
                    }
                    MultiEffect { anchors.fill: logo; source: logo }
                    // Ruido blanco animado, solo donde hay logo
                    Item {
                        anchors.fill: logo
                        clip: true
                        opacity: root.noiseStrength
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: logo
                            maskThresholdMin: 0.05
                            maskSpreadAtMin: 0.0
                        }
                        Image {
                            id: logoNoise
                            width: parent.width + 512; height: parent.height + 512
                            source: "file://" + root.noiseFile
                            fillMode: Image.Tile
                            smooth: true
                            transform: Scale { xScale: 2; yScale: 2 }
                        }
                        Timer {
                            interval: 166; running: root.shown && root.noiseStrength > 0; repeat: true    // 6 por segundo, calmo
                            onTriggered: { logoNoise.x = -Math.floor(Math.random() * 256) * 2; logoNoise.y = -Math.floor(Math.random() * 256) * 2; }
                        }
                    }
                }

                // ── Derecha: título, buscador y lista ──
                Item {
                    id: side
                    anchors { left: logoBox.right; leftMargin: 12; right: parent.right; top: parent.top; bottom: hud.top; bottomMargin: 8 }

                    Column {
                        anchors.fill: parent
                        spacing: 0

                        // Arriba: info del sistema (fastfetch sin logo), tipo máquina de escribir
                        Text {
                            id: info
                            width: parent.width
                            clip: true
                            textFormat: Text.RichText
                            font.family: root.fontName
                            font.pointSize: root.fontSize
                            lineHeight: 1.1
                            color: root.cFg
                            // altura fija = todas las líneas, así el buscador no salta mientras se tipea
                            height: root.infoLines.length * content.lineH
                            text: root.infoLines.slice(0, root.typed).join("<br>")
                                + (root.typed > 0 && root.typed < root.infoLines.length
                                   ? '<span style="color:' + root.cAmber + '">█</span>' : "")
                        }
                        Item { width: 1; height: content.lineH }   // separación

                        Text {
                            height: content.lineH
                            verticalAlignment: Text.AlignVCenter
                            text: "検索 ─ BUSCAR APPS"
                            color: root.cOchre
                            font.family: root.fontName
                            font.pointSize: root.fontSize
                        }

                        // Prompt
                        Row {
                            height: content.lineH
                            width: parent.width
                            Text {
                                height: parent.height
                                verticalAlignment: Text.AlignVCenter
                                text: "❯ "
                                color: root.cAmber
                                font.family: root.fontName
                                font.pointSize: root.fontSize
                            }
                            TextInput {
                                id: input
                                height: parent.height
                                width: parent.width - x
                                verticalAlignment: TextInput.AlignVCenter
                                color: root.cFg
                                font.family: root.fontName
                                font.pointSize: root.fontSize
                                focus: root.open
                                text: root.query
                                onTextEdited: { root.query = text; root.rebuild(); }

                                // Cursor de bloque ámbar que titila (como el de kitty)
                                cursorDelegate: Rectangle {
                                    width: fm.averageCharacterWidth
                                    height: content.lineH
                                    color: root.cAmber
                                    SequentialAnimation on opacity {
                                        loops: Animation.Infinite
                                        running: root.open
                                        PropertyAction { value: 1 }
                                        PauseAnimation { duration: 600 }
                                        PropertyAction { value: 0 }
                                        PauseAnimation { duration: 600 }
                                    }
                                }

                                Keys.onPressed: event => {
                                    const ctrl = event.modifiers & Qt.ControlModifier;
                                    const n = list.count;
                                    const move = d => { if (n) list.currentIndex = (list.currentIndex + d + n) % n; };  // --cycle
                                    if (event.key === Qt.Key_Escape) root.hide();
                                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.launch(root.entries[list.currentIndex]);
                                    else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) move(1);
                                    else if (event.key === Qt.Key_Up   || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) move(-1);
                                    else return;
                                    event.accepted = true;
                                }
                            }
                        }

                        // Lista de apps
                        ListView {
                            id: list
                            width: parent.width
                            height: parent.height - y - content.lineH   // deja lugar a la descripción
                            clip: true
                            model: root.entries
                            boundsBehavior: Flickable.StopAtBounds
                            highlightMoveDuration: 0

                            delegate: Rectangle {
                                id: row
                                required property var modelData
                                required property int index
                                readonly property bool sel: ListView.isCurrentItem
                                width: list.width
                                height: content.lineH
                                color: sel ? root.cSelBg : "transparent"

                                // ▌ marca la seleccionada · ★ = más usada · ícono · nombre · "· Nx"
                                Row {
                                    anchors.fill: parent
                                    spacing: 0

                                    Text {          // "▌★ " (o espacios, para que todo quede alineado)
                                        height: parent.height
                                        verticalAlignment: Text.AlignVCenter
                                        textFormat: Text.RichText
                                        font.family: root.fontName
                                        font.pointSize: root.fontSize
                                        text: '<span style="color:' + root.cAmber + '">'
                                            + (row.sel ? "▌" : "&nbsp;")
                                            + (row.modelData.star ? "★" : "&nbsp;")
                                            + "&nbsp;</span>"
                                    }

                                    Image {         // ícono de la app (si no tiene, un ícono genérico)
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.round(content.lineH * 0.9)
                                        height: width
                                        sourceSize: Qt.size(width * 2, height * 2)   // nítido aunque el shader agrande
                                        source: Quickshell.iconPath(row.modelData.entry.icon, "application-x-executable")
                                        asynchronous: true
                                        smooth: true
                                        opacity: row.sel ? 1.0 : 0.75                // las no seleccionadas, un poco apagadas
                                    }

                                    Text {
                                        height: parent.height
                                        width: parent.width - x
                                        verticalAlignment: Text.AlignVCenter
                                        textFormat: Text.RichText
                                        elide: Text.ElideRight
                                        font.family: root.fontName
                                        font.pointSize: root.fontSize
                                        color: row.sel ? root.cSel : root.cDim
                                        text: "&nbsp;" + Fuzzy.highlight(row.modelData.entry.name, row.modelData.hits, root.cAmber)
                                            + (row.modelData.star ? ' <span style="color:' + root.cMuted + '">· ' + row.modelData.count + "x</span>" : "")
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: list.currentIndex = row.index
                                    onClicked: root.launch(row.modelData)
                                }
                            }
                        }

                        // Descripción de la app seleccionada (tenue, una línea)
                        Text {
                            width: parent.width
                            height: content.lineH
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            font.family: root.fontName
                            font.pointSize: root.fontSize
                            color: root.cMuted
                            readonly property var cur: root.entries[list.currentIndex]?.entry ?? null
                            readonly property string desc: cur ? (cur.comment || cur.genericName || "") : ""
                            text: desc ? "── " + desc : ""
                        }
                    }
                }
            }
        }
        }   // fin de la escena (stage)
    }
}
