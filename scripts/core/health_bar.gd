extends Control

@export var max_health: int = 60
@export var current_health: int = 60

@onready var _bar: ProgressBar = get_node_or_null("health")
@onready var _total_label: Label = get_node_or_null("icon/plate/health_total")
@onready var _plate: Panel = get_node_or_null("icon/plate")

signal health_changed(current: int, max: int)

var _plate_material: ShaderMaterial = null
var _base_colors := {
	"color_a": null,
	"color_b": null,
	"color_c": null,
}

var _display_health: int = 0
var _tween: Tween = null
@export var animate_duration: float = 0.35

func _ready() -> void:
	if _bar:
		_bar.max_value = max_health
	_setup_plate_material()
	_display_health = current_health
	_sync()

func set_health(value: int) -> void:
	var target: int = clamp(value, 0, max_health)
	if target == current_health and _tween == null:
		return
	current_health = target
	_animate_health(target)

func change_health(delta: int) -> void:
	set_health(current_health + delta)

func apply_damage(amount: int) -> void:
	change_health(-abs(amount))

func apply_heal(amount: int) -> void:
	change_health(abs(amount))

func set_max_health(value: int, keep_ratio: bool = true) -> void:
	var ratio := 1.0
	if keep_ratio and max_health > 0:
		ratio = float(current_health) / float(max_health)
	max_health = max(1, value)
	current_health = clamp(int(round(max_health * ratio)), 0, max_health)
	_display_health = current_health
	_sync()

func _sync() -> void:
	if _bar:
		_bar.max_value = max_health
		_bar.value = _display_health
	if _total_label:
		_total_label.text = str(_display_health)
	_update_plate_color()
	health_changed.emit(_display_health, max_health)


func _animate_health(target: int) -> void:
	if _tween:
		_tween.kill()
	var start := _display_health
	if target == start:
		return
	var diff := target - start
	var steps: int = abs(diff)
	var step_time: float = animate_duration / max(steps, 1)
	step_time = clamp(step_time, 0.02, 0.10)
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_LINEAR)
	_tween.set_ease(Tween.EASE_IN_OUT)
	var current := start
	for i in range(steps):
		current += sign(diff)
		_tween.tween_interval(step_time)
		_tween.tween_callback(Callable(self, "_set_display_health").bind(current))
	_tween.finished.connect(func():
		_tween = null
	)


func _set_display_health(value: float) -> void:
	_display_health = int(round(value))
	_sync()


func _setup_plate_material() -> void:
	if _plate == null:
		return
	if _plate.material is ShaderMaterial:
		_plate_material = (_plate.material as ShaderMaterial).duplicate()
		_plate.material = _plate_material
		_base_colors["color_a"] = _plate_material.get_shader_parameter("color_a")
		_base_colors["color_b"] = _plate_material.get_shader_parameter("color_b")
		_base_colors["color_c"] = _plate_material.get_shader_parameter("color_c") if _plate_material.get_shader_parameter("color_c") != null else null


func _update_plate_color() -> void:
	if _plate_material == null:
		return
	var ratio := 0.0
	if max_health > 0:
		ratio = float(current_health) / float(max_health)

	var target_color = null
	if ratio <= 0.3:
		target_color = Color(0.9, 0.1, 0.1, 1.0)
	elif ratio <= 0.5:
		target_color = Color(1.0, 0.85, 0.2, 1.0)

	if target_color == null:
		if _base_colors["color_a"] != null:
			_plate_material.set_shader_parameter("color_a", _base_colors["color_a"])
		if _base_colors["color_b"] != null:
			_plate_material.set_shader_parameter("color_b", _base_colors["color_b"])
		if _base_colors["color_c"] != null:
			_plate_material.set_shader_parameter("color_c", _base_colors["color_c"])
		return

	var darker := Color(
		target_color.r * 0.6,
		target_color.g * 0.6,
		target_color.b * 0.6,
		target_color.a
	)
	_plate_material.set_shader_parameter("color_a", target_color)
	_plate_material.set_shader_parameter("color_b", darker)
	if _base_colors["color_c"] != null:
		_plate_material.set_shader_parameter("color_c", target_color)
