shader_type spatial;
// Arco voltaico: núcleo branco-quente, halo na cor do elemento e plasma que "ferve" ao longo do raio.
// Sai em HDR (valores acima de 1) para alimentar o Glow/Bloom do ambiente.
// UV.x = ao longo do raio (0..1), UV.y = de uma borda da fita à outra (0..1).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(0.6, 0.85, 1.0, 1.0);
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
// Intensidade HDR do núcleo e do halo.
uniform float core_energy = 6.0;
uniform float glow_energy = 2.2;
// Largura do núcleo em relação à fita (0..0.5).
uniform float core_width = 0.12;
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	float across = abs(UV.y - 0.5) * 2.0;  // 0 no centro, 1 na borda
	float t = TIME * 18.0 + seed * 13.0;
	float plasma = noise(vec2(UV.x * 24.0 - t, seed)) * 0.6 + noise(vec2(UV.x * 61.0 + t * 1.7, seed + 3.0)) * 0.4;
	float core = 1.0 - smoothstep(core_width * (0.6 + plasma * 0.8), core_width * 2.2, across);
	float halo = pow(1.0 - across, 2.2) * (0.55 + plasma * 0.9);
	// As pontas do raio somem suavemente.
	float ends = smoothstep(0.0, 0.04, UV.x) * smoothstep(1.0, 0.96, UV.x);
	vec3 hot = mix(color.rgb, vec3(1.0), 0.75);
	ALBEDO = (hot * core * core_energy + color.rgb * halo * glow_energy) * alpha * ends;
}
