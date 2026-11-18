class_name Obstacle
extends Node3D

enum ObstacleType {
	CONE,
	TIRE_STACK,
	BARRIER,
	CRATE
}

@export var obstacle_type: ObstacleType = ObstacleType.CONE
@export var speed_loss: float = 0.20
@export var knockback_force: float = 4.0
@export var camera_shake: float = 0.25
@export var hit_cooldown_time: float = 0.6

var _cooldown := 0.0
var _visual_mesh: Node3D
var _wobble_time := 0.0
var _is_wobbling := false

func _ready() -> void:
	_configure_defaults()
	_visual_mesh = get_node_or_null("Visual") as Node3D
	var area := get_node_or_null("HitArea") as Area3D
	if area != null:
		area.body_entered.connect(_on_body_entered)

func _configure_defaults() -> void:
	match obstacle_type:
		ObstacleType.CONE:
			speed_loss = 0.15
			knockback_force = 3.0
			camera_shake = 0.20
		ObstacleType.TIRE_STACK:
			speed_loss = 0.35
			knockback_force = 6.0
			camera_shake = 0.40
		ObstacleType.BARRIER:
			speed_loss = 0.50
			knockback_force = 7.5
			camera_shake = 0.55
		ObstacleType.CRATE:
			speed_loss = 0.45
			knockback_force = 6.5
			camera_shake = 0.45

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown = maxf(0.0, _cooldown - delta)

	if _is_wobbling and _visual_mesh != null:
		_wobble_time += delta * 20.0
		var damp := exp(-_wobble_time * 0.15)
		_visual_mesh.rotation.z = sin(_wobble_time) * 0.25 * damp
		if damp < 0.02:
			_is_wobbling = false
			_visual_mesh.rotation.z = 0.0

func _on_body_entered(body: Node) -> void:
	if _cooldown > 0.0:
		return
	if not body.has_method("apply_obstacle_impact"):
		return

	_cooldown = hit_cooldown_time
	_is_wobbling = true
	_wobble_time = 0.0

	var hit_pos: Vector3 = body.global_position
	var diff := hit_pos - global_position
	diff.y = 0.0
	var knockback_dir := diff.normalized()
	if knockback_dir.length_squared() < 0.001:
		knockback_dir = -body.global_transform.basis.z

	var knockback_impulse := knockback_dir * knockback_force
	body.apply_obstacle_impact(speed_loss, knockback_impulse)

	var cam := get_viewport().get_camera_3d()
	if cam != null and cam.has_method("apply_shake"):
		cam.apply_shake(camera_shake)

	_spawn_impact_particles(global_position + Vector3.UP * 0.4)

func _spawn_impact_particles(pos: Vector3) -> void:
	# Small visual impact burst
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.4, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.2)
	mat.emission_energy_multiplier = 2.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.mesh = sphere
	flash.material_override = mat
	get_parent().add_child(flash)
	flash.global_position = pos

	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3(1.8, 1.8, 1.8), 0.18)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.18)
	tween.tween_callback(flash.queue_free)
