class_name NitroEffect
extends Node3D

@export var pulse_speed := 28.0
@export var flame_length := 1.7
@export var nozzle_spacing := 0.42

var _controller: NitroController
var _flames_outer: Array[MeshInstance3D] = []
var _flames_inner: Array[MeshInstance3D] = []
var _particles: Array[CPUParticles3D] = []
var _underglow: OmniLight3D
var _active := false
var _time := 0.0
var _shock_timer := 0.0

func _ready() -> void:
	_controller = get_parent().get_node_or_null("NitroController") as NitroController
	_clear_initial_placeholders()
	_build_aaa_nitro_vfx()

	if _controller != null:
		_controller.activated.connect(_on_activated)
		_controller.deactivated.connect(_on_deactivated)

func _clear_initial_placeholders() -> void:
	for child in get_children():
		child.queue_free()

func _build_aaa_nitro_vfx() -> void:
	# Materials
	var outer_mat := StandardMaterial3D.new()
	outer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	outer_mat.albedo_color = Color(0.08, 0.65, 1.0, 0.85) # Electric Solar Cyan
	outer_mat.emission_enabled = true
	outer_mat.emission = Color(0.0, 0.75, 1.0)
	outer_mat.emission_energy_multiplier = 4.0

	var inner_mat := StandardMaterial3D.new()
	inner_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inner_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	inner_mat.albedo_color = Color(0.92, 0.98, 1.0, 0.95) # White-hot plasma core
	inner_mat.emission_enabled = true
	inner_mat.emission = Color(0.85, 0.95, 1.0)
	inner_mat.emission_energy_multiplier = 6.0

	var particle_mat := StandardMaterial3D.new()
	particle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	particle_mat.albedo_color = Color(0.2, 0.85, 1.0, 0.9)

	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(0.12, 0.12)
	quad_mesh.material = particle_mat

	var offsets := [-nozzle_spacing, nozzle_spacing]

	for offset_x in offsets:
		var nozzle := Node3D.new()
		nozzle.name = "Nozzle_%s" % ("L" if offset_x < 0 else "R")
		nozzle.position = Vector3(offset_x, 0, 0)
		add_child(nozzle)

		# 1. Outer Supersonic Flame Cone
		var outer_mesh := CylinderMesh.new()
		outer_mesh.top_radius = 0.02
		outer_mesh.bottom_radius = 0.16
		outer_mesh.height = flame_length
		outer_mesh.radial_segments = 12

		var outer_inst := MeshInstance3D.new()
		outer_inst.mesh = outer_mesh
		outer_inst.material_override = outer_mat
		# Cylinder default is along Y; rotate 90 deg around X so bottom is forward, top is back (+Z)
		outer_inst.rotation_degrees = Vector3(-90, 0, 0)
		outer_inst.position = Vector3(0, 0, flame_length * 0.5)
		outer_inst.visible = false
		nozzle.add_child(outer_inst)
		_flames_outer.append(outer_inst)

		# 2. Inner White-Hot Plasma Core
		var inner_mesh := CylinderMesh.new()
		inner_mesh.top_radius = 0.005
		inner_mesh.bottom_radius = 0.07
		inner_mesh.height = flame_length * 1.15
		inner_mesh.radial_segments = 8

		var inner_inst := MeshInstance3D.new()
		inner_inst.mesh = inner_mesh
		inner_inst.material_override = inner_mat
		inner_inst.rotation_degrees = Vector3(-90, 0, 0)
		inner_inst.position = Vector3(0, 0, flame_length * 0.55)
		inner_inst.visible = false
		nozzle.add_child(inner_inst)
		_flames_inner.append(inner_inst)

		# 3. High-Velocity Sparks / Embers Particle Stream
		var cpu_p := CPUParticles3D.new()
		cpu_p.name = "Sparks"
		cpu_p.mesh = quad_mesh
		cpu_p.emitting = false
		cpu_p.amount = 36
		cpu_p.lifetime = 0.32
		cpu_p.speed_scale = 1.2
		cpu_p.explosiveness = 0.0
		cpu_p.randomness = 0.35
		cpu_p.direction = Vector3(0, 0, 1) # Streams straight backward (+Z)
		cpu_p.spread = 7.0
		cpu_p.initial_velocity_min = 18.0
		cpu_p.initial_velocity_max = 28.0
		cpu_p.gravity = Vector3(0, -1.5, 0)
		cpu_p.scale_amount_min = 0.7
		cpu_p.scale_amount_max = 1.4
		cpu_p.color = Color(0.3, 0.9, 1.0, 0.9)
		nozzle.add_child(cpu_p)
		_particles.append(cpu_p)

	# 4. Dynamic Neon Ground Light
	_underglow = OmniLight3D.new()
	_underglow.name = "NitroUnderglow"
	_underglow.light_color = Color(0.1, 0.82, 1.0)
	_underglow.light_energy = 0.0
	_underglow.omni_range = 6.0
	_underglow.omni_attenuation = 1.3
	_underglow.position = Vector3(0, -0.15, 0.4)
	add_child(_underglow)

