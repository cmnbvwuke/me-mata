class_name SoldierModel
extends Node3D
## Modelo animado do soldado raso (Mixamo, 41 ossos) usado pelos guardas.
## Animações (assets/characters/soldier_anims.res, extraídas dos FBX enviados,
## já sem deslocamento horizontal do quadril e sem o giro dos "turns"):
##   idle, aim (pose de mira), walk, shoot (anda atirando), turn_l, turn_r, dying.
## A malha não tem arma: o fuzil procedural é posicionado a cada quadro entre a
## mão direita (empunhadura) e a esquerda (guarda-mão). O agachamento é feito
## por um SkeletonModifier3D que dobra joelhos/quadril por cima da animação.

const HEIGHT := 1.78
## Modelos disponíveis (EnemyProfile.soldier_variant). Para um modelo novo, rode
## tools/extract_character_anims.gd e copie aqui os valores que ele imprime:
##   head_top     — topo da cabeça em unidades do modelo
##   walk_stride  — m/s (em unidades do modelo) da animação "walk"
##   shoot_stride — idem para "shoot"
##   neck         — altura do pescoço / altura (acima disso = tiro na cabeça)
const VARIANTS := {
	"soldier": {
		"model": "res://assets/characters/soldier.fbx",
		"anims": "res://assets/characters/soldier_anims.res",
		"head_top": 0.9923,
		"walk_stride": 0.7288 / 1.3,
		"shoot_stride": 0.914 / 0.9333,
		"neck": 0.735,
	},
	# Elite: malha riggada no Mixamo sem textura; o material PBR é montado aqui
	"elite": {
		"model": "res://assets/characters/elite.fbx",
		"anims": "res://assets/characters/elite_anims.res",
		"head_top": 1.7862,
		"walk_stride": 0.9907,
		"shoot_stride": 1.7306,
		"neck": 0.737,
		"textures": {
			"albedo": "res://assets/characters/elite_cor.png",
			"normal": "res://assets/characters/elite_normal.png",
			"roughness": "res://assets/characters/elite_rugosidade.png",
			"metallic": "res://assets/characters/elite_metal.png",
		},
	},
	# Milícia: caminhada recortada do "Rifle Walk To Stop"
	"militia": {
		"model": "res://assets/characters/militia.fbx",
		"anims": "res://assets/characters/militia_anims.res",
		"head_top": 1.7888,
		"walk_stride": 0.9599,
		"shoot_stride": 1.7286,
		"neck": 0.749,
		"textures": {
			"albedo": "res://assets/characters/militia_cor.png",
			"normal": "res://assets/characters/militia_normal.png",
			"roughness": "res://assets/characters/militia_rugosidade.png",
			"metallic": "res://assets/characters/militia_metal.png",
		},
	},
}

## AK-47 (Blend Swap #94134, CC0) — origem no receptor, cano para -Z.
const AK47 := preload("res://assets/weapons/ak47.glb")

## Chave de VARIANTS. Definir antes de adicionar à árvore.
var variant := "soldier"

## Tom multiplicado na textura da farda (diferencia guarda/elite/milícia).
## Definir antes de adicionar à árvore.
var tint := Color.WHITE
## 0 = em pé, 1 = totalmente agachado.
var crouch := 0.0
var muzzle: Marker3D
var rifle: Node3D

var _model: Node3D
var _ap: AnimationPlayer
var _skeleton: Skeleton3D
var _crouch_mod: _CrouchModifier
var _scale := 1.0
var _bone_rhand := -1
var _bone_lhand := -1
var _current := ""
var _turning := 0.0
var _recoil := 0.0
var _dead := false
var _v: Dictionary

## Um material por tom, compartilhado entre todos os soldados.
static var _tinted: Dictionary = {}
## Materiais PBR montados a partir de VARIANTS[...]["textures"].
static var _built: Dictionary = {}


