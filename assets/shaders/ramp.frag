#version 440
// A linear gradient across the frame, dithered before it is quantised.
// Rectangle's gradient is interpolated in float too, but it lands in an
// 8-bit framebuffer as it is, and a dark ramp then steps a whole level every
// dozen pixels, which reads as bands. Adding ±half a level of noise here,
// while the value is still continuous, turns each step into a gradual change
// in the density of two neighbouring levels, which nothing can see.
//
// Geometry matches the Rectangle this replaced: a square as wide as the
// frame's diagonal, rotated by `angle` about the centre, stop 0 along its
// top edge and stop 1 along its bottom.
//
// Build: qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o ramp.frag.qsb ramp.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float angle;        // degrees, clockwise, as Item.rotation
    vec2 frame;         // item size in pixels
    vec4 c0;
    vec4 c1;
    vec4 c2;
    vec4 c3;
    vec4 c4;
    vec4 pos;           // stops 1..4; stop 0 sits at 0
};

vec4 seg(vec4 a, vec4 b, float pa, float pb, float t) {
    return mix(a, b, clamp((t - pa) / max(pb - pa, 1e-5), 0.0, 1.0));
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 d = (qt_TexCoord0 - 0.5) * frame;
    float a = radians(angle);
    float diag = length(frame);
    float t = clamp((-sin(a) * d.x + cos(a) * d.y) / diag + 0.5, 0.0, 1.0);

    vec4 c = seg(c0, c1, 0.0, pos.x, t);
    if (t > pos.x) c = seg(c1, c2, pos.x, pos.y, t);
    if (t > pos.y) c = seg(c2, c3, pos.y, pos.z, t);
    if (t > pos.z) c = seg(c3, c4, pos.z, pos.w, t);

    // Triangular noise of one level, centred on zero.
    float n = hash(gl_FragCoord.xy) + hash(gl_FragCoord.xy + 17.0) - 1.0;
    c.rgb += n / 255.0;

    fragColor = vec4(c.rgb, 1.0) * qt_Opacity;
}
