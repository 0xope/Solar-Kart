class_name Collectible
extends Node3D

enum CollectibleType {
	SOLAR_COIN,
	NITRO_CELL
}

@export var collectible_type: CollectibleType = CollectibleType.SOLAR_COIN
@export var nitro_restore_amount: float = 35.0
@export var float_speed: float = 3.5
@export var float_height: float = 0.18
@export var rotate_speed: float = 3.0

var _collected := false
var _time := 0.0
var _base_y := 0.0
var _visual: Node3D
var _collision_shape: CollisionShape3D

func _ready() -> void:
	_visual = get_node_or_null("Visual") as Node3D
	if _visual != null:
		_base_y = _visual.position.y

	var area := get_node_or_null("Area3D") as Area3D
	if area != null:
		area.body_entered.connect(_on_body_entered)
		_collision_shape = area.get_node_or_null("CollisionShape3D") as CollisionShape3D

func _process(delta: float) -> void:
	if _collected or _visual == null:
		return

	_time += delta
	_visual.position.y = _base_y + sin(_time * float_speed) * float_height
	_visual.rotate_y(rotate_speed * delta)

func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if not body.has_method("forward_speed") and not "nitro" in body:
		return

	_collected = true
	if _visual != null:
		_visual.visible = false
	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", true)

	var audio: Node = body.get("audio_manager") if "audio_manager" in body else null

	if collectible_type == CollectibleType.SOLAR_COIN:
		var rm := _find_race_manager()
		if rm != null and rm.has_method("add_coin"):
			rm.add_coin()
		if audio != null and audio.has_method("play_coin"):
			audio.play_coin()
		_spawn_pickup_burst(global_position + Vector3.UP * 0.5, Color(1.0, 0.85, 0.15))
	elif collectible_type == CollectibleType.NITRO_CELL:
		var nitro_ctrl: Node = body.get("nitro") if "nitro" in body else null
		if nitro_ctrl != null and nitro_ctrl.has_method("add_charge"):
			nitro_ctrl.add_charge(nitro_restore_amount)
		if audio != null and audio.has_method("play_nitro_cell"):
			audio.play_nitro_cell()
		_spawn_pickup_burst(global_position + Vector3.UP * 0.5, Color(0.2, 0.85, 1.0))

func reset_collectible() -> void:
	_collected = false
	if _visual != null:
		_visual.visible = true
	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", false)

func _find_race_manager() -> Node:
	return get_tree().root.find_child("RaceManager", true, false)

func _spawn_pickup_burst(pos: Vector3, color: Color) -> void:
	var burst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	burst.mesh = sphere
	burst.material_override = mat
	get_parent().add_child(burst)
	burst.global_position = pos

	var tween := burst.create_tween()
	tween.tween_property(burst, "scale", Vector3(2.2, 2.2, 2.2), 0.22)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.22)
	tween.tween_callback(burst.queue_free)
