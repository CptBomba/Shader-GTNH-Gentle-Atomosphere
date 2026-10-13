#ifndef GENTLE_WATER_SURFACE
#define GENTLE_WATER_SURFACE
#include "/lib/sky.glsl"
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform sampler2D colortex4;
uniform sampler2D depthtex1;
uniform int isEyeInWater;
uniform float viewWidth;
uniform float viewHeight;

vec3 gentleWaveNormal(vec2 position, vec2 pixelDx, vec2 pixelDy) {
    // A continuous world-space height field and its analytic derivatives.
    // Integer temporal harmonics make the Angelica hourly timer wrap seamless.
    float t = frameTimeCounter * GENTLE_TAU / 3600.0;
    vec2 a = vec2(0.48, 0.31), b = vec2(-0.27, 0.63), c = vec2(1.13, -0.81);
    // Fade unresolved harmonics before the Nyquist limit, retaining close waves.
    // Derivatives arrive from uniform flow in geometry.fsh, before cutout discard.
    vec3 footprint = max(abs(vec3(dot(pixelDx, a), dot(pixelDx, b), dot(pixelDx, c))),
        abs(vec3(dot(pixelDy, a), dot(pixelDy, b), dot(pixelDy, c))));
    vec3 resolved = vec3(1.0) - smoothstep(vec3(1.0), vec3(3.14159265), footprint);
    vec2 slope = a * (cos(dot(position, a) + t * 172.0) * 0.11 * resolved.x)
        + b * (cos(dot(position, b) - t * 131.0) * 0.07 * resolved.y)
        + c * (cos(dot(position, c) + t * 233.0) * 0.018 * resolved.z);
    return normalize(vec3(-slope.x * WATER_STRENGTH, 1.0, -slope.y * WATER_STRENGTH));
}

// Distance the view ray travels under the surface before meeting the
// opaque scene (the riverbed), in blocks. One depth read per water pixel.
float gentleWaterThickness(vec3 viewPosition) {
    vec2 uv = gl_FragCoord.xy / max(vec2(viewWidth, viewHeight), vec2(1.0));
    float depth = texture2D(depthtex1, uv).r;
    if (depth >= 0.99999) return 64.0;
    vec4 bed = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    return max(length(bed.xyz / max(abs(bed.w), 0.00001)) - length(viewPosition), 0.0);
}

vec3 gentleWaterReflection(vec3 viewPosition, vec3 worldRay, vec3 fallback) {
#if WATER_REFLECTIONS > 0
    vec3 ray = normalize(mat3(gbufferModelView) * worldRay);
    vec3 origin = viewPosition + ray * 0.25;
    float previousGap = -1000.0;
    float distanceAlong = 0.25;
    #if WATER_REFLECTIONS == 2
        const int steps = 24;
    #else
        const int steps = 12;
    #endif
    for (int i = 0; i < steps; i++) {
        float stride = 0.35 + float(i) * 0.24;
        distanceAlong += stride;
        vec3 point = origin + ray * distanceAlong;
        if (point.z > -0.15) break;
        vec4 projected = gbufferProjection * vec4(point, 1.0);
        vec2 uv = projected.xy / max(projected.w, 0.00001) * 0.5 + 0.5;
        if (any(lessThan(uv, vec2(0.015))) || any(greaterThan(uv, vec2(0.985)))) break;
        float depth = texture2D(depthtex1, uv).r;
        if (depth < 0.99999) {
            vec4 surface = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
            float sceneZ = surface.z / max(abs(surface.w), 0.00001);
            float gap = sceneZ - point.z;
            // A crossing is required: do not reflect objects behind the ray.
            if (gap > 0.0 && previousGap <= 0.0 && gap < 0.40 + stride * 1.25) {
                // Refine the crossing instead of exposing discrete march bands.
                float low = max(distanceAlong - stride, 0.25), high = distanceAlong;
                for (int refinement = 0; refinement < 3; refinement++) {
                    float middle = (low + high) * 0.5;
                    vec3 probe = origin + ray * middle;
                    vec4 probeClip = gbufferProjection * vec4(probe, 1.0);
                    vec2 probeUV = probeClip.xy / max(probeClip.w, 0.00001) * 0.5 + 0.5;
                    float probeDepth = texture2D(depthtex1, probeUV).r;
                    vec4 probeSurface = gbufferProjectionInverse * vec4(probeUV * 2.0 - 1.0, probeDepth * 2.0 - 1.0, 1.0);
                    float probeGap = probeSurface.z / max(abs(probeSurface.w), 0.00001) - probe.z;
                    if (probeDepth >= 0.99999 || probeGap <= 0.0) low = middle;
                    else high = middle;
                }
                vec4 hitClip = gbufferProjection * vec4(origin + ray * high, 1.0);
                uv = hitClip.xy / max(hitClip.w, 0.00001) * 0.5 + 0.5;
                vec2 border = min(uv, vec2(1.0) - uv);
                float confidence = smoothstep(0.015, 0.10, min(border.x, border.y));
                confidence *= 1.0 - smoothstep(18.0, 55.0, distanceAlong);
                return mix(fallback, texture2D(colortex4, uv).rgb, confidence * 0.85);
            }
            previousGap = gap;
        } else {
            previousGap = -1000.0;
        }
    }
    // Reflected sky rays can reuse the actual rendered clouds and sun if those
    // pixels are visible. Off-screen rays smoothly fall back to the sky gradient.
    if (ray.z < -0.01) {
        vec4 farPoint = gbufferProjection * vec4(ray * 128.0, 1.0);
        vec2 uv = farPoint.xy / max(farPoint.w, 0.00001) * 0.5 + 0.5;
        if (all(greaterThan(uv, vec2(0.015))) && all(lessThan(uv, vec2(0.985)))) {
            vec2 border = min(uv, vec2(1.0) - uv);
            float edge = smoothstep(0.015, 0.12, min(border.x, border.y));
            if (texture2D(depthtex1, uv).r >= 0.99999)
                return mix(fallback, texture2D(colortex4, uv).rgb, edge);
        }
    }
#endif
    return fallback;
}

