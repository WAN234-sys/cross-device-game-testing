shader_type canvas_item;
// Full-screen color correction for color vision deficiency.
// mode: 0 off, 1 deuteranopia, 2 protanopia, 3 tritanopia (daltonization).
uniform int mode = 0;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

vec3 simulate(vec3 c, int m) {
	mat3 sim;
	if (m == 1) sim = mat3(vec3(0.625, 0.7, 0.0), vec3(0.375, 0.3, 0.3), vec3(0.0, 0.0, 0.7));
	else if (m == 2) sim = mat3(vec3(0.567, 0.558, 0.0), vec3(0.433, 0.442, 0.242), vec3(0.0, 0.0, 0.758));
	else sim = mat3(vec3(0.95, 0.0, 0.0), vec3(0.05, 0.433, 0.475), vec3(0.0, 0.567, 0.525));
	return sim * c;
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	if (mode != 0) {
		vec3 err = c - simulate(c, mode);
		// Shift lost information into channels the viewer can see
		vec3 fix = vec3(0.0, err.r * 0.7 + err.g, err.r * 0.7 + err.b);
		c = clamp(c + fix, 0.0, 1.0);
	}
	COLOR = vec4(c, 1.0);
}
