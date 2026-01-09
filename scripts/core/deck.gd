extends Control

const CARD_SCENE: PackedScene = preload("res://scenes/core/card.tscn")

@export var hand_path: NodePath
@export var stack_offset: Vector2 = Vector2(0, -1)
@export var stack_max_visible: int = 10
# Hand-specific properties removed; hand will be a separate scene

@onready var deck_spawn: ReferenceRect = $DeckSpawnPoint
var _hand: Control = null

var _deck: Array[CardDefinition] = []
var _deck_cards: Array[Control] = []

func _ready() -> void:
	_resolve_hand()
	deck_spawn.mouse_filter = Control.MOUSE_FILTER_STOP
	deck_spawn.gui_input.connect(_on_deck_spawn_input)
	_build_deck()
	_spawn_deck_stack()


func _spawn_deck_stack() -> void:
	_deck.shuffle()
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


func _draw_card_to_hand() -> void:
	if _hand == null:
		return
	if _deck_cards.is_empty():
		return
	if _hand.has_method("has_space") and not _hand.call("has_space"):
		return
	var card: Control = _deck_cards.pop_back()
	card.get_parent().remove_child(card)
	var added := false
	if _hand.has_method("add_card"):
		added = _hand.call("add_card", card)
	if not added:
		_return_card_to_top(card)


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


func _resolve_hand() -> void:
	if hand_path == NodePath(""):
		_hand = null
		return
	_hand = get_node_or_null(hand_path) as Control


func _build_deck() -> void:
	_deck.clear()
	_deck.append_array(_make_cards("Damage", CardDefinition.Kind.DAMAGE, "red", 25, 0, 1))
	_deck.append_array(_make_cards("Damage", CardDefinition.Kind.DAMAGE, "red", 15, 0, 2))
	_deck.append_array(_make_cards("Damage", CardDefinition.Kind.DAMAGE, "red", 10, 0, 5))

	_deck.append_array(_make_cards("Heal", CardDefinition.Kind.HEAL, "yellow", 15, 0, 2))
	_deck.append_array(_make_cards("Heal", CardDefinition.Kind.HEAL, "yellow", 10, 0, 3))
	_deck.append_array(_make_cards("Heal", CardDefinition.Kind.HEAL, "yellow", 5, 0, 3))

	_deck.append_array(_make_cards("Discard", CardDefinition.Kind.DISCARD, "blue", 0, 2, 6))
	_deck.append_array(_make_cards("Discard", CardDefinition.Kind.DISCARD, "blue", 0, 3, 2))

	_deck.append_array(_make_cards("Regenerate", CardDefinition.Kind.REGENERATE, "white", 4, 0, 1, 3, "persistent"))
	_deck.append_array(_make_cards("Bleed", CardDefinition.Kind.BLEED, "black", 4, 0, 1, 3, "persistent"))
	_deck.append_array(_make_cards("Replenish", CardDefinition.Kind.REPLENISH, "green", 0, 1, 1, 3, "persistent"))
	_deck.append_array(_make_cards("Balance", CardDefinition.Kind.BALANCE, "gradient", 0, 0, 1))


func _make_cards(
	card_name: String,
	kind: CardDefinition.Kind,
	suit: String,
	amount: int,
	count: int,
	copies: int,
	duration_rounds: int = 0,
	special_value: String = "none"
) -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for i in range(copies):
		var defn: CardDefinition = CardDefinition.new()
		defn.id = card_name
		defn.kind = kind
		defn.suit = suit
		defn.amount = amount
		defn.count = count
		defn.duration_rounds = duration_rounds
		defn.special_value = special_value
		cards.append(defn)
	return cards


func _on_card_input(_viewport: Node, event: InputEvent, _shape_idx: int, card: Control) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _deck_cards.is_empty():
			return
		if card == _deck_cards[_deck_cards.size() - 1]:
			_draw_card_to_hand()


func _on_deck_spawn_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _deck_cards.is_empty():
			return
		_draw_card_to_hand()
