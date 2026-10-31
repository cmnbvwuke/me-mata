extends SceneTree
## Monta a AnimationLibrary de um personagem Mixamo para o SoldierModel.
##
## Uso (os FBX já precisam ter sido importados pelo Godot: rode antes
## `godot --headless --import --path operation-black-tide`):
##   godot --headless --path operation-black-tide -s res://tools/extract_character_anims.gd -- \
##       res://assets/characters/_src_elite res://assets/characters/elite_anims.res
##
## A pasta de origem deve ter, exportados do Mixamo (FBX Binary, 30 fps):
##   walk.fbx    Rifle Walk      ("With Skin": é também a malha base). Também aceita
##               "Rifle Walk To Stop": o ciclo de passos é recortado e vira loop.
##   shoot.fbx   Shoot Rifle     (pode ser "Without Skin")
##   dying.fbx   Dying
##   turn_l.fbx  Turn Left 45 Degrees
##   turn_r.fbx  Turning Right 45 Degrees
##   idle.fbx    (opcional) Rifle Idle; sem ele a pose parada sai da caminhada
##
## O que é feito: remove o deslocamento horizontal do quadril (animações no
## lugar, quem anda é o CharacterBody3D), remove o giro dos "turns" (quem gira é
## o código), põe walk/shoot/idle em loop e cria as poses "idle" e "aim".
## No fim imprime os valores para colar em SoldierModel.VARIANTS.

