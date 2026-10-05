// ─────────────────────────────────────────────────────────────────────────────
//  Ansi.js — convierte la salida de fastfetch (texto con códigos de color de
//  terminal) en HTML que Quickshell puede mostrar con los mismos colores.
//  Entiende lo que usa fastfetch: colores 24 bits (38;2;r;g;b), los 16 colores
//  básicos (30–37 / 90–97, y sus fondos 40–47 / 100–107), "reset" (ESC[m) y
//  saltos de columna (ESC[nG), que fastfetch usa para alinear la info al logo.
// ─────────────────────────────────────────────────────────────────────────────
.pragma library

// Los 16 colores de kitty (kitty/themes/rice-gruvbox.conf), para que se vean igual
var PALETTE = ["#1d2021", "#cc241d", "#98971a", "#d79921", "#458588", "#b16286", "#689d6a", "#a89984",
               "#665c54", "#fb4934", "#b8bb26", "#fabd2f", "#83a598", "#d3869b", "#8ec07c", "#ebdbb2"];

function hex(n) { return (n < 16 ? "0" : "") + n.toString(16); }

function esc(s) {
    // (los espacios van como &nbsp;: en HTML varios espacios seguidos se
    //  juntan en uno y se desarmaría la alineación del logo)
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/ /g, "&nbsp;");
}

// Devuelve HTML: una línea por renglón, con <span> de color.
function toHtml(text) {
    var lines = text.replace(/\n$/, "").split("\n");
    var out = [];
    for (var l = 0; l < lines.length; l++) {
        var line = lines[l];
        var fg = null, bg = null, col = 0, html = "";
        var re = /\x1b\[([0-9;]*)([A-Za-z])/g, last = 0, m;
        var put = function (s) {             // agrega texto visible con el color actual
            if (!s.length) return;
            var st = (fg ? "color:" + fg + ";" : "") + (bg ? "background-color:" + bg + ";" : "");
            html += st ? '<span style="' + st + '">' + esc(s) + "</span>" : esc(s);
            col += s.length;
        };
        while ((m = re.exec(line)) !== null) {
            put(line.slice(last, m.index));
            last = re.lastIndex;
            if (m[2] === "G") {               // ir a la columna n (se rellena con espacios)
                var target = parseInt(m[1] || "1") - 1;
                var savedBg = bg; bg = null;
                if (target > col) put(" ".repeat(target - col));
                bg = savedBg;
            } else if (m[2] === "m") {        // colores
                var p = m[1] === "" ? [0] : m[1].split(";").map(Number);
                for (var i = 0; i < p.length; i++) {
                    var c = p[i];
                    if (c === 0) { fg = null; bg = null; }
                    else if (c === 39) fg = null;
                    else if (c === 49) bg = null;
                    else if ((c === 38 || c === 48) && p[i + 1] === 2) {
                        var rgb = "#" + hex(p[i + 2]) + hex(p[i + 3]) + hex(p[i + 4]);
                        if (c === 38) fg = rgb; else bg = rgb;
                        i += 4;
                    } else if ((c === 38 || c === 48) && p[i + 1] === 5) {
                        var idx = p[i + 2];
                        var col256 = idx < 16 ? PALETTE[idx] : null;   // (fastfetch no usa los otros)
                        if (c === 38) fg = col256; else bg = col256;
                        i += 2;
                    }
                    else if (c >= 30 && c <= 37)   fg = PALETTE[c - 30];
                    else if (c >= 90 && c <= 97)   fg = PALETTE[c - 90 + 8];
                    else if (c >= 40 && c <= 47)   bg = PALETTE[c - 40];
                    else if (c >= 100 && c <= 107) bg = PALETTE[c - 100 + 8];
                    // 1 (negrita) y el resto se ignoran: la fuente pixel no tiene negrita
                }
            }
        }
        put(line.slice(last));
        out.push(html);
    }
    return out.join("<br>");
}
