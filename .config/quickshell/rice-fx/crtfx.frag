#version 440
// ─────────────────────────────────────────────────────────────────────────────
//  crtfx.frag — el "look" del arranque MAGI para imágenes EN COLOR.
//  Lo usan: rice-wallfx (fondo de pantalla), rice-lock (bloqueo) y
//  rice-console (encendido/apagado del modo consola).
//
//  Interferencia tipo tracking de VHS o glitch digital (uniform style), halo (bloom) de lo brillante, más
//  exposición y saturación, grano animado, scanlines, barra de refresco,
//  viñeta y el encendido de tubo (punto → línea → imagen con fogonazo).
//  power = 1 → imagen normal; bajando a 0 → el tubo se apaga (al revés).
//
//  Compilar después de editar (y copiar el .qsb no hace falta: todos lo leen
//  de esta carpeta):
//    /usr/lib/qt6/bin/qsb --qt6 -o crtfx.frag.qsb crtfx.frag
// ─────────────────────────────────────────────────────────────────────────────
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float time;     // segundos
    float power;    // 0 = tubo apagado (negro), 1 = imagen completa
    float glitch;   // 0→1 interferencia extra (ráfagas)
    float amount;   // 0→1 fuerza general de distorsión/grano (0 = imagen limpia)
    float bloomAmt; // halo
    float expo;     // exposición (1 = igual)
    float sat;      // saturación (1 = igual)
    vec2  res;      // tamaño en píxeles
    float style;    // 0 = interferencia VHS (bloqueo, consola); 1 = glitch digital (fondo)
};
layout(binding = 1) uniform sampler2D src;   // imagen en color, con mipmaps

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
// ── Glitch digital ──────────────────────────────────────────────────────────
// Como un video comprimido que se rompe: macrobloques que se corren, toman otro
// pedazo de la imagen o se pixelan, y renglones finos que saltan de costado.
// Va a saltos (12 cuadros por segundo), no fluido. strength 0 = imagen limpia.
// Devuelve el uv corrido; split = separación de color extra (en uv).
vec2 dglitch(vec2 uv, float t, float strength, out float split) {
    split = 0.0;
    if (strength <= 0.001) return uv;
    float gt = floor(t * 12.0);
    vec2 ppx = uv * res;
    // Macrobloques anchos (128x32); algunos se parten en chicos (32x16)
    vec2 cell = floor(ppx / vec2(128.0, 32.0));
    if (hash(cell + vec2(gt * 0.13, 1.7)) > 0.55) cell = floor(ppx / vec2(32.0, 16.0)) + 977.0;
    float hit = step(1.0 - 0.30 * strength, hash(cell + vec2(gt * 1.7, 3.1)));
    vec2 d = vec2(hash(cell + vec2(gt, 5.0)) - 0.5, 0.0) * 0.16;
    d.y = (hash(cell + vec2(gt, 9.0)) - 0.5) * 0.05 * step(0.65, hash(cell + vec2(gt, 11.0)));
    vec2 g = uv + hit * d * strength;
    // La mitad de los bloques tocados se ven pixelados (8 px)
    if (hit > 0.5 && hash(cell + vec2(gt, 13.0)) > 0.5) g = (floor(g * res / 8.0) + 0.5) * 8.0 / res;
    split = hit * hash(cell + vec2(gt, 17.0)) * 7.0 / res.x * strength;
    // Renglones finos (4 px) que saltan
    float slice = floor(ppx.y / 4.0);
    float sl = step(1.0 - 0.05 * strength, hash(vec2(slice * 0.71, gt + 0.5)));
    g.x += sl * (hash(vec2(slice, gt + 2.0)) - 0.5) * 0.22 * strength;
    return g;
}

// Ráfagas del fondo: cada 4 s hay una chance (65 %) de un glitch corto
// (0,12–0,45 s) que además parpadea cuadro a cuadro.
float dburst(float t) {
    float slot = floor(t / 4.0);
    float local = t - slot * 4.0 - hash(vec2(slot, 1.0)) * 3.0;
    float len = 0.12 + 0.33 * hash(vec2(slot, 2.0));
    float on = step(0.0, local) * step(local, len) * step(0.35, hash(vec2(slot, 3.0)));
    return on * step(0.25, hash(vec2(floor(t * 12.0), 4.0)));
}

float lum(vec3 c) { return dot(c, vec3(0.30, 0.55, 0.15)); }

vec3 bright(vec2 uv, float lod) {   // solo lo claro aporta halo
    vec3 c = textureLod(src, uv, lod).rgb;
    return c * smoothstep(0.35, 0.85, lum(c));
}