func _process(delta: float) -> void:
	if not _active:
		if _underglow != null and _underglow.light_energy > 0.0:
			_underglow.light_energy = move_toward(_underglow.light_energy, 0.0, 10.0 * delta)
		return

	_time += delta
	_shock_timer += delta

	# Supersonic Flame Pulse Animation
	var pulse := 1.0 + 0.18 * sin(_time * pulse_speed)
	var jitter_x := 0.92 + 0.16 * randf()
	var jitter_y := 0.92 + 0.16 * randf()

	for flame in _flames_outer:
		flame.scale = Vector3(jitter_x, jitter_y, pulse)

	for core in _flames_inner:
		var core_pulse := 1.0 + 0.25 * sin(_time * (pulse_speed * 1.3))
		core.scale = Vector3(jitter_y * 0.9, jitter_x * 0.9, core_pulse)

	# Neon Underglow Pulsing
	if _underglow != null:
		var target_energy := 3.2 + 0.8 * sin(_time * 20.0)
		_underglow.light_energy = lerpf(_underglow.light_energy, target_energy, 24.0 * delta)

	# Periodic Supersonic Shock Rings (Mach diamonds)
	if _shock_timer >= 0.11:
		_shock_timer = 0.0
		_spawn_shock_ring()

func _spawn_shock_ring() -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.16
	torus.outer_radius = 0.22
	torus.rings = 16
	torus.ring_segments = 6

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.25, 0.85, 1.0, 0.8)

	ring.mesh = torus
	ring.material_override = mat
	# Align ring perpendicular to +Z direction
	ring.rotation_degrees = Vector3(90, 0, 0)
	get_parent().get_parent().add_child(ring)

	ring.global_position = global_position + Vector3(0, 0.05, 0.2)

	var tween := ring.create_tween()
	var final_scale := Vector3(2.6, 2.6, 2.6)
	var final_pos := ring.global_position + global_transform.basis.z * 1.8
	tween.tween_property(ring, "scale", final_scale, 0.22)
	tween.parallel().tween_property(ring, "global_position", final_pos, 0.22)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.22)
	tween.tween_callback(ring.queue_free)

func _on_activated() -> void:
	_active = true
	_time = 0.0
	_shock_timer = 0.0

	for flame in _flames_outer:
		flame.visible = true
	for core in _flames_inner:
		core.visible = true
	for p in _particles:
		p.emitting = true
		p.restart()
	if _underglow != null:
		_underglow.light_energy = 3.5

func _on_deactivated() -> void:
	_active = false
	for flame in _flames_outer:
		flame.visible = false
	for core in _flames_inner:
		core.visible = false
	for p in _particles:
		p.emitting = false
