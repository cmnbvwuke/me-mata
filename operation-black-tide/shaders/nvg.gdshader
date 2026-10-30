shader_type canvas_item;
// Visão noturna (NVG): amplifica a luminância da tela, tinge de verde,
// adiciona granulação, linhas de varredura e vinheta circular do tubo.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float gain = 6.0;
uniform float noise_amount = 0.09;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	lum = 1.0 - exp(-lum * gain);
	lum += (rand(SCREEN_UV * 700.0 + TIME) - 0.5) * noise_amount;
	lum *= 0.94 + 0.06 * sin(SCREEN_UV.y * 900.0);
	vec2 d = (SCREEN_UV - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float vig = smoothstep(0.62, 0.38, length(d));
	COLOR = vec4(vec3(0.2, 1.0, 0.35) * lum * vig, 1.0);
}
