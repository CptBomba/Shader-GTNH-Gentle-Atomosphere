#ifndef GENTLE_BLOCKLIGHT
#define GENTLE_BLOCKLIGHT
// Artificial light (torches, lamps, lava, held items). Everything is built on
// the game's own lightmap texture, so brightness, gamma, night vision and
// lightning flashes keep working exactly as in vanilla.
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

// Vanilla lightmap coordinate <-> light level 0..15.
float gentleLightLevel(float coordinate) {
    return clamp((coordinate * 256.0 - 8.0) / 16.0, 0.0, 15.0);
}

float gentleLightCoordinate(float level) {
    return (clamp(level, 0.0, 15.0) * 16.0 + 8.0) / 256.0;
}

// A torch, glowstone or any light-emitting item in either hand lights the
// surroundings like a placed block would: one level less per block.
vec2 gentleHeldLight(vec2 lightUV, vec3 relativePosition) {
#if HANDHELD_LIGHT == 1
    float held = float(max(heldBlockLightValue, heldBlockLightValue2));
    if (held > 0.0 && gentleEarth()) {
        float level = held - length(relativePosition);
        lightUV.x = max(lightUV.x, gentleLightCoordinate(level));
    }
#endif
    return lightUV;
}

// Warm, slightly brighter pools of light around artificial sources, fading
// wherever skylight dominates (daylight outdoors stays untouched).
vec3 gentleBlockLight(vec3 light, vec2 lightUV, vec3 worldPosition) {
    if (BLOCKLIGHT_WARMTH <= 0.0 || !gentleEarth()) return light;
    vec3 luma = vec3(0.2126, 0.7152, 0.0722);
    float blockOnly = dot(texture2D(lightmap, vec2(lightUV.x, 0.03125)).rgb, luma);
    float skyOnly = dot(texture2D(lightmap, vec2(0.03125, lightUV.y)).rgb, luma);
    float share = smoothstep(0.45, 0.90, blockOnly / (blockOnly + skyOnly + 0.02));
    // Level 15 is the light source itself (lava, fullbright machine overlays
    // and lamp faces): keep its authored color.
    share *= 1.0 - smoothstep(0.93, 0.965, lightUV.x);
    float level = gentleLightLevel(lightUV.x) / 15.0;
    // Hotter and brighter close to the flame, a deeper amber further away.
    vec3 tint = mix(vec3(1.10, 0.90, 0.68), vec3(1.16, 0.97, 0.80), level * level);
    float glow = 1.0 + 0.28 * pow(level, 6.0);
#if TORCH_FLICKER == 1
    // A soft, irregular breathing of nearby light. Long spatial wavelength:
    // one room flickers together, separate rooms drift apart.
    float t = frameTimeCounter * GENTLE_TAU / 3600.0;
    float phase = dot(worldPosition.xz, vec2(0.09, 0.07)) + worldPosition.y * 0.05;
    float flicker = sin(t * 26000.0 + phase) * 0.55 + sin(t * 41000.0 + phase * 1.7) * 0.30
        + sin(t * 9000.0 + phase * 0.6) * 0.15;
    glow *= 1.0 + 0.035 * flicker * level * level;
#endif
    vec3 graded = light * tint * glow;
    return min(mix(light, graded, share * BLOCKLIGHT_WARMTH), vec3(1.25));
}
#endif
