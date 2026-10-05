// ─────────────────────────────────────────────────────────────────────────────
//  Fuzzy.js — búsqueda difusa al estilo fzf: las letras escritas tienen que
//  aparecer en orden dentro del nombre ("frx" encuentra "Firefox").
//  Puntaje: más puntos si las letras van seguidas, si caen al principio de una
//  palabra o al principio del nombre. Devuelve también qué letras coincidieron
//  (para pintarlas en naranja).
// ─────────────────────────────────────────────────────────────────────────────
.pragma library

function match(query, text) {
    var q = query.toLowerCase().replace(/\s+/g, ""), t = text.toLowerCase();
    if (!q.length) return { score: 0, hits: [] };
    var hits = [], score = 0, ti = 0, prev = -2;
    for (var qi = 0; qi < q.length; qi++) {
        var found = t.indexOf(q[qi], ti);
        if (found < 0) return null;            // falta una letra → no coincide
        // Si la letra también aparece al inicio de una palabra más adelante y
        // todavía no veníamos en racha, preferir ese inicio de palabra.
        if (found !== prev + 1) {
            for (var k = found; k < t.length; k++) {
                if (t[k] === q[qi] && (k === 0 || /[\s\-_.]/.test(t[k - 1]))) { found = k; break; }
            }
        }
        score += 10;
        if (found === prev + 1) score += 15;                              // seguidas
        if (found === 0 || /[\s\-_.]/.test(t[found - 1])) score += 12;    // inicio de palabra
        score -= Math.min(found - prev - 1, 10);                          // huecos restan un poco
        hits.push(found);
        prev = found; ti = found + 1;
    }
    score -= hits[0] * 0.5;                    // empezar antes es mejor
    return { score: score, hits: hits };
}

// Nombre como HTML con las letras coincidentes resaltadas
function highlight(text, hits, color) {
    if (!hits || !hits.length) return esc(text);
    var out = "", set = {};
    for (var i = 0; i < hits.length; i++) set[hits[i]] = true;
    for (var j = 0; j < text.length; j++)
        out += set[j] ? '<span style="color:' + color + '">' + esc(text[j]) + "</span>" : esc(text[j]);
    return out;
}

function esc(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}
