#include "/lib/environment.glsl"
#include "/lib/foliage.glsl"
uniform sampler2D texture;
varying vec2 gentleShadowUV;
varying float gentleShadowAlpha;
varying float gentleShadowMaterial;
varying vec3 gentleShadowRelative;
/* DRAWBUFFERS:0 */
void main() {
    // Alpha-tested leaves/plants cast their actual silhouette. Translucent
    // fluids are excluded; players, entities and TESRs participate when supported.
    float alpha = texture2D(texture, gentleShadowUV).a;
    if (!gentleEarth() || alpha < gentleFoliageCutoff(gentleShadowMaterial, length(gentleShadowRelative))
        || alpha * gentleShadowAlpha < 0.1) discard;
    gl_FragData[0] = vec4(1.0);
}
