class_name PlayerKart
extends CharacterBody3D

@export var max_forward_speed := 36.0
@export var max_reverse_speed := 10.0
@export var acceleration := 13.0
@export var launch_boost_factor := 1.18
@export var launch_boost_threshold := 8.5
@export var brake_deceleration := 24.0
@export var coast_deceleration := 4.5
@export var reverse_acceleration := 12.0
@export var reverse_engage_speed := 0.5

@export var turn_rate := 2.6
@export var steering_full_speed := 14.0
@export var steering_min_factor := 0.42
@export var lateral_grip := 18.0
@export var max_lateral_slip := 3.5
@export var turn_drag := 0.35
@export var sharp_steer_threshold := 0.88

@export var suspension_spring_stiffness := 20.0
@export var suspension_damping := 8.5
@export var max_body_pitch := 0.09
@export var max_body_roll := 0.13

@export var collision_speed_loss := 0.35
@export var collision_reference_speed := 18.0

@export var off_road_speed_multiplier := 0.48
@export var off_road_drag := 5.0
@export var road_edge_margin := 0.35
@export var road_data_path := "res://Game/Assets/enviroment/Tracks/KartRing/KartRing.json"
@export var road_reference_path: NodePath
@export var road_width := 8.0
@export var ground_height := 0.0

@onready var nitro: NitroController = $NitroController

var _road_surface := RoadSurface.new()
var _road_reference: Node3D
var _spawn_transform: Transform3D
var _forward_speed := 0.0
var _lateral_speed := 0.0
var _steer_input := 0.0
var _throttle_input := 0.0
var _surface_speed_multiplier := 1.0
var _is_on_road := true
var _intended_velocity := Vector3.ZERO
var _controls_enabled := true
var _respawn_cooldown := 0.0

# Chassis Suspension simulation
var _body_pitch := 0.0
var _body_pitch_velocity := 0.0
var _body_roll := 0.0
var _body_roll_velocity := 0.0
var _suspension_time := 0.0
var _bounce_offset := 0.0

# Visual feedback nodes
var _wheel_fl: Node3D
var _wheel_fr: Node3D
var _spin_fl: Node3D
var _spin_fr: Node3D
var _spin_rl: Node3D
var _spin_rr: Node3D
var _body_node: Node3D
var _wheel_spin_angle := 0.0
var _tire_smoke_timer := 0.0

var audio_manager: Node

func _ready() -> void:
	_spawn_transform = global_transform
	_road_surface.load_from_json(road_data_path, road_width)
	if road_reference_path != NodePath(""):
		_road_reference = get_node_or_null(road_reference_path) as Node3D
	if _road_reference == null and get_parent() != null:
		_road_reference = get_parent().get_node_or_null("KartRing") as Node3D

	if nitro == null:
		nitro = get_node_or_null("NitroController") as NitroController

	if nitro != null:
		if not nitro.activated.is_connected(_on_nitro_activated):
			nitro.activated.connect(_on_nitro_activated)
		if not nitro.deactivated.is_connected(_on_nitro_deactivated):
			nitro.deactivated.connect(_on_nitro_deactivated)

	_cache_visual_nodes()

func _cache_visual_nodes() -> void:
	_wheel_fl = find_child("Wheel_FL", true, false) as Node3D
	_wheel_fr = find_child("Wheel_FR", true, false) as Node3D
	_spin_fl = find_child("Wheel_FL_Spin", true, false) as Node3D
	_spin_fr = find_child("Wheel_FR_Spin", true, false) as Node3D
	_spin_rl = find_child("Wheel_RL_Spin", true, false) as Node3D
	_spin_rr = find_child("Wheel_RR_Spin", true, false) as Node3D
	_body_node = find_child("Body", true, false) as Node3D

func _physics_process(delta: float) -> void:
	if _respawn_cooldown > 0.0:
		_respawn_cooldown = maxf(0.0, _respawn_cooldown - delta)
		if _respawn_cooldown == 0.0:
			_controls_enabled = true

	if not _controls_enabled:
		_apply_locked_controls(delta)
		_update_suspension(delta, 0.0, 0.0)
		_animate_wheels(delta)
		_update_audio(0.0)
		return

	_update_road_surface()
	_read_inputs()
	_update_steering_rotation(delta)
	_update_speed(delta)
	_update_nitro(delta)
	_apply_velocity(delta)
	_move_kart(delta)
	_update_suspension(delta, _throttle_input, _steer_input)
	_animate_wheels(delta)
	_update_tire_effects(delta)
	_update_audio(_throttle_input)

