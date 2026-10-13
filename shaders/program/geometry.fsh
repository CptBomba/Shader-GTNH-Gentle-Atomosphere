#include "/lib/environment.glsl"
#include "/lib/fog.glsl"
#if defined(GENTLE_TERRAIN) || defined(GENTLE_WATER) || defined(GENTLE_RECEIVER)
#include "/lib/lighting.glsl"
#include "/lib/local_lights.glsl"
uniform vec3 cameraPosition;
#endif
#include "/lib/foliage.glsl"
uniform sampler2D texture;
uniform sampler2D lightmap;
#ifdef GENTLE_WATER
#include "/lib/water.glsl"
#endif
#ifdef GENTLE_ENTITY
uniform vec4 entityColor;
#endif
varying vec2 gentleUV;
varying vec2 gentleLightUV;
varying vec4 gentleColor;
varying vec3 gentleView;
varying vec3 gentleWorld;
varying float gentleMaterial;
varying float gentleUp;
varying vec3 gentleNormal;
#ifdef GENTLE_SKY_MASK
uniform int renderStage;
/* DRAWBUFFERS:01 */
#else
/* DRAWBUFFERS:0 */
#endif

void main() {
    // PCF derivatives must execute before any alpha discard or varying water
    // branch. A single geometric visibility also serves the water's sun glint.
#if defined(GENTLE_TERRAIN) || defined(GENTLE_WATER) || defined(GENTLE_RECEIVER)
    float sunVisibility = 1.0;
    bool needsSunVisibility = SUNLIGHT_STRENGTH > 0.0;
#if defined(GENTLE_WATER) && WATER_EFFECT == 1
    needsSunVisibility = needsSunVisibility || WATER_STRENGTH > 0.0;
#endif
    if (needsSunVisibility && gentleEarth() && gentleDay() > 0.0) {
        bool plant = gentleMaterial > 10001.5 && gentleMaterial < 10003.5;
        vec3 n = normalize(gentleNormal + vec3(0.0, 0.00001, 0.0));
        sunVisibility = gentleSunVisibility(gentleWorld - cameraPosition, n, plant);
    }
#endif
#if defined(GENTLE_WATER) && WATER_EFFECT == 1
    vec2 waterDx = dFdx(gentleWorld.xz), waterDy = dFdy(gentleWorld.xz);
#endif
#ifdef GENTLE_BASIC
    vec4 color = gentleColor;
#else
    // Original atlas, biome tint, vertex AO and alpha are retained.
    vec4 atlas = texture2D(texture, gentleUV);
#if defined(GENTLE_TERRAIN) || defined(GENTLE_WATER)
    // Use the native mip footprint once; negative LOD bias revived distant
    // subpixel blades and required an extra atlas fetch on every plant.
    atlas = gentleFoliage(atlas, gentleMaterial, length(gentleView));
#endif
    vec4 color = atlas * gentleColor;
#endif
#ifdef GENTLE_LIT
    vec3 light = texture2D(lightmap, gentleLightUV).rgb;
    color.rgb *= light;
#endif
#ifdef GENTLE_WATER
    vec3 nativeWater = color.rgb;
#endif
#if defined(GENTLE_TERRAIN) || defined(GENTLE_WATER) || defined(GENTLE_RECEIVER)
#ifdef GENTLE_WATER
    // Unknown/mod liquids retain their original color and lightmap response.
    if (gentleEarth() && abs(gentleMaterial - 10004.0) < 0.25) {
#else
    if (gentleEarth()) {
#endif
        float daylight = gentleDay();
        float exterior = smoothstep(0.50, 0.92, gentleLightUV.y) * daylight;
        // Torch-lit and emissive/fullbright surfaces are protected from grading.
        float blockLightProtection = 1.0 - smoothstep(0.60, 0.92, gentleLightUV.x);
        float influence = exterior * blockLightProtection;
        vec3 tint = mix(vec3(1.045, 1.012, 0.965), vec3(1.065, 1.008, 0.935), gentleTwilight());
        tint = mix(tint, vec3(0.998, 1.0, 1.004), clamp(wetness, 0.0, 1.0));
        color.rgb *= mix(vec3(1.0), tint, COLOR_STRENGTH * influence);
        // Gentle relief of vanilla directional shade, retaining vertex AO.
        // Multiplication retains biome tint and AO without whitening textures.
        float darkFace = 1.0 - clamp(max(gentleColor.r, max(gentleColor.g, gentleColor.b)), 0.0, 1.0);
        color.rgb *= 1.0 + darkFace * SHADE_SOFTNESS * influence;
        // Sun-facing surfaces and cast shadows now have a distinct response.
        color.rgb = gentleSunlight(color.rgb, gentleWorld - cameraPosition,
            gentleNormal, influence, gentleMaterial, sunVisibility);
        // Angelica 2.2.28 exposes entity-eye cameraPosition in both views.
        // Subtracting inverse-modelview translation would move the voxel grid
        // with the third-person camera and duplicate the renderer's own fix.
        color.rgb = gentleLocalLights(color.rgb, gentleWorld, gentleNormal, gentleLightUV.x, gentleLightUV.y);
    }
#endif
#if defined(GENTLE_WATER) && WATER_EFFECT == 1
    if (gentleEarth() && abs(gentleMaterial - 10004.0) < 0.25 && gentleUp > 0.8) {
        // Smooth color still follows biome vertex tint, the original lightmap,
        // and the same solar grading; the repeating atlas contrast is adjustable.
        vec3 smoothWater = vec3(0.12, 0.34, 0.43) * gentleColor.rgb * light;
        smoothWater *= clamp(color.rgb / max(nativeWater, vec3(0.01)), vec3(0.5), vec3(1.5));
        color.rgb = gentleWaterSurface(color.rgb, smoothWater, color.a, gentleWorld, gentleView,
            gentleLightUV.y, waterDx, waterDy, sunVisibility);
    }
#endif
#ifdef GENTLE_ENTITY
    // Vanilla hurt/flash overlays used by mobs and special mod renderers.
    color.rgb = mix(color.rgb, entityColor.rgb, entityColor.a);
#endif
#ifndef GENTLE_NO_FOG
    color.rgb = gentleFog(color.rgb, gentleView);
#endif
    gl_FragData[0] = color;
#ifdef GENTLE_SKY_MASK
    // Inspected beta66b WorldRenderingPhase ordinals: SUN=4, MOON=5, STARS=6.
    // Dome, native sunset fan and void plate must not preserve a horizon seam.
    // Native sun/moon/stars use SRC_ALPHA, ONE. Accumulate their RGB on a
    // zero background, never the old sky already blended into colortex0.
    // Zero alpha prevents the sunset fan from altering this independent layer.
    gl_FragData[1] = renderStage >= 4 && renderStage <= 6 ? color : vec4(0.0);
#endif
}
