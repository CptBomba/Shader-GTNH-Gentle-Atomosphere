#include "/lib/environment.glsl"
uniform float viewWidth;
uniform float viewHeight;
varying vec2 gentleScreenUV;
// Separable Gaussian over the quarter-resolution glow area (see
// bloom_extract). Horizontal: colortex2 -> colortex3. Vertical: colortex3 ->
// colortex6. colortex2 stays unblurred for the tight glow in final.
#ifdef GENTLE_BLUR_VERTICAL
uniform sampler2D colortex3;
#define GENTLE_BLUR_SOURCE colortex3
/* DRAWBUFFERS:6 */
#else
uniform sampler2D colortex2;
#define GENTLE_BLUR_SOURCE colortex2
/* DRAWBUFFERS:3 */
#endif
vec3 gentleBlurPair(vec2 uv, vec2 offset, vec2 limit) {
    return texture2D(GENTLE_BLUR_SOURCE, min(uv + offset, limit)).rgb
        + texture2D(GENTLE_BLUR_SOURCE, max(uv - offset, vec2(0.0))).rgb;
}
void main() {
    vec3 glow = vec3(0.0);
    vec2 pixel = 1.0 / max(vec2(viewWidth, viewHeight), vec2(1.0));
    if ((BLOOM_STRENGTH > 0.0 || EMISSIVE_GLOW > 0.0) && gentleEarth()
        && all(lessThan(gentleScreenUV, vec2(0.25)))) {
#ifdef GENTLE_BLUR_VERTICAL
        vec2 axis = vec2(0.0, pixel.y);
#else
        vec2 axis = vec2(pixel.x, 0.0);
#endif
        // Gaussian, sigma 4 texels (16 screen pixels), radius 12, as 13
        // linearly filtered taps. Tap spacing stays below 2 texels so small,
        // distant flames blur smoothly instead of leaving ghost copies.
        // Clamping to the working area repeats its border texel.
        vec2 limit = vec2(0.25) - pixel * 0.5;
        glow = texture2D(GENTLE_BLUR_SOURCE, gentleScreenUV).rgb * 0.099908;
        glow += gentleBlurPair(gentleScreenUV, axis * 1.476580, limit) * 0.185003;
        glow += gentleBlurPair(gentleScreenUV, axis * 3.445530, limit) * 0.136012;
        glow += gentleBlurPair(gentleScreenUV, axis * 5.414899, limit) * 0.078177;
        glow += gentleBlurPair(gentleScreenUV, axis * 7.384912, limit) * 0.035128;
        glow += gentleBlurPair(gentleScreenUV, axis * 9.355775, limit) * 0.012338;
        glow += gentleBlurPair(gentleScreenUV, axis * 11.327668, limit) * 0.003387;
    }
    gl_FragData[0] = vec4(glow, 1.0);
}
