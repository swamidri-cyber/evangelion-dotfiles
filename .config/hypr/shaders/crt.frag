#version 300 es
// ─────────────────────────────────────────────────────────────────────────────
//  crt.frag — efecto CRT para toda la pantalla (screen_shader de Hyprland)
//
//  Qué hace, en orden:
//    0. (opcional) Curvatura de vidrio + carcasa negra con esquinas redondeadas
//    1. Aberración cromática leve (rojo/azul corridos hacia los bordes)
//    2. Glow: halo alrededor de lo brillante y CÁLIDO (texto ámbar/dorado,
//       cursor, bordes). Lo blanco/gris casi no brilla, así una página web
//       blanca no se convierte en un reflector.
//    3. Scanlines: líneas horizontales muy tenues
//    4. Grano fijo tipo película
//    5. Viñeta + sombra interior del vidrio
//    6. Tinte cálido muy leve (fósforo ámbar)
//
//  Cada efecto tiene su "perilla" abajo. Poné 0.0 para apagar uno.
//  Al guardar, Hyprland recarga el shader solo.
//
//  Atajos (hypr/config/shader.lua):
//    Super+F12 → prender/apagar todo el efecto
//    Super+F11 → prender/apagar SOLO la curvatura (genera una copia de este
//                archivo con CURVE_ON = 1; vos editá siempre este)
//
//  Notas de rendimiento:
//   · El grano NO está animado: usar el uniform de tiempo obliga a Hyprland a
//     redibujar la pantalla entera en cada cuadro aunque nada cambie.
//   · El glow y la aberración leen píxeles vecinos; por eso shader.lua pone
//     debug:damage_tracking = 1 (redibujar el monitor completo cuando algo
//     cambia). Sin eso aparecen líneas brillantes "pegadas" al borde de las
//     zonas que se redibujan.
// ─────────────────────────────────────────────────────────────────────────────
precision highp float;

in vec2 v_texcoord;          // coordenada del píxel (0..1)
uniform sampler2D tex;       // la imagen de la pantalla ya compuesta
layout(location = 0) out vec4 fragColor;

// ── Curvatura (0 = pantalla plana, 1 = vidrio abombado) ─────────────────────
// No cambies este 0 a mano: Super+F11 genera la versión curva automáticamente.
#define CURVE_ON 0
// Modo consola (rice-console): pantalla en fósforo VERDE monocromo, como un
// sistema en hibernación. shader.lua genera una copia con GREEN_MODE 1.
#define GREEN_MODE 0
const vec3  GREEN_DARK  = vec3(0.008, 0.035, 0.018); // negro verdoso del tubo
const vec3  GREEN_LIGHT = vec3(0.82, 1.0, 0.80);     // blanco fósforo
const float GREEN_KEEP  = 0.35;   // cuánto color original se cuela (0 = puro verde; 0.08 = verde 1, 0.35 = verde 2)
const float CURVE       = 0.025;  // intensidad de la curva (0.015 = apenas, 0.05 = notoria)
const float BEZEL       = 0.008;  // ancho del marco negro (fracción de pantalla; antes 0.018)
const float CORNER      = 0.055;  // radio de las esquinas de la imagen (fracción del alto)
const float GLASS_SHADE = 0.05;   // ancho de la sombra interior en el borde del vidrio
const float GLASS_DARK  = 0.55;   // qué tanto oscurece esa sombra (0..1)

// ── Resto de las perillas ───────────────────────────────────────────────────
const float ABERRATION  = 0.0006; // separación de color (fracción de pantalla)
const float GLOW        = 0.55;   // intensidad del halo
const float GLOW_RAD    = 3.0;    // radio del halo en píxeles (anillo interno; el externo es x2.2)
const float GLOW_TH     = 0.35;   // a partir de qué brillo empieza a brillar (0..1)
const float GLOW_WARM   = 0.15;   // cuánto más "rojo que azul" tiene que ser para brillar
const float SCANLINES   = 0.04;   // oscuridad de las líneas horizontales
const float SCAN_PERIOD = 3.0;    // cada cuántos píxeles hay una línea
const float GRAIN       = 0.03;   // fuerza del grano
// Estática en el brillo naranja de las ventanas (la sombra ámbar de Hyprland):
// se detecta como naranja + tenue + LISO (degradé). Lo granulado, como un fondo
// con grano, queda afuera. 0 = sin estática.
const float STATIC      = 0.0;    // fuerza del ruido en el brillo
const float STATIC_DASH = 0.55;   // brillo de las rayitas de interferencia
const float STATIC_SMOOTH = 0.0025; // cuánta variación tolera para considerarlo "liso"
const float VIGNETTE    = 0.30;   // oscurecimiento de esquinas
const vec3  TINT        = vec3(1.03, 1.0, 0.94); // R,G,B: >1 realza, <1 apaga

// Ruido pseudoaleatorio barato (hash) para el grano
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