func _apply_locked_controls(delta: float) -> void:
	_forward_speed = move_toward(_forward_speed, 0.0, coast_deceleration * 3.0 * delta)
	_lateral_speed = move_toward(_lateral_speed, 0.0, lateral_grip * delta)
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	velocity = forward * _forward_speed + right * _lateral_speed

	if global_position.y > ground_height:
		velocity.y -= 25.0 * delta
		global_position.y = maxf(ground_height, global_position.y + velocity.y * delta)
	else:
		velocity.y = 0.0
		global_position.y = ground_height

	move_and_slide()

func _update_road_surface() -> void:
	var query_position := global_position
	if _road_reference != null:
		query_position = _road_reference.to_local(global_position)
	var info := _road_surface.road_info(query_position)
	_is_on_road = info["on_road"] or info["distance"] <= info["half_width"] + road_edge_margin
	_surface_speed_multiplier = 1.0 if _is_on_road else off_road_speed_multiplier

func _read_inputs() -> void:
	_steer_input = clampf(
		Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left"),
		-1.0,
		1.0
	)
	var accel := Input.get_action_strength("accelerate")
	var brk := Input.get_action_strength("brake")
	_throttle_input = accel - brk

func _update_steering_rotation(delta: float) -> void:
	if absf(_forward_speed) < 0.3:
		return
	# Beach Buggy dynamic steering curve: snappy at low/mid speed, rock-solid at top speed
	var speed_ratio := clampf(absf(_forward_speed) / steering_full_speed, 0.0, 1.0)
	var speed_factor := lerpf(1.0, steering_min_factor, speed_ratio * 0.75)
	var turn_direction := -_steer_input
	rotate_y(turn_direction * turn_rate * speed_factor * delta)

func _update_speed(delta: float) -> void:
	var accelerating := Input.is_action_pressed("accelerate")
	var braking := Input.is_action_pressed("brake")

	if braking:
		if _forward_speed > reverse_engage_speed:
			_forward_speed = move_toward(_forward_speed, 0.0, brake_deceleration * delta)
		else:
			_forward_speed = move_toward(_forward_speed, -max_reverse_speed, reverse_acceleration * delta)
	elif accelerating:
		var effective_max := _effective_max_speed()
		# Beach Buggy non-linear power curve: punchy torque boost off the line
		var current_speed_ratio := clampf(maxf(0.0, _forward_speed) / max_forward_speed, 0.0, 1.0)
		var torque_multiplier := 1.0
		if _forward_speed < launch_boost_threshold:
			torque_multiplier = lerpf(launch_boost_factor, 1.0, _forward_speed / launch_boost_threshold)
		# Top-end acceleration taper for realistic weight
		var top_end_taper := clampf(1.0 - pow(current_speed_ratio, 2.5), 0.15, 1.0)
		var rate := acceleration * torque_multiplier * top_end_taper * _nitro_acceleration_multiplier()
		_forward_speed = move_toward(_forward_speed, effective_max, rate * delta)
	else:
		# Natural aerodynamic coasting
		_forward_speed = move_toward(_forward_speed, 0.0, coast_deceleration * delta)
		_forward_speed *= (1.0 - 0.08 * delta)

	if not _is_on_road:
		_forward_speed = move_toward(_forward_speed, 0.0, off_road_drag * delta)
	if absf(_steer_input) > sharp_steer_threshold and absf(_forward_speed) > steering_full_speed * 0.5:
		_forward_speed = move_toward(_forward_speed, 0.0, turn_drag * delta)

func _update_nitro(delta: float) -> void:
	if nitro == null:
		return
	if Input.is_action_just_pressed("nitro") or (Input.is_action_pressed("nitro") and nitro.is_ready() and not nitro.is_active()):
		nitro.try_activate(_forward_speed)
	nitro.update(delta)

func _apply_velocity(delta: float) -> void:
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x

	# Beach Buggy controlled lateral slip during aggressive turns
	var target_slip := 0.0
	if absf(_steer_input) > 0.1 and absf(_forward_speed) > 10.0:
		var speed_ratio := clampf(absf(_forward_speed) / max_forward_speed, 0.0, 1.0)
		target_slip = -_steer_input * max_lateral_slip * speed_ratio
	_lateral_speed = move_toward(_lateral_speed, target_slip, lateral_grip * delta)

	if global_position.y < ground_height - 0.2:
		velocity.y -= 25.0 * delta
		global_position.y += velocity.y * delta
	else:
		velocity.y = 0.0
		global_position.y = ground_height

	velocity.x = forward.x * _forward_speed + right.x * _lateral_speed
	velocity.z = forward.z * _forward_speed + right.z * _lateral_speed
	_intended_velocity = velocity

func _move_kart(delta: float) -> void:
	move_and_slide()

	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var impact_speed := maxf(0.0, -_intended_velocity.dot(collision.get_normal()))
		var impact := clampf(impact_speed / collision_reference_speed, 0.0, 1.0)
		var loss := collision_speed_loss * impact
		_forward_speed *= (1.0 - loss)
		_lateral_speed *= (1.0 - loss * 0.5)

