#include "/lib/environment.glsl"
uniform sampler2D colortex0;
uniform float viewWidth;
uniform float viewHeight;
varying vec2 gentleScreenUV;
/* DRAWBUFFERS:2 */
vec3 gentleBright(vec3 color) {
    float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float knee = smoothstep(0.78, 0.98, luminance);
    return color * knee * 0.5;
}
void main() {
    vec3 glow = vec3(0.0);
    if (BLOOM_STRENGTH > 0.0 && gentleEarth()) {
        vec2 pixel = 1.0 / max(vec2(viewWidth, viewHeight), vec2(1.0));
        glow = gentleBright(texture2D(colortex0, gentleScreenUV + pixel * vec2(-0.5, -0.5)).rgb);
        glow += gentleBright(texture2D(colortex0, gentleScreenUV + pixel * vec2(0.5, -0.5)).rgb);
        glow += gentleBright(texture2D(colortex0, gentleScreenUV + pixel * vec2(-0.5, 0.5)).rgb);
        glow += gentleBright(texture2D(colortex0, gentleScreenUV + pixel * vec2(0.5, 0.5)).rgb);
        glow *= 0.25;
    }
    gl_FragData[0] = vec4(glow, 1.0);
}