vec4 gentleWaterSurface(vec3 nativeColor, vec3 smoothColor, float opacity, vec3 worldPosition,
    vec3 viewPosition, float skylight, vec2 pixelDx, vec2 pixelDy, float visibility) {
    if (WATER_STRENGTH <= 0.0 || isEyeInWater != 0) return vec4(nativeColor, opacity);
    vec3 normal = gentleWaveNormal(worldPosition.xz, pixelDx, pixelDy);
    vec3 eye = normalize(cameraPosition - worldPosition + vec3(0.0, 0.00001, 0.0));
    vec3 reflectedRay = reflect(-eye, normal);
    float facing = clamp(dot(normal, eye), 0.0, 1.0);
    float fresnel = 0.04 + 0.66 * pow(1.0 - facing, 5.0);
    float exterior = smoothstep(0.35, 0.92, skylight);
    float day = gentleDay();
    float strength = WATER_STRENGTH * exterior;
    // Shallow shores become clearer and deep water gains a richer body. The
    // effect follows the real riverbed depth, so lakes, rivers and puddles
    // differ naturally. Caves and indoor water keep the original look.
    float deep = smoothstep(0.6, 7.0, gentleWaterThickness(viewPosition));
    float alpha = mix(opacity * (1.0 - 0.38 * strength),
        mix(opacity, max(opacity, 0.88), strength), deep);
    vec3 fallback = gentleSkyGradient(skyColor, reflectedRay, mat3(gbufferModelViewInverse) * sunPosition, 0.0);
    fallback *= mix(0.35, 1.0, day);
    vec3 reflection = exterior > 0.0 ? gentleWaterReflection(viewPosition, reflectedRay, fallback) : fallback;
    // Retain some native water detail, but suppress repeating block texture
    // contrast. Waterfalls and side faces never reach this function.
    vec3 base = mix(smoothColor, nativeColor, WATER_TEXTURE);
    base = mix(nativeColor, base, strength);
    base *= mix(vec3(1.0), vec3(0.62, 0.80, 0.88), deep * 0.45 * strength);
    // Alpha blending would attenuate Fresnel twice. Compensate in RGB, with a
    // strict bound, instead of making shores or mod fluids artificially opaque.
    float reflectivity = min(fresnel * strength / max(alpha, 0.25), 0.80);
    vec3 color = mix(base, reflection, reflectivity);
    vec3 halfVector = normalize(eye + gentleSunDirection() + vec3(0.0, 0.00001, 0.0));
    float specular = pow(max(dot(normal, halfVector), 0.0), 96.0);
    float glint = specular * 0.10 * strength * day;
    // Reuse the geometric receiver's shadow for the glint: no second PCF
    // lookup, and wave normals cannot move the receiver bias through a wall.
    color += vec3(1.0, 0.94, 0.83) * glint * visibility / max(alpha, 0.25);
    return vec4(color, alpha);
}
#endif
