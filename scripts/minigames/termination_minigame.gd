extends CanvasLayer
class_name TerminationMinigame

signal termination_complete(success: bool)

# --------------------------
# CONFIG
@export var fill_per_click: float = 2
@export var decay_per_second: float = 10
@export var max_value: float = 100.0
@export var duration: float = 10.0
@export var atp_reduction: int = 6

@export var green_screen : PackedScene
@export var red_screen : PackedScene

@export var pulse_scale: float = 1.2
@export var pulse_duration: float = 0.1

# --------------------------
# STATE
var current_value: float = 0.0
var remaining_time: float = 0.0
var game_active: bool = false
var timer_started: bool = false
var button_held: bool = false  # track if button is held

# --------------------------
# NODES
@onready var progress_bar: TextureProgressBar = $Control/CONTAINER/ProgressBar
@onready var mash_button: Button = $Control/CONTAINER/Button
@onready var timer_label: Label = $Control/CONTAINER/Timer
@onready var atp_label: Label = $Control/CONTAINER/Label
@onready var termination_visual : Sprite2D = $Control/CONTAINER/TeminationVisual

func _ready():
	progress_bar.min_value = 0
	progress_bar.max_value = max_value
	progress_bar.value = 0
	
	timer_label.text = "PRESS THE BUTTON OR SPACE TO START"
	_update_atp_label()
	
	# Connect signals
	mash_button.pressed.connect(_on_button_pressed)
	# Godot 4.5: detect release manually using _unhandled_input

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				# handled by pressed signal
				pass
			else:
				_reset_visual_scale()
				button_held = false
	if event is InputEventKey:
		if event.is_action_released("ui_accept"):  # space key released
			_reset_visual_scale()
			button_held = false
		elif event.is_action_pressed("ui_accept"):
			_start_timer_if_needed()
			_increment_fill()
			_scale_up_visual()
			button_held = true

func _process(delta):
	if not game_active:
		return
	
	if timer_started:
		remaining_time -= delta
		if remaining_time <= 0:
			remaining_time = 0
			game_active = false
			_reset_visual_scale()
			_fail_game()
		_update_timer_label()
	
	if current_value > 0:
		current_value = max(current_value - decay_per_second * delta, 0)
		progress_bar.value = current_value

# --------------------------
func _update_timer_label():
	if timer_started:
		timer_label.text = "Time: %0.1fs" % remaining_time

func _update_atp_label():
	atp_label.text = "ATP: %d" % PlayerInfo.player_info.atp_units

# --------------------------
func _on_button_pressed():
	_start_timer_if_needed()
	_increment_fill()
	_scale_up_visual()
	button_held = true

# --------------------------
func _start_timer_if_needed():
	if not timer_started:
		timer_started = true
		game_active = true
		remaining_time = duration
		_update_timer_label()

# --------------------------
func _increment_fill():
	current_value += fill_per_click
	if current_value >= max_value:
		current_value = max_value
		progress_bar.value = current_value
		game_active = false
		_reset_visual_scale()
		_success_game()
	else:
		progress_bar.value = current_value

# --------------------------
func _success_game():
	timer_label.text = "TERMINATED SUCCESSFULLY"
	emit_signal("termination_complete", true)
	if green_screen:
		var green_instance = green_screen.instantiate()
		add_child(green_instance)
	await get_tree().create_timer(1).timeout
	queue_free()

# --------------------------
func _fail_game():
	timer_label.text = "FAILED TO TERMINATE, TRY AGAIN"
	PlayerInfo.player_info.atp_units = max(PlayerInfo.player_info.atp_units - atp_reduction, 0)
	_update_atp_label()
	emit_signal("termination_complete", false)
	if red_screen:
		var red_instance = red_screen.instantiate()
		add_child(red_instance)
	await get_tree().create_timer(1).timeout
	queue_free()

# --------------------------
func _scale_up_visual():
	var tw = create_tween()
	tw.tween_property(termination_visual, "scale", Vector2.ONE * pulse_scale, pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _reset_visual_scale():
	var tw = create_tween()
	tw.tween_property(termination_visual, "scale", Vector2.ONE, pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
