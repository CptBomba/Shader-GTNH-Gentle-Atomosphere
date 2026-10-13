#ifndef GENTLE_LOCAL_LIGHTS
#define GENTLE_LOCAL_LIGHTS
// Angelica's public custom-resource texture hook binds the companion's RGBA8
// grid to the existing noisetex sampler. Missing/invalid resources fail closed.
uniform sampler2D noisetex;
vec4 gentleGridPixel(float index) {
    return texture2D(noisetex, (vec2(mod(index, 256.0), floor(index / 256.0)) + 0.5) / vec2(256.0, 512.0));
}
vec3 gentleGridBytes(float index) { return floor(gentleGridPixel(index).rgb * 255.0 + 0.5); }
float gentleGridOrigin(float index) {
    return dot(gentleGridBytes(index), vec3(65536.0, 256.0, 1.0)) - 8388608.0;
}
float gentleVolumeVisibility(vec3 point, vec3 light, float volume) {
    vec3 cell = floor(point), target = floor(light);
    vec3 delta = light - point;
    vec3 stepDir = sign(delta);
    vec3 inverse = 1.0 / max(abs(delta), vec3(0.00001));
    vec3 boundary = cell + step(vec3(0.0), delta);
    vec3 next = abs(boundary - point) * inverse;
    // Amanatides/Woo DDA, no random per-frame samples or screen-space holes.
    for (int stepIndex = 0; stepIndex < 32; ++stepIndex) {
        if (all(equal(cell, target))) return 1.0;
        if (any(lessThan(cell, vec3(0.0))) || any(greaterThanEqual(cell, vec3(32.0)))) return 1.0;
        float index = 256.0 + volume * 32768.0 + cell.x + cell.z * 32.0 + cell.y * 1024.0;
        vec3 voxel = gentleGridPixel(index).rgb;
        if (voxel.b < 0.5) return 1.0; // Unknown/unloaded: preserve vanilla.
        if (voxel.r > 0.5) return 0.0;
        if (next.x <= next.y && next.x <= next.z) { cell.x += stepDir.x; next.x += inverse.x; }
        else if (next.y <= next.z) { cell.y += stepDir.y; next.y += inverse.y; }
        else { cell.z += stepDir.z; next.z += inverse.z; }
    }
    return 1.0;
}
float gentleVoxelVisibility(vec3 point, vec3 light) { return gentleVolumeVisibility(point, light, 0.0); }
float gentleLocalOcclusion(vec3 world, vec3 normal, float volume) {
    float base = volume * 4.0;
    vec3 origin = vec3(gentleGridOrigin(base + 1.0), gentleGridOrigin(base + 2.0), gentleGridOrigin(base + 3.0));
    vec3 local = world - origin;
    if (any(lessThan(local, vec3(0.0))) || any(greaterThan(local, vec3(32.0)))) return 0.0;
    float edge = min(min(local.x, 32.0-local.x), min(min(local.y, 32.0-local.y), min(local.z, 32.0-local.z)));
    vec3 n = length(normal) > 0.01 ? normalize(normal) : vec3(0.0, 1.0, 0.0);
    float blocked = 0.0, total = 0.0;
    for (int i = 0; i < 8; ++i) {
        vec4 data = gentleGridPixel(8.0 + volume * 8.0 + float(i));
        float level = floor(data.a * 15.0 + 0.5);
        if (level < 1.0) continue;
        vec3 light = floor(data.rgb * 255.0 + 0.5) + vec3(0.5);
        float distanceToLight = length(light - local);
        float range = min(12.0, level * 0.85);
        if (distanceToLight >= range) continue;
        float falloff = 1.0 - distanceToLight / range;
        float weight = falloff * falloff * level / 15.0
            * smoothstep(0.35, 0.85, distanceToLight);
        float visibility = gentleVolumeVisibility(local + n * 0.10, light, volume);
        blocked += (1.0 - visibility) * weight;
        total += weight;
    }
    // No first-N cutoff per fragment and no division by a near-zero total.
    return blocked / (total + 0.35) * smoothstep(0.0, 2.0, edge);
}
vec3 gentleLocalLights(vec3 color, vec3 world, vec3 normal, float blockLight, float skyLight) {
#if LOCAL_LIGHT_SHADOWS > 0
    float litFraction = smoothstep(0.09, 0.70, blockLight)
        * (1.0 - smoothstep(0.94, 0.96875, blockLight)); // Preserve fullbright/emissive.
    // Dark and emissive surfaces receive no local attenuation. Avoid tracing
    // both complete volumes when their contribution is exactly zero.
    if (litFraction <= 0.0 || !gentleEarth()) return color;
    vec3 header = gentleGridBytes(0.0);
    if (any(notEqual(header, vec3(97.0, 2.0, 255.0)))) return color;
    float fade = smoothstep(0.0, 1.0, gentleGridPixel(4.0).r);
    float current = fade > 0.0 ? gentleLocalOcclusion(world, normal, 0.0) : 0.0;
    float previous = fade < 1.0 ? gentleLocalOcclusion(world, normal, 1.0) : 0.0;
    float strength = mix(previous, current, fade);
    float daylightProtection = 1.0 - gentleDay() * smoothstep(0.45, 0.95, skyLight) * 0.80;
#if LOCAL_LIGHT_SHADOWS == 1
    strength *= 0.80;
#endif
    return color * (1.0 - strength * 0.45 * litFraction * daylightProtection);
#else
    return color;
#endif
}
#endif
