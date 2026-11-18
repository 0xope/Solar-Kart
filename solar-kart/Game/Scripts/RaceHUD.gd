class_name RaceHUD
extends CanvasLayer

@onready var lap_label: Label = $Root/TopLeft/LapPanel/VBox/LapLabel
@onready var cp_label: Label = $Root/TopLeft/LapPanel/VBox/CpLabel
@onready var timer_label: Label = $Root/TopCenter/TimerPanel/TimerLabel
@onready var coin_label: Label = $Root/TopRight/CoinPanel/HBox/CoinLabel
@onready var countdown_label: Label = $Root/Center/CountdownLabel
@onready var finish_panel: Control = $Root/Center/FinishPanel
@onready var final_time_label: Label = $Root/Center/FinishPanel/VBox/FinalTimeLabel
@onready var final_coins_label: Label = $Root/Center/FinishPanel/VBox/FinalCoinsLabel
@onready var restart_button: Button = $Root/Center/FinishPanel/VBox/RestartButton
@onready var nitro_bar: ProgressBar = $Root/BottomCenter/NitroContainer/NitroBar
@onready var nitro_label: Label = $Root/BottomCenter/NitroContainer/NitroLabel
@onready var speed_label: Label = $Root/BottomRight/SpeedPanel/SpeedLabel
@onready var respawn_flash: ColorRect = $Root/RespawnFlash

var _race_manager: Node
var _kart: Node
var _is_countdown_active := false

var _oob_panel: PanelContainer
var _oob_label: Label
var _oob_vignette: ColorRect
var _respawn_label: Label

func _ready() -> void:
	if finish_panel:
		finish_panel.visible = false
	if countdown_label:
		countdown_label.visible = false
	if respawn_flash:
		respawn_flash.modulate.a = 0.0

	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)

	_setup_oob_ui()
	call_deferred("_connect_signals")

func _setup_oob_ui() -> void:
	var root: Control = get_node_or_null("Root") as Control
	if root == null:
		return

	# Red Warning Vignette around screen perimeter
	_oob_vignette = ColorRect.new()
	_oob_vignette.name = "OOBVignette"
	_oob_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_oob_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_oob_vignette.color = Color(1.0, 0.08, 0.08, 0.35)
	_oob_vignette.modulate.a = 0.0
	root.add_child(_oob_vignette)

	# Out of Bounds Warning Panel
	_oob_panel = PanelContainer.new()
	_oob_panel.name = "OOBPanel"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.05, 0.05, 0.9)
	sb.border_color = Color(1.0, 0.3, 0.15, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_oob_panel.add_theme_stylebox_override("panel", sb)

	_oob_label = Label.new()
	_oob_label.name = "OOBLabel"
	_oob_label.add_theme_font_size_override("font_size", 22)
	_oob_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_oob_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_oob_label.text = "⚠️ OUT OF TRACK! 2.0s"
	_oob_panel.add_child(_oob_label)

	root.add_child(_oob_panel)
	_oob_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_oob_panel.custom_minimum_size = Vector2(380, 50)
	_oob_panel.position = Vector2(200, 85)
	_oob_panel.visible = false

	# Respawn Checkpoint Status Label inside RespawnFlash
	if respawn_flash:
		_respawn_label = Label.new()
		_respawn_label.name = "RespawnLabel"
		_respawn_label.set_anchors_preset(Control.PRESET_CENTER)
		_respawn_label.custom_minimum_size = Vector2(500, 60)
		_respawn_label.position = Vector2(150, 200)
		_respawn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_respawn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_respawn_label.add_theme_font_size_override("font_size", 26)
		_respawn_label.add_theme_color_override("font_color", Color(0.15, 0.95, 1.0))
		_respawn_label.text = "⚡ RETURNING TO LAST CHECKPOINT ⚡"
		respawn_flash.add_child(_respawn_label)

func _connect_signals() -> void:
	_race_manager = get_tree().root.find_child("RaceManager", true, false)
	_kart = get_tree().root.find_child("PlayerKart", true, false)

	if _race_manager != null:
		_race_manager.countdown_tick.connect(_on_countdown_tick)
		_race_manager.race_started.connect(_on_race_started)
		_race_manager.lap_completed.connect(_on_lap_completed)
		_race_manager.race_finished.connect(_on_race_finished)
		_race_manager.coins_changed.connect(_on_coins_changed)
		_race_manager.checkpoint_passed.connect(_on_checkpoint_passed)
		_race_manager.respawn_triggered.connect(_on_respawn_triggered)
		_race_manager.out_of_bounds_tick.connect(_on_out_of_bounds_tick)

	if _kart != null and "nitro" in _kart and _kart.nitro != null:
		_kart.nitro.charge_changed.connect(_on_nitro_charge_changed)
		_on_nitro_charge_changed(_kart.nitro.current_charge, _kart.nitro.max_charge)

func _process(delta: float) -> void:
	if _race_manager != null and _race_manager.get("state") == 1: # RACING
		var t: float = float(_race_manager.get("race_time"))
		_update_timer_display(t)

	if _kart != null and _kart.has_method("forward_speed"):
		var spd: float = maxf(0.0, _kart.forward_speed() * 3.6) # m/s to km/h
		if speed_label:
			speed_label.text = "%3d KM/H" % int(spd)

	if _kart != null and _kart.has_method("is_nitro_active"):
		if _kart.is_nitro_active():
			if nitro_label:
				nitro_label.text = ">>> BOOSTING! <<<"
				nitro_label.modulate = Color(1.0, 0.4, 0.1)
		else:
			if nitro_label:
				nitro_label.text = "NITRO [SPACE]"
				nitro_label.modulate = Color(0.2, 0.85, 1.0)

func _update_timer_display(t: float) -> void:
	if timer_label == null:
		return
	var minutes := int(t / 60.0)
	var seconds := int(fmod(t, 60.0))
	var centiseconds := int(fmod(t, 1.0) * 100.0)
	timer_label.text = "%02d:%02d.%02d" % [minutes, seconds, centiseconds]

func _on_countdown_tick(text: String) -> void:
	if countdown_label == null:
		return
	countdown_label.text = text
	countdown_label.visible = true
	countdown_label.scale = Vector2(1.4, 1.4)
	countdown_label.modulate = Color(1.0, 0.85, 0.2) if text != "GO!" else Color(0.2, 1.0, 0.4)

	var tween := create_tween()
	tween.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_race_started() -> void:
	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(countdown_label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): countdown_label.visible = false)

