class_name Hitbox
extends Area3D
## Área que causa dano. Fica "armada" só durante a janela ativa do golpe.
## Monitora o tempo todo para resolver o acerto no mesmo frame em que é armada,
## o que mantém a janela de parry exata.

signal hit_landed(hurtbox: Hurtbox, info: DamageInfo)

var is_armed: bool:
	get:
		return _info != null

var _info: DamageInfo
var _already_hit: Array[Hurtbox] = []


func _ready() -> void:
	monitoring = true
	monitorable = false
	area_entered.connect(_try_hit)


func arm(info: DamageInfo) -> void:
	_info = info
	_already_hit.clear()
	for area: Area3D in get_overlapping_areas():
		_try_hit(area)


func disarm() -> void:
	_info = null
	_already_hit.clear()


func _try_hit(area: Area3D) -> void:
	if _info == null:
		return
	var hurtbox := area as Hurtbox
	if hurtbox == null or hurtbox in _already_hit:
		return
	_already_hit.append(hurtbox)
	var info := _info.copy()
	hurtbox.receive_hit(info)
	# Emitido depois, para o defensor já ter marcado contra-ataque/elemento no info.
	hit_landed.emit(hurtbox, info)
