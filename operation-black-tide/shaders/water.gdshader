shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
// Mar procedural: ondas somadas no vertex shader (normais por diferenças finitas),
// ondulações finas no fragment e Fresnel para refletir o céu nos ângulos rasos.

uniform vec4 deep_color : source_color = vec4(0.008, 0.028, 0.042, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.03, 0.085, 0.1, 1.0);
uniform float wave_height = 0.28;
uniform float wave_scale = 0.07;
uniform float speed = 0.55;

varying vec3 world_pos;

float waves(vec2 p, float t) {
	return sin(p.x * wave_scale * 6.0 + t) * 0.5
		+ sin(p.y * wave_scale * 4.3 - t * 1.3) * 0.35
		+ sin((p.x + p.y) * wave_scale * 9.1 + t * 0.7) * 0.15;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * speed;
	VERTEX.y += waves(w.xz, t) * wave_height;
	float e = 0.6;
	float hx = waves(w.xz + vec2(e, 0.0), t) - waves(w.xz - vec2(e, 0.0), t);
	float hz = waves(w.xz + vec2(0.0, e), t) - waves(w.xz - vec2(0.0, e), t);
	NORMAL = normalize(vec3(-hx * wave_height / (2.0 * e), 1.0, -hz * wave_height / (2.0 * e)));
	world_pos = w;
}

void fragment() {
	vec2 uv = world_pos.xz * 0.4 + vec2(TIME * 0.06, TIME * 0.035);
	vec3 ripple = vec3(sin(uv.x * 7.0 + sin(uv.y * 5.0)) * 0.08, 0.0, cos(uv.y * 6.0 + sin(uv.x * 4.0)) * 0.08);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(ripple, 0.0)).xyz);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, clamp(fresnel * 0.7, 0.0, 1.0));
	ROUGHNESS = 0.06;
	METALLIC = 0.25;
	SPECULAR = 0.7;
}
