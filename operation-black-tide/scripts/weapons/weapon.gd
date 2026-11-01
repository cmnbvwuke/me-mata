class_name Weapon
extends Node3D
## Uma arma equipável: estado de munição, cadência, recarga, modo de disparo
## e o modelo procedural em primeira pessoa (viewmodel).
## A balística (raycast) fica no WeaponManager, que conhece a câmera.

signal ammo_changed(in_mag: int, reserve: int)
signal reload_started(duration: float)
signal reload_finished
signal fire_mode_changed(is_auto: bool)

enum State { HOLSTERED, EQUIPPING, READY, RELOADING }

var data: WeaponData
var ammo_in_mag: int = 0
var ammo_reserve: int = 0
var is_auto: bool = true
var state: State = State.HOLSTERED
var muzzle: Marker3D

var _cooldown := 0.0
var _reload_timer := 0.0
var _reload_duration := 1.0
var _reload_empty := false
var _reload_stage := 0
var _equip_timer := 0.0
var _flash_light: OmniLight3D
var _flash_mesh: MeshInstance3D
var _flash_timer := 0.0
## Material das mãos (a cor muda ao vivo pelas configurações).
var _hand_mat: StandardMaterial3D

## Mão low-poly com cada falange separada (palma, polegar e 4 dedos em 3 partes).
const HAND_MODEL := preload("res://assets/characters/hand.glb")
## Modelos das armas (convertidos no Blender: escala real, cano em -Z; ver README).
const M4A1_MODEL := preload("res://assets/weapons/m4a1.glb")
const P226_MODEL := preload("res://assets/weapons/p226.glb")
const HAND_SCALE := 0.05


func setup(p_data: WeaponData) -> void:
	data = p_data
	ammo_in_mag = data.magazine_size
	ammo_reserve = data.reserve_ammo
	is_auto = data.default_auto and data.allows_auto
	_build_model()


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash_light.visible = false
			_flash_mesh.visible = false
	match state:
		State.EQUIPPING:
			_equip_timer += delta
			if _equip_timer >= data.equip_time:
				state = State.READY
		State.RELOADING:
			_process_reload(delta)


# =========================================================================
# Disparo
# =========================================================================

## Tenta disparar. Retorna true se uma bala saiu (o chamador faz o raycast).
func try_fire(trigger_just_pressed: bool) -> bool:
	if state != State.READY or _cooldown > 0.0:
		return false
	if not is_auto and not trigger_just_pressed:
		return false
	if ammo_in_mag <= 0:
		if trigger_just_pressed:
			AudioManager.play_2d("dry_fire", -6.0)
		return false
	ammo_in_mag -= 1
	_cooldown = 60.0 / data.fire_rate
	_show_muzzle_flash()
	AudioManager.play_2d(data.sound_name, data.shot_volume_db, 0.04)
	# Cápsula caindo no chão um instante depois
	var casing_tw := create_tween()
	casing_tw.tween_interval(0.3)
	casing_tw.tween_callback(func() -> void: AudioManager.play_2d("casing", -24.0, 0.2))
	ammo_changed.emit(ammo_in_mag, ammo_reserve)
	return true


func toggle_fire_mode() -> void:
	if not data.allows_auto or state == State.HOLSTERED:
		return
	is_auto = not is_auto
	AudioManager.play_2d("fire_mode", -6.0)
	fire_mode_changed.emit(is_auto)


func _show_muzzle_flash() -> void:
	_flash_timer = 0.045
	_flash_light.visible = true
	_flash_mesh.visible = true
	_flash_mesh.rotation.z = randf() * TAU
	var s := randf_range(0.8, 1.2)
	_flash_mesh.scale = Vector3(s, s, s)


# =========================================================================
# Recarga / equipar
# =========================================================================

func can_reload() -> bool:
	return state == State.READY and ammo_in_mag < data.magazine_size and ammo_reserve > 0


func start_reload() -> void:
	if not can_reload():
		return
	state = State.RELOADING
	_reload_empty = ammo_in_mag == 0
	_reload_duration = data.empty_reload_time if _reload_empty else data.reload_time
	_reload_timer = 0.0
	_reload_stage = 0
	AudioManager.play_2d("mag_out", -6.0)
	reload_started.emit(_reload_duration)