func _ready() -> void:
	_v = VARIANTS.get(variant, VARIANTS["soldier"])
	_model = (load(_v["model"]) as PackedScene).instantiate() as Node3D
	_scale = HEIGHT / float(_v["head_top"])
	_model.scale = Vector3.ONE * _scale
	_model.rotation.y = PI  # o modelo olha para +Z; o jogo usa -Z como frente
	add_child(_model)
	_ap = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	_ap.add_animation_library("s", load(_v["anims"]) as AnimationLibrary)
	_bone_rhand = _skeleton.find_bone("mixamorig_RightHand")
	_bone_lhand = _skeleton.find_bone("mixamorig_LeftHand")
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).lod_bias = 0.6
		if _v.has("textures"):
			for i in (mi as MeshInstance3D).mesh.get_surface_count():
				(mi as MeshInstance3D).set_surface_override_material(i, _variant_material())
		if tint != Color.WHITE:
			_apply_tint(mi as MeshInstance3D)

	_crouch_mod = _CrouchModifier.new()
	_crouch_mod.setup(_skeleton)
	_skeleton.add_child(_crouch_mod)

	rifle = Node3D.new()
	rifle.name = "Rifle"
	rifle.top_level = true
	add_child(rifle)
	rifle.add_child(AK47.instantiate())
	muzzle = Marker3D.new()
	muzzle.position = Vector3(0, 0.006, -0.54)
	rifle.add_child(muzzle)
	# Depois dos modificadores (agachamento) a pose final dos ossos já vale
	_skeleton.skeleton_updated.connect(_update_rifle)
	# Fora da tela não precisa animar (economia de CPU/GPU com muitos guardas)
	var notifier := VisibleOnScreenNotifier3D.new()
	notifier.aabb = AABB(Vector3(-0.8, 0.0, -0.8), Vector3(1.6, 2.0, 1.6))
	notifier.screen_entered.connect(func() -> void: _ap.active = true)
	notifier.screen_exited.connect(func() -> void: _ap.active = _dead)
	add_child(notifier)
	_play("idle")


func _variant_material() -> StandardMaterial3D:
	if not _built.has(variant):
		var tex: Dictionary = _v["textures"]
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(tex["albedo"])
		if tex.has("normal"):
			m.normal_enabled = true
			m.normal_texture = load(tex["normal"])
		if tex.has("roughness"):
			m.roughness = 1.0
			m.roughness_texture = load(tex["roughness"])
		if tex.has("metallic"):
			m.metallic = 1.0
			m.metallic_texture = load(tex["metallic"])
		_built[variant] = m
	return _built[variant]


func _apply_tint(mi: MeshInstance3D) -> void:
	for i in mi.mesh.get_surface_count():
		var base := mi.get_surface_override_material(i) as BaseMaterial3D
		if base == null:
			base = mi.mesh.surface_get_material(i) as BaseMaterial3D
		if base == null:
			continue
		var key := "%s/%d/%s" % [mi.mesh.resource_path, i, tint.to_html()]
		if not _tinted.has(key):
			var m := base.duplicate() as BaseMaterial3D
			m.albedo_color = base.albedo_color * tint
			_tinted[key] = m
		mi.set_surface_override_material(i, _tinted[key])


## Altura (relativa aos pés) acima da qual um impacto é tiro na cabeça.
func headshot_height() -> float:
	return HEIGHT * float(_v["neck"]) * lerpf(1.0, 0.72, crouch)


## Atualiza a animação conforme o movimento.
## `speed` em m/s, `yaw_rate` em rad/s (positivo = girando para a esquerda).
func update_animation(delta: float, speed: float, yaw_rate: float, aiming: bool, firing: bool) -> void:
	if _dead:
		return
	_recoil = maxf(_recoil - delta * 6.0, 0.0)
	_crouch_mod.amount = crouch
	_crouch_mod.active = crouch > 0.01
	scale.y = lerpf(1.0, 0.86, crouch)
	_turning = maxf(_turning - delta, 0.0)
	if speed > 0.15:
		_turning = 0.0
		if aiming and firing:
			_play("shoot", clampf(speed / (float(_v["shoot_stride"]) * _scale), 0.6, 2.2))
		else:
			_play("walk", clampf(speed / (float(_v["walk_stride"]) * _scale), 0.6, 2.6))
	elif absf(yaw_rate) > 1.2 and crouch < 0.3:
		if _turning <= 0.0 or (_current != "turn_l" and _current != "turn_r"):
			_play("turn_l" if yaw_rate > 0.0 else "turn_r", clampf(absf(yaw_rate) / 1.2, 1.0, 2.2))
			_ap.seek(0.0, true)
			_turning = 0.5
	elif _turning <= 0.0:
		_play("aim" if aiming else "idle")