const HIPS := "mixamorig_Hips"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("uso: -- <pasta res:// com os fbx> <saida.res>")
		quit(1)
		return
	var src := args[0].trim_suffix("/")
	var out := args[1]
	var walk := _anim(src + "/walk.fbx")
	var shoot := _anim(src + "/shoot.fbx")
	var dying := _anim(src + "/dying.fbx")
	var tl := _anim(src + "/turn_l.fbx")
	var tr := _anim(src + "/turn_r.fbx")
	if walk == null or shoot == null or dying == null or tl == null or tr == null:
		quit(1)
		return
	if walk.length > 2.0:
		walk = _cut_walk_cycle(walk)
	var walk_travel := _strip_xz(walk)
	var shoot_travel := _strip_xz(shoot)
	_strip_xz(tl)
	_strip_xz(tr)
	_strip_yaw(tl)
	_strip_yaw(tr)
	walk.loop_mode = Animation.LOOP_LINEAR
	shoot.loop_mode = Animation.LOOP_LINEAR

	var lib := AnimationLibrary.new()
	lib.add_animation("walk", walk)
	lib.add_animation("shoot", shoot)
	lib.add_animation("turn_l", tl)
	lib.add_animation("turn_r", tr)
	lib.add_animation("dying", dying)
	lib.add_animation("aim", _pose(tl, 0.0))

	var root := (load(src + "/walk.fbx") as PackedScene).instantiate() as Node3D
	get_root().add_child(root)
	var ap := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk := root.find_child("Skeleton3D", true, false) as Skeleton3D
	ap.add_animation_library("x", lib)
	# Transformação do esqueleto relativa à raiz do modelo (FBX do Blender vem com escala)
	var to_root := Transform3D.IDENTITY
	var n: Node = sk
	while n != root:
		to_root = (n as Node3D).transform * to_root
		n = n.get_parent()

	if ResourceLoader.exists(src + "/idle.fbx"):
		var idle := _anim(src + "/idle.fbx")
		_strip_xz(idle)
		idle.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation("idle", idle)
	else:
		# Quadro da caminhada com os pés mais juntos
		var best := 0.0
		var best_d := INF
		var t := 0.0
		while t < walk.length:
			_seek(ap, sk, "x/walk", t)
			var fl := sk.get_bone_global_pose(sk.find_bone("mixamorig_LeftFoot")).origin
			var fr := sk.get_bone_global_pose(sk.find_bone("mixamorig_RightFoot")).origin
			if absf(fl.z - fr.z) < best_d:
				best_d = absf(fl.z - fr.z)
				best = t
			t += 1.0 / 30.0
		lib.add_animation("idle", _pose(walk, best))

	_seek(ap, sk, "x/idle", 0.0)
	var head := (to_root * sk.get_bone_global_pose(sk.find_bone("mixamorig_HeadTop_End"))).origin.y
	var neck := (to_root * sk.get_bone_global_pose(sk.find_bone("mixamorig_Neck"))).origin.y
	var unit := to_root.basis.get_scale().y  # converte deslocamento do quadril para unidades do modelo
	var err := ResourceSaver.save(lib, out, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_error("falha ao salvar %s (%d)" % [out, err])
		quit(1)
		return
	print("Salvo: ", out)
	print("Cole em SoldierModel.VARIANTS:")
	print('\t"head_top": %.4f,' % head)
	print('\t"walk_stride": %.4f,' % (walk_travel * unit / walk.length))
	print('\t"shoot_stride": %.4f,' % (shoot_travel * unit / shoot.length))
	print('\t"neck": %.3f,' % (neck / head))
	root.free()
	quit()


func _anim(path: String) -> Animation:
	if not ResourceLoader.exists(path):
		push_error("faltando: " + path)
		return null
	var r := (load(path) as PackedScene).instantiate()
	var ap := r.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null or ap.get_animation_list().is_empty():
		push_error("sem animação: " + path)
		r.free()
		return null
	var list := ap.get_animation_list()
	var a := ap.get_animation(list[list.size() - 1]).duplicate(true) as Animation
	r.free()
	return a


## "Walk To Stop": acha o ciclo completo (2 passos) no trecho de caminhada
## constante e emenda o fim no começo com uma transição suave.
func _cut_walk_cycle(src: Animation) -> Animation:
	var rot: Array[int] = []
	for t in src.get_track_count():
		if src.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			rot.append(t)
	var best_err := INF
	var t0 := 0.0
	var period := 1.0
	var a := 0.0
	while a <= 0.5:
		var p := 0.8
		while p <= 1.45 and a + p <= 1.45:
			var e := 0.0
			for t in rot:
				e += src.rotation_track_interpolate(t, a).angle_to(src.rotation_track_interpolate(t, a + p))
			if e < best_err:
				best_err = e
				t0 = a
				period = p
			p += 1.0 / 60.0
		a += 1.0 / 60.0
	print("ciclo de caminhada: início %.2f s, duração %.2f s (erro %.2f)" % [t0, period, best_err])
	var fade := minf(0.3, period * 0.3)
	var out := Animation.new()
	out.length = period
	for t in src.get_track_count():
		var type := src.track_get_type(t)
		var nt := out.add_track(type)
		out.track_set_path(nt, src.track_get_path(t))
		var time := 0.0
		while time <= period + 0.0001:
			var w := clampf((time - (period - fade)) / fade, 0.0, 1.0)
			var at := t0 + time
			var back := maxf(at - period, 0.0)
			var v: Variant
			match type:
				Animation.TYPE_POSITION_3D:
					var p1 := src.position_track_interpolate(t, at)
					var p2 := src.position_track_interpolate(t, back)
					# só a altura recebe a transição: o avanço horizontal é removido depois
					v = Vector3(p1.x, lerpf(p1.y, p2.y, w), p1.z)
				Animation.TYPE_ROTATION_3D:
					v = src.rotation_track_interpolate(t, at).slerp(src.rotation_track_interpolate(t, back), w)
				Animation.TYPE_SCALE_3D:
					v = src.scale_track_interpolate(t, at)
				_:
					v = src.track_get_key_value(t, 0)
			out.track_insert_key(nt, time, v)
			time += 1.0 / 30.0
	return out


func _seek(ap: AnimationPlayer, sk: Skeleton3D, anim: String, time: float) -> void:
	ap.play(anim)
	ap.seek(time, true)
	sk.force_update_all_bone_transforms()


func _track(a: Animation, type: int) -> int:
	for t in a.get_track_count():
		if a.track_get_type(t) == type and str(a.track_get_path(t)).ends_with(":" + HIPS):
			return t
	return -1


## Trava X/Z do quadril no primeiro quadro; devolve a distância percorrida.
func _strip_xz(a: Animation) -> float:
	var t := _track(a, Animation.TYPE_POSITION_3D)
	if t < 0:
		return 0.0
	var first: Vector3 = a.track_get_key_value(t, 0)
	var last: Vector3 = a.track_get_key_value(t, a.track_get_key_count(t) - 1)
	for k in a.track_get_key_count(t):
		var v: Vector3 = a.track_get_key_value(t, k)
		a.track_set_key_value(t, k, Vector3(first.x, v.y, first.z))
	return Vector2(last.x - first.x, last.z - first.z).length()


func _yaw(q: Quaternion) -> float:
	var f := q * Vector3.FORWARD
	return atan2(f.x, f.z)


## Remove o giro em Y do quadril (o corpo continua virado para a frente).
func _strip_yaw(a: Animation) -> void:
	var t := _track(a, Animation.TYPE_ROTATION_3D)
	if t < 0:
		return
	var y0 := _yaw(a.track_get_key_value(t, 0))
	for k in a.track_get_key_count(t):
		var q: Quaternion = a.track_get_key_value(t, k)
		a.track_set_key_value(t, k, Quaternion(Vector3.UP, -angle_difference(y0, _yaw(q))) * q)


## Animação de 1 quadro com a pose de `src` no instante `time`.
func _pose(src: Animation, time: float) -> Animation:
	var a := Animation.new()
	a.length = 0.1
	for t in src.get_track_count():
		var type := src.track_get_type(t)
		var nt := a.add_track(type)
		a.track_set_path(nt, src.track_get_path(t))
		var v: Variant
		match type:
			Animation.TYPE_POSITION_3D:
				v = src.position_track_interpolate(t, time)
			Animation.TYPE_ROTATION_3D:
				v = src.rotation_track_interpolate(t, time)
			Animation.TYPE_SCALE_3D:
				v = src.scale_track_interpolate(t, time)
			_:
				v = src.track_get_key_value(t, 0)
		a.track_insert_key(nt, 0.0, v)
	return a