func _process_reload(delta: float) -> void:
	_reload_timer += delta
	var t := _reload_timer / _reload_duration
	if _reload_stage == 0 and t > 0.55:
		_reload_stage = 1
		AudioManager.play_2d("mag_in", -5.0)
	if _reload_stage == 1 and _reload_empty and t > 0.8:
		_reload_stage = 2
		AudioManager.play_2d("bolt", -5.0)
	if t >= 1.0:
		var needed := data.magazine_size - ammo_in_mag
		var taken := mini(needed, ammo_reserve)
		ammo_in_mag += taken
		ammo_reserve -= taken
		state = State.READY
		ammo_changed.emit(ammo_in_mag, ammo_reserve)
		reload_finished.emit()


## 0..1 durante a recarga, -1 fora dela (usado pela animação procedural).
func get_reload_progress() -> float:
	if state != State.RELOADING:
		return -1.0
	return clampf(_reload_timer / _reload_duration, 0.0, 1.0)


func get_equip_progress() -> float:
	if state == State.EQUIPPING:
		return clampf(_equip_timer / data.equip_time, 0.0, 1.0)
	return 1.0


func equip() -> void:
	visible = true
	state = State.EQUIPPING
	_equip_timer = 0.0
	AudioManager.play_2d("equip", -10.0)


func holster() -> void:
	visible = false
	state = State.HOLSTERED


func refill() -> void:
	ammo_reserve = data.reserve_ammo
	if state != State.RELOADING:
		ammo_in_mag = data.magazine_size
	ammo_changed.emit(ammo_in_mag, ammo_reserve)


# =========================================================================
# Modelo procedural (viewmodel)
# =========================================================================

func _build_model() -> void:
	var glove := _mat(GameManager.hand_color(), 0.0, 0.8)
	_hand_mat = glove
	GameManager.settings_changed.connect(func() -> void: _hand_mat.albedo_color = GameManager.hand_color())
	var sleeve := _mat(Color(0.22, 0.23, 0.17), 0.0, 1.0)
	var cuff := _mat(Color(0.16, 0.17, 0.12), 0.0, 1.0)
	muzzle = Marker3D.new()
	muzzle.name = "Muzzle"
	add_child(muzzle)

	var model := (P226_MODEL if data.model_type == "pistol" else M4A1_MODEL).instantiate() as Node3D
	add_child(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if data.model_type == "pistol":
		# Pontos de trítio: maça e alça de mira
		_emissive_dot(Vector3(0, 0.029, -0.113), Color(0.3, 1.0, 0.4), 0.0022)
		_emissive_dot(Vector3(-0.009, 0.031, 0.021), Color(0.3, 1.0, 0.4), 0.0018)
		_emissive_dot(Vector3(0.009, 0.031, 0.021), Color(0.3, 1.0, 0.4), 0.0018)
		# Direita na empunhadura; esquerda envolve a direita pelo lado esquerdo
		_arm(Vector3(0.027, -0.062, 0.05), Vector3(0, -0.25, -1), Vector3(-1, 0, 0), true, 1.0,
			Vector3(0.08, -0.25, 0.26), Vector3(0.14, -0.42, 0.46), sleeve, cuff, glove)
		_arm(Vector3(-0.032, -0.075, 0.045), Vector3(0, -0.4, -1), Vector3(1, 0, 0), false, 0.85,
			Vector3(-0.16, -0.26, 0.2), Vector3(-0.44, -0.42, 0.42), sleeve, cuff, glove, true)
		muzzle.position = Vector3(0, 0.01, -0.291)
	else:
		# Ponto vermelho na lente dianteira da mira (o tubo é vazado)
		_emissive_dot(Vector3(0, 0.0927, 0.04), Color(1.0, 0.1, 0.05), 0.0016)
		# Direita na empunhadura; esquerda por baixo do guarda-mão, polegar no lado esquerdo
		_arm(Vector3(0.026, -0.14, 0.155), Vector3(0, -0.3, -1), Vector3(-1, 0, 0), true, 1.0,
			Vector3(0.1, -0.27, 0.32), Vector3(0.15, -0.42, 0.5), sleeve, cuff, glove)
		_arm(Vector3(-0.008, -0.068, -0.2), Vector3(1, 0, -0.3), Vector3(0, 1, 0), false, 0.8,
			Vector3(-0.2, -0.22, 0.0), Vector3(-0.48, -0.42, 0.4), sleeve, cuff, glove, true)
		muzzle.position = Vector3(0, -0.003, -0.44)

	# Clarão do disparo
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.72, 0.4)
	_flash_light.light_energy = 0.6 if data.suppressed else 4.0
	_flash_light.omni_range = 2.5 if data.suppressed else 6.0
	_flash_light.visible = false
	muzzle.add_child(_flash_light)
	_flash_mesh = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06) if data.suppressed else Vector2(0.2, 0.2)
	_flash_mesh.mesh = quad
	_flash_mesh.material_override = FX.flash_material()
	_flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash_mesh.visible = false
	muzzle.add_child(_flash_mesh)
	MeshMerger.merge(self, false, 1000.0)


