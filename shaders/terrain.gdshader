shader_type spatial;
// Terreno da trilha: chão de floresta, lama na trilha (COLOR.r) e rocha nos paredões
// (COLOR.g + inclinação). Otimizado para GPU integrada:
// - lama e rocha só são lidas onde aparecem (desvio por peso);
// - a rocha usa só a projeção do eixo dominante da normal (1 leitura por mapa, sem esticar nas encostas);
// - rugosidade só do chão/lama; a rocha usa um valor fixo.

uniform sampler2D ground_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D ground_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D ground_rough : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D mud_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mud_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D mud_rough : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_rough : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform float ground_scale = 0.22;
uniform float mud_scale = 0.3;
uniform float rock_scale = 0.12;
uniform float rock_roughness = 0.85;
uniform float slope_rock_start = 0.82;
uniform float slope_rock_end = 0.6;
uniform vec3 tint = vec3(0.85, 0.85, 0.9);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv_ground = world_pos.xz * ground_scale;
	vec3 albedo = texture(ground_albedo, uv_ground).rgb;
	vec3 normal_map = texture(ground_normal, uv_ground).rgb;
	float rough = texture(ground_rough, uv_ground).r;

	float mud = smoothstep(0.15, 0.85, COLOR.r);
	if (mud > 0.01) {
		vec2 uv_mud = world_pos.xz * mud_scale;
		albedo = mix(albedo, texture(mud_albedo, uv_mud).rgb, mud);
		normal_map = mix(normal_map, texture(mud_normal, uv_mud).rgb, mud);
		rough = mix(rough, texture(mud_rough, uv_mud).r, mud);
	}

	float rock = clamp(COLOR.g + smoothstep(slope_rock_start, slope_rock_end, world_normal.y), 0.0, 1.0);
	if (rock > 0.01) {
		vec3 n = abs(world_normal);
		vec2 uv_rock = (n.y >= n.x && n.y >= n.z) ? world_pos.xz : ((n.x >= n.z) ? world_pos.zy : world_pos.xy);
		uv_rock *= rock_scale;
		albedo = mix(albedo, texture(rock_albedo, uv_rock).rgb, rock);
		normal_map = mix(normal_map, texture(rock_normal, uv_rock).rgb, rock);
		rough = mix(rough, rock_roughness, rock);
	}

	ALBEDO = albedo * tint;
	NORMAL_MAP = normal_map;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
}
