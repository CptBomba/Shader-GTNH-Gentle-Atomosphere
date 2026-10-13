#ifndef GENTLE_LIGHTING
#define GENTLE_LIGHTING
uniform mat4 gbufferModelViewInverse;
uniform vec3 shadowLightPosition;
#if SHADOWS == 1 && !defined(GENTLE_NON_EARTH)
uniform sampler2D shadowtex0;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
const int shadowMapResolution = 2048;
const float shadowDistance = 64.0;
const float shadowDistanceRenderMul = 1.0;
const float shadowIntervalSize = 0.0625;
const bool shadowtex0Nearest = true;
#endif

vec3 gentleSunDirection() {
    vec3 light = mat3(gbufferModelViewInverse) * shadowLightPosition;
    return normalize(light + vec3(0.0, 0.00001, 0.0));
}

vec2 gentleShadowGradient(vec3 normal, vec3 dpdx, vec3 dpdy, bool plant) {
#if SHADOWS == 1 && !defined(GENTLE_NON_EARTH)
    // A block's geometric plane survives close-up pixel footprints. Animated
    // crossed quads can differ from their authored normals, so their actual
    // plane comes from position derivatives taken in uniform control flow.
    vec3 plane = plant ? cross(dpdx, dpdy) : normal;
    plane = mat3(shadowModelView) * plane;
    plane /= max(length(plane), 0.00000000000000000001);
    if (abs(plane.z) > 0.00001)
        return -plane.xy / plane.z * shadowProjection[2][2]
            / vec2(shadowProjection[0][0], shadowProjection[1][1]);
#endif
    return vec2(0.0);
}

// Direct sunlight cannot reach a surface that the sky barely reaches. Vanilla
// skylight levels 15..14 keep the shadow map, 13 fades, 12 and below are
// always shaded. This removes indoor light leaks through roofs, caves and
// walls outside the shadow map, and skips the nine shadow taps there.
float gentleSkyAccess(float skylight) {
    return smoothstep(0.75, 0.90, skylight);
}

// Surfaces turned away from the sun are always on the shaded side. Plants and
// leaves are two-sided and keep their own softer response.
float gentleFacing(vec3 normal, bool foliage) {
    if (foliage) return 1.0;
    return smoothstep(0.0, 0.10, dot(normal, gentleSunDirection()));
}

float gentleSunVisibility(vec3 relativePosition, vec3 normal, bool plant, vec2 gradient) {
#if SHADOWS == 1 && !defined(GENTLE_NON_EARTH)
    vec3 lightDirection = gentleSunDirection();
    // Bias towards the illuminated side even for crossed/back-facing quads.
    vec3 biasNormal = plant ? vec3(0.0, 1.0, 0.0) : normal;
    vec3 facingNormal = dot(biasNormal, lightDirection) < 0.0 ? -biasNormal : biasNormal;
    vec4 projected = shadowProjection * shadowModelView
        * vec4(relativePosition + (facingNormal * 0.035 + lightDirection * 0.035) * SHADOW_BIAS, 1.0);
    vec3 coord = projected.xyz / max(abs(projected.w), 0.00001) * 0.5 + 0.5;
    if (any(lessThan(coord, vec3(0.002))) || any(greaterThan(coord, vec3(0.998)))) return 1.0;
    float texel = 1.0 / float(shadowMapResolution);
    float bias = 0.00006 * SHADOW_BIAS;
    // Compact separable filter anchored to texel centers. Weights reach zero
    // before a tap leaves the 3x3 window, so subtexel motion has no box-PCF jumps.
    // Receiver-plane correction: each tap compares against the depth of this
    // surface at that tap, instead of a single depth for the whole kernel.
    vec2 center = floor(coord.xy * float(shadowMapResolution));
    vec2 fraction = coord.xy * float(shadowMapResolution) - center - 0.5;
    vec2 left = 0.5 - fraction, right = 0.5 + fraction;
    vec3 weightX = vec3(0.5 * left.x * left.x, 0.75 - fraction.x * fraction.x, 0.5 * right.x * right.x);
    vec3 weightY = vec3(0.5 * left.y * left.y, 0.75 - fraction.y * fraction.y, 0.5 * right.y * right.y);
    // Quadratic B-spline weights sum to one without divisions. The softness
    // control blends towards a tighter linear filter, with the same continuity.
    float tightness = (1.8 - SHADOW_SOFTNESS) / 1.2;
    weightX = mix(weightX, vec3(max(-fraction.x, 0.0), 1.0 - abs(fraction.x), max(fraction.x, 0.0)), tightness);
    weightY = mix(weightY, vec3(max(-fraction.y, 0.0), 1.0 - abs(fraction.y), max(fraction.y, 0.0)), tightness);
    float visibility = 0.0;
    for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
        // Compare at the texel actually fetched. A clamped gradient or the
        // unrounded UV produces stripes/stipple on grazing industrial faces.
        vec2 sampleUV = (center + vec2(float(x), float(y)) + 0.5) * texel;
        float planeDepth = coord.z + dot(gradient, sampleUV - coord.xy) - bias;
        visibility += step(planeDepth, texture2D(shadowtex0, sampleUV).r) * weightX[x + 1] * weightY[y + 1];
    }
    float edge = max(abs(coord.x - 0.5), abs(coord.y - 0.5)) * 2.0;
    float distanceFade = smoothstep(48.0, 62.0, length(relativePosition.xz));
    return mix(visibility, 1.0, max(distanceFade, smoothstep(0.84, 0.98, edge)));
