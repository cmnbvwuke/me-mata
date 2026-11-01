shader_type canvas_item;
// Retícula de luneta: tudo preto fora do círculo, cruz fina com marcações
// (mil-dots), ponto central vermelho iluminado e escurecimento na borda da lente.

uniform float radius = 0.45;      // fração da altura da tela
uniform float line_px = 1.5;
uniform vec2 screen_size = vec2(1280.0, 720.0);

void fragment() {
	vec2 px = (UV - 0.5) * screen_size;
	float r = radius * screen_size.y;
	float d = length(px);
	float alpha = smoothstep(r - 2.0, r + 2.0, d);
	// vinheta interna da lente
	alpha = max(alpha, smoothstep(r * 0.82, r, d) * 0.55);
	// cruz: grossa nas pontas, fina perto do centro
	float thick = mix(line_px, line_px * 4.0, step(r * 0.55, max(abs(px.x), abs(px.y))));
	float cross_h = step(abs(px.y), thick * 0.5) * step(r * 0.012, abs(px.x));
	float cross_v = step(abs(px.x), thick * 0.5) * step(r * 0.012, abs(px.y));
	// marcações (mil-dots) a cada 6% do raio na parte fina
	float spacing = r * 0.06;
	float ticks = 0.0;
	if (abs(px.y) < 4.0 && abs(px.x) < r * 0.55 && abs(mod(abs(px.x), spacing)) < 1.2 && abs(px.x) > spacing * 0.5) ticks = 1.0;
	if (abs(px.x) < 4.0 && abs(px.y) < r * 0.55 && abs(mod(abs(px.y), spacing)) < 1.2 && abs(px.y) > spacing * 0.5) ticks = 1.0;
	float ink = max(max(cross_h, cross_v), ticks);
	COLOR = vec4(0.0, 0.0, 0.0, max(alpha, ink * 0.95));
	// ponto central iluminado (visível à noite)
	float glow = smoothstep(4.2, 2.4, d);
	COLOR = mix(COLOR, vec4(1.0, 0.12, 0.06, 1.0), glow);
}
