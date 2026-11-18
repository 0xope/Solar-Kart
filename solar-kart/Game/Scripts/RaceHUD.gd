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

func _ready() -> void:
	if finish_panel:
		finish_panel.visible = false
	if countdown_label:
		countdown_label.visible = false
	if respawn_flash:
		respawn_flash.modulate.a = 0.0

	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)

	call_deferred("_connect_signals")

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

func _on_respawn_triggered() -> void:
	if respawn_flash:
		respawn_flash.modulate.a = 0.6
		var tween := create_tween()
		tween.tween_property(respawn_flash, "modulate:a", 0.0, 0.35)

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
