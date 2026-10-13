#include "/lib/environment.glsl"
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
varying vec2 gentleCloudUV;
varying vec4 gentleCloudColor;
varying vec3 gentleCloudWorld;
varying vec3 gentleCloudView;

void main() {
    vec4 viewPosition = gl_ModelViewMatrix * gl_Vertex;
    gentleCloudWorld = (gbufferModelViewInverse * viewPosition).xyz + cameraPosition;
    gentleCloudView = viewPosition.xyz;
    gentleCloudUV = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    gentleCloudColor = gl_Color;
    // Keep the provider's native altitude, geometry, translation and face shade.
    gl_Position = gl_ProjectionMatrix * viewPosition;
}
