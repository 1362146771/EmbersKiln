shader_type canvas_item;
// Match the portrait's denser midtones while preserving ceramic highlights.
uniform float midtone_gamma : hint_range(1.0, 1.5) = 1.20;
uniform float saturation : hint_range(0.8, 1.2) = 1.04;

void fragment() {
    vec4 pixel = COLOR;
    vec3 tone = pow(max(pixel.rgb, vec3(0.0)), vec3(midtone_gamma));
    float gray = dot(tone, vec3(0.2126, 0.7152, 0.0722));
    COLOR = vec4(clamp(mix(vec3(gray), tone, saturation), 0.0, 1.0), pixel.a);
}
