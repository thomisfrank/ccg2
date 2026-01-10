extends Panel

signal resolution_ok

@onready var _label: Label = get_node_or_null("announce_text") as Label
@onready var _resolution_phase: Control = get_node_or_null("ResolutionPhase") as Control
@onready var _resolution_winner: Control = get_node_or_null("ResolutionWinner") as Control
@onready var _ok_button: Button = get_node_or_null("ResolutionWinner/Button") as Button

@export var default_duration: float = 1.25

func show_message(text: String, duration: float = -1.0) -> void:
	if duration < 0.0:
		duration = default_duration
	if _label != null:
		_label.text = text
		_label.visible = true
	if _resolution_phase != null:
		_resolution_phase.visible = false
	if _resolution_winner != null:
		_resolution_winner.visible = false
	visible = true
	await get_tree().create_timer(duration).timeout
	visible = false
	if _label != null:
		_label.visible = false


func show_resolution_phase() -> void:
	visible = true
	if _label != null:
		_label.visible = false
	if _resolution_phase != null:
		_resolution_phase.visible = true
	if _resolution_winner != null:
		_resolution_winner.visible = false


func show_resolution_winner() -> void:
	visible = true
	if _label != null:
		_label.visible = false
	if _resolution_phase != null:
		_resolution_phase.visible = false
	if _resolution_winner != null:
		_resolution_winner.visible = true


func hide_all() -> void:
	visible = false
	if _label != null:
		_label.visible = false
	if _resolution_phase != null:
		_resolution_phase.visible = false
	if _resolution_winner != null:
		_resolution_winner.visible = false


func _ready() -> void:
	if _ok_button != null and not _ok_button.pressed.is_connected(_on_ok_pressed):
		_ok_button.pressed.connect(_on_ok_pressed)


func _on_ok_pressed() -> void:
	resolution_ok.emit()
