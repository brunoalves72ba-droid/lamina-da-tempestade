class_name GraphicsSettings
extends RefCounted
## Presets de qualidade gráfica (Baixo / Médio / Alto), calibrados numa GPU integrada (Intel Iris Xe).
## Baixo: sem SSAO, neblina comum, 67% da resolução com FSR 1.
## Médio: neblina volumétrica leve, SSAO em meia resolução, 75% com FSR 1.
## Alto: SSAO e reflexos completos, iluminação global (SDFGI), resolução cheia.

enum Quality { LOW, MEDIUM, HIGH }

const NAMES: Array[String] = ["Baixo", "Médio", "Alto"]
const RENDER_SCALE: Array[float] = [0.67, 0.75, 1.0]


static func apply(viewport: Viewport, environment: Environment, quality: int) -> void:
	quality = clampi(quality, 0, NAMES.size() - 1)
	var high := quality == Quality.HIGH
	var medium_or_high := quality >= Quality.MEDIUM
	if environment != null:
		environment.sdfgi_enabled = high
		environment.ssao_enabled = medium_or_high
		environment.ssil_enabled = false
		environment.ssr_enabled = high
		environment.volumetric_fog_enabled = medium_or_high
		environment.fog_enabled = not medium_or_high
		environment.glow_enabled = true
	RenderingServer.environment_set_ssao_quality(
			RenderingServer.ENV_SSAO_QUALITY_HIGH if high else RenderingServer.ENV_SSAO_QUALITY_VERY_LOW,
			not high, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_volumetric_fog_volume_size(128 if high else 48, 96 if high else 32)
	RenderingServer.directional_shadow_atlas_set_size(4096 if high else 2048, true)
	if viewport != null:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if high else Viewport.SCALING_3D_MODE_FSR
		viewport.scaling_3d_scale = RENDER_SCALE[quality]
		viewport.msaa_3d = Viewport.MSAA_DISABLED
		viewport.use_taa = high
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if high else Viewport.SCREEN_SPACE_AA_FXAA


static func display_name(quality: int) -> String:
	return NAMES[clampi(quality, 0, NAMES.size() - 1)]
