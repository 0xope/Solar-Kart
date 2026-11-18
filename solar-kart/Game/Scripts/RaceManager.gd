class_name RaceManager
extends Node

const CheckpointScript = preload("res://Game/Scripts/Checkpoint.gd")

signal countdown_tick(count_text: String)
signal race_started
signal lap_completed(current_lap: int, total_laps: int)
signal race_finished(final_time: float)
signal coins_changed(count: int)
signal checkpoint_passed(index: int, total: int)
signal respawn_triggered
signal out_of_bounds_tick(remaining_seconds: float, is_active: bool)

enum RaceState {
	COUNTDOWN,
	RACING,
	RESPAWNING,
	FINISHED
}

@export var total_laps := 3
@export var track_json_path := "res://Game/Assets/enviroment/Tracks/KartRing/KartRing.json"
@export var road_reference_path: NodePath = NodePath("../KartRing")
@export var fall_height_threshold := -4.0
@export var max_offroad_distance := 6.8
@export var out_of_bounds_time_limit := 2.0

var state: RaceState = RaceState.COUNTDOWN
var current_lap := 1
var race_time := 0.0
var coins := 0

var _kart: Node3D
var _camera: Node3D
var _audio: Node
var _road_surface: RoadSurface
var _road_reference: Node3D
var _next_checkpoint := 0
var _total_checkpoints := 8
var _last_valid_respawn_transform: Transform3D
var _start_grid_transform: Transform3D

var _countdown_timer := 3.5
var _last_countdown_display := ""
var _oob_timer := 2.0
var _is_out_of_bounds := false
var _oob_sound_timer := 0.0
var _checkpoints_container: Node3D
var _collectibles_container: Node3D

func _ready() -> void:
	_road_surface = RoadSurface.new()
	_road_surface.load_from_json(track_json_path, 8.0)
	call_deferred("_initialize_race")

func _initialize_race() -> void:
	if road_reference_path != NodePath(""):
		_road_reference = get_node_or_null(road_reference_path) as Node3D
	if _road_reference == null:
		_road_reference = get_tree().root.find_child("KartRing", true, false) as Node3D

	_kart = get_tree().root.find_child("PlayerKart", true, false) as Node3D
	_camera = get_tree().root.find_child("ThirdPersonCamera", true, false) as Node3D
	_audio = get_tree().root.find_child("ArcadeAudio", true, false)

	if _kart != null:
		_start_grid_transform = _kart.global_transform
		_last_valid_respawn_transform = _start_grid_transform
		if _kart.has_method("set_controls_enabled"):
			_kart.set_controls_enabled(false)
		if _audio != null and "audio_manager" in _kart:
			_kart.audio_manager = _audio

	_setup_checkpoints()
	_start_countdown()

func _setup_checkpoints() -> void:
	var TrackRaceDataScript = load("res://Game/Scripts/TrackRaceData.gd")
	var track_data = TrackRaceDataScript.new()
	var ok: bool = false
	ok = track_data.load_from_json(track_json_path, 8.0, _road_reference)
	if not ok or track_data.checkpoint_count() == 0:
		return

	_total_checkpoints = track_data.checkpoint_count()
	_checkpoints_container = Node3D.new()
	_checkpoints_container.name = "CheckpointsContainer"
	get_parent().add_child(_checkpoints_container)

	for i in range(_total_checkpoints):
		var cp: Area3D = CheckpointScript.new()
		cp.name = "Checkpoint_%d" % i
		cp.set("checkpoint_index", i)
		_checkpoints_container.add_child(cp)

		var t: Transform3D = track_data.checkpoint_transform(i)
		cp.global_transform = t

		var area_shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(18.0, 6.0, 6.0)
		area_shape.shape = box
		area_shape.position = Vector3(0, 3.0, 0)
		cp.add_child(area_shape)
		cp.passed.connect(_on_checkpoint_passed)

func _start_countdown() -> void:
	state = RaceState.COUNTDOWN
	current_lap = 1
	race_time = 0.0
	_next_checkpoint = 0
	_countdown_timer = 3.6
	_last_countdown_display = ""
	_oob_timer = out_of_bounds_time_limit
	_is_out_of_bounds = false

	if _kart != null and _kart.has_method("set_controls_enabled"):
		_kart.set_controls_enabled(false)

	lap_completed.emit(current_lap, total_laps)
	coins_changed.emit(coins)

func _process(delta: float) -> void:
	match state:
		RaceState.COUNTDOWN:
			_process_countdown(delta)
		RaceState.FINISHED:
			if Input.is_action_just_pressed("reset_kart") or Input.is_key_pressed(KEY_R) or Input.is_key_pressed(KEY_ENTER):
				restart_race()

func _physics_process(delta: float) -> void:
	if state == RaceState.RACING:
		_process_racing(delta)

