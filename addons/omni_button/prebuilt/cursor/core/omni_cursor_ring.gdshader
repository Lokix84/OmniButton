shader_type canvas_item;
// A soft ring for OmniVirtualCursor: brightest along its middle line and fading to transparent both
// inward and outward, so it reads as a glowing tube. Drawn on a square; sizes are fractions of it.

uniform vec4 ring_color : source_color = vec4(1.0, 1.0, 1.0, 0.95);
// Middle of the tube, from the center (0) to the edge of the square (1).
uniform float radius : hint_range(0.05, 1.0) = 0.7;
// Full width of the tube, as a fraction of the square's half-size.
uniform float thickness : hint_range(0.02, 1.0) = 0.46;
// Shapes the fade: 1 = soft, higher = a harder edge with a brighter core.
uniform float sharpness : hint_range(0.5, 4.0) = 1.2;

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float t = 1.0 - clamp(abs(d - radius) / (thickness * 0.5), 0.0, 1.0);
	t = smoothstep(0.0, 1.0, t);
	COLOR = vec4(ring_color.rgb, ring_color.a * pow(t, sharpness));
}
