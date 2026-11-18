class_name NitroEffect
extends Node3D

@export var flicker_speed := 22.0
@export var min_scale := 0.8
@export var max_scale := 1.4

var _controller: NitroController
var _flames: Array[MeshInstance3D] = []
var _particles: Array[GPUParticles3D] = []
var _active := false
var _time := 0.0

func _ready() -> void:
	_controller = get_parent().get_node_or_null("NitroController") as NitroController
	for child in get_children():
		if child is MeshInstance3D:
			_flames.append(child)
			child.visible = false
		elif child is GPUParticles3D:
			_particles.append(child)
			child.emitting = false

	if _controller != null:
		_controller.activated.connect(_on_activated)
		_controller.deactivated.connect(_on_deactivated)

func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	var pulse := lerpf(min_scale, max_scale, 0.5 + 0.5 * sin(_time * flicker_speed))
	var flicker_x := 0.9 + 0.2 * randf()
	for flame in _flames:
		flame.scale = Vector3(flicker_x, flicker_x, pulse)

func _on_activated() -> void:
	_active = true
	_time = 0.0
	for flame in _flames:
		flame.visible = true
	for p in _particles:
		p.emitting = true

func _on_deactivated() -> void:
	_active = false
	for flame in _flames:
		flame.visible = false
	for p in _particles:
		p.emitting = false