## Coice do disparo (o fuzil recua e volta).
func kick() -> void:
	_recoil = 1.0


func play_death() -> void:
	_dead = true
	_crouch_mod.active = false
	scale.y = 1.0
	_play("dying")
	_ap.seek(0.0, true)
	# Solta o fuzil: cai ao lado do corpo
	var drop_basis := Basis(Vector3.UP, randf() * TAU) * Basis(Vector3.FORWARD, PI * 0.5)
	var ground := global_position + global_basis * Vector3(0.5, 0.04, -0.4)
	var tw := rifle.create_tween().set_parallel(true)
	tw.tween_property(rifle, "global_position", ground, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(rifle, "global_basis", drop_basis, 0.45)


func _play(anim: String, speed_scale: float = 1.0) -> void:
	var full := "s/" + anim
	if _current != anim:
		_current = anim
		_ap.play(full, 0.25)
	_ap.speed_scale = speed_scale


func _update_rifle() -> void:
	if _dead:
		return
	# Fuzil: empunhadura na mão direita, cano apontando para a mão esquerda
	var sk := _skeleton.global_transform
	var rh := sk * _skeleton.get_bone_global_pose(_bone_rhand).origin
	var lh := sk * _skeleton.get_bone_global_pose(_bone_lhand).origin
	var dir := lh - rh
	if dir.length() < 0.05:
		dir = -global_basis.z
	var up := global_basis.y
	if absf(dir.normalized().dot(up)) > 0.95:
		up = -global_basis.z
	var b := Basis.looking_at(dir, up)
	var grip := rh + b * Vector3(0, 0.04, 0.02)
	rifle.global_transform = Transform3D(b, grip - b * Vector3(0, -0.09, 0.06 + _recoil * 0.05))


## Dobra joelhos e quadril sobre a pose animada (agachado atrás da cobertura).
class _CrouchModifier extends SkeletonModifier3D:
	var amount := 0.0
	var _hips := -1
	var _spine := -1
	var _legs: Array[PackedInt32Array] = []
	var _leg_len := 0.34

	func setup(sk: Skeleton3D) -> void:
		_hips = sk.find_bone("mixamorig_Hips")
		_spine = sk.find_bone("mixamorig_Spine")
		for side in ["Left", "Right"]:
			_legs.append(PackedInt32Array([
				sk.find_bone("mixamorig_%sUpLeg" % side),
				sk.find_bone("mixamorig_%sLeg" % side),
				sk.find_bone("mixamorig_%sFoot" % side),
			]))

	func _process_modification() -> void:
		var sk := get_skeleton()
		if sk == null or _hips < 0:
			return
		var a := deg_to_rad(78.0) * amount
		# Modelo olha para +Z: girar em X negativo leva o joelho para a frente
		var knee_fwd := Basis(Vector3.RIGHT, -a)
		var shin_back := Basis(Vector3.RIGHT, a)
		var old: Array[Transform3D] = []
		for leg in _legs:
			for bone in leg:
				old.append(sk.get_bone_global_pose(bone))
		var hips := sk.get_bone_pose(_hips)
		hips.origin.y -= _leg_len * (1.0 - cos(a))
		hips.origin.z -= 0.05 * amount
		sk.set_bone_pose(_hips, hips)
		var i := 0
		for leg in _legs:
			var thigh := sk.get_bone_global_pose(leg[0])
			sk.set_bone_global_pose(leg[0], Transform3D(knee_fwd * old[i].basis, thigh.origin))
			var shin := sk.get_bone_global_pose(leg[1])
			sk.set_bone_global_pose(leg[1], Transform3D(shin_back * old[i + 1].basis, shin.origin))
			var foot := sk.get_bone_global_pose(leg[2])
			sk.set_bone_global_pose(leg[2], Transform3D(old[i + 2].basis, foot.origin))
			i += 3
		if _spine >= 0:
			var sp := sk.get_bone_global_pose(_spine)
			sk.set_bone_global_pose(_spine, Transform3D(Basis(Vector3.RIGHT, 0.3 * amount) * sp.basis, sp.origin))
