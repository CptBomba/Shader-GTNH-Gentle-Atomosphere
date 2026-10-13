#ifndef GENTLE_SKY
#define GENTLE_SKY
uniform vec3 skyColor;
uniform vec3 sunPosition;

vec3 gentleSkyGradient(vec3 nativeColor, vec3 direction, vec3 sunDirection, float celestial) {
    if (SKY_STRENGTH <= 0.0) return nativeColor;
    float daylight = gentleDay();
    // Continuous through y=0: the native sky dome's polygon-color boundary
    // must not leak through a weighted blend with the original background.
    float horizon = 1.0 - smoothstep(-0.16, 0.70, direction.y);
    vec3 zenith = mix(skyColor, vec3(0.27, 0.55, 0.79), daylight * 0.38);
    zenith *= vec3(0.86, 0.95, 1.02);
    vec3 distant = mix(skyColor, fogColor, 0.65);
    distant = mix(distant, vec3(0.70, 0.81, 0.88), daylight * 0.32);
    vec3 baseline = mix(skyColor, fogColor, horizon * 0.65);
    vec3 gradient = mix(baseline, mix(zenith, distant, horizon), SKY_STRENGTH);
    vec3 sun = normalize(sunDirection + vec3(0.000001));
    vec2 sunHorizontal = normalize(sun.xz + vec2(0.000001));
    vec2 eyeHorizontal = normalize(direction.xz + vec2(0.000001));
    float sunSide = pow(max(dot(sunHorizontal, eyeHorizontal), 0.0), 3.0);
    float dusk = gentleTwilight() * exp(-abs(direction.y) * 4.5) * SKY_STRENGTH;
    // Warm glow faces the actual sun; the opposite horizon stays cooler.
    gradient += mix(vec3(0.025, 0.020, 0.042), vec3(0.18, 0.058, 0.009), sunSide) * dusk;
    float luminance = dot(gradient, vec3(0.2126, 0.7152, 0.0722));
    gradient = mix(gradient, vec3(luminance) * vec3(0.98, 1.0, 1.03), clamp(wetness, 0.0, 1.0) * 0.55);
    // The real sky render stages supply this mask; luminance cannot distinguish
    // a dim moon from a bright native horizon/void plate.
    return mix(gradient, nativeColor, clamp(celestial, 0.0, 1.0));
}
#endif
