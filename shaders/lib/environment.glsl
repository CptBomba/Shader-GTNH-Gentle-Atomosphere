#ifndef GENTLE_ENVIRONMENT
#define GENTLE_ENVIRONMENT
#include "/lib/settings.glsl"
uniform bool hasSkylight;
uniform bool hasCeiling;
uniform int biome;
uniform int worldTime;
uniform float wetness;
uniform float frameTimeCounter;
uniform int moonPhase;
uniform ivec2 eyeBrightnessSmooth;

bool gentleEarth() {
#if EARTH_EFFECTS == 1 && !defined(GENTLE_NON_EARTH)
    // Conservative allowlist from the inspected GTNH 2.8.4 biome configuration.
    // Unknown biomes fail closed. Galacticraft base 141 is outside these sets.
    // This is a biome guard, NOT an exact dimension ID (unavailable in beta66b).
    bool vanilla = biome >= 0 && biome <= 39 && biome != 8 && biome != 9;
    bool bop = biome >= 40 && biome <= 123 && biome != 46 && biome != 55
        && biome != 93 && biome != 116 && biome != 117;
    // Verified Thaumcraft.cfg: Eerie 190, Magical Forest 192, Taint 193.
    // Eldritch 191 belongs to a separate dimension and remains protected.
    bool thaumcraft = biome == 190 || biome == 192 || biome == 193;
    // All 25 RWG biomes from this instance's rwg.cfg, not RWG's default IDs.
    // GalaxySpace IDs are interleaved here: never accept the entire 200..239 range.
    bool rwg = biome == 200 || biome == 202 || biome == 205 || biome == 207
        || biome == 209 || biome == 211 || biome == 213 || biome == 214
        || biome == 216 || biome == 218 || (biome >= 223 && biome <= 237);
    return hasSkylight && !hasCeiling && (vanilla || bop || thaumcraft || rwg);
#else
    return false;
#endif
}

float gentleDay() {
    // Minecraft's noon is 6000 ticks; civil midnight is 18000.
    float solar = cos((float(worldTime) - 6000.0) * GENTLE_TAU / 24000.0);
    return smoothstep(-0.16, 0.24, solar);
}

// 0 by day, 1 in full night. Uniform across a frame.
float gentleNight() {
    return 1.0 - gentleDay();
}

// Moonlight follows the lunar cycle: full moon 1.0, new moon 0.55.
float gentleMoonlight() {
    float fromFull = min(float(moonPhase), 8.0 - float(moonPhase));
    return 1.0 - 0.1125 * fromFull;
}

// Deep night-blue that replaces pure black outdoors; scaled by the option.
vec3 gentleNightTint() {
    return vec3(0.020, 0.032, 0.062) * NIGHT_BRIGHTNESS * gentleMoonlight();
}

float gentleTwilight() {
    float solar = cos((float(worldTime) - 6000.0) * GENTLE_TAU / 24000.0);
    return (1.0 - smoothstep(0.05, 0.42, abs(solar)))
        * (1.0 - clamp(wetness, 0.0, 1.0));
}
#endif
