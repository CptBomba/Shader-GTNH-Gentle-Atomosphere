#ifndef GENTLE_FOLIAGE
#define GENTLE_FOLIAGE
float gentleFoliageCutoff(float material, float distanceToEye) {
#if FOLIAGE_FILTER == 1
    if (gentleEarth() && material > 10000.5 && material < 10003.5)
        return mix(0.10, 0.20, smoothstep(12.0, 48.0, distanceToEye));
#endif
    return 0.10;
}

vec4 gentleFoliage(vec4 atlas, float material, float distanceToEye) {
#if FOLIAGE_FILTER == 1
    bool foliage = abs(material - 10001.0) < 0.25
        || abs(material - 10002.0) < 0.25 || abs(material - 10003.0) < 0.25;
    if (gentleEarth() && foliage) {
        // Raise only weak cutout fringes, avoiding opaque billboard rectangles.
        if (atlas.a < gentleFoliageCutoff(material, distanceToEye)) discard;
        // RC-2 MipmapGenerator already fills transparent RGB, uses weighted
        // colors and preserves cutout coverage. Dividing RGB by alpha again
        // overbrightens those corrected mip edges. Retain the native RGB/alpha.
    }
#endif
    return atlas;
}
#endif
