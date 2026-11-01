class_name WeaponModels
extends RefCounted
## Modelos temporários das armas sem modelo 3D, montados com caixas e cilindros
## (cano em -Z, origem no receptor, mesma convenção dos modelos importados).
## HANDS: posição das mãos (ver Weapon._arm), boca do cano e altura do olho na
## mira de cada uma. Para trocar por um modelo de verdade, basta colocar o .glb
## em Weapon.MODELS com o mesmo model_type.

## [palma dir., dedos dir., cotovelo dir., ombro dir.,
##  palma esq., dedos esq., palma-para esq., fechamento esq., cotovelo esq., ombro esq., boca do cano]
const HANDS := {
	"mp5sd": [Vector3(0.026, -0.085, 0.08), Vector3(0, -0.3, -1), Vector3(0.1, -0.24, 0.28), Vector3(0.15, -0.42, 0.48),
		Vector3(-0.008, -0.075, -0.19), Vector3(1, 0, -0.3), Vector3(0, 1, 0), 0.8, Vector3(-0.2, -0.22, -0.02), Vector3(-0.48, -0.42, 0.4),
		Vector3(0, 0, -0.47)],
	"m4_shotgun": [Vector3(0.026, -0.09, 0.09), Vector3(0, -0.3, -1), Vector3(0.1, -0.25, 0.29), Vector3(0.15, -0.42, 0.48),
		Vector3(-0.008, -0.06, -0.22), Vector3(1, 0, -0.3), Vector3(0, 1, 0), 0.8, Vector3(-0.2, -0.22, -0.04), Vector3(-0.48, -0.42, 0.4),
		Vector3(0, 0.01, -0.54)],
	"m24": [Vector3(0.028, -0.085, 0.14), Vector3(0, -0.35, -1), Vector3(0.1, -0.26, 0.34), Vector3(0.15, -0.42, 0.52),
		Vector3(-0.008, -0.075, -0.28), Vector3(1, 0, -0.3), Vector3(0, 1, 0), 0.8, Vector3(-0.2, -0.22, -0.1), Vector3(-0.48, -0.42, 0.4),
		Vector3(0, 0, -0.8)],
	"m249": [Vector3(0.03, -0.105, 0.12), Vector3(0, -0.3, -1), Vector3(0.11, -0.27, 0.32), Vector3(0.16, -0.43, 0.5),
		Vector3(-0.01, -0.075, -0.25), Vector3(1, 0, -0.3), Vector3(0, 1, 0), 0.8, Vector3(-0.22, -0.23, -0.06), Vector3(-0.5, -0.43, 0.4),
		Vector3(0, 0, -0.6)],
	"glock": [Vector3(0.027, -0.062, 0.05), Vector3(0, -0.25, -1), Vector3(0.08, -0.25, 0.26), Vector3(0.14, -0.42, 0.46),
		Vector3(-0.032, -0.075, 0.045), Vector3(0, -0.4, -1), Vector3(1, 0, 0), 0.85, Vector3(-0.16, -0.26, 0.2), Vector3(-0.44, -0.42, 0.42),
		Vector3(0, 0.012, -0.124)],
	"deagle": [Vector3(0.029, -0.064, 0.055), Vector3(0, -0.25, -1), Vector3(0.08, -0.25, 0.27), Vector3(0.14, -0.42, 0.47),
		Vector3(-0.034, -0.078, 0.05), Vector3(0, -0.4, -1), Vector3(1, 0, 0), 0.85, Vector3(-0.16, -0.26, 0.21), Vector3(-0.44, -0.42, 0.43),
		Vector3(0, 0.012, -0.17)],
}

## Pistolas usam as miras altas de Weapon._pistol_sights; as outras têm a mira
## própria construída aqui (o olho fica na altura indicada em ads_position.y).
const PISTOLS := ["glock", "deagle"]


