class_name TrackRaceData
extends RefCounted

var road := RoadSurface.new()
var checkpoints: Array[Dictionary] = []
var grid_slots: Array[Dictionary] = []
var track_laps := 3
var reference: Node3D

func load_from_json(path: String, fallback_width: float, reference_node: Node3D = null) -> bool:
	reference = reference_node
	checkpoints.clear()
	grid_slots.clear()
	track_laps = 3
	if not road.load_from_json(path, fallback_width):
		return false
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		return false
	track_laps = int(json.data.get("laps", 3))
	var checkpoint_data: Variant = json.data.get("checkpoints", [])
	if checkpoint_data is Array:
		for point in checkpoint_data:
			if point is Dictionary:
				checkpoints.append(point)
	checkpoints.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("index", 0)) < int(b.get("index", 0)))
	var grid_data: Variant = json.data.get("grid", [])
	if grid_data is Array:
		for point in grid_data:
			if point is Dictionary:
				grid_slots.append(point)
	grid_slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("slot", 0)) < int(b.get("slot", 0)))
	return checkpoints.size() > 0 and grid_slots.size() > 0

func road_info(world_position: Vector3) -> Dictionary:
	var local_position := world_position
	if reference != null:
		local_position = reference.to_local(world_position)
	var info := road.road_info(local_position)
	info["local_position"] = local_position
	return info

func checkpoint_count() -> int:
	return checkpoints.size()

func grid_count() -> int:
	return grid_slots.size()

func checkpoint_distance(local_position: Vector3, index: int) -> float:
	if index < 0 or index >= checkpoints.size():
		return INF
	var point := checkpoints[index]
	var checkpoint := Vector2(float(point.get("x", 0.0)), float(point.get("z", 0.0)))
	return Vector2(local_position.x, local_position.z).distance_to(checkpoint)

func checkpoint_radius(index: int, extra: float) -> float:
	if index < 0 or index >= checkpoints.size():
		return extra
	var point := checkpoints[index]
	return float(point.get("width", 8.0)) * 0.5 + extra

func checkpoint_transform(index: int) -> Transform3D:
	if index < 0 or index >= checkpoints.size():
		return Transform3D.IDENTITY
	return _point_transform(checkpoints[index])

func grid_transform(slot_index: int) -> Transform3D:
	if slot_index < 0 or slot_index >= grid_slots.size():
		return checkpoint_transform(0)
	return _point_transform(grid_slots[slot_index])

func _point_transform(point: Dictionary) -> Transform3D:
	var local_position := Vector3(float(point.get("x", 0.0)), float(point.get("y", 0.0)), float(point.get("z", 0.0)))
	var direction := Vector3(float(point.get("dirX", 1.0)), 0.0, float(point.get("dirZ", 0.0)))
	if direction.length_squared() < 0.0001:
		direction = Vector3(0.0, 0.0, -1.0)
	direction = direction.normalized()
	var yaw := atan2(-direction.x, -direction.z)
	var position := local_position
	if reference != null:
		position = reference.to_global(local_position)
	return Transform3D(Basis(Vector3.UP, yaw), position)