func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m


## Braço em dois segmentos afunilados (antebraço e braço), punho e mão.
##  palm_center: centro da palma; fingers: direção dos dedos esticados;
##  palm: para onde a palma aponta (para a arma); curl: 0 = aberta, 1 = fechada.
func _arm(palm_center: Vector3, fingers: Vector3, palm: Vector3, right: bool, curl: float,
		elbow: Vector3, shoulder: Vector3, sleeve: Material, cuff: Material, glove: Material,
		watch: bool = false) -> void:
	fingers = fingers.normalized()
	var wrist := palm_center - fingers * 0.05
	var up_arm := (elbow - wrist).normalized()
	_limb(elbow, shoulder, 0.043, 0.05, sleeve)
	_limb(wrist + up_arm * 0.04, elbow, 0.034, 0.044, sleeve)
	_joint(elbow, 0.045, sleeve)
	_limb(wrist + up_arm * 0.01, wrist + up_arm * 0.045, 0.031, 0.034, cuff)
	_hand(palm_center, fingers, palm, right, curl, glove)
	if watch:
		_limb(wrist + up_arm * 0.045, wrist + up_arm * 0.062, 0.036, 0.036, _mat(Color(0.05, 0.05, 0.05), 0.3, 0.5))


## Mão com os dedos dobrados em volta da arma, juntada numa única malha.
## No modelo os dedos apontam para -Z, o polegar para +X e os dedos dobram
## para +Y (mão direita com a palma para cima) ou -Y (mão esquerda).
func _hand(pos: Vector3, fingers_dir: Vector3, palm: Vector3, right: bool, curl: float, mat: Material) -> void:
	var model := HAND_MODEL.instantiate() as Node3D
	var side := 1.0 if right else -1.0
	for finger in ["index", "middle", "ring", "pinky"]:
		var bend := [0.75, 1.15, 0.9]
		for i in 3:
			var node := model.find_child("%s_%d" % [finger, i], true, false) as Node3D
			if node:
				node.rotation.x = side * bend[i] * curl
	var thumb := [Vector3(0.35, -0.25, 0.55), Vector3(0.0, 0.0, 0.35), Vector3(0.0, 0.0, 0.3)]
	for i in 3:
		var node := model.find_child("thumb_%d" % i, true, false) as Node3D
		if node:
			node.rotation = Vector3(thumb[i].x * side, thumb[i].y, thumb[i].z * side) * curl
	var st := SurfaceTool.new()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if mi.name == "arm_lower":
			continue  # o antebraço é a manga do uniforme
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != model:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		st.append_from((mi as MeshInstance3D).mesh, 0, xf)
	model.free()
	var out := MeshInstance3D.new()
	out.mesh = st.commit()
	out.material_override = mat
	out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(out)
	var z := -fingers_dir
	var y := (palm.normalized() * side - z * z.dot(palm.normalized() * side)).normalized()
	var b := Basis(y.cross(z), y, z).scaled(Vector3.ONE * HAND_SCALE)
	out.transform = Transform3D(b, pos)


func _limb(a: Vector3, b: Vector3, radius_a: float, radius_b: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius_a
	mesh.top_radius = radius_b
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 12
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.transform = Transform3D(_basis_along(b - a), (a + b) * 0.5)


func _joint(pos: Vector3, radius: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Base cujo eixo Y aponta na direção dada (para cilindros/cápsulas).
func _basis_along(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


func _emissive_dot(pos: Vector3, color: Color, radius: float) -> void:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 4.0
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