static func build(type: String, parent: Node3D) -> void:
	var black := _mat(Color(0.045, 0.045, 0.048), 0.35, 0.55)
	var polymer := _mat(Color(0.07, 0.07, 0.072), 0.0, 0.8)
	match type:
		"mp5sd":
			_box(parent, Vector3(0.05, 0.07, 0.3), Vector3(0, 0, -0.02), black)               # receptor
			_cyl(parent, 0.022, 0.3, Vector3(0, 0.0, -0.32), black)                           # supressor
			_box(parent, Vector3(0.056, 0.06, 0.16), Vector3(0, -0.045, -0.2), polymer)       # guarda-mão
			_box(parent, Vector3(0.03, 0.17, 0.05), Vector3(0, -0.12, -0.08), black, 0.25)    # carregador curvo
			_box(parent, Vector3(0.035, 0.1, 0.045), Vector3(0, -0.09, 0.08), polymer, -0.3)  # empunhadura
			_box(parent, Vector3(0.03, 0.03, 0.05), Vector3(0, -0.03, 0.03), black)           # guarda-mato
			for x in [-0.018, 0.018]:
				_box(parent, Vector3(0.008, 0.012, 0.22), Vector3(x, -0.01, 0.22), black)      # coronha retrátil
			_box(parent, Vector3(0.045, 0.1, 0.025), Vector3(0, -0.03, 0.33), polymer)
			_iron_sights(parent, black, 0.059, 0.09, -0.16)
		"m4_shotgun":
			_box(parent, Vector3(0.05, 0.07, 0.24), Vector3(0, 0, 0), black)                  # receptor
			_cyl(parent, 0.012, 0.42, Vector3(0, 0.01, -0.33), black)                         # cano
			_cyl(parent, 0.013, 0.34, Vector3(0, -0.022, -0.29), black)                       # tubo de cartuchos
			_box(parent, Vector3(0.05, 0.05, 0.18), Vector3(0, -0.025, -0.22), polymer)       # telha
			_box(parent, Vector3(0.036, 0.1, 0.045), Vector3(0, -0.09, 0.09), polymer, -0.3)  # empunhadura
			_box(parent, Vector3(0.045, 0.08, 0.26), Vector3(0, -0.035, 0.25), polymer)       # coronha
			_box(parent, Vector3(0.012, 0.02, 0.05), Vector3(0.026, 0.0, -0.02), black)       # janela de ejeção
			_iron_sights(parent, black, 0.045, 0.06, -0.52)
		"m24":
			var od := _mat(Color(0.16, 0.18, 0.12), 0.0, 0.85)
			_box(parent, Vector3(0.06, 0.08, 0.72), Vector3(0, -0.035, -0.05), od)            # coronha/telha
			_box(parent, Vector3(0.04, 0.11, 0.05), Vector3(0, -0.1, 0.13), od, -0.25)        # empunhadura
			_cyl(parent, 0.02, 0.24, Vector3(0, 0.012, 0.0), black)                           # receptor
			_cyl(parent, 0.011, 0.5, Vector3(0, 0.012, -0.55), black)                         # cano
			_box(parent, Vector3(0.05, 0.008, 0.008), Vector3(0.035, 0.015, 0.06), black)     # alavanca do ferrolho
			_sphere(parent, 0.009, Vector3(0.06, 0.015, 0.06), black)
			_cyl(parent, 0.016, 0.3, Vector3(0, 0.075, -0.02), black)                         # luneta
			_cyl(parent, 0.024, 0.06, Vector3(0, 0.075, -0.19), black)                        # objetiva
			_cyl(parent, 0.021, 0.05, Vector3(0, 0.075, 0.14), black)                         # ocular
			_box(parent, Vector3(0.02, 0.012, 0.022), Vector3(0, 0.08, -0.02), black)         # torre de ajuste
			for z in [-0.08, 0.05]:
				_box(parent, Vector3(0.024, 0.05, 0.02), Vector3(0, 0.045, z), black)          # montagens
		"m249":
			var tan := _mat(Color(0.42, 0.36, 0.25), 0.0, 0.85)
			_box(parent, Vector3(0.08, 0.1, 0.34), Vector3(0, 0, 0), black)                   # receptor
			_cyl(parent, 0.013, 0.4, Vector3(0, 0.0, -0.4), black)                            # cano
			_box(parent, Vector3(0.036, 0.02, 0.2), Vector3(0, 0.022, -0.32), black)          # escudo térmico
			_box(parent, Vector3(0.065, 0.055, 0.2), Vector3(0, -0.04, -0.26), polymer)       # guarda-mão
			_box(parent, Vector3(0.09, 0.12, 0.11), Vector3(-0.055, -0.1, -0.03), tan)        # caixa de munição
			_box(parent, Vector3(0.036, 0.1, 0.045), Vector3(0, -0.1, 0.12), polymer, -0.3)   # empunhadura
			_box(parent, Vector3(0.05, 0.1, 0.28), Vector3(0, -0.02, 0.32), polymer)          # coronha
			for x in [-0.012, 0.012]:
				_box(parent, Vector3(0.008, 0.008, 0.2), Vector3(x, -0.03, -0.5), black, 0.0)  # bipé dobrado
			_box(parent, Vector3(0.04, 0.03, 0.08), Vector3(0, 0.065, 0.02), black)           # base da mira
		"glock":
			_box(parent, Vector3(0.026, 0.03, 0.185), Vector3(0, 0.0112, -0.03), polymer)     # ferrolho (topo 0.0262)
			_box(parent, Vector3(0.024, 0.022, 0.16), Vector3(0, -0.013, -0.04), polymer)     # armação
			_box(parent, Vector3(0.029, 0.11, 0.05), Vector3(0, -0.07, 0.045), polymer, -0.3) # empunhadura
			_box(parent, Vector3(0.022, 0.018, 0.055), Vector3(0, -0.035, -0.02), polymer)    # guarda-mato
		"deagle":
			var steel := _mat(Color(0.6, 0.6, 0.62), 0.85, 0.3)
			_box(parent, Vector3(0.032, 0.034, 0.24), Vector3(0, 0.0092, -0.05), steel)       # ferrolho (topo 0.0262)
			_box(parent, Vector3(0.022, 0.012, 0.13), Vector3(0, 0.03, -0.1), steel)          # cano triangular
			_box(parent, Vector3(0.03, 0.026, 0.2), Vector3(0, -0.018, -0.05), steel)         # armação
			_box(parent, Vector3(0.033, 0.12, 0.055), Vector3(0, -0.075, 0.05), black, -0.25) # empunhadura
			_box(parent, Vector3(0.024, 0.02, 0.06), Vector3(0, -0.042, -0.03), steel)        # guarda-mato


## Alça (duas lâminas com entalhe) atrás e maça na frente, topo em `eye_y`.
static func _iron_sights(parent: Node3D, mat: Material, eye_y: float, rear_z: float, front_z: float) -> void:
	var base := eye_y - 0.02
	for x in [-0.007, 0.007]:
		_box(parent, Vector3(0.007, 0.026, 0.01), Vector3(x, base + 0.009, rear_z), mat)
	_box(parent, Vector3(0.024, 0.01, 0.012), Vector3(0, base - 0.004, rear_z), mat)
	_box(parent, Vector3(0.004, 0.022, 0.006), Vector3(0, eye_y - 0.011, front_z), mat)
	_box(parent, Vector3(0.016, 0.008, 0.014), Vector3(0, eye_y - 0.026, front_z), mat)


static func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_x: float = 0.0) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.rotation.x = rot_x
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


static func _cyl(parent: Node3D, radius: float, length: float, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = length
	c.radial_segments = 14
	c.rings = 1
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	mi.rotation.x = PI * 0.5   # eixo do cilindro em Z
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


static func _sphere(parent: Node3D, radius: float, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 10
	s.rings = 5
	mi.mesh = s
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
