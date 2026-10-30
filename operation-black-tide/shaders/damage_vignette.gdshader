shader_type canvas_item;
// Vinheta vermelha de dano: borda da tela pulsa conforme o dano recebido
// e escurece com vida baixa.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.55, 0.0, 0.0, 1.0);

void fragment() {
	vec2 d = UV - 0.5;
	float v = smoothstep(0.2, 0.75, length(d) * 1.25);
	COLOR = vec4(tint.rgb, clamp(v * intensity * 1.4, 0.0, 0.92));
}
