class_name Checkpoint
extends Area3D

signal passed(index: int, transform: Transform3D)

@export var checkpoint_index: int = 0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.has_method("forward_speed"):
		return
	passed.emit(checkpoint_index, global_transform)
