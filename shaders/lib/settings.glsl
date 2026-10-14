#ifndef GENTLE_SETTINGS
#define GENTLE_SETTINGS
// Numeric options are intentionally compatible with Angelica beta66b.
#define VEGETATION_SWAY 1 // [0 1]
#define WIND_STRENGTH 0.75 // [0.0 0.25 0.40 0.55 0.75 1.0]
#define MOD_LEAVES 1 // [0 1]
#define MOD_FLOWERS 1 // [0 1]
#define FOLIAGE_FILTER 1 // [0 1]
#define CLOUD_QUALITY 2 // [0 1 2 3]
#define CLOUD_STYLE 1 // [0 1]
#define CLOUD_COVERAGE 0.65 // [0.35 0.50 0.65 0.80]
#define CLOUD_HEIGHT 168 // [144 168 192 224]
#define CLOUD_SPEED 1.0 // [0.5 1.0 1.5 2.0]
#define SKY_STRENGTH 0.75 // [0.0 0.35 0.55 0.75 1.0]
#define COLOR_STRENGTH 0.55 // [0.0 0.20 0.35 0.55 0.75 1.0]
#define SHADE_SOFTNESS 0.15 // [0.0 0.08 0.15 0.22 0.30]
#define SUNLIGHT_STRENGTH 0.80 // [0.0 0.40 0.60 0.80 1.0]
#define SHADOWS 1 // [0 1]
#define SHADOW_SOFTNESS 1.0 // [0.6 1.0 1.4 1.8]
#define SHADOW_BIAS 1.0 // [0.6 1.0 1.4 2.0]
#define LOCAL_LIGHT_SHADOWS 0 // [0 1 2]
#define BLOCKLIGHT_WARMTH 0.60 // [0.0 0.30 0.60 0.90]
#define TORCH_FLICKER 1 // [0 1]
#define EMISSIVE_GLOW 1.0 // [0.0 0.5 1.0 1.5]
#define HANDHELD_LIGHT 1 // [0 1]
#define WATER_STRENGTH 0.65 // [0.0 0.35 0.65 1.0]
#define WATER_EFFECT 1 // [0 1]
#define WATER_REFLECTIONS 1 // [0 1 2]
#define WATER_TEXTURE 0.50 // [0.25 0.50 0.75 1.0]
#define ANTIALIASING 1 // [0 1]
#define SHARPNESS 0.35 // [0.0 0.20 0.35 0.50 0.70]
#define BLOOM_STRENGTH 0.06 // [0.0 0.04 0.06 0.10 0.16]
#define HIGHLIGHT_COMPRESSION 0.25 // [0.0 0.15 0.25 0.40 0.60]
#define FOG_STRENGTH 1.1 // [0.8 1.0 1.1 1.2]
#define EARTH_EFFECTS 1 // [0 1]
// Every temporal frequency completes an integer number of cycles in 3600 s.
// Angelica resets frameTimeCounter each hour; this avoids an animation jump.
const float GENTLE_TAU = 6.28318530718;
#endif
