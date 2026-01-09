extends Panel

@export var is_opponent: bool = false

@onready var _indicator_glow: ColorRect = get_node_or_null("IndicatorGlow") as ColorRect


func _ready() -> void:
	if not is_opponent:
		add_to_group("play_area")
	_set_indicator_glow(false)


func set_drag_indicator_glow(enabled: bool) -> void:
	_set_indicator_glow(enabled)


func _set_indicator_glow(enabled: bool) -> void:
	if _indicator_glow == null:
		return
	_indicator_glow.visible = enabled
