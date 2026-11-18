class_name NitroController
extends Node

signal activated
signal deactivated
signal charge_changed(current_charge: float, max_charge: float)

@export var max_charge := 100.0
@export var initial_charge := 100.0
@export var burst_cost := 25.0
@export var duration := 1.3
@export var cooldown := 0.35
@export var speed_multiplier := 1.45
@export var acceleration_multiplier := 1.75
@export var min_speed_to_activate := 1.0

var current_charge := 100.0
var _time_left := 0.0
var _cooldown_left := 0.0

func _ready() -> void:
	current_charge = initial_charge
	charge_changed.emit(current_charge, max_charge)

func try_activate(current_speed: float = 0.0) -> bool:
	if _time_left > 0.0 or _cooldown_left > 0.0:
		return false
	if current_charge < burst_cost:
		return false
	if absf(current_speed) < min_speed_to_activate:
		return false

	current_charge = maxf(0.0, current_charge - burst_cost)
	_time_left = duration
	_cooldown_left = cooldown + duration
	charge_changed.emit(current_charge, max_charge)
	activated.emit()
	return true

func add_charge(amount: float) -> void:
	if amount <= 0.0:
		return
	current_charge = clampf(current_charge + amount, 0.0, max_charge)
	charge_changed.emit(current_charge, max_charge)

func update(delta: float) -> void:
	if _time_left > 0.0:
		_time_left = maxf(0.0, _time_left - delta)
		if _time_left == 0.0:
			deactivated.emit()

	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)

func is_active() -> bool:
	return _time_left > 0.0

func is_ready() -> bool:
	return _time_left <= 0.0 and _cooldown_left <= 0.0 and current_charge >= burst_cost

func speed_multiplier_value() -> float:
	return speed_multiplier if is_active() else 1.0

func acceleration_multiplier_value() -> float:
	return acceleration_multiplier if is_active() else 1.0

func charge_ratio() -> float:
	return 0.0 if max_charge <= 0.0 else clampf(current_charge / max_charge, 0.0, 1.0)

func reset() -> void:
	var was_active := is_active()
	_time_left = 0.0
	_cooldown_left = 0.0
	current_charge = initial_charge
	if was_active:
		deactivated.emit()
	charge_changed.emit(current_charge, max_charge)
