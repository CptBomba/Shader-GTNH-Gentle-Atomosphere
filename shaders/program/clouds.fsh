#include "/lib/environment.glsl"
#include "/lib/fog.glsl"
uniform sampler2D texture;
uniform sampler2D lightmap;
varying vec2 gentleCloudUV;
varying vec4 gentleCloudColor;
varying vec3 gentleCloudWorld;
varying vec3 gentleCloudView;
/* DRAWBUFFERS:0 */

float gentleCloudHash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float gentleCloudNoise(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(gentleCloudHash(cell), gentleCloudHash(cell + vec2(1.0, 0.0)), f.x),
        mix(gentleCloudHash(cell + vec2(0.0, 1.0)), gentleCloudHash(cell + vec2(1.0)), f.x), f.y);
}

void main() {
#if CLOUD_STYLE == 1 || CLOUD_QUALITY == 0
    // Suppress native shapes/depth only in protected Earth conditions. Other
    // dimension providers retain their native clouds and original render path.
    if (gentleEarth()) discard;
#endif
    vec4 color = texture2D(texture, gentleCloudUV) * gentleCloudColor;
    // Angelica's VBO cloud renderer supplies provider color through a 1x1
    // texture on the lightmap unit. With no lightmap Iris binds a white pixel.
    color.rgb *= texture2D(lightmap, vec2(0.5)).rgb;
#if CLOUD_QUALITY == 0
    if (gentleEarth()) discard;
#else
    if (gentleEarth()) {
        float daylight = gentleDay();
        vec3 tint = mix(vec3(0.84, 0.90, 1.0), vec3(1.0, 0.995, 0.98), daylight);
        tint = mix(tint, vec3(1.0, 0.93, 0.84), gentleTwilight() * 0.35);
        tint = mix(tint, vec3(0.94, 0.96, 0.98), clamp(wetness, 0.0, 1.0) * 0.7);
        color.rgb *= tint;
        // A clean night sky: retain stars and native sky, thin cloud opacity.
        color.a *= mix(0.52, 0.96, daylight);
#if CLOUD_QUALITY >= 2
        // Two-dimensional shading only. No volume integration or ray marching.
        // CLOUD_SPEED controls this slow billow; mesh speed remains Minecraft's.
        float t = frameTimeCounter * GENTLE_TAU / 3600.0;
        vec2 flow = vec2(sin(t * 4.0 * CLOUD_SPEED), cos(t * 2.0 * CLOUD_SPEED)) * 0.28;
        vec2 p = gentleCloudWorld.xz * 0.028 + flow;
        float body = gentleCloudNoise(p);
        float depth = body;
#if CLOUD_QUALITY >= 3
        depth = body * 0.72 + gentleCloudNoise(p * 2.0 + vec2(9.0)) * 0.28;
#endif
        // Original cubic silhouette is never replaced with a circular cutout.
        color.rgb *= mix(0.94, 1.015, depth);
        color.a *= mix(0.91, 1.0, body);
#endif
    }
#endif
    color.rgb = gentleFog(color.rgb, gentleCloudView);
    gl_FragData[0] = color;
}