func _process_countdown(delta: float) -> void:
	_countdown_timer -= delta
	var display_text := ""
	if _countdown_timer > 2.0:
		display_text = "3"
	elif _countdown_timer > 1.0:
		display_text = "2"
	elif _countdown_timer > 0.0:
		display_text = "1"
	else:
		display_text = "GO!"

	if display_text != _last_countdown_display:
		_last_countdown_display = display_text
		countdown_tick.emit(display_text)
		if _audio != null:
			if display_text == "GO!":
				_audio.play_countdown_go()
			else:
				_audio.play_countdown_beep()

	if _countdown_timer <= -0.6:
		state = RaceState.RACING
		if _kart != null and _kart.has_method("set_controls_enabled"):
			_kart.set_controls_enabled(true)
		race_started.emit()

func _process_racing(delta: float) -> void:
	race_time += delta

	if _kart == null:
		return

	# Out of bounds check 1: Deep fall off track (instant void respawn)
	if _kart.global_position.y < fall_height_threshold:
		trigger_respawn()
		return

	# Out of bounds check 2: 2-second countdown when leaving track bounds
	var query_pos := _kart.global_position
	if _road_reference != null:
		query_pos = _road_reference.to_local(query_pos)
	var info := _road_surface.road_info(query_pos)
	var dist: float = float(info.get("distance", 0.0))

	# Out of bounds if distance > max_offroad_distance or dropped off road deck
	var is_oob: bool = dist > max_offroad_distance or _kart.global_position.y < -1.0

	if is_oob:
		if not _is_out_of_bounds:
			_is_out_of_bounds = true
			_oob_timer = out_of_bounds_time_limit
			_oob_sound_timer = 0.0

		_oob_timer = maxf(0.0, _oob_timer - delta)
		out_of_bounds_tick.emit(_oob_timer, true)

		_oob_sound_timer -= delta
		if _oob_sound_timer <= 0.0:
			_oob_sound_timer = 0.45
			if _audio != null and _audio.has_method("play_oob_warning"):
				_audio.play_oob_warning()

		if _oob_timer <= 0.0:
			_is_out_of_bounds = false
			out_of_bounds_tick.emit(0.0, false)
			trigger_respawn()
			return
	else:
		if _is_out_of_bounds:
			_is_out_of_bounds = false
			_oob_timer = out_of_bounds_time_limit
			out_of_bounds_tick.emit(0.0, false)

func _on_checkpoint_passed(index: int, cp_transform: Transform3D) -> void:
	if state != RaceState.RACING:
		return

	if index == _next_checkpoint:
		_last_valid_respawn_transform = cp_transform
		checkpoint_passed.emit(index, _total_checkpoints)

		if index == 0 and _next_checkpoint == 0:
			# Crossed start line towards checkpoint 1
			_next_checkpoint = 1
		else:
			_next_checkpoint = (_next_checkpoint + 1) % _total_checkpoints
			if _next_checkpoint == 0:
				# Completed a full lap around all checkpoints!
				current_lap += 1
				if current_lap > total_laps:
					_finish_race()
				else:
					lap_completed.emit(current_lap, total_laps)
					_next_checkpoint = 1

func _finish_race() -> void:
	state = RaceState.FINISHED
	_is_out_of_bounds = false
	out_of_bounds_tick.emit(0.0, false)
	if _kart != null and _kart.has_method("set_controls_enabled"):
		_kart.set_controls_enabled(false)
	race_finished.emit(race_time)

func trigger_respawn() -> void:
	if state != RaceState.RACING:
		return

	state = RaceState.RESPAWNING
	_is_out_of_bounds = false
	_oob_timer = out_of_bounds_time_limit
	out_of_bounds_tick.emit(0.0, false)
	respawn_triggered.emit()

	if _audio != null and _audio.has_method("play_teleport_whoosh"):
		_audio.play_teleport_whoosh()

	if _kart != null and _kart.has_method("respawn_at"):
		_kart.respawn_at(_last_valid_respawn_transform)

	# Smooth AAA respawn transition before restoring controls
	get_tree().create_timer(0.45).timeout.connect(func():
		if state == RaceState.RESPAWNING:
			state = RaceState.RACING
			if _audio != null and _audio.has_method("play_teleport_drop"):
				_audio.play_teleport_drop()
			if _kart != null and _kart.has_method("set_controls_enabled"):
				_kart.set_controls_enabled(true)
	)

func restart_race() -> void:
	if _kart != null and _kart.has_method("reset_to_transform"):
		_kart.reset_to_transform(_start_grid_transform)

	coins = 0
	coins_changed.emit(coins)

	# Reset all collectibles on track
	var collectibles := get_tree().root.find_children("*", "Collectible", true, false)
	for c in collectibles:
		if c.has_method("reset_collectible"):
			c.reset_collectible()

	_last_valid_respawn_transform = _start_grid_transform
	_start_countdown()

func add_coin() -> void:
	coins += 1
	coins_changed.emit(coins)