#else
    return 1.0;
#endif
}

// Complete direct-sun visibility for a fragment. Must be called from uniform
// control flow: it takes the position derivatives before any branch.
float gentleSunVisibility(vec3 relativePosition, vec3 normal, float material, float skylight) {
    vec3 dpdx = dFdx(relativePosition), dpdy = dFdy(relativePosition);
    if (SUNLIGHT_STRENGTH <= 0.0 && WATER_STRENGTH <= 0.0) return 1.0;
    if (!gentleEarth() || gentleDay() <= 0.0) return 1.0;
    bool plant = material > 10001.5 && material < 10003.5;
    bool foliage = material > 10000.5 && material < 10003.5;
    vec3 n = normalize(normal + vec3(0.0, 0.00001, 0.0));
    vec2 gradient = gentleShadowGradient(n, dpdx, dpdy, plant);
    float access = gentleSkyAccess(skylight) * gentleFacing(n, foliage);
    // Shadow taps have no mipmaps, so the varying branch is well defined.
    if (access <= 0.0) return 0.0;
    return access * gentleSunVisibility(relativePosition, n, plant, gradient);
}

vec3 gentleSunlight(vec3 color, vec3 normal, float influence, float material, float visibility) {
    // Time is uniform across the draw, so this avoids all nighttime work.
    if (SUNLIGHT_STRENGTH <= 0.0 || gentleDay() <= 0.0) return color;
    vec3 n = normalize(normal + vec3(0.0, 0.00001, 0.0));
    float diffuse = max(dot(n, gentleSunDirection()), 0.0);
    // Crossed plant quads receive light on both sides instead of becoming dark.
    bool plant = material > 10001.5 && material < 10003.5;
    if (material > 10000.5 && material < 10003.5) diffuse = 0.65 + 0.20 * abs(dot(n, gentleSunDirection()));
    vec3 sunlit = mix(vec3(1.030, 1.015, 0.985), vec3(1.09, 1.025, 0.90), gentleTwilight() * 0.55);
    // Shade is a soft sky-blue, never a black cutout: the game should still
    // look like Minecraft, only with a sense of where the sun is.
    vec3 shaded = plant ? vec3(0.80, 0.86, 0.93) : vec3(0.75, 0.82, 0.91);
    vec3 lighting = mix(shaded, sunlit, visibility);
    lighting *= 0.91 + 0.15 * diffuse;
    // Overcast light is diffuse: shadows fade out with rain.
    lighting = mix(lighting, vec3(0.97, 0.98, 1.0), clamp(wetness, 0.0, 1.0) * 0.85);
    return color * mix(vec3(1.0), lighting, influence * SUNLIGHT_STRENGTH);
}
#endif
