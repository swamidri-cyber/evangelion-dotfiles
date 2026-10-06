#version 440
// ─────────────────────────────────────────────────────────────────────────────
//  post.frag — "revelado" del arranque MAGI. La escena se dibuja en grises
//  (intensidad pura) y acá se convierte en fósforo ámbar sobreexpuesto, como el
//  fondo de pantalla: núcleos color crema, halos naranja saturados, sombras
//  marrón casi negro, grano fuerte.
//
//  Además: glitch digital (macrobloques que se corren o pixelan, a saltos), encendido de tubo (punto → línea → imagen) y apagado de fósforo
//  (el fondo se va primero y lo brillante queda brillando un rato).
//
//  Compilar después de editar:
//    /usr/lib/qt6/bin/qsb --qt6 -o post.frag.qsb post.frag
// ─────────────────────────────────────────────────────────────────────────────
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float time;     // segundos
    float power;    // 0→1 encendido del tubo
    float glitch;   // 0→1 interferencia extra (ráfagas)
    float outp;     // 0→1 salida (fósforo que se apaga)
    vec2  res;      // tamaño en píxeles
};
layout(binding = 1) uniform sampler2D src;   // escena en grises, con mipmaps (para el halo)

// ── Perillas ────────────────────────────────────────────────────────────────
const float EXPOSURE  = 1.35;   // sobreexposición general
const float BLOOM     = 1.25;   // fuerza del halo
const float GRAIN     = 0.11;   // grano animado
const float SCAN      = 0.10;   // scanlines propias
const float GLITCH    = 0.6;    // fuerza de las ráfagas de glitch digital
const float ABERR_PX  = 1.6;    // separación de color (px)

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

// Ráfagas del arranque (más seguidas que en el fondo: dura 6 s): cada 1,2 s
// una chance (70 %) de un glitch de 0,08–0,3 s que parpadea cuadro a cuadro.
float dburst(float t) {
    float slot = floor(t / 1.2);
    float local = t - slot * 1.2 - hash(vec2(slot, 1.0)) * 0.8;
    float len = 0.08 + 0.22 * hash(vec2(slot, 2.0));
    float on = step(0.0, local) * step(local, len) * step(0.30, hash(vec2(slot, 3.0)));
    return on * step(0.25, hash(vec2(floor(t * 12.0), 4.0)));
}

// Mapa de color del fósforo (intensidad → color)
vec3 ramp(float i) {
    const vec3 c0 = vec3(0.0);
    const vec3 c1 = vec3(0.32, 0.075, 0.012);
    const vec3 c2 = vec3(0.95, 0.32, 0.025);
    const vec3 c3 = vec3(1.0, 0.62, 0.15);
    const vec3 c4 = vec3(1.0, 0.88, 0.60);
    const vec3 c5 = vec3(1.0, 0.98, 0.90);
    i = max(i, 0.0);
    if (i < 0.18) return mix(c0, c1, i / 0.18);
    if (i < 0.45) return mix(c1, c2, (i - 0.18) / 0.27);
    if (i < 0.72) return mix(c2, c3, (i - 0.45) / 0.27);
    if (i < 1.05) return mix(c3, c4, (i - 0.72) / 0.33);
    return mix(c4, c5, clamp((i - 1.05) / 0.7, 0.0, 1.0));
}

// Halo: promedio de varios niveles de mipmap (cada nivel = mitad de resolución)
float bloom(vec2 uv) {
    vec2 o = 6.0 / res;
    float b = textureLod(src, uv, 2.0).r * 0.45;
    b += textureLod(src, uv, 3.5).r * 0.7;
    b += (textureLod(src, uv + vec2(o.x * 4.0, 0.0), 5.0).r + textureLod(src, uv - vec2(o.x * 4.0, 0.0), 5.0).r
        + textureLod(src, uv + vec2(0.0, o.y * 4.0), 5.0).r + textureLod(src, uv - vec2(0.0, o.y * 4.0), 5.0).r) * 0.25 * 0.9;
    b += textureLod(src, uv, 6.5).r * 0.6;
    // Las zonas grandes y llenas (bloques votados) casi no suman halo: así
    // las líneas finas brillan mucho sin que lo relleno se queme a blanco
    float area = textureLod(src, uv, 4.5).r;
    return b * (1.0 - 0.85 * smoothstep(0.08, 0.32, area));
}

