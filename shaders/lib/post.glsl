#ifndef GENTLE_POST
#define GENTLE_POST
uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjectionInverse;
uniform float viewWidth;
uniform float viewHeight;

float gentleLuma(vec3 color) {
    return dot(color, vec3(0.299, 0.587, 0.114));
}

vec3 gentlePostImage(vec2 uv) {
    vec2 pixel = 1.0 / max(vec2(viewWidth, viewHeight), vec2(1.0));
    vec3 center = texture2D(colortex0, uv).rgb;
    vec3 north = texture2D(colortex0, uv + vec2(0.0, pixel.y)).rgb;
    vec3 south = texture2D(colortex0, uv - vec2(0.0, pixel.y)).rgb;
    vec3 east = texture2D(colortex0, uv + vec2(pixel.x, 0.0)).rgb;
    vec3 west = texture2D(colortex0, uv - vec2(pixel.x, 0.0)).rgb;
    vec3 low = min(center, min(min(north, south), min(east, west)));
    vec3 high = max(center, max(max(north, south), max(east, west)));
    vec3 result = center;
    float coverage = 0.0;
#if ANTIALIASING == 1
    vec3 nw = texture2D(colortex0, uv + vec2(-pixel.x, pixel.y)).rgb;
    vec3 ne = texture2D(colortex0, uv + pixel).rgb;
    vec3 sw = texture2D(colortex0, uv - pixel).rgb;
    vec3 se = texture2D(colortex0, uv + vec2(pixel.x, -pixel.y)).rgb;
    float lNW = gentleLuma(nw), lNE = gentleLuma(ne), lSW = gentleLuma(sw), lSE = gentleLuma(se);
    float lC = gentleLuma(center);
    float lMin = min(gentleLuma(low), min(min(lNW, lNE), min(lSW, lSE)));
    float lMax = max(gentleLuma(high), max(max(lNW, lNE), max(lSW, lSE)));
    if (lMax - lMin > max(0.045, lMax * 0.14)) {
        vec2 direction = vec2(-((lNW + lNE) - (lSW + lSE)), (lNW + lSW) - (lNE + lSE));
        float reduce = max((lNW + lNE + lSW + lSE) * 0.03125, 0.0078125);
        direction = clamp(direction / (min(abs(direction.x), abs(direction.y)) + reduce), vec2(-6.0), vec2(6.0)) * pixel;
        vec3 narrow = 0.5 * (texture2D(colortex0, uv - direction / 6.0).rgb + texture2D(colortex0, uv + direction / 6.0).rgb);
        vec3 wide = narrow * 0.5 + 0.25 * (texture2D(colortex0, uv - direction * 0.5).rgb + texture2D(colortex0, uv + direction * 0.5).rgb);
        float lWide = gentleLuma(wide);
        result = lWide < lMin || lWide > lMax ? narrow : wide;
    }
    // Diagonal-only FXAA misses a 1-pixel checkerboard (chainmail/cutouts):
    // every diagonal equals the center and the inferred direction is zero.
    // Restore bounded subpixel coverage without sharpening those tiny holes.
    vec3 neighborhood = (north + south + east + west) / 6.0 + (nw + ne + sw + se) / 12.0;
    float subpixel = abs(lC - gentleLuma(neighborhood)) / max(lMax - lMin, 0.001);
    coverage = smoothstep(0.15, 0.70, subpixel) * 0.35;
    result = mix(result, neighborhood, coverage);
#endif
    // Locally bounded sharpening: no white/black ringing outside nearby colors.
    // Strong edges receive less sharpening so it does not undo antialiasing.
    float contrast = gentleLuma(high - low);
    float gain = SHARPNESS * (1.0 - smoothstep(0.12, 0.60, contrast));
    gain *= 1.0 - coverage / 0.35 * 0.90;
    float depth = texture2D(depthtex0, uv).r;
    vec4 view = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    float distanceToEye = length(view.xyz / max(abs(view.w), 0.00001));
    gain *= 1.0 - smoothstep(24.0, 64.0, distanceToEye) * 0.85;
    vec3 detail = center - (north + south + east + west) * 0.25;
    return clamp(result + detail * gain, low, high);
}

vec3 gentleBloom(vec2 uv) {
    vec2 offset = vec2(0.0, 2.0 / max(viewHeight, 1.0));
    // Five linear-filtered taps provide a wide Gaussian approximation.
    vec3 glow = texture2D(colortex3, uv).rgb * 0.227027;
    glow += texture2D(colortex3, uv + offset * 1.384615).rgb * 0.316216;
    glow += texture2D(colortex3, uv - offset * 1.384615).rgb * 0.316216;
    glow += texture2D(colortex3, uv + offset * 3.230769).rgb * 0.070270;
    glow += texture2D(colortex3, uv - offset * 3.230769).rgb * 0.070270;
    return min(glow, vec3(0.50)) * BLOOM_STRENGTH;
}

vec3 gentleHighlights(vec3 color) {
    float peak = max(color.r, max(color.g, color.b));
    float bright = max(peak - 0.72, 0.0);
    float compressed = 0.72 + bright / (1.0 + bright * HIGHLIGHT_COMPRESSION * 4.0);
    return color * (peak > 0.72 ? compressed / max(peak, 0.00001) : 1.0);
}
#endif