void main() {
    vec2 uv = qt_TexCoord0;
    float t = time;
    float px = 1.0 / res.x;

    // ── Encendido / apagado de tubo ─────────────────────────────────────────
    float p = power;
    float lineW = smoothstep(0.0, 0.28, p);
    float openH = mix(0.003, 1.0, smoothstep(0.28, 0.62, p));
    float dy = uv.y - 0.5;
    float inside = step(abs(dy), openH * 0.5) * step(abs(uv.x - 0.5), lineW * 0.5 + 0.001) * step(0.0001, p);
    vec2 suv = vec2(uv.x, 0.5 + dy / openH);
    float flash = step(0.0001, p) * (1.0 - smoothstep(0.35, 1.0, p));

    // ── Distorsión: glitch digital (style 1) o interferencia VHS (style 0) ──
    vec2 duv;
    float ab;
    if (style > 0.5) {
        float split;
        duv = dglitch(suv, t, amount * dburst(t) + glitch, split);
        ab = 1.6 * px * amount + split;
    } else {
        float y = suv.y;
        float off = 0.0;
        for (int k = 0; k < 3; k++) {
            float fk = float(k);
            float dir = (k == 1) ? -1.0 : 1.0;
            float c = fract(0.23 + 0.37 * fk + dir * t * (0.06 + 0.035 * fk));
            float w = 0.010 + 0.016 * fract(fk * 0.618 + 0.3);
            float env = smoothstep(w, 0.0, abs(y - c));
            float amp = 9.0 * (k == 0 ? 1.0 : 0.55) * amount + glitch * 30.0;
            off += env * amp * px * (0.55 + 0.45 * sin(y * 820.0 + t * 15.0 + fk * 2.1));
        }
        float slot = floor(t * 1.25);
        float ph = fract(t * 1.25);
        if (hash(vec2(slot, 7.0)) > 0.4) {
            float c2 = hash(vec2(slot, 3.0)) + ph * 0.06;
            float w2 = 0.025 + 0.07 * hash(vec2(slot, 5.0));
            float e2 = smoothstep(w2, 0.0, abs(y - c2)) * sin(ph * 3.14159);
            off += e2 * (12.0 + 22.0 * hash(vec2(slot, 9.0))) * amount * px * sin(y * 260.0 + t * 9.0);
        }
        float row = floor(y * res.y / 3.0);
        float pick = step(0.72, hash(vec2(row * 0.37, floor(t * 14.0))));
        off += glitch * (hash(vec2(row, floor(t * 30.0))) - 0.5) * 70.0 * px * pick;
        off += (hash(vec2(floor(y * res.y), floor(t * 50.0))) - 0.5) * 0.9 * px * amount;
        duv = vec2(suv.x + off, suv.y);
        ab = 1.6 * px * (amount + glitch * 4.0 + abs(off) / px * 0.15);
    }

    // ── Color ────────────────────────────────────────────────────────────────
    vec3 col = vec3(texture(src, duv + vec2(ab, 0.0)).r, texture(src, duv).g, texture(src, duv - vec2(ab, 0.0)).b);
    vec3 glow = bright(duv, 2.5) * 0.5 + bright(duv, 4.0) * 0.6 + bright(duv, 5.5) * 0.5;
    col += glow * bloomAmt;
    float flick = 1.0 + amount * (0.02 * sin(t * 57.0) + 0.03 * (hash(vec2(floor(t * 18.0), 1.0)) - 0.5));
    col *= expo * flick * (1.0 + flash * 2.2 + glitch * 0.25);
    col = mix(vec3(lum(col)), col, sat);
    col = col / (1.0 + max(col - 1.0, 0.0) * 0.6);   // los blancos se "queman" suave, sin cortar

    float roll = smoothstep(0.09, 0.0, abs(fract(uv.y * 0.8 - t * 0.11) - 0.5));
    col += vec3(0.05, 0.018, 0.004) * roll * amount;
    float n = hash(floor(uv * res / 1.5) + floor(t * 24.0) * 13.1);
    col += (n - 0.5) * 0.10 * amount * (0.35 + col);
    col *= 1.0 - 0.08 * amount * (0.5 + 0.5 * sin(uv.y * res.y * 3.14159 / 1.5));

    // Línea brillante del encendido
    float lineGlow = (1.0 - smoothstep(0.3, 0.6, p)) * step(0.0001, p)
                   * exp(-abs(dy) * res.y / (2.0 + 30.0 * smoothstep(0.2, 0.55, p)))
                   * smoothstep(lineW * 0.5 + 0.01, lineW * 0.5 - 0.04, abs(uv.x - 0.5));
    col = col * inside + vec3(1.0, 0.9, 0.72) * lineGlow * 1.6;

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
