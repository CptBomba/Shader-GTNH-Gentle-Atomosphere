varying vec2 gentleScreenUV;
void main() {
    gentleScreenUV = gl_MultiTexCoord0.xy;
    gl_Position = ftransform();
}
