class_name RoadSurface
extends RefCounted

var _points := PackedVector2Array()
var _half_widths := PackedFloat32Array()
var _fallback_half_width := 4.0

func load_from_json(path: String, fallback_width: float) -> bool:
	_points.clear()
	_half_widths.clear()
	_fallback_half_width = fallback_width * 0.5

	if not FileAccess.file_exists(path):
		push_warning("RoadSurface: track data not found: %s" % path)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("RoadSurface: could not open %s" % path)
		return false

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		push_warning("RoadSurface: invalid JSON in %s" % path)
		return false

	var center_line: Variant = json.data.get("centerLine", [])
	if not center_line is Array or center_line.size() < 2:
		push_warning("RoadSurface: missing centerLine in %s" % path)
		return false

	for point in center_line:
		if not point is Dictionary:
			continue
		_points.append(Vector2(float(point.get("x", 0.0)), float(point.get("z", 0.0))))
		_half_widths.append(float(point.get("width", fallback_width)) * 0.5)

	if _points.size() < 2 or _half_widths.size() != _points.size():
		push_warning("RoadSurface: incomplete centerLine in %s" % path)
		return false

	return true

func road_info(world_position: Vector3) -> Dictionary:
	if _points.is_empty():
		return {"on_road": true, "distance": 0.0, "half_width": _fallback_half_width}

	var position := Vector2(world_position.x, world_position.z)
	var best_distance := INF
	var best_half_width := _fallback_half_width

	for i in _points.size():
		var j := (i + 1) % _points.size()
		var a := _points[i]
		var b := _points[j]
		var segment := b - a
		var segment_length_sq := segment.length_squared()
		var t := 0.0 if segment_length_sq == 0.0 else clampf((position - a).dot(segment) / segment_length_sq, 0.0, 1.0)
		var closest := a + segment * t
		var distance := position.distance_to(closest)
		var half_width := lerpf(_half_widths[i], _half_widths[j], t)

		if distance < best_distance:
			best_distance = distance
			best_half_width = half_width

	return {
		"on_road": best_distance <= best_half_width,
		"distance": best_distance,
		"half_width": best_half_width,
	}
