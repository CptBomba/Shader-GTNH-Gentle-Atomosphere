#ifndef GENTLE_FOG
#define GENTLE_FOG
uniform int fogMode;
uniform float fogDensity;
uniform float fogStart;
uniform float fogEnd;
uniform vec3 fogColor;

float gentleFogFactor(vec3 viewPosition) {
    float d = length(viewPosition);
    float visibility = 1.0;
    if (fogMode == 9729) {
        visibility = clamp((fogEnd - d) / max(fogEnd - fogStart, 0.001), 0.0, 1.0);
        if (gentleEarth()) {
            // Extra atmosphere only near the existing fog horizon.
            float strength = FOG_STRENGTH + clamp(wetness, 0.0, 1.0) * 0.035;
            float extra = max(strength - 1.0, 0.0);
            float distant = smoothstep(fogEnd * 0.24, fogEnd * 0.86, d);
            visibility *= 1.0 - distant * extra * 0.72;
            visibility = 1.0 - clamp((1.0 - visibility) * strength, 0.0, 1.0);
        }
    } else if (fogMode == 2048) {
        visibility = exp(-d * fogDensity);
    } else if (fogMode == 2049) {
        visibility = exp(-d * d * fogDensity * fogDensity);
    }
    // EXP/EXP2 are unchanged: lava, water, blindness and mod fog stay readable.
    return 1.0 - clamp(visibility, 0.0, 1.0);
}

vec3 gentleFog(vec3 color, vec3 viewPosition) {
    return mix(color, fogColor, gentleFogFactor(viewPosition));
}
#endif