func _on_lap_completed(lap: int, total: int) -> void:
	if lap_label:
		lap_label.text = "LAP %d/%d" % [lap, total]
	if finish_panel:
		finish_panel.visible = false

func _on_checkpoint_passed(index: int, total: int) -> void:
	if cp_label:
		cp_label.text = "CP %d/%d" % [index + 1, total]

func _on_coins_changed(count: int) -> void:
	if coin_label:
		coin_label.text = "%d" % count

func _on_nitro_charge_changed(current: float, max_val: float) -> void:
	if nitro_bar:
		nitro_bar.max_value = max_val
		nitro_bar.value = current

func _on_out_of_bounds_tick(remaining: float, is_active: bool) -> void:
	if _oob_panel == null or _oob_label == null:
		return
	if is_active:
		_oob_panel.visible = true
		_oob_label.text = "⚠️ OUT OF TRACK! RETURN: %.1fs" % maxf(0.0, remaining)
		if remaining <= 1.0:
			_oob_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
		else:
			_oob_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.15))
		if _oob_vignette:
			_oob_vignette.modulate.a = 0.45 + 0.25 * sin(Time.get_ticks_msec() * 0.015)
	else:
		_oob_panel.visible = false
		if _oob_vignette:
			_oob_vignette.modulate.a = 0.0

func _on_respawn_triggered() -> void:
	if _oob_panel:
		_oob_panel.visible = false
	if _oob_vignette:
		_oob_vignette.modulate.a = 0.0
	if respawn_flash:
		respawn_flash.modulate.a = 0.92
		var tween := create_tween()
		tween.tween_property(respawn_flash, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_race_finished(final_time: float) -> void:
	if finish_panel:
		finish_panel.visible = true
	var minutes := int(final_time / 60.0)
	var seconds := int(fmod(final_time, 60.0))
	var centiseconds := int(fmod(final_time, 1.0) * 100.0)
	if final_time_label:
		final_time_label.text = "FINAL TIME: %02d:%02d.%02d" % [minutes, seconds, centiseconds]
	if final_coins_label and _race_manager != null:
		final_coins_label.text = "SOLAR COINS: %d" % int(_race_manager.get("coins"))

func _on_restart_pressed() -> void:
	if finish_panel:
		finish_panel.visible = false
	if _race_manager != null and _race_manager.has_method("restart_race"):
		_race_manager.restart_race()
