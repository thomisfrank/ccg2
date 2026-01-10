extends Control

const CARD_SCENE: PackedScene = preload("res://scenes/core/card.tscn")

@export var hand_path: NodePath
@export var deck_recipe: DeckRecipe
@export var stack_offset: Vector2 = Vector2(0, -1)
@export var stack_max_visible: int = 10
@export var initial_hand_size: int = 3
@export var auto_draw_on_ready: bool = true
@export var auto_draw_delay: float = 0.05
@export var deck_z_index: int = -100
# Hand-specific properties removed; hand will be a separate scene

@onready var deck_spawn: ReferenceRect = $DeckSpawnPoint
@onready var _shadow: Control = get_node_or_null("Shadow") as Control
var _hand: Control = null

var _deck: Array[CardDefinition] = []
var _deck_cards: Array[Control] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _initial_deck_count: int = 0

func _ready() -> void:
	z_index = deck_z_index
	_rng.randomize()
	_resolve_hand()
	deck_spawn.mouse_filter = Control.MOUSE_FILTER_STOP
	deck_spawn.gui_input.connect(_on_deck_spawn_input)
	_build_deck()
	_spawn_deck_stack()
	if auto_draw_on_ready and initial_hand_size > 0:
		call_deferred("_start_auto_draw", initial_hand_size)


func _spawn_deck_stack() -> void:
	_deck.shuffle()
	_initial_deck_count = _deck.size()
	for i in range(_deck.size()):
		var card: Control = CARD_SCENE.instantiate()
		deck_spawn.add_child(card)
		var stack_index: int = min(i, stack_max_visible - 1)
		card.position = deck_spawn.size / 2 + stack_offset * stack_index
		card.z_index = i
		if card.has_method("apply_definition"):
			card.apply_definition(_deck[i])
		if card.has_method("set_face_down"):
			card.set_face_down(true)
		if card.has_method("set_hover_enabled"):
			card.set_hover_enabled(false)
		if card.has_method("set_shadow_visible"):
			card.set_shadow_visible(false)
		var area: Area2D = card.get_node_or_null("Area2D") as Area2D
		if area != null:
			area.input_pickable = true
			area.input_event.connect(_on_card_input.bind(card))
		_deck_cards.append(card)
	_update_shadow_visibility()


func _draw_card_to_hand() -> void:
	if _hand == null:
		return
	if _deck_cards.is_empty():
		return
	if _hand.has_method("has_space") and not _hand.call("has_space"):
		return
	var card: Control = _deck_cards.pop_back()
	var start_pos := card.global_position
	card.get_parent().remove_child(card)
	var added := false
	if _hand.has_method("add_card_from_pos"):
		added = _hand.call("add_card_from_pos", card, start_pos)
	elif _hand.has_method("add_card"):
		added = _hand.call("add_card", card)
	if not added:
		_return_card_to_top(card)
		return
	_update_shadow_visibility()
	if _hand.has_signal("card_draw_finished"):
		await _hand.card_draw_finished


func _return_card_to_top(card: Control) -> void:
	deck_spawn.add_child(card)
	_deck_cards.append(card)
	var stack_index: int = min(_deck_cards.size() - 1, stack_max_visible - 1)
	card.position = deck_spawn.size / 2 + stack_offset * stack_index
	card.z_index = _deck_cards.size() - 1
	if card.has_method("set_face_down"):
		card.set_face_down(true)
	if card.has_method("set_hover_enabled"):
		card.set_hover_enabled(false)
	if card.has_method("set_shadow_visible"):
		card.set_shadow_visible(false)
	_update_shadow_visibility()


func _resolve_hand() -> void:
	if hand_path == NodePath(""):
		_hand = null
		return
	_hand = get_node_or_null(hand_path) as Control


func _build_deck() -> void:
	_deck.clear()
	if deck_recipe != null:
		_deck.append_array(DeckBuilder.build_shuffled_deck(deck_recipe))
	else:
		_deck.append_array(DeckFactory.build_standard_deck())


func _draw_cards(count: int) -> void:
	for i in range(count):
		if _deck_cards.is_empty():
			return
		_draw_card_to_hand()


