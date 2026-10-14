#ifndef GENTLE_CLOUD_SHAPES
#define GENTLE_CLOUD_SHAPES
// Analytic intersections with joined, softly bevelled block-shaped puffs.
// No volume sampling, no ray marching and no replacement cloud image required.
float gentleShapeHash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float gentleShapeNoise(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(gentleShapeHash(cell), gentleShapeHash(cell + vec2(1.0, 0.0)), f.x),
        mix(gentleShapeHash(cell + vec2(0.0, 1.0)), gentleShapeHash(cell + vec2(1.0)), f.x), f.y);
}

vec3 gentleCloudInverse(vec3 direction) {
    return mix(vec3(-1.0), vec3(1.0), step(vec3(0.0), direction))
        / max(abs(direction), vec3(0.00001));
}

bool gentleCloudBounds(vec3 origin, vec3 inverseDirection, vec3 center, vec3 halfSize, float nearest) {
    vec3 a = (center - halfSize - origin) * inverseDirection;
    vec3 b = (center + halfSize - origin) * inverseDirection;
    vec3 nearPlane = min(a, b), farPlane = max(a, b);
    float enter = max(nearPlane.x, max(nearPlane.y, nearPlane.z));
    float leave = min(farPlane.x, min(farPlane.y, farPlane.z));
    return leave >= max(enter, 0.0) && max(enter, 0.0) <= nearest;
}

bool gentleCloudClip(vec3 origin, vec3 direction, vec3 halfSize, vec3 plane,
    float limit, inout float enter, inout float leave,
    inout vec3 enterNormal, inout vec3 leaveNormal) {
    float denominator = dot(plane, direction);
    float numerator = limit - dot(plane, origin);
    if (abs(denominator) < 0.000001) return numerator >= 0.0;
    float distance = numerator / denominator;
    if (denominator < 0.0 && distance > enter) {
        enter = distance;
        enterNormal = normalize(plane / halfSize);
    } else if (denominator > 0.0 && distance < leave) {
        leave = distance;
        leaveNormal = normalize(plane / halfSize);
    }
    return leave >= max(enter, 0.0);
}

