shader_type spatial;
// Brilho de contorno (fresnel) desenhado por cima do personagem: flash de dano, cor do elemento,
// atordoamento. Aditivo e barato (uma conta por pixel, sem textura).
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 rim_color : source_color = vec4(1.0);
uniform float intensity = 0.0;
uniform float power = 2.2;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), power);
	ALBEDO = rim_color.rgb * rim * intensity;
}
