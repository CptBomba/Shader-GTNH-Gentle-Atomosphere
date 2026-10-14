#ifndef GENTLE_STARS
#define GENTLE_STARS
// Procedural stars replacing vanilla's square specks: varied size and color,
// gentle twinkle, horizon fade, and an optional faint Milky Way. They turn
// with the sky like vanilla stars. Only sky pixels at night pay for this.
float gentleStarHash(vec3 p) {
    return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float gentleStarNoise(vec3 p) {
    vec3 cell = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = mix(gentleStarHash(cell), gentleStarHash(cell + vec3(1.0, 0.0, 0.0)), f.x);
    float b = mix(gentleStarHash(cell + vec3(0.0, 1.0, 0.0)), gentleStarHash(cell + vec3(1.0, 1.0, 0.0)), f.x);
    float c = mix(gentleStarHash(cell + vec3(0.0, 0.0, 1.0)), gentleStarHash(cell + vec3(1.0, 0.0, 1.0)), f.x);
    float d = mix(gentleStarHash(cell + vec3(0.0, 1.0, 1.0)), gentleStarHash(cell + vec3(1.0)), f.x);
    return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

// One layer of stars on a 3D grid laid over the celestial sphere.
vec3 gentleStarLayer(vec3 direction, float density, float chance, float size, float brightness) {
    vec3 p = direction * density;
    // Derivatives first: they are undefined after a divergent branch.
    float pixel = length(fwidth(p));
    vec3 cell = floor(p);
    float exists = gentleStarHash(cell);
    if (exists > chance) return vec3(0.0);
    vec3 star = cell + 0.25 + 0.5 * vec3(gentleStarHash(cell + 1.7), gentleStarHash(cell + 3.1), gentleStarHash(cell + 5.3));
    // Antialiased: never smaller than about one screen pixel.
    float sigma = max(size, pixel * 0.55);
    float d = length(p - star);
    float energy = (size * size) / (sigma * sigma);
    float shape = exp(-d * d / (2.0 * sigma * sigma)) * energy;
    float r = exists / chance;
    vec3 color = mix(vec3(0.72, 0.82, 1.0), vec3(1.0, 0.88, 0.72), gentleStarHash(cell + 9.4));
    float t = frameTimeCounter * GENTLE_TAU / 3600.0;
    float twinkle = 0.80 + 0.20 * sin(t * 7200.0 + r * 40.0);
    return color * shape * brightness * mix(0.35, 1.0, r) * twinkle;
}

vec3 gentleStars(vec3 direction, vec3 sunDirection) {
#if STAR_STYLE > 0
    float night = gentleNight();
    if (night <= 0.0 || !gentleEarth() || SKY_STRENGTH <= 0.0) return vec3(0.0);
    float visible = night * night * (1.0 - clamp(wetness, 0.0, 1.0));
    visible *= smoothstep(-0.02, 0.22, direction.y);
    vec2 sun = normalize(sunDirection.xy + vec2(0.0, 0.000001));
    // Rotate into a frame fixed to the sun's path, so stars turn with the sky.
    vec3 d = vec3(direction.x * sun.x + direction.y * sun.y,
        -direction.x * sun.y + direction.y * sun.x, direction.z);
    vec3 stars = gentleStarLayer(d, 180.0, 0.12, 0.07, 2.0)
        + gentleStarLayer(d, 70.0, 0.05, 0.06, 4.5);
#if STAR_STYLE == 2
    // A faint, patchy band across the sky.
    vec3 bandNormal = normalize(vec3(0.35, 0.25, 1.0));
    float band = exp(-pow(dot(d, bandNormal) / 0.22, 2.0));
    float clouds = gentleStarNoise(d * 7.0) * 0.65 + gentleStarNoise(d * 17.0) * 0.35;
    stars += vec3(0.50, 0.55, 0.78) * band * smoothstep(0.30, 0.85, clouds) * 0.06;
    stars += gentleStarLayer(d, 260.0, 0.35 * band, 0.06, 0.9);
#endif
    // A bright full moon washes out the faintest stars a little.
    return stars * visible * (1.3 - 0.4 * gentleMoonlight());
#else
    return vec3(0.0);
#endif
}
#endif
