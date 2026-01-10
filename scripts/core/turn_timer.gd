extends Control

signal turn_timeout

@export var turn_duration: float = 30.0
@export var danger_threshold: float = 5.0
@export var danger_color_a: Color = Color(0.9, 0.2, 0.2, 1.0)
@export var danger_color_b: Color = Color(1.0, 0.35, 0.35, 1.0)
@export var danger_color_c: Color = Color(0.6, 0.0, 0.0, 1.0)

@onready var turn_timer: Timer = $Timer
@onready var timer_label: Label = $TimerLabel
@onready var gradient_material: ShaderMaterial = material as ShaderMaterial

var _normal_color_a: Color
var _normal_color_b: Color
var _normal_color_c: Color
var _is_danger: bool = false

func _ready():
	if turn_timer.timeout.is_connected(_on_turn_timer_timeout) == false:
		turn_timer.timeout.connect(_on_turn_timer_timeout)
	_cache_normal_colors()
	_update_timer_label(turn_duration)
	_set_danger_state(false)

func start_player_turn():
	turn_timer.wait_time = turn_duration
	turn_timer.start()
	_update_timer_label(turn_duration)
	_set_danger_state(false)
	# You might also play a sound or animation here

func stop_player_turn():
	turn_timer.stop()
	_update_timer_label(0.0)
	_set_danger_state(false)

func _process(_delta):
	# Only update UI if the timer is actually running
	if not turn_timer.is_stopped():
		var time_left = turn_timer.time_left
		_update_timer_label(time_left)
		_set_danger_state(time_left <= danger_threshold)

func _on_turn_timer_timeout():
	_update_timer_label(0.0)
	_set_danger_state(true)
	turn_timeout.emit()
	handle_turn_timeout()

func handle_turn_timeout():
	print("Time's up! Player forfeits the round.")
	# Add your logic here to discard a card or end the turn automatically
	# per your rule: "Failure to play forfeits the round"

func _update_timer_label(time_left: float) -> void:
	var total_seconds: int = max(0, int(ceil(time_left)))
	var minutes: int = int(total_seconds / 60.0)  # Explicit conversion
	var seconds: int = total_seconds % 60
	timer_label.text = "%d:%02d" % [minutes, seconds]

func _cache_normal_colors() -> void:
	if gradient_material == null:
		return
	_normal_color_a = gradient_material.get_shader_parameter("color_a")
	_normal_color_b = gradient_material.get_shader_parameter("color_b")
	_normal_color_c = gradient_material.get_shader_parameter("color_c")

func _set_danger_state(enable: bool) -> void:
	if gradient_material == null:
		return
	if _is_danger == enable:
		return
	_is_danger = enable
	if enable:
		gradient_material.set_shader_parameter("color_a", danger_color_a)
		gradient_material.set_shader_parameter("color_b", danger_color_b)
		gradient_material.set_shader_parameter("color_c", danger_color_c)
	else:
		gradient_material.set_shader_parameter("color_a", _normal_color_a)
		gradient_material.set_shader_parameter("color_b", _normal_color_b)
		gradient_material.set_shader_parameter("color_c", _normal_color_c)
