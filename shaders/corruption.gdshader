shader_type spatial;
// Corrupção demoníaca (a Mácula) desenhada por cima do personagem: escurece a pele em manchas,
// risca veias escuras e abre rachaduras que brilham e pulsam como brasa.
// Segunda passada do material de contorno (AnimatedBody.set_corruption).
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform float corruption : hint_range(0.0, 1.0) = 0.6;
uniform vec4 glow_color : source_color = vec4(1.0, 0.25, 0.08, 1.0);
uniform float glow_energy = 3.0;
uniform float scale = 6.0;
uniform float pulse_speed = 2.2;

varying vec3 local_pos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	// Pelo UV (não pela posição): as veias acompanham a pele durante a animação.
	local_pos = vec3(UV * 3.0, 0.0);
}

void fragment() {
	vec3 p = local_pos * scale;
	float blotch = smoothstep(0.35, 0.75, noise(p * 0.5));
	float n = noise(p) * 0.65 + noise(p * 2.3) * 0.35;
	float vein = 1.0 - smoothstep(0.0, 0.06, abs(n - 0.5));
	float crack = 1.0 - smoothstep(0.0, 0.025, abs(noise(p * 1.4 + 7.0) - 0.5));
	float pulse = 0.55 + 0.45 * sin(TIME * pulse_speed + noise(p * 0.3) * 6.28);
	float glow = crack * blotch * pulse * corruption;
	float dark = (blotch * 0.55 + vein * 0.5) * corruption;
	ALBEDO = glow_color.rgb * glow * glow_energy;
	ALPHA = clamp(max(dark * 0.85, glow), 0.0, 1.0);
}
