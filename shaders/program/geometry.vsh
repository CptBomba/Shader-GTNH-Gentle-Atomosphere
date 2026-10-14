#include "/lib/environment.glsl"
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
#define GENTLE_CAMERA_DECLARED
#if defined(GENTLE_TERRAIN) || defined(GENTLE_WATER)
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
#include "/lib/vegetation.glsl"
#endif
varying vec2 gentleUV;
varying vec2 gentleLightUV;
varying vec4 gentleColor;
varying vec3 gentleView;
varying vec3 gentleWorld;
varying float gentleMaterial;
varying float gentleUp;
varying vec3 gentleNormal;

void main() {
    vec4 viewPosition = gl_ModelViewMatrix * gl_Vertex;
    vec3 relativePosition = (gbufferModelViewInverse * viewPosition).xyz;
    gentleWorld = relativePosition + cameraPosition;
    gentleUV = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    gentleLightUV = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    gentleColor = gl_Color;
    gentleMaterial = -1.0;
    gentleUp = 0.0;
    gentleNormal = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal);
#if defined(GENTLE_TERRAIN) || defined(GENTLE_WATER)
    gentleMaterial = mc_Entity.x;
    // Both UVs are in the atlas coordinate system supplied by Angelica.
    float upperVertex = 1.0 - step(mc_midTexCoord.y, gl_MultiTexCoord0.y);
    vec3 displacement = gentleWind(gentleWorld, mc_Entity.x, upperVertex, gentleLightUV.y);
    relativePosition += displacement;
    gentleWorld += displacement;
    viewPosition = gbufferModelView * vec4(relativePosition, 1.0);
    vec3 worldNormal = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal);
    gentleUp = clamp(worldNormal.y, 0.0, 1.0);
    gentleNormal = worldNormal;
#endif
    gentleView = viewPosition.xyz;
    gl_Position = gl_ProjectionMatrix * viewPosition;
}
