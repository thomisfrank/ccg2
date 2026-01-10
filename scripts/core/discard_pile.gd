extends Panel

@export var is_opponent: bool = false
@export var stack_offset: Vector2 = Vector2(8.0, -8.0)
@export var max_visible_cards: int = 5
@export var rotation_variance: float = 0.3  # radians (~17 degrees max)
@export var animation_duration: float = 0.4
@export var animation_trans: Tween.TransitionType = Tween.TRANS_CUBIC
@export var animation_ease: Tween.EaseType = Tween.EASE_OUT
@export var zoom_scale: float = 1.0  # Keep cards at full size like play area

var _discard_stack: Array[Control] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


func add_card(card: Control, from_global_pos: Vector2 = Vector2.ZERO, animate: bool = false) -> bool:
	if card == null:
		return false
	
	# Remove from parent if it has one
	if card.get_parent() != null:
		card.get_parent().remove_child(card)
	
	# Add to our discard pile
	add_child(card)
	_prepare_card_for_discard(card)
	
	if animate and from_global_pos != Vector2.ZERO:
		_animate_card_to_pile(card, from_global_pos)
	else:
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

func pop_top_card() -> Control:
	if _discard_stack.is_empty():
		return null
	var card: Control = _discard_stack.pop_back()
	if card != null and card.get_parent() == self:
		remove_child(card)
	_update_z_order()
	return card

func remove_card(card: Control) -> void:
	if card == null:
		return
	_discard_stack.erase(card)
	if card.get_parent() == self:
		remove_child(card)
	_update_z_order()

func get_cards() -> Array[Control]:
	return _discard_stack.duplicate()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_show_discard_menu()
	if event is InputEventScreenTouch and event.pressed:
		_show_discard_menu()

func _show_discard_menu() -> void:
	var menu := get_tree().root.find_child("DiscardPile_Menu", true, false)
	if menu == null:
		return
	if menu.has_method("show_menu"):
		menu.show_menu(get_cards(), is_opponent)


func _prepare_card_for_discard(card: Control) -> void:
	# All cards in discard pile are face-up
	if card.has_method("set_face_down"):
		card.set_face_down(false)
	if card.has_method("set_hover_enabled"):
		card.set_hover_enabled(false)
	if card.has_method("set_shadow_visible"):
		card.set_shadow_visible(false)
	if card.has_method("set"):
		card.set("_is_in_play_area", false)
	# Keep cards at full size (like play area)
	card.scale = Vector2(zoom_scale, zoom_scale)
	card.rotation = 0.0  # Reset rotation before positioning


func _position_card_in_pile(card: Control) -> void:
	# Stack cards with offset for visual effect
	var stack_index: int = min(_discard_stack.size(), max_visible_cards - 1)
	
	# Center the card in the discard pile, accounting for its size
	var pile_center := size / 2.0
	var card_size := card.size * card.scale
	var card_center_offset := card_size / 2.0
	
	# Position at center with stack offset, then add slight random rotation
	var target_rotation := _rng.randf_range(-rotation_variance, rotation_variance)
	
	# Set pivot to center for proper rotation
	card.pivot_offset = card.size / 2.0
	
	# Position at pile center with stack offset
	card.position = pile_center - card_center_offset + (stack_offset * stack_index)
	card.rotation = target_rotation
	# Use larger z-index gaps to prevent child elements from overlapping
	card.z_index = _discard_stack.size() * 10


func _animate_card_to_pile(card: Control, from_global_pos: Vector2) -> void:
	# Calculate target position
	var stack_index: int = min(_discard_stack.size(), max_visible_cards - 1)
	var pile_center := size / 2.0
	var card_size := card.size * card.scale
	var card_center_offset := card_size / 2.0
	var target_rotation := _rng.randf_range(-rotation_variance, rotation_variance)
	
	# Set pivot to center for proper rotation
	card.pivot_offset = card.size / 2.0
	
	# Convert from_global_pos to local position relative to the discard pile
	var from_local_pos := from_global_pos - global_position
	
	# Calculate target LOCAL position (since card is now a child of discard pile)
	var target_pos := pile_center - card_center_offset + (stack_offset * stack_index)
	
	# Set initial position (local to discard pile) - must be BEFORE creating tween
	card.position = from_local_pos
	card.rotation = 0.0
	
	# Create tween for animation - use LOCAL position since card is now a child
	var tween := create_tween()
	tween.set_trans(animation_trans)
	tween.set_ease(animation_ease)
	tween.set_parallel(true)
	tween.tween_property(card, "position", target_pos, animation_duration)
	tween.tween_property(card, "rotation", target_rotation, animation_duration)


func _update_z_order() -> void:
	for i in range(_discard_stack.size()):
		if _discard_stack[i] != null:
			# Use larger z-index gaps to prevent child elements from overlapping
			_discard_stack[i].z_index = i * 10
