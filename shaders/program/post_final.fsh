#include "/lib/environment.glsl"
#include "/lib/post.glsl"
varying vec2 gentleScreenUV;
void main() {
    vec4 scene = texture2D(colortex0, gentleScreenUV);
    scene.rgb = gentlePostImage(gentleScreenUV);
    if (gentleEarth()) {
        scene.rgb += gentleBloom(gentleScreenUV);
        scene.rgb = gentleHighlights(scene.rgb);
    }
    gl_FragColor = scene;
}
