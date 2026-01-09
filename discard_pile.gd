extends Panel

@export var is_opponent: bool = false
@export var stack_offset: Vector2 = Vector2(1.5, -1.5)
@export var max_visible_cards: int = 5
@export var rotation_variance: float = 0.3  # radians (~17 degrees max)

var _discard_stack: Array[Control] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func add_card(card: Control) -> bool:
	if card == null:
		return false
	
	# Remove from parent if it has one
	if card.get_parent() != null:
		card.get_parent().remove_child(card)
	
	# Add to our discard pile
	add_child(card)
	_prepare_card_for_discard(card)
	_position_card_in_pile(card)
	_discard_stack.append(card)
	_update_z_order()
	return true


func get_top_card() -> Control:
	if _discard_stack.is_empty():
		return null
	return _discard_stack[_discard_stack.size() - 1]


func get_card_count() -> int:
	return _discard_stack.size()


func _prepare_card_for_discard(card: Control) -> void:
	# Show cards face-up in player pile, face-down in opponent pile
	if card.has_method("set_face_down"):
		card.set_face_down(is_opponent)
	if card.has_method("set_hover_enabled"):
		card.set_hover_enabled(false)
	if card.has_method("set_shadow_visible"):
		card.set_shadow_visible(false)


func _position_card_in_pile(card: Control) -> void:
	# Stack cards with offset for visual effect
	var stack_index: int = min(_discard_stack.size(), max_visible_cards - 1)
	card.position = stack_offset * stack_index
	# Add slight random rotation for "thrown" look
	card.rotation = _rng.randf_range(-rotation_variance, rotation_variance)
	card.z_index = _discard_stack.size()


func _update_z_order() -> void:
	for i in range(_discard_stack.size()):
		if _discard_stack[i] != null:
			_discard_stack[i].z_index = i

