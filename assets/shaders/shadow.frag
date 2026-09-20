#version 440
// A soft shadow under a rounded rectangle, computed analytically and
// dithered before it is quantised. MultiEffect's shadow is a multi-pass
// blur through 8-bit textures, and at the radii a padded frame asks for it
// stepped into rings and, past a point, fell apart. This is the closed-form
// Gaussian blur of a rounded box (Evan Wallace, "Fast Rounded Rectangle
// Shadows"): exact along x through erf, four Gaussian samples along y.
//
// Build: qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o shadow.frag.qsb shadow.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float sigma;        // blur, in item pixels
    float corner;       // the card's corner radius
    vec2 frame;         // item size in pixels
    vec4 box;           // the shadow's rectangle: x, y, w, h in item pixels
    vec4 tint;          // straight (non-premultiplied) shadow color
};

float gaussian(float x, float s) {
    return exp(-(x * x) / (2.0 * s * s)) / (sqrt(2.0 * 3.14159265) * s);
}

vec2 erf(vec2 x) {
    vec2 s = sign(x), a = abs(x);
    x = 1.0 + (0.278393 + (0.230389 + 0.078108 * (a * a)) * a) * a;
    x *= x;
    return s - s / (x * x);
}

// Coverage of one blurred row of the box, at height y from its centre.
float rowShadow(float x, float y, float s, float r, vec2 hs) {
    float delta = min(hs.y - r - abs(y), 0.0);
    float curved = hs.x - r + sqrt(max(0.0, r * r - delta * delta));
    vec2 integral = 0.5 + 0.5 * erf((x + vec2(-curved, curved)) * (sqrt(0.5) / s));
    return integral.y - integral.x;
}

float boxShadow(vec2 lower, vec2 upper, vec2 p, float s, float r) {
    vec2 centre = (lower + upper) * 0.5;
    vec2 hs = (upper - lower) * 0.5;
    p -= centre;
    float low = p.y - hs.y;
    float high = p.y + hs.y;
    float start = clamp(-3.0 * s, low, high);
    float end = clamp(3.0 * s, low, high);
    float step = (end - start) / 4.0;
    float y = start + step * 0.5;
    float value = 0.0;
    for (int i = 0; i < 4; i++) {
        value += rowShadow(p.x, p.y - y, s, r, hs) * gaussian(y, s) * step;
        y += step;
    }
    return value;
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 p = qt_TexCoord0 * frame;
    float a = tint.a * boxShadow(box.xy, box.xy + box.zw, p, max(sigma, 0.5), corner);
    float n = hash(gl_FragCoord.xy) + hash(gl_FragCoord.xy + 17.0) - 1.0;
    a = clamp(a + n / 255.0, 0.0, 1.0);
    fragColor = vec4(tint.rgb * a, a) * qt_Opacity;
}
