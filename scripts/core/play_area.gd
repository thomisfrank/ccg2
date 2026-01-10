extends Panel

@export var is_opponent: bool = false
@export var hand_path: NodePath
@export var submit_button_path: NodePath

@onready var _indicator_glow: ColorRect = get_node_or_null("IndicatorGlow") as ColorRect
var _hand: Control = null
var _submit_button: Button = null


func _ready() -> void:
	if not is_opponent:
		add_to_group("play_area")
		gui_input.connect(_on_gui_input)
	_set_indicator_glow(false)
	_resolve_hand()
	_resolve_submit_button()


func set_drag_indicator_glow(enabled: bool) -> void:
	_set_indicator_glow(enabled)


func _set_indicator_glow(enabled: bool) -> void:
	if _indicator_glow == null:
		return
	_indicator_glow.visible = enabled


func _on_gui_input(event: InputEvent) -> void:
	if is_opponent:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_return_card_to_hand()
	if event is InputEventScreenTouch and event.pressed:
		_return_card_to_hand()


func _return_card_to_hand() -> void:
	if _hand == null:
		return
	var card := _get_top_card()
	if card == null:
		return
	var from_pos := card.global_position
	if card.get_parent():
		card.get_parent().remove_child(card)
	if _hand.has_method("add_card_from_pos"):
		_hand.call("add_card_from_pos", card, from_pos)
	elif _hand.has_method("add_card"):
		_hand.call("add_card", card)
	if card.has_method("set_face_down"):
		card.set_face_down(false)
	if _count_cards_in_area() == 0:
		_set_submit_visible(false)


func _get_top_card() -> Control:
	var children := get_children()
	for i in range(children.size() - 1, -1, -1):
		var child := children[i]
		if child is Control and child.has_method("set_face_down"):
			return child as Control
	return null


func _count_cards_in_area() -> int:
	var count := 0
	for child in get_children():
		if child is Control and child.has_method("set_face_down"):
			count += 1
	return count


func _resolve_hand() -> void:
	_hand = _resolve_node_path(hand_path)
	if _hand == null:
		_hand = get_node_or_null("/root/main/hand") as Control


func _resolve_submit_button() -> void:
	_submit_button = _resolve_node_path(submit_button_path) as Button
	if _submit_button == null:
		_submit_button = get_node_or_null("/root/main/SubmitButton") as Button


func _resolve_node_path(path: NodePath) -> Node:
	if path == NodePath(""):
		return null
	return get_node_or_null(path)


func _set_submit_visible(submit_visible: bool) -> void:
	if _submit_button == null:
		return
	_submit_button.visible = submit_visible
	_submit_button.disabled = not submit_visible
