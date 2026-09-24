#version 440
// A magnifier's lens: the area it shows, stretched over the whole item and
// cut to a circle with an antialiased rim. Drawn here rather than as a Shape
// filled with the texture, whose fill mapped the texture at a scale that
// followed how the layer was transformed and put the zoomed pixels in the
// wrong place, and rather than through a layer mask, which resamples. The
// texture comes from a ShaderEffectSource with smooth off, so each shot pixel
// stays a square block.
//
// Build: qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o lens.frag.qsb lens.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float edge;         // width of the rim's fade, as a fraction of the radius
};

layout(binding = 1) uniform sampler2D source;

void main() {
    float r = length(qt_TexCoord0 - 0.5) * 2.0;      // 1 on the rim
    float a = 1.0 - smoothstep(1.0 - edge, 1.0, r);
    fragColor = texture(source, qt_TexCoord0) * a * qt_Opacity;
}
