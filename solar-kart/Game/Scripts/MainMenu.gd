class_name MainMenu
extends Control

@export var track_scene_path := "res://Game/Scenes/TestTrack.tscn"

# Currency state
var coins: int = 1250
var gems: int = 50
var current_kart: String = "Red Fury"

# Audio helper
var _audio: Node

# Node references
@onready var background: TextureRect = $Background
@onready var buttons_layer: Control = $ButtonsLayer
@onready var modals_layer: Control = $ModalsLayer
@onready var backdrop: ColorRect = $ModalsLayer/Backdrop

# Interactive Buttons
@onready var btn_play: Button = $ButtonsLayer/PlayButton
@onready var btn_leaderboard: Button = $ButtonsLayer/LeaderboardButton
@onready var btn_shop: Button = $ButtonsLayer/ShopButton
@onready var btn_how_to_play: Button = $ButtonsLayer/HowToPlayButton
@onready var btn_garage: Button = $ButtonsLayer/GarageButton
@onready var btn_wallet: Button = $ButtonsLayer/WalletButton
@onready var btn_settings: Button = $ButtonsLayer/SettingsButton
@onready var btn_profile: Button = $ButtonsLayer/ProfileButton
@onready var btn_coin_plus: Button = $ButtonsLayer/CoinPlusButton
@onready var btn_gem_plus: Button = $ButtonsLayer/GemPlusButton

# Modals
@onready var modal_leaderboard: PanelContainer = $ModalsLayer/LeaderboardModal
@onready var modal_garage: PanelContainer = $ModalsLayer/GarageModal
@onready var modal_shop: PanelContainer = $ModalsLayer/ShopModal
@onready var modal_wallet: PanelContainer = $ModalsLayer/WalletModal
@onready var modal_how_to_play: PanelContainer = $ModalsLayer/HowToPlayModal
@onready var modal_settings: PanelContainer = $ModalsLayer/SettingsModal
@onready var modal_profile: PanelContainer = $ModalsLayer/ProfileModal

var _active_modal: Control = null

func _ready() -> void:
	# Initialize audio
	_audio = ArcadeAudio.new()
	_audio.name = "ArcadeAudio"
	add_child(_audio)

	# Setup buttons interaction
	_setup_buttons()

	# Hide all modals initially
	modals_layer.visible = false
	backdrop.modulate.a = 0.0
	for m in [modal_leaderboard, modal_garage, modal_shop, modal_wallet, modal_how_to_play, modal_settings, modal_profile]:
		if m != null:
			m.visible = false

	if backdrop != null:
		backdrop.gui_input.connect(_on_backdrop_gui_input)

func _setup_buttons() -> void:
	var buttons := [
		btn_play, btn_leaderboard, btn_shop, btn_how_to_play,
		btn_garage, btn_wallet, btn_settings, btn_profile,
		btn_coin_plus, btn_gem_plus
	]

	for btn in buttons:
		if btn == null:
			continue
		btn.mouse_entered.connect(_on_button_hover.bind(btn))
		btn.mouse_exited.connect(_on_button_unhover.bind(btn))

	# Connect actions
	if btn_play: btn_play.pressed.connect(_on_play_pressed)
	if btn_leaderboard: btn_leaderboard.pressed.connect(func(): _open_modal(modal_leaderboard))
	if btn_garage: btn_garage.pressed.connect(func(): _open_modal(modal_garage))
	if btn_shop: btn_shop.pressed.connect(func(): _open_modal(modal_shop))
	if btn_wallet: btn_wallet.pressed.connect(func(): _open_modal(modal_wallet))
	if btn_how_to_play: btn_how_to_play.pressed.connect(func(): _open_modal(modal_how_to_play))
	if btn_settings: btn_settings.pressed.connect(func(): _open_modal(modal_settings))
	if btn_profile: btn_profile.pressed.connect(func(): _open_modal(modal_profile))
	if btn_coin_plus: btn_coin_plus.pressed.connect(func(): _open_modal(modal_shop))
	if btn_gem_plus: btn_gem_plus.pressed.connect(func(): _open_modal(modal_shop))

func _on_button_hover(btn: Button) -> void:
	if _audio != null and _audio.has_method("play_ui_hover"):
		_audio.play_ui_hover()

	btn.pivot_offset = btn.size * 0.5
	var tween := create_tween()
	var is_play := (btn == btn_play)
	var target_scale := Vector2(1.035, 1.035) if is_play else Vector2(1.025, 1.025)
	tween.tween_property(btn, "scale", target_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_button_unhover(btn: Button) -> void:
	btn.pivot_offset = btn.size * 0.5
	var tween := create_tween()
	tween.tween_property(btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_play_pressed() -> void:
	if _audio != null and _audio.has_method("play_ui_click"):
		_audio.play_ui_click()

	btn_play.pivot_offset = btn_play.size * 0.5
	var tween := create_tween()
	tween.tween_property(btn_play, "scale", Vector2(0.96, 0.96), 0.08)
	tween.tween_property(btn_play, "scale", Vector2(1.05, 1.05), 0.15)
	tween.tween_callback(func():
		# Screen fade transition to race
		var flash := ColorRect.new()
		flash.color = Color(1, 1, 1, 0)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(flash)

		var f_tween := flash.create_tween()
		f_tween.tween_property(flash, "color:a", 1.0, 0.35)
		f_tween.tween_callback(func():
			get_tree().change_scene_to_file(track_scene_path)
		)
	)

func _open_modal(modal: Control) -> void:
	if modal == null:
		return
	if _audio != null and _audio.has_method("play_ui_click"):
		_audio.play_ui_click()

	if _active_modal != null and _active_modal != modal:
		_active_modal.visible = false

	_active_modal = modal
	modals_layer.visible = true
	modal.visible = true
	modal.pivot_offset = modal.size * 0.5
	modal.scale = Vector2(0.92, 0.92)
	modal.modulate.a = 0.0

	var tween := create_tween()
	tween.parallel().tween_property(backdrop, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(modal, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(modal, "modulate:a", 1.0, 0.18)

func close_active_modal() -> void:
	if _active_modal == null:
		return
	if _audio != null and _audio.has_method("play_ui_hover"):
		_audio.play_ui_hover()

	var modal := _active_modal
	_active_modal = null

	var tween := create_tween()
	tween.parallel().tween_property(backdrop, "modulate:a", 0.0, 0.18)
	tween.parallel().tween_property(modal, "scale", Vector2(0.95, 0.95), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(modal, "modulate:a", 0.0, 0.18)
	tween.tween_callback(func():
		modal.visible = false
		modals_layer.visible = false
	)

func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_active_modal()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _active_modal != null:
			close_active_modal()

# Interactive modal logic callbacks:
func equip_kart(kart_name: String) -> void:
	current_kart = kart_name
	if _audio != null and _audio.has_method("play_ui_click"):
		_audio.play_ui_click()
	print("Equipped Kart: ", current_kart)

func buy_item(coin_cost: int, gem_reward: int, coin_reward: int) -> void:
	if coins >= coin_cost:
		coins -= coin_cost
		coins += coin_reward
		gems += gem_reward
		if _audio != null and _audio.has_method("play_coin"):
			_audio.play_coin()
		print("Purchase successful! Coins: %d, Gems: %d" % [coins, gems])
	else:
		if _audio != null and _audio.has_method("play_ui_hover"):
			_audio.play_ui_hover()
		print("Not enough coins!")
