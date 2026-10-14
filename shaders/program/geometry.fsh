#include "/lib/environment.glsl"
#include "/lib/fog.glsl"
#if defined(GENTLE_TERRAIN) || defined(GENTLE_WATER) || defined(GENTLE_RECEIVER)
#include "/lib/lighting.glsl"
#include "/lib/local_lights.glsl"
#endif
uniform vec3 cameraPosition;
#include "/lib/foliage.glsl"
uniform sampler2D texture;
uniform sampler2D lightmap;
#include "/lib/blocklight.glsl"
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
// Opaque geometry, entities, the hand and particles also write the halo
// source (colortex5): flames add light there, everything else occludes it.
#if defined(GENTLE_TERRAIN) || defined(GENTLE_ENTITY) || defined(GENTLE_RECEIVER) || defined(GENTLE_PARTICLES)
#define GENTLE_GLOW_TARGET
#endif
#ifdef GENTLE_SKY_MASK
uniform int renderStage;
/* DRAWBUFFERS:01 */
#elif defined(GENTLE_GLOW_TARGET)
/* DRAWBUFFERS:05 */
#else
/* DRAWBUFFERS:0 */
#endif

void main() {
    // Shadow-plane derivatives must execute before any alpha discard or
    // varying branch. One geometric visibility also serves the water's glint.
#if defined(GENTLE_TERRAIN) || defined(GENTLE_WATER) || defined(GENTLE_RECEIVER)
    float sunVisibility = gentleSunVisibility(gentleWorld - cameraPosition, gentleNormal,
        gentleMaterial, gentleLightUV.y);
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
#ifdef GENTLE_GLOW_TARGET
    // Which light sources glow, and how much. Flames brighten and flicker
    // with their own phase; the same flicker drives their halo.
    vec3 emissive = vec3(0.0);
#ifndef GENTLE_BASIC
    float glowWeight = 0.0;
    float flicker = 1.0;
#ifdef GENTLE_TERRAIN
    vec3 source = floor(gentleWorld + vec3(0.001));
    float sourcePhase = fract(sin(dot(source, vec3(12.9898, 78.233, 37.719))) * 43758.5453) * GENTLE_TAU;
    if (abs(gentleMaterial - 10006.0) < 0.25) {
        glowWeight = 1.0;
        flicker = gentleFlicker(sourcePhase, 1.0);
    } else if (abs(gentleMaterial - 10007.0) < 0.25) {
        glowWeight = 0.40;
        flicker = gentleFlicker(dot(gentleWorld.xz, vec2(0.21, 0.17)), 0.0);
    }
#elif defined(GENTLE_PARTICLES)
    // Flame and lava particles are drawn fullbright; smoke and dust are not.
    glowWeight = 0.85 * smoothstep(0.86, 0.92, gentleLightUV.x);
    flicker = gentleFlicker(dot(gentleWorld, vec3(3.1, 2.3, 2.7)), 1.0);
#elif defined(GENTLE_ENTITY) && !defined(GENTLE_RECEIVER)
    // First-person hand: a held torch keeps its flame alive.
    glowWeight = max(float(heldBlockLightValue), float(heldBlockLightValue2)) > 0.0 ? 0.80 : 0.0;
    flicker = gentleFlicker(0.0, 1.0);
#endif
    if (EMISSIVE_GLOW > 0.0 && glowWeight > 0.0 && gentleEarth()) {
        float flame = gentleFlameMask(atlas.rgb) * glowWeight;
        color.rgb *= 1.0 + (flicker - 1.0) * 0.6 * flame;
        // Distant flames cover few pixels; a moderate boost keeps their halo
        // visible without making them larger than nearby ones.
        float distanceBoost = 1.0 + min(length(gentleView) / 6.0, 3.0);
        emissive = atlas.rgb * gentleColor.rgb * flame * flicker * distanceBoost;
    }
#endif
#endif
#ifdef GENTLE_LIT
    // Held light sources raise the block-light level around the player; the
    // result is graded towards warm, gently flickering torch light.
    vec2 lightUV = gentleHeldLight(gentleLightUV, gentleWorld - cameraPosition);
    vec3 light = gentleBlockLight(texture2D(lightmap, lightUV).rgb, lightUV, gentleWorld);
    vec3 albedo = color.rgb;
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
        color.rgb = gentleSunlight(color.rgb, gentleWorld - cameraPosition, gentleNormal,
            influence, gentleMaterial, sunVisibility);
        // Angelica 2.2.28 exposes entity-eye cameraPosition in both views.
        // Subtracting inverse-modelview translation would move the voxel grid
        // with the third-person camera and duplicate the renderer's own fix.
        color.rgb = gentleLocalLights(color.rgb, gentleWorld, gentleNormal, lightUV.x, lightUV.y);
        // Moonlight: outdoors at night the world keeps a soft blue-grey
        // visibility instead of sinking into black. Caves, rooms and
        // torch-lit areas are untouched (skylight and block light decide).
        float moonlit = smoothstep(0.55, 0.95, gentleLightUV.y) * gentleNight() * blockLightProtection;
        if (NIGHT_BRIGHTNESS > 0.0 && moonlit > 0.0) {
            float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
            // Colors cool and soften a little, as the eye sees them at night.
            color.rgb = mix(color.rgb, luma * vec3(0.80, 0.92, 1.25), 0.30 * moonlit);
            color.rgb += albedo * vec3(0.08, 0.10, 0.15) * moonlit * NIGHT_BRIGHTNESS * gentleMoonlight();
        }
    }
#endif
#if defined(GENTLE_WATER) && WATER_EFFECT == 1
    if (gentleEarth() && abs(gentleMaterial - 10004.0) < 0.25 && gentleUp > 0.8) {
        // Smooth color still follows biome vertex tint, the original lightmap,
        // and the same solar grading; the repeating atlas contrast is adjustable.
        vec3 smoothWater = vec3(0.12, 0.34, 0.43) * gentleColor.rgb * light;
        smoothWater *= clamp(color.rgb / max(nativeWater, vec3(0.01)), vec3(0.5), vec3(1.5));
        color = gentleWaterSurface(color.rgb, smoothWater, color.a, gentleWorld, gentleView,
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
#ifdef GENTLE_GLOW_TARGET
#ifndef GENTLE_NO_FOG
    emissive *= 1.0 - gentleFogFactor(gentleView);
#endif
    gl_FragData[1] = vec4(emissive, color.a);
#endif
#ifdef GENTLE_SKY_MASK
    // Inspected beta66b WorldRenderingPhase ordinals: SUN=4, MOON=5, STARS=6.
    // Dome, native sunset fan and void plate must not preserve a horizon seam.
    // Native sun/moon/stars use SRC_ALPHA, ONE. Accumulate their RGB on a
    // zero background, never the old sky already blended into colortex0.
    // Zero alpha prevents the sunset fan from altering this independent layer.
    // Custom stars (STAR_STYLE > 0) replace the vanilla ones: stage 6 is dropped.
#if STAR_STYLE > 0
    gl_FragData[1] = renderStage >= 4 && renderStage <= 5 ? color : vec4(0.0);
#else
    gl_FragData[1] = renderStage >= 4 && renderStage <= 6 ? color : vec4(0.0);
#endif
#endif
}
