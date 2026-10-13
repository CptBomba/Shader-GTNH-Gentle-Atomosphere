#include "/lib/environment.glsl"
#include "/lib/fog.glsl"
#include "/lib/sky.glsl"
#include "/lib/cloud_shapes.glsl"
uniform sampler2D colortex0;
uniform sampler2D colortex1;
// Keep the faint native halo/stars above the precision of an 8-bit mask.
const int RGBA16F = 34842;
const int colortex1Format = RGBA16F;
const bool colortex1Clear = true;
const vec4 colortex1ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
uniform sampler2D depthtex0;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform int isEyeInWater;
varying vec2 gentleScreenUV;
/* DRAWBUFFERS:04 */
void main() {
    vec4 scene = texture2D(colortex0, gentleScreenUV);
    float depth = texture2D(depthtex0, gentleScreenUV).r;
    // Executed before translucent geometry: glass, fluids and particles render
    // naturally over the sky. Opaque terrain, hands and machines are untouched.
    if (gentleEarth() && isEyeInWater == 0 && depth >= 1.0) {
        vec4 view = gbufferProjectionInverse * vec4(gentleScreenUV * 2.0 - 1.0, 1.0, 1.0);
        vec3 direction = normalize(mat3(gbufferModelViewInverse) * (view.xyz / max(abs(view.w), 0.00001)));
        vec3 sunDirection = mat3(gbufferModelViewInverse) * sunPosition;
        if (SKY_STRENGTH > 0.0)
            scene.rgb = gentleSkyGradient(scene.rgb, direction, sunDirection, 0.0)
                + texture2D(colortex1, gentleScreenUV).rgb;
        scene.rgb = gentleCloudField(scene.rgb, cameraPosition, direction, sunDirection);
    }
    gl_FragData[0] = scene;
    // Immutable opaque/sky snapshot: water reads colortex4 and writes only 0.
    // beta66b restricts geometry samplers to colortex4 and higher.
    gl_FragData[1] = scene;
}
