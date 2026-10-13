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
    if (!leaf && !plant && !crop) return vec3(0.0);

    // World-space phase prevents synchronization and camera-relative swimming.
    // Slow, periodic oscillations; no vertical stretching and no trunk mapping.
    // Long spatial wavelengths keep the vertices of a flower/leaf coherent.
    // Short per-vertex phases were shearing crossed quads in opposite directions.
    float phase = worldPosition.x * 0.12 + worldPosition.z * 0.09;
    float t = frameTimeCounter * GENTLE_TAU / 3600.0;
    float gust = sin(t * 240.0 + phase)
        + 0.22 * sin(t * 143.0 + phase * 1.37);
    float crosswind = sin(t * 180.0 + phase * 0.83);
    float amplitude = leaf ? 0.055 : (crop ? 0.12 : 0.19);
    // Crop/grass feet remain fixed by the atlas midpoint, not fract(world.y).
    // Indoor leaves/plants have almost no movement; machines always have zero.
    float anchor = leaf ? 1.0 : upperVertex;
    float exposure = smoothstep(0.10, 0.65, skylight);
    // Identical camera distance in geometry and shadow passes; far subpixel
    // plants stop swaying instead of exposing alternating dark texels.
    float distanceFade = 1.0 - smoothstep(24.0, 64.0, length(worldPosition - cameraPosition));
    return vec3(gust, 0.0, crosswind * 0.55)
        * amplitude * WIND_STRENGTH * anchor * exposure * distanceFade;
#else
    return vec3(0.0);
#endif
}
#endif