func _update_suspension(delta: float, throttle: float, steer: float) -> void:
	if _body_node == null:
		return

	# Target Pitch: Squat on launch/accel, Dive on heavy braking
	# In Body (child of 90-deg rotated model), pitch rotates around local Z axis
	var target_pitch := 0.0
	if throttle > 0.1:
		target_pitch = max_body_pitch * clampf(throttle, 0.0, 1.0)
		if is_nitro_active():
			target_pitch *= 1.45 # Extra punchy squat on boost!
	elif throttle < -0.1:
		target_pitch = -max_body_pitch * 1.15 * clampf(-throttle, 0.0, 1.0)

	# Harmonic Spring Pitch
	var pitch_force := (target_pitch - _body_pitch) * suspension_spring_stiffness
	_body_pitch_velocity += pitch_force * delta
	_body_pitch_velocity *= exp(-suspension_damping * delta)
	_body_pitch += _body_pitch_velocity * delta

	# Target Roll: Chassis rolls with cornering force
	# In Body, roll rotates around local X axis
	var speed_factor := clampf(absf(_forward_speed) / 18.0, 0.0, 1.0)
	var target_roll := -steer * max_body_roll * speed_factor

	# Harmonic Spring Roll
	var roll_force := (target_roll - _body_roll) * suspension_spring_stiffness
	_body_roll_velocity += roll_force * delta
	_body_roll_velocity *= exp(-suspension_damping * delta)
	_body_roll += _body_roll_velocity * delta

	# Road Micro-vibrations & Buggy Terrain Bounce
	_suspension_time += delta * (22.0 + absf(_forward_speed) * 0.5)
	var bounce_amplitude := 0.012 if _is_on_road else 0.038
	_bounce_offset = sin(_suspension_time) * bounce_amplitude * speed_factor

	# Apply to visual chassis node
	# X is roll (tilting left/right), Z is pitch (tilting front/back)
	_body_node.rotation.x = _body_roll
	_body_node.rotation.z = _body_pitch
	_body_node.position.y = _bounce_offset

func _animate_wheels(delta: float) -> void:
	var steer_target := -_steer_input * deg_to_rad(24.0)
	if _wheel_fl:
		_wheel_fl.rotation.y = lerpf(_wheel_fl.rotation.y, steer_target, 16.0 * delta)
	if _wheel_fr:
		_wheel_fr.rotation.y = lerpf(_wheel_fr.rotation.y, steer_target, 16.0 * delta)

	# Dynamic Wheel Camber on hard cornering
	var camber_tilt := -_steer_input * 0.04
	if _wheel_fl:
		_wheel_fl.rotation.x = camber_tilt
	if _wheel_fr:
		_wheel_fr.rotation.x = camber_tilt

	# Rolling wheel spin
	var spin_rate := (_forward_speed / 0.35) * delta
	_wheel_spin_angle += spin_rate
	for spin_node in [_spin_fl, _spin_fr, _spin_rl, _spin_rr]:
		if spin_node:
			spin_node.rotation.z = _wheel_spin_angle

func _update_tire_effects(delta: float) -> void:
	# Tire smoke / screech intensity during burnout or hard slip
	var slip_intensity := absf(_lateral_speed) / max_lateral_slip
	var burnout_intensity := 0.0
	if Input.is_action_pressed("accelerate") and absf(_forward_speed) < 6.0:
		burnout_intensity = 0.6

	var total_skid := maxf(slip_intensity, burnout_intensity)
	if audio_manager != null and audio_manager.has_method("set_tire_skid"):
		audio_manager.set_tire_skid(total_skid)

	# Visual tire dust/smoke puffs
	if total_skid > 0.45 or not _is_on_road:
		_tire_smoke_timer += delta
		if _tire_smoke_timer > 0.08:
			_tire_smoke_timer = 0.0
			_spawn_wheel_dust()

func _spawn_wheel_dust() -> void:
	var rear_left := global_position - global_transform.basis.z * 1.3 - global_transform.basis.x * 0.8
	var rear_right := global_position - global_transform.basis.z * 1.3 + global_transform.basis.x * 0.8
	for pos in [rear_left, rear_right]:
		var puff := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.22
		s.height = 0.44
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.82, 0.75, 0.45) if _is_on_road else Color(0.65, 0.50, 0.32, 0.6)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		puff.mesh = s
		puff.material_override = mat
		get_parent().add_child(puff)
		puff.global_position = pos + Vector3.UP * 0.15

		var tween := puff.create_tween()
		tween.tween_property(puff, "scale", Vector3(1.8, 1.8, 1.8), 0.25)
		tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.25)
		tween.tween_callback(puff.queue_free)

