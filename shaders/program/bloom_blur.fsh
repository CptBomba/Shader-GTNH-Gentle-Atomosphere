#include "/lib/environment.glsl"
uniform sampler2D colortex2;
uniform float viewWidth;
varying vec2 gentleScreenUV;
/* DRAWBUFFERS:3 */
void main() {
    vec3 glow = vec3(0.0);
    if (BLOOM_STRENGTH > 0.0 && gentleEarth()) {
        vec2 offset = vec2(2.0 / max(viewWidth, 1.0), 0.0);
        glow = texture2D(colortex2, gentleScreenUV).rgb * 0.227027;
        glow += texture2D(colortex2, gentleScreenUV + offset * 1.384615).rgb * 0.316216;
        glow += texture2D(colortex2, gentleScreenUV - offset * 1.384615).rgb * 0.316216;
        glow += texture2D(colortex2, gentleScreenUV + offset * 3.230769).rgb * 0.070270;
        glow += texture2D(colortex2, gentleScreenUV - offset * 3.230769).rgb * 0.070270;
    }
    gl_FragData[0] = vec4(glow, 1.0);
}
