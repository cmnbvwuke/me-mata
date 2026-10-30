class_name GraphicsQuality
extends RefCounted
## Níveis de qualidade gráfica (Configurações > Qualidade gráfica).
##   BAIXO: resolução 3D 70% com FSR, sem sombras de luzes pontuais, sem névoa
##          volumétrica/SSAO/SSIL — feito para GPUs integradas.
##   MÉDIO: resolução 85% com FSR, sombras só em lanternas/holofotes, SSAO.
##   ALTO:  tudo ligado (resolução nativa, MSAA 2x, todas as sombras, SSIL, névoa volumétrica).
## Luzes criadas depois (lanternas de reforços, explosões) consultam
## `positional_shadows_allowed()`.

enum Level { LOW, MEDIUM, HIGH }

const NAMES := ["Baixo", "Médio", "Alto"]


static func level() -> int:
	return GameManager.graphics_quality


## Nível sugerido para a placa de vídeo atual (usado na primeira execução).
static func detect_default() -> int:
	match RenderingServer.get_video_adapter_type():
		RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU, RenderingDevice.DEVICE_TYPE_CPU:
			return Level.LOW
		RenderingDevice.DEVICE_TYPE_DISCRETE_GPU:
			return Level.HIGH
	return Level.MEDIUM


static func positional_shadows_allowed(is_spot: bool) -> bool:
	if OS.has_feature("web"):
		return false
	match level():
		Level.LOW:
			return false
		Level.MEDIUM:
			return is_spot
	return true


## Aplica o nível atual à janela, ao ambiente e às luzes de uma cena.
static func apply(scene: Node, environment: Environment, sun: DirectionalLight3D) -> void:
	var q := level()
	var vp := scene.get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if q < Level.HIGH else Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = [0.7, 0.85, 1.0][q]
	vp.msaa_3d = Viewport.MSAA_2X if q == Level.HIGH else Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	vp.positional_shadow_atlas_size = [1024, 2048, 4096][q]
	vp.mesh_lod_threshold = [4.0, 2.0, 1.0][q]
	if environment:
		if not environment.has_meta("vol_fog"):
			environment.set_meta("vol_fog", environment.volumetric_fog_enabled)
		environment.volumetric_fog_enabled = bool(environment.get_meta("vol_fog")) and q == Level.HIGH
		environment.ssil_enabled = q == Level.HIGH
		environment.ssao_enabled = q >= Level.MEDIUM
	if sun:
		sun.directional_shadow_max_distance = [45.0, 70.0, 90.0][q]
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if q == Level.LOW \
			else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	for node in scene.find_children("*", "Light3D", true, false):
		if node is DirectionalLight3D:
			continue
		var light := node as Light3D
		if not light.has_meta("wants_shadow"):
			light.set_meta("wants_shadow", light.shadow_enabled)
		light.shadow_enabled = bool(light.get_meta("wants_shadow")) and positional_shadows_allowed(light is SpotLight3D)