void main() {
    vec2 uv = qt_TexCoord0;
    float t = time;
    float px = 1.0 / res.x;

    // ── Encendido: punto → línea horizontal → se abre en vertical ──────────
    float p = power;
    float lineW = smoothstep(0.0, 0.28, p);
    float openH = mix(0.003, 1.0, smoothstep(0.28, 0.62, p));
    float dy = uv.y - 0.5;
    float inside = step(abs(dy), openH * 0.5) * step(abs(uv.x - 0.5), lineW * 0.5 + 0.001) * step(0.0001, p);
    vec2 suv = vec2(uv.x, 0.5 + dy / openH);
    float flash = step(0.0001, p) * (1.0 - smoothstep(0.35, 1.0, p));

    // ── Glitch digital (antes: interferencia VHS; ver post.frag.antes-glitch) ──
    float split;
    vec2 duv = dglitch(suv, t, GLITCH * dburst(t) + glitch, split);
    float ab = ABERR_PX * px * (1.0 + glitch * 4.0) + split;

    // ── Revelado ─────────────────────────────────────────────────────────────
    float sG = texture(src, duv).r;
    float sR = texture(src, duv + vec2(ab, 0.0)).r;
    float sB = texture(src, duv - vec2(ab, 0.0)).r;
    float glow = bloom(duv) * BLOOM * (1.0 + outp * 1.5);
    float flick = 1.0 + 0.025 * sin(t * 57.0) + 0.04 * (hash(vec2(floor(t * 18.0), 1.0)) - 0.5);
    float expo = EXPOSURE * flick * (1.0 + flash * 2.2 + glitch * 0.25);
    float fade = 1.0 - smoothstep(0.08, 1.0, outp);   // lo brillante se apaga lento
    vec3 lit = vec3(ramp((sR + glow) * expo).r, ramp((sG + glow) * expo).g, ramp((sB + glow) * expo).b) * fade;

    // Fondo: negro marrón con un resplandor cálido en el medio (como el fondo de pantalla)
    vec2 q = (uv - 0.5) * vec2(1.25, 1.7);
    vec3 bg = vec3(0.13, 0.042, 0.010) * max(0.0, 1.0 - length(q)) + vec3(0.018, 0.006, 0.002);
    // Barra de refresco que baja despacio
    float roll = smoothstep(0.09, 0.0, abs(fract(uv.y * 0.8 - t * 0.11) - 0.5));
    bg += vec3(0.05, 0.018, 0.004) * roll;

    vec3 col = bg + lit;
    // Grano (fuerte, como la foto del fondo) y scanlines
    float n = hash(floor(uv * res / 1.5) + floor(t * 24.0) * 13.1);
    col += (n - 0.5) * GRAIN * (0.35 + col);
    col *= 1.0 - SCAN * (0.5 + 0.5 * sin(uv.y * res.y * 3.14159 / 1.5));
    // Viñeta
    col *= 1.0 - 0.5 * pow(clamp(length((uv - 0.5) * vec2(1.1, 1.3)), 0.0, 1.0), 2.2);

    // Línea brillante del encendido
    float lineGlow = (1.0 - smoothstep(0.3, 0.6, p)) * step(0.0001, p)
                   * exp(-abs(dy) * res.y / (2.0 + 30.0 * smoothstep(0.2, 0.55, p)))
                   * smoothstep(lineW * 0.5 + 0.01, lineW * 0.5 - 0.04, abs(uv.x - 0.5));
    col = col * inside + vec3(1.0, 0.9, 0.72) * lineGlow * 1.6;

    // ── Salida: el fondo se va primero, lo encendido queda brillando ────────
    float bgA = 1.0 - smoothstep(0.0, 0.45, outp);
    float litA = clamp(max(lit.r, max(lit.g, lit.b)), 0.0, 1.0);
    float a = max(bgA, litA);
    // Premultiplicado: lo que queda brillando se SUMA al escritorio
    vec3 rgb = mix(lit, col, bgA);
    fragColor = vec4(rgb, a) * qt_Opacity;
}
