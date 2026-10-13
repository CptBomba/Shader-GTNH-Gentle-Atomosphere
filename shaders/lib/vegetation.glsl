#ifndef GENTLE_VEGETATION
#define GENTLE_VEGETATION
#ifndef GENTLE_CAMERA_DECLARED
#define GENTLE_CAMERA_DECLARED
uniform vec3 cameraPosition;
#endif
vec3 gentleWind(vec3 worldPosition, float material, float upperVertex, float skylight) {
#if VEGETATION_SWAY == 1
    if (!gentleEarth() || WIND_STRENGTH <= 0.0) return vec3(0.0);
    bool leaf = abs(material - 10001.0) < 0.25;
    bool plant = abs(material - 10002.0) < 0.25;
    bool crop = abs(material - 10003.0) < 0.25;
    bool lily = abs(material - 10005.0) < 0.25;
    if (!leaf && !plant && !crop && !lily) return vec3(0.0);

    // World-space phase prevents synchronization and camera-relative swimming.
    // Every temporal multiplier is an integer number of cycles per hour.
    float t = frameTimeCounter * GENTLE_TAU / 3600.0;
    float exposure = smoothstep(0.10, 0.65, skylight);
    // Identical camera distance in geometry and shadow passes; far subpixel
    // plants stop swaying instead of exposing alternating dark texels.
    float distanceFade = 1.0 - smoothstep(24.0, 64.0, length(worldPosition - cameraPosition));
    // Rain brings stronger wind.
    float weather = 1.0 + clamp(wetness, 0.0, 1.0) * 0.6;
    float strength = WIND_STRENGTH * exposure * distanceFade * weather;
    float phase = worldPosition.x * 0.12 + worldPosition.z * 0.09;
    if (lily) {
        // Lily pads drift and bob gently on the water as one piece.
        float bob = sin(t * 700.0 + phase * 2.0);
        return vec3(sin(t * 410.0 + phase) * 0.020, bob * 0.012, cos(t * 330.0 + phase * 1.3) * 0.020)
            * strength / max(WIND_STRENGTH, 0.01);
    }
    // Slow lean: long spatial wavelengths keep a flower/leaf coherent. Short
    // per-vertex phases were shearing crossed quads in opposite directions.
    float gust = sin(t * 240.0 + phase) + 0.22 * sin(t * 143.0 + phase * 1.37);
    float crosswind = sin(t * 180.0 + phase * 0.83);
    // Gust fronts roll across fields and canopies (about 30 blocks apart,
    // a few blocks per second), so grass visibly waves in passing bands.
    float front = sin(t * 540.0 - dot(worldPosition.xz, vec2(0.17, 0.12)));
    float crest = 0.5 + 0.5 * front;
    float envelope = 0.55 + 0.45 * crest * crest;
    // Quick flutter: blades and leaves never freeze completely.
    float flutter = sin(t * 2300.0 + phase * 3.1) * 0.6 + sin(t * 3700.0 + phase * 5.3) * 0.4;
    if (leaf) {
        // Leaves rustle in place: whole blocks barely move, vertices shimmer
        // with a short world-space phase so the canopy reads as alive.
        float rustle = sin(t * 2900.0 + dot(worldPosition, vec3(1.9, 1.3, 2.3)));
        return vec3(gust * 0.040 + rustle * 0.022, rustle * 0.012, crosswind * 0.030 + rustle * 0.018)
            * envelope * strength;
    }
    float amplitude = crop ? 0.12 : 0.19;
    // Crop/grass feet remain fixed by the atlas midpoint, not fract(world.y).
    float sway = gust * 0.75 + flutter * 0.35;
    return vec3(sway, 0.0, crosswind * 0.55 + flutter * 0.20)
        * amplitude * envelope * strength * upperVertex;
#else
    return vec3(0.0);
#endif
}
#endif