vec4 gentleCloudBox(vec3 origin, vec3 direction, vec3 inverseDirection, vec3 center, vec3 halfSize, float nearest) {
#if CLOUD_QUALITY >= 2
    vec3 a = (center - halfSize - origin) * inverseDirection;
    vec3 b = (center + halfSize - origin) * inverseDirection;
#else
    // The two-puff Minimal path is cheaper without the additional bounds.
    vec3 safeDirection = mix(vec3(-1.0), vec3(1.0), step(vec3(0.0), direction))
        * max(abs(direction), vec3(0.00001));
    vec3 a = (center - halfSize - origin) / safeDirection;
    vec3 b = (center + halfSize - origin) / safeDirection;
#endif
    vec3 nearPlane = min(a, b);
    vec3 farPlane = max(a, b);
    float enter = max(nearPlane.x, max(nearPlane.y, nearPlane.z));
    float leave = min(farPlane.x, min(farPlane.y, farPlane.z));
    if (leave < max(enter, 0.0)) return vec4(0.0, 0.0, 0.0, 1e20);
#if CLOUD_QUALITY >= 2
    if (max(enter, 0.0) > nearest) return vec4(0.0, 0.0, 0.0, 1e20);
#endif
    vec3 enterAxis = vec3(0.0);
    if (abs(nearPlane.x - enter) < 0.001) enterAxis.x = 1.0;
    else if (abs(nearPlane.y - enter) < 0.001) enterAxis.y = 1.0;
    else enterAxis.z = 1.0;
    vec3 leaveAxis = vec3(0.0);
    if (abs(farPlane.x - leave) < 0.001) leaveAxis.x = 1.0;
    else if (abs(farPlane.y - leave) < 0.001) leaveAxis.y = 1.0;
    else leaveAxis.z = 1.0;
#if CLOUD_QUALITY >= 2
    vec3 enterNormal = -enterAxis * sign(inverseDirection);
    vec3 leaveNormal = leaveAxis * sign(inverseDirection);
    // Only rays which hit the bounding box pay for edge clipping. Twelve
    // analytic half-planes soften corners while retaining the block silhouette.
    vec3 localOrigin = (origin - center) / halfSize;
    vec3 localDirection = direction / halfSize;
    for (int a = -1; a <= 1; a += 2) {
        for (int b = -1; b <= 1; b += 2) {
            if (!gentleCloudClip(localOrigin, localDirection, halfSize,
                vec3(float(a), float(b), 0.0), 1.72, enter, leave, enterNormal, leaveNormal))
                return vec4(0.0, 0.0, 0.0, 1e20);
            if (!gentleCloudClip(localOrigin, localDirection, halfSize,
                vec3(float(a), 0.0, float(b)), 1.65, enter, leave, enterNormal, leaveNormal))
                return vec4(0.0, 0.0, 0.0, 1e20);
            if (!gentleCloudClip(localOrigin, localDirection, halfSize,
                vec3(0.0, float(a), float(b)), 1.72, enter, leave, enterNormal, leaveNormal))
                return vec4(0.0, 0.0, 0.0, 1e20);
        }
    }
#else
    vec3 enterNormal = -enterAxis * sign(safeDirection);
    vec3 leaveNormal = leaveAxis * sign(safeDirection);
#endif
    bool inside = enter < 0.0;
    float distance = inside ? leave : enter;
    vec3 normal = inside ? leaveNormal : enterNormal;
#if CLOUD_QUALITY >= 2
    if (distance >= nearest) return vec4(0.0, 0.0, 0.0, 1e20);
    // Smooth lighting at bevel transitions, without blur or volume sampling.
    vec3 point = clamp((origin + direction * distance - center) / halfSize, -1.0, 1.0);
    vec3 square = point * point;
    vec3 roundedNormal = normalize(point * square * square / halfSize);
    normal = normalize(mix(normal, roundedNormal, 0.58));
#endif
    return vec4(normal, distance);
}

void gentleNearestCloud(inout vec4 nearest, inout float density,
    vec4 candidate, float candidateDensity) {
    if (candidate.w < nearest.w) {
        nearest = candidate;
        density = candidateDensity;
    }
}