func _update_audio(throttle: float) -> void:
	if audio_manager == null or not audio_manager.has_method("set_engine_state"):
		return
	var speed_ratio := clampf(absf(_forward_speed) / max_forward_speed, 0.0, 1.3)
	audio_manager.set_engine_state(speed_ratio, maxf(0.0, throttle))

func apply_obstacle_impact(speed_loss_ratio: float, knockback_impulse: Vector3) -> void:
	_forward_speed *= clampf(1.0 - speed_loss_ratio, 0.0, 1.0)
	_lateral_speed *= 0.5
	velocity += knockback_impulse
	_body_pitch_velocity += 1.5 * speed_loss_ratio
	if audio_manager != null and audio_manager.has_method("play_impact"):
		audio_manager.play_impact(speed_loss_ratio > 0.3)

func respawn_at(target_transform: Transform3D) -> void:
	_controls_enabled = false
	_respawn_cooldown = 0.45
	global_transform.basis = target_transform.basis
	var spawn_pos := target_transform.origin
	spawn_pos.y = ground_height + 0.65 # Hover drop for suspension landing bounce
	global_position = spawn_pos
	velocity = Vector3.ZERO
	_forward_speed = 0.0
	_lateral_speed = 0.0
	_intended_velocity = Vector3.ZERO
	_body_pitch = 0.0
	_body_pitch_velocity = 0.0
	_body_roll = 0.0
	_body_roll_velocity = 0.0
	if nitro != null and nitro.is_active():
		nitro.reset()

	_spawn_respawn_vfx(target_transform.origin)

func _spawn_respawn_vfx(ground_pos: Vector3) -> void:
	# 1. Holographic Quantum Landing Ring on track surface
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.3
	torus.outer_radius = 1.7
	torus.rings = 20
	torus.ring_segments = 8

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.1, 0.9, 1.0, 0.85)

	ring.mesh = torus
	ring.material_override = mat
	ring.rotation_degrees = Vector3(90, 0, 0)
	get_parent().add_child(ring)
	ring.global_position = Vector3(ground_pos.x, ground_height + 0.04, ground_pos.z)

	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3(2.2, 2.2, 2.2), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tween.tween_callback(ring.queue_free)

	# 2. Cyan Energy Spark Dispersal
	for i in range(12):
		var angle := randf() * TAU
		var offset := Vector3(cos(angle) * 1.0, 0.1, sin(angle) * 1.0)
		var spark := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.08, 0.08, 0.08)
		var spark_mat := StandardMaterial3D.new()
		spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		spark_mat.albedo_color = Color(0.3, 0.95, 1.0, 0.9)
		spark.mesh = box
		spark.material_override = spark_mat
		get_parent().add_child(spark)
		spark.global_position = ground_pos + offset

		var s_tween := spark.create_tween()
		var target_pos := spark.global_position + Vector3(cos(angle) * 1.8, randf_range(0.4, 1.1), sin(angle) * 1.8)
		s_tween.tween_property(spark, "global_position", target_pos, 0.4)
		s_tween.parallel().tween_property(spark_mat, "albedo_color:a", 0.0, 0.4)
		s_tween.tween_callback(spark.queue_free)

func reset_to_transform(t: Transform3D) -> void:
	global_transform = t
	global_position.y = ground_height
	velocity = Vector3.ZERO
	_forward_speed = 0.0
	_lateral_speed = 0.0
	_intended_velocity = Vector3.ZERO
	_body_pitch = 0.0
	_body_pitch_velocity = 0.0
	_body_roll = 0.0
	_body_roll_velocity = 0.0
	if nitro != null:
		nitro.reset()

func set_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	if not enabled:
		_forward_speed = 0.0
		_lateral_speed = 0.0
		velocity = Vector3.ZERO

func _effective_max_speed() -> float:
	var n_mult := nitro.speed_multiplier_value() if nitro != null else 1.0
	return max_forward_speed * _surface_speed_multiplier * n_mult

func _nitro_acceleration_multiplier() -> float:
	return nitro.acceleration_multiplier_value() if nitro != null else 1.0

func _on_nitro_activated() -> void:
	_body_pitch_velocity -= 1.8 # Dramatic backward kick on boost
	if audio_manager != null and audio_manager.has_method("play_nitro"):
		audio_manager.play_nitro()

func _on_nitro_deactivated() -> void:
	if audio_manager != null and audio_manager.has_method("stop_nitro"):
		audio_manager.stop_nitro()

func is_on_road() -> bool:
	return _is_on_road

func forward_speed() -> float:
	return _forward_speed

func is_nitro_active() -> bool:
	return nitro != null and nitro.is_active()