// Cuánto "brilla" un color: tiene que ser claro Y cálido (rojo > azul)
float glowMask(vec3 c) {
#if GREEN_MODE
    return smoothstep(GLOW_TH, 1.0, luma(c));   // en verde brilla todo lo claro
#endif
    float warm = smoothstep(0.0, GLOW_WARM, c.r - c.b);
    return smoothstep(GLOW_TH, 1.0, luma(c)) * warm;
}

// Distancia a un rectángulo de esquinas redondeadas (negativa = adentro)
float roundBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 res = vec2(textureSize(tex, 0));
    vec2 px  = 1.0 / res;                 // tamaño de un píxel en coordenadas 0..1
    vec2 uv  = v_texcoord;
    float edgeShade = 1.0;

#if CURVE_ON
    // 0. Curvatura de barril: cada punto de la pantalla muestra lo que hay un
    //    poco más afuera → la imagen se "abomba" y se achica hacia el centro.
    vec2 p = uv * 2.0 - 1.0;                       // -1..1
    p *= (1.0 + CURVE * dot(p, p)) * (1.0 + BEZEL * 2.0);
    uv = p * 0.5 + 0.5;

    // Máscara del vidrio: rectángulo redondeado en píxeles reales (sin
    // deformar por la proporción 16:9)
    vec2 aspect = vec2(res.x / res.y, 1.0);
    float d = roundBox(p * aspect, aspect, CORNER * 2.0);
    float onePx = 2.0 / res.y;
    if (d > onePx) { fragColor = vec4(0.0, 0.0, 0.0, 1.0); return; } // carcasa
    float glass = 1.0 - smoothstep(-onePx, onePx, d);                // borde suave
    // Sombra interior: oscurece de a poco al acercarse al borde del vidrio
    edgeShade = glass * mix(1.0 - GLASS_DARK, 1.0, smoothstep(0.0, GLASS_SHADE * 2.0, -d));
#endif

    vec2 fromCenter = uv - 0.5;

    // 1. Aberración cromática: crece hacia los bordes, nula en el centro
    vec2 shift = fromCenter * ABERRATION * 2.0;
    vec4 base  = texture(tex, uv);
    vec3 col   = vec3(texture(tex, uv + shift).r, base.g, texture(tex, uv - shift).b);

    // 2. Glow: dos anillos de 8 muestras (cerca y lejos) → halo suave
    vec3 glow = vec3(0.0);
    float lsum = 0.0, lsq = 0.0;                    // para medir si la zona es lisa
    for (int i = 0; i < 8; i++) {
        float a = float(i) * 0.785398 + 0.39;      // 45° entre muestras
        vec2 dir = vec2(cos(a), sin(a)) * px * GLOW_RAD;
        vec3 s1 = texture(tex, uv + dir).rgb;
        vec3 s2 = texture(tex, uv + dir * 2.2).rgb;
        glow += s1 * glowMask(s1) * 0.65 + s2 * glowMask(s2) * 0.35;
        float l1 = luma(s1); lsum += l1; lsq += l1 * l1;
    }
    col += glow / 8.0 * GLOW;

    // 2b. Estática en el brillo naranja (solo donde es tenue, cálido y liso)
    if (STATIC > 0.0) {
        float lm = lsum / 8.0;
        float variance = max(lsq / 8.0 - lm * lm, 0.0);
        float lb = luma(base.rgb);
        float orange = smoothstep(0.03, 0.12, base.r - base.b) * step(base.g, base.r * 0.8);
        float dim = smoothstep(0.015, 0.06, lb) * (1.0 - smoothstep(0.30, 0.50, lb));
        float smooth_ = 1.0 - smoothstep(STATIC_SMOOTH * 0.3, STATIC_SMOOTH, variance);
        float zone = orange * dim * smooth_;
        if (zone > 0.0) {
            float n = hash(gl_FragCoord.xy * 1.37 + 17.0) - 0.5;
            float dash = step(0.982, hash(vec2(floor(gl_FragCoord.x / 6.0), gl_FragCoord.y + 3.0)));
            col += zone * (n * 2.0 * STATIC + dash * STATIC_DASH * lb * 4.0) * vec3(1.0, 0.72, 0.45);
        }
    }

    // 3. Scanlines (coordenada de píxel real de la pantalla)
    float line = sin(gl_FragCoord.y * 6.28318 / SCAN_PERIOD) * 0.5 + 0.5;
    col *= 1.0 - SCANLINES * line;

    // 4. Grano fijo por píxel
    col += (hash(gl_FragCoord.xy) - 0.5) * GRAIN;

    // 5. Viñeta + sombra del vidrio
    col *= clamp(1.0 - dot(fromCenter, fromCenter) * VIGNETTE * 2.2, 0.0, 1.0);
    col *= edgeShade;

    // 6. Tinte cálido
    col *= TINT;

#if GREEN_MODE
    // 7. Fósforo verde: el brillo de cada píxel elige un tono de la rampa verde
    float gl = clamp(luma(col), 0.0, 1.0);
    col = mix(mix(GREEN_DARK, GREEN_LIGHT, pow(gl, 0.85)), col, GREEN_KEEP);
#endif

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