void gentleCloudLayer(vec3 origin, vec3 direction, vec3 sun, float altitude, float layer,
    vec3 backdrop, out vec4 cloud, out float distance) {
    cloud = vec4(0.0);
    distance = 1e20;
    if (abs(direction.y) < 0.065) return;
    float planeDistance = (altitude - origin.y) / direction.y;
    if (planeDistance < -15.0 || planeDistance > 2600.0) return;
    // A 2048-block tiled field: every available speed wraps in one hour.
    vec3 shiftedOrigin = origin - vec3(frameTimeCounter * (4096.0 / 3600.0) * CLOUD_SPEED, 0.0, 0.0);
    vec3 planePoint = shiftedOrigin + direction * max(planeDistance, 0.0);
    vec2 baseCell = floor(planePoint.xz / 128.0);
    vec3 inverseDirection = gentleCloudInverse(direction);
    vec4 nearest = vec4(0.0, 0.0, 0.0, 1e20);
    float density = 0.0;
    float weather = clamp(wetness, 0.0, 1.0);
    float coverage = min(0.94, CLOUD_COVERAGE + weather * 0.14);
    if (layer > 0.5) coverage *= 0.62;
    for (int x = -1; x <= 1; x++) {
        for (int z = -1; z <= 1; z++) {
            vec2 cell = baseCell + vec2(float(x), float(z));
#if CLOUD_QUALITY >= 2
            // Conservative bounds include offsets, all four puffs, rotation
            // and breathing. Reject empty rays before hashing the formation.
            vec3 cellCenter = vec3((cell.x + 0.5) * 128.0, altitude, (cell.y + 0.5) * 128.0);
            if (!gentleCloudBounds(shiftedOrigin, inverseDirection, cellCenter,
                vec3(154.0, 50.0, 154.0), nearest.w)) continue;
#endif
            vec2 seed = mod(cell, 16.0) + vec2(layer * 19.0);
            float r = gentleShapeHash(seed);
            // Coarse patches produce groups and open spaces, not a uniform grid.
            float formationPatch = gentleShapeHash(floor(seed / 4.0) + vec2(55.0, 17.0));
            float localCoverage = clamp(coverage + (formationPatch - 0.5) * 0.42, 0.1, 0.97);
            if (r > localCoverage + 0.03) continue;
            // Formations at the coverage threshold shrink rather than turning
            // into translucent glass blocks; only the smallest ones fade.
            float formationGrowth = 1.0 - smoothstep(localCoverage - 0.06, localCoverage + 0.03, r);
            float formationDensity = smoothstep(0.0, 0.30, formationGrowth);
            float formationScale = mix(0.45, 1.0, formationGrowth);
            float rx = gentleShapeHash(seed + vec2(3.1, 7.7));
            float rz = gentleShapeHash(seed + vec2(11.4, 2.3));
            float shape = gentleShapeHash(seed + vec2(21.8, 32.5));
            float offsetX = gentleShapeHash(seed + vec2(37.0, 13.0)) - 0.5;
            float offsetZ = gentleShapeHash(seed + vec2(19.0, 41.0)) - 0.5;
            float width = mix(38.0, 110.0, rx) * formationScale;
            float depth = mix(30.0, 90.0, rz) * formationScale;
            float breathe = 1.0 + 0.035 * sin(frameTimeCounter * GENTLE_TAU * 24.0 / 3600.0 + shape * GENTLE_TAU);
            float height = mix(6.0, 17.0, shape) * breathe * mix(0.7, 1.0, formationGrowth);
            float side = rx < 0.5 ? -1.0 : 1.0;
            vec3 center = vec3((cell.x + 0.5) * 128.0 + offsetX * 92.0,
                altitude + (r - 0.5) * 36.0,
                (cell.y + 0.5) * 128.0 + offsetZ * 92.0);
            float heading = floor(shape * 8.0) * GENTLE_TAU / 8.0;
            float cs = cos(heading);
            float sn = sin(heading);
            mat2 rotation = mat2(cs, -sn, sn, cs);
            vec3 localOrigin = shiftedOrigin - center;
            localOrigin.xz = rotation * localOrigin.xz;
            vec3 localDirection = direction;
            localDirection.xz = rotation * localDirection.xz;
            vec3 localInverse = gentleCloudInverse(localDirection);
#if CLOUD_QUALITY >= 2
            if (!gentleCloudBounds(localOrigin, localInverse, vec3(0.0),
                vec3(width * 0.69, height * 1.76, depth * 0.84), nearest.w)) continue;
#endif
            vec4 cluster = vec4(0.0, 0.0, 0.0, 1e20);
            float clusterDensity = 0.0;
            gentleNearestCloud(cluster, clusterDensity, gentleCloudBox(localOrigin, localDirection, localInverse, vec3(0.0),
                vec3(width * mix(0.23, 0.36, shape), height, depth * 0.31), nearest.w), formationDensity);
            gentleNearestCloud(cluster, clusterDensity, gentleCloudBox(localOrigin, localDirection, localInverse,
                vec3(side * width * mix(0.18, 0.37, rz), height * (rx - 0.25), (rz - 0.5) * depth * 0.65),
                vec3(width * mix(0.18, 0.31, rz), height * mix(0.55, 1.0, rx), depth * 0.28), min(nearest.w, cluster.w)), formationDensity);
#if CLOUD_QUALITY >= 2
            // Compact, tall, L-shaped and stretched groups use different layouts.
            if (shape > 0.18) gentleNearestCloud(cluster, clusterDensity, gentleCloudBox(localOrigin, localDirection, localInverse,
                vec3(-side * width * 0.26, height * (rz - 0.5), depth * (shape - 0.25) * 0.65),
                vec3(width * mix(0.16, 0.27, rx), height * 0.75, depth * mix(0.18, 0.34, shape)), min(nearest.w, cluster.w)), formationDensity);
            if (shape > 0.57) gentleNearestCloud(cluster, clusterDensity, gentleCloudBox(localOrigin, localDirection, localInverse,
                vec3(width * (rz - 0.5) * 0.52, height * 0.8, -depth * 0.27),
                vec3(width * 0.22, height * 0.6, depth * 0.25), min(nearest.w, cluster.w)), formationDensity);
#endif
            cluster.xz = mat2(cs, sn, -sn, cs) * cluster.xz;
            gentleNearestCloud(nearest, density, cluster, clusterDensity);
        }
    }
    if (nearest.w > 2500.0) return;
    distance = nearest.w;
    float daylight = gentleDay();
    float top = max(nearest.y, 0.0);
    float bottom = max(-nearest.y, 0.0);
    // Distinct top, side and underside tones provide visible, restrained depth.
    vec3 face = mix(vec3(0.90, 0.94, 0.97), vec3(1.0, 0.985, 0.95), top);
    face = mix(face, vec3(0.72, 0.79, 0.85), bottom * 0.90);
    // Faces turned to the real sun are a touch brighter than the far side.
    face *= 0.93 + 0.09 * max(dot(nearest.xyz, sun), 0.0) * daylight;
    // Soft large-scale mottling: the cubic silhouette stays, the surface is
    // no longer a flat plastic color. One value-noise lookup per sky pixel.
    vec3 hit = shiftedOrigin + direction * distance;
    face *= 0.92 + 0.12 * gentleShapeNoise(hit.xz * 0.045 + hit.y * 0.11 + layer * 7.0);
    face = mix(face * vec3(0.25, 0.32, 0.43), face, daylight);
    face = mix(face, face * vec3(1.06, 0.90, 0.78), gentleTwilight() * 0.42);
    face += vec3(0.16, 0.095, 0.045) * gentleTwilight();
    // Rain clouds turn a soft grey; nothing becomes a storm wall.
    face = mix(face, face * vec3(0.70, 0.73, 0.78), weather * 0.75);
    // Clouds around the sun glow warmly, most at sunrise and sunset.
    float scatter = pow(max(dot(direction, sun), 0.0), 6.0);
    face += vec3(1.0, 0.84, 0.62) * scatter * (0.08 + 0.40 * gentleTwilight()) * sqrt(daylight) * (1.0 - weather);
    float haze = (1.0 - exp(-distance * 0.00075)) * 0.74;
    face = mix(face, backdrop, haze);
    float edgeFade = smoothstep(0.065, 0.16, abs(direction.y));
    float rangeFade = 1.0 - smoothstep(1100.0, 2500.0, distance);
    // Night clouds stay mostly opaque so stars do not shine through them.
    float opacity = mix(0.82, 0.96, daylight) * edgeFade * rangeFade * density;
    if (layer > 0.5) opacity *= 0.78;
    cloud = vec4(face, opacity);
}

vec3 gentleCloudField(vec3 background, vec3 origin, vec3 direction, vec3 sunDirection) {
#if CLOUD_STYLE == 1 && CLOUD_QUALITY > 0
    vec4 lowCloud;
    float lowDistance;
    vec3 sun = normalize(sunDirection + vec3(0.0, 0.00001, 0.0));
    gentleCloudLayer(origin, direction, sun, float(CLOUD_HEIGHT), 0.0, background, lowCloud, lowDistance);
#if CLOUD_QUALITY >= 3
    vec4 highCloud;
    float highDistance;
    gentleCloudLayer(origin, direction, sun, float(CLOUD_HEIGHT) + 42.0, 1.0, background, highCloud, highDistance);
    if (highDistance > lowDistance) {
        background = mix(background, highCloud.rgb, highCloud.a);
        background = mix(background, lowCloud.rgb, lowCloud.a);
    } else {
        background = mix(background, lowCloud.rgb, lowCloud.a);
        background = mix(background, highCloud.rgb, highCloud.a);
    }
#else
    background = mix(background, lowCloud.rgb, lowCloud.a);
#endif
#endif
    return background;
}
#endif
