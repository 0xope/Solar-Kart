class_name ThirdPersonCamera
extends Camera3D

@export var target_path: NodePath

@export var min_distance := 6.6
@export var max_distance := 8.6
@export var boost_distance := 10.2

@export var min_height := 2.4
@export var max_height := 3.1
@export var look_height := 0.85
@export var look_ahead := 4.0
@export var follow_speed := 9.5
@export var turn_swing_lag := 0.28

@export var base_fov := 76.0
@export var max_speed_fov := 84.0
@export var nitro_fov := 92.0

@export var max_trauma := 1.0
@export var trauma_decay := 2.5
@export var max_shake_offset := Vector3(0.35, 0.25, 0.2)
@export var max_shake_roll := 0.05

var _target: Node3D
var _kart: Node3D
var _trauma := 0.0
var _shake_time := 0.0
var _current_look_target := Vector3.ZERO
var _current_distance := 6.8
var _current_height := 3.0
var _smooth_yaw := 0.0

func _ready() -> void:
	fov = base_fov
	if not target_path.is_empty():
		_target = get_node_or_null(target_path) as Node3D
		_kart = _target
		if _target != null:
			_snap_to_target()

func _process(delta: float) -> void:
	if _target == null:
		return

	var forward_spd: float = 0.0
	var is_boosting := false
	if _kart != null and _kart.has_method("forward_speed"):
		forward_spd = _kart.forward_speed()
		if _kart.has_method("is_nitro_active"):
			is_boosting = _kart.is_nitro_active()

	var speed_ratio := clampf(forward_spd / 36.0, 0.0, 1.3)

	# 1. Beach Buggy Dynamic FOV
	var target_fov := lerpf(base_fov, max_speed_fov, speed_ratio)
	if is_boosting:
		target_fov = nitro_fov
	fov = lerpf(fov, target_fov, 8.0 * delta)

	# 2. Dynamic Distance & Lowered Height at High Speed
	var target_dist := lerpf(min_distance, max_distance, speed_ratio)
	if is_boosting:
		target_dist = boost_distance
	_current_distance = lerpf(_current_distance, target_dist, 6.0 * delta)

	# Camera lowers at high speed for visceral ground-rush sensation
	var target_h := lerpf(max_height, min_height, speed_ratio * 0.7)
	_current_height = lerpf(_current_height, target_h, 6.0 * delta)

	# 3. High-Speed Road / Engine Vibration Shake
	var speed_vibration := 0.0
	if speed_ratio > 0.6:
		speed_vibration = (speed_ratio - 0.6) * 0.35

	# 4. Camera Shake (Impacts + High-Speed Rumble)
	var active_trauma := maxf(_trauma, speed_vibration)
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - delta * trauma_decay)
	_shake_time += delta * (25.0 + forward_spd * 0.5)

	var shake_amount := active_trauma * active_trauma
	var shake_offset := Vector3(
		sin(_shake_time * 1.3) * max_shake_offset.x * shake_amount,
		cos(_shake_time * 1.7) * max_shake_offset.y * shake_amount,
		sin(_shake_time * 0.9) * max_shake_offset.z * shake_amount
	)
	var shake_roll := sin(_shake_time * 1.1) * max_shake_roll * shake_amount

	# 5. Smooth Spring Follow with Turn Swing Lag
	var desired_pos := _calculate_desired_position() + shake_offset
	var follow_weight := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(desired_pos, follow_weight)

	_update_look_at(delta, shake_roll)

func apply_shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, max_trauma)

func _snap_to_target() -> void:
	_current_distance = min_distance
	_current_height = max_height
	global_position = _calculate_desired_position()
	_current_look_target = _calc_look_target()
	look_at(_current_look_target, Vector3.UP)

func _calculate_desired_position() -> Vector3:
	var kart_basis := _target.global_transform.basis
	var backward := kart_basis.z
	return _target.global_position + backward * _current_distance + Vector3.UP * _current_height

func _calc_look_target() -> Vector3:
	return _target.global_position + Vector3.UP * look_height - _target.global_transform.basis.z * look_ahead

func _update_look_at(delta: float, shake_roll: float) -> void:
	var target_look := _calc_look_target()
	_current_look_target = _current_look_target.lerp(target_look, 14.0 * delta)
	look_at(_current_look_target, Vector3.UP)
	if absf(shake_roll) > 0.001:
		rotation.z += shake_roll