func _start_auto_draw(count: int) -> void:
	await get_tree().process_frame
	await _draw_cards_async(count)


func _draw_cards_async(count: int) -> void:
	for i in range(count):
		if _deck_cards.is_empty():
			return
		await _draw_card_to_hand()
		if auto_draw_delay > 0.0:
			await get_tree().create_timer(auto_draw_delay).timeout


func get_remaining_count() -> int:
	return _deck_cards.size()

func draw_cards(count: int) -> void:
	await _draw_cards_async(count)

func add_card_to_deck(card: Control, shuffle: bool = true) -> void:
	if card == null or deck_spawn == null:
		return
	if card.get_parent() != null:
		card.get_parent().remove_child(card)
	deck_spawn.add_child(card)
	if card.has_method("set"):
		card.set("_is_in_play_area", false)
	if card.has_method("_apply_thumbnail_mode"):
		card._apply_thumbnail_mode()
	else:
		card.scale = Vector2.ONE
	card.rotation = 0.0
	card.pivot_offset = card.size / 2.0
	if card.has_method("set_face_down"):
		card.set_face_down(true)
	if card.has_method("set_hover_enabled"):
		card.set_hover_enabled(false)
	if card.has_method("set_shadow_visible"):
		card.set_shadow_visible(false)
	var insert_index := _deck_cards.size()
	if shuffle:
		insert_index = _rng.randi_range(0, _deck_cards.size())
	_deck_cards.insert(insert_index, card)
	_restack_deck_cards()
	_update_shadow_visibility()

func _restack_deck_cards() -> void:
	for i in range(_deck_cards.size()):
		var card: Control = _deck_cards[i]
		if card == null:
			continue
		if card.get_parent() != deck_spawn:
			deck_spawn.add_child(card)
		var stack_index: int = min(i, stack_max_visible - 1)
		card.position = deck_spawn.size / 2 + stack_offset * stack_index
		card.z_index = i


func discard_top_cards(count: int, discard_pile: Control) -> void:
	if discard_pile == null:
		print("DEBUG deck: discard_pile is null")
		return
	
	var cards_to_discard: int = min(count, _deck_cards.size())
	print("DEBUG deck: discarding ", cards_to_discard, " cards from deck with ", _deck_cards.size(), " remaining")
	
	for i in range(cards_to_discard):
		if _deck_cards.is_empty():
			break
		
		var card: Control = _deck_cards.pop_back()
		if card == null:
			continue
		
		# Use deck position as the animation source so opponent discards animate correctly.
		var from_pos := deck_spawn.get_global_rect().get_center()
		
		# Remove from deck spawn parent
		if card.get_parent():
			card.get_parent().remove_child(card)
		
		# Add to discard pile with animation
		if discard_pile.has_method("add_card"):
			discard_pile.add_card(card, from_pos, true)
		else:
			print("DEBUG deck: discard_pile doesn't have add_card method")
		
		# Small delay between discards for staggered effect
		if i < cards_to_discard - 1:
			await get_tree().create_timer(0.1).timeout
	_update_shadow_visibility()

func _update_shadow_visibility() -> void:
	if _shadow == null:
		return
	if _initial_deck_count <= 0:
		_shadow.visible = false
		return
	var ratio := float(_deck_cards.size()) / float(_initial_deck_count)
	_shadow.visible = ratio > 0.15


func _on_card_input(_viewport: Node, event: InputEvent, _shape_idx: int, card: Control) -> void:
	# Handle mouse input
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _deck_cards.is_empty():
			return
		if card == _deck_cards[_deck_cards.size() - 1]:
			_draw_card_to_hand()
	
	# Handle touch input
	if event is InputEventScreenTouch and event.pressed:
		if _deck_cards.is_empty():
			return
		if card == _deck_cards[_deck_cards.size() - 1]:
			_draw_card_to_hand()


func _on_deck_spawn_input(event: InputEvent) -> void:
	# Handle mouse input
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _deck_cards.is_empty():
			return
		_draw_card_to_hand()
	
	# Handle touch input
	if event is InputEventScreenTouch and event.pressed:
		if _deck_cards.is_empty():
			return
		_draw_card_to_hand()
