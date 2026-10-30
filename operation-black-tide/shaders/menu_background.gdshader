shader_type canvas_item;
// Fundo do menu: gradiente noturno, "mar" ondulando, linhas de varredura e grão.

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec3 sky = mix(vec3(0.05, 0.07, 0.1), vec3(0.0, 0.005, 0.015), uv.y);
	float horizon = 0.62;
	if (uv.y > horizon) {
		float w = sin(uv.x * 40.0 + TIME * 0.6 + uv.y * 90.0) * 0.5 + 0.5;
		sky = vec3(0.01, 0.02, 0.035) + vec3(0.04, 0.05, 0.07) * w * (1.0 - (uv.y - horizon) * 2.5);
	}
	// Facho de holofote varrendo o céu
	float beam_x = 0.7 + sin(TIME * 0.25) * 0.2;
	float beam = smoothstep(0.06, 0.0, abs(uv.x - beam_x - (horizon - uv.y) * 0.5)) * step(uv.y, horizon);
	sky += vec3(0.12, 0.13, 0.12) * beam * (1.0 - (horizon - uv.y));
	sky *= 0.9 + 0.1 * sin(uv.y * 800.0);
	sky += (rand(uv * 500.0 + TIME) - 0.5) * 0.03;
	float vig = smoothstep(1.1, 0.3, length(uv - 0.5) * 1.4);
	COLOR = vec4(sky * vig, 1.0);
}
