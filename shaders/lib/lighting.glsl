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

vec2 gentleShadowGradient(vec3 relativePosition, vec3 normal, vec3 coord, bool plant) {
#if SHADOWS == 1 && !defined(GENTLE_NON_EARTH)
    if (!plant) {
        // A block's geometric plane survives close-up pixel footprints. Taking
        // derivatives of normalized shadow depth loses those tiny differences
        // (and the old absolute determinant cutoff dropped the plane entirely).
        vec3 plane = mat3(shadowModelView) * normal;
        if (abs(plane.z) > 0.00001)
            return -plane.xy / plane.z * shadowProjection[2][2]
                / vec2(shadowProjection[0][0], shadowProjection[1][1]);
        return vec2(0.0);
    }
    // Animated crossed quads can differ from their authored normals. Derive
    // their actual plane before projection, without subtracting nearly equal
    // normalized depth values. Normalize before testing for a singular plane.
    vec3 plane = mat3(shadowModelView) * cross(dFdx(relativePosition), dFdy(relativePosition));
    plane /= max(length(plane), 0.00000000000000000001);
    if (abs(plane.z) > 0.00001)
        return -plane.xy / plane.z * shadowProjection[2][2]
            / vec2(shadowProjection[0][0], shadowProjection[1][1]);
#endif
    return vec2(0.0);
}

float gentleSunVisibility(vec3 relativePosition, vec3 normal, bool plant) {
#if SHADOWS == 1 && !defined(GENTLE_NON_EARTH)
    vec3 lightDirection = gentleSunDirection();
    // Bias towards the illuminated side even for crossed/back-facing quads.
    vec3 biasNormal = plant ? vec3(0.0, 1.0, 0.0) : normal;
    vec3 facingNormal = dot(biasNormal, lightDirection) < 0.0 ? -biasNormal : biasNormal;
    vec4 projected = shadowProjection * shadowModelView
        * vec4(relativePosition + (facingNormal * 0.035 + lightDirection * 0.035) * SHADOW_BIAS, 1.0);
    vec3 coord = projected.xyz / max(abs(projected.w), 0.00001) * 0.5 + 0.5;
    // Receiver-plane correction: each PCF tap compares against the depth of
    // this surface AT THAT TAP, instead of a single depth for the whole kernel.
    // Nearest-texel rounding also needs half a texel of slope compensation.
    vec2 gradient = gentleShadowGradient(relativePosition, normal, coord, plant);
    if (any(lessThan(coord, vec3(0.002))) || any(greaterThan(coord, vec3(0.998)))) return 1.0;
    float texel = 1.0 / float(shadowMapResolution);
    float bias = 0.00006 * SHADOW_BIAS;
    // Compact separable filter anchored to texel centers. Weights reach zero
    // before a tap leaves the 3x3 window, so subtexel motion has no box-PCF jumps.
    // Keep nine depth reads and compare each one on the actual receiver plane.
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

float gentleSunVisibility(vec3 relativePosition, vec3 normal) {
    return gentleSunVisibility(relativePosition, normal, false);
}

vec3 gentleSunlight(vec3 color, vec3 relativePosition, vec3 normal,
    float influence, float material, float visibility) {
    // Time is uniform across the draw, so this avoids all nighttime PCF
    // work without putting receiver-plane derivatives in a varying branch.
    if (SUNLIGHT_STRENGTH <= 0.0 || gentleDay() <= 0.0) return color;
    vec3 n = normalize(normal + vec3(0.0, 0.00001, 0.0));
    float diffuse = max(dot(n, gentleSunDirection()), 0.0);
    // Crossed plant quads receive light on both sides instead of becoming dark.
    bool plant = material > 10001.5 && material < 10003.5;
    if (material > 10000.5 && material < 10003.5) diffuse = 0.65 + 0.20 * abs(dot(n, gentleSunDirection()));
    // Crossed plants share a gentler contrast.
    vec3 sunlit = mix(vec3(1.030, 1.015, 0.985), vec3(1.09, 1.025, 0.90), gentleTwilight() * 0.55);
    vec3 shaded = vec3(0.73, 0.81, 0.91);
    if (plant) shaded = vec3(0.80, 0.86, 0.93);
    vec3 lighting = mix(shaded, sunlit, visibility);
    lighting *= 0.91 + 0.15 * diffuse;
    lighting = mix(lighting, vec3(0.97, 0.98, 1.0), clamp(wetness, 0.0, 1.0) * 0.85);
    return color * mix(vec3(1.0), lighting, influence * SUNLIGHT_STRENGTH);
}

vec3 gentleSunlight(vec3 color, vec3 relativePosition, vec3 normal,
    float influence, float material) {
    if (SUNLIGHT_STRENGTH <= 0.0 || gentleDay() <= 0.0) return color;
    bool plant = material > 10001.5 && material < 10003.5;
    vec3 n = normalize(normal + vec3(0.0, 0.00001, 0.0));
    return gentleSunlight(color, relativePosition, n, influence, material,
        gentleSunVisibility(relativePosition, n, plant));
}
#endif
