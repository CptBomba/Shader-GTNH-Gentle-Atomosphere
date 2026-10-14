#include "/lib/environment.glsl"
uniform sampler2D colortex0;
uniform sampler2D colortex5;
uniform float viewWidth;
uniform float viewHeight;
varying vec2 gentleScreenUV;
// Glow works at quarter resolution inside the lower-left quarter of the
// full-size buffers: wide halos for a few taps, and no half-size targets
// (beta66b rounded those to zero at 1 px windows). 16-bit floats avoid
// banding in the faint halo gradients.
const int RGBA16F = 34842;
const int colortex2Format = RGBA16F;
const int colortex3Format = RGBA16F;
const int colortex6Format = RGBA16F;
const bool colortex5Clear = true;
const vec4 colortex5ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
/* DRAWBUFFERS:2 */
vec3 gentleBright(vec3 color) {
    float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float knee = smoothstep(0.78, 0.98, luminance);
    return color * knee * 0.5;
}
vec3 gentleGlowSource(vec2 uv) {
    vec3 glow = min(gentleBright(texture2D(colortex0, uv).rgb), vec3(0.5)) * BLOOM_STRENGTH;
    return glow + texture2D(colortex5, uv).rgb * EMISSIVE_GLOW * 0.60;
}
void main() {
    vec3 glow = vec3(0.0);
    if ((BLOOM_STRENGTH > 0.0 || EMISSIVE_GLOW > 0.0) && gentleEarth()
        && all(lessThan(gentleScreenUV, vec2(0.25)))) {
        // Four bilinear taps average the 4x4 block this texel stands for.
        vec2 pixel = 1.0 / max(vec2(viewWidth, viewHeight), vec2(1.0));
        vec2 uv = gentleScreenUV * 4.0;
        glow = gentleGlowSource(uv + pixel * vec2(-1.0, -1.0));
        glow += gentleGlowSource(uv + pixel * vec2(1.0, -1.0));
        glow += gentleGlowSource(uv + pixel * vec2(-1.0, 1.0));
        glow += gentleGlowSource(uv + pixel * vec2(1.0, 1.0));
        glow *= 0.25;
    }
    gl_FragData[0] = vec4(glow, 1.0);
}
