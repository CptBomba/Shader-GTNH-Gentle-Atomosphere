#include "/lib/environment.glsl"
#include "/lib/vegetation.glsl"
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
varying vec2 gentleShadowUV;
varying float gentleShadowAlpha;
varying float gentleShadowMaterial;
varying vec3 gentleShadowRelative;
void main() {
    vec4 viewPosition = gl_ModelViewMatrix * gl_Vertex;
    vec3 relative = (shadowModelViewInverse * viewPosition).xyz;
    vec2 light = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    float upper = 1.0 - step(mc_midTexCoord.y, gl_MultiTexCoord0.y);
    relative += gentleWind(relative + cameraPosition, mc_Entity.x, upper, light.y);
    gl_Position = gl_ProjectionMatrix * shadowModelView * vec4(relative, 1.0);
    gentleShadowUV = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    gentleShadowAlpha = gl_Color.a;
    gentleShadowMaterial = mc_Entity.x;
    gentleShadowRelative = relative;
}
