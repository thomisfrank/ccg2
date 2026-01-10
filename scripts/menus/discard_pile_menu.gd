extends Panel

signal card_chosen(card: Control)

@onready var _menu: VBoxContainer = get_node_or_null("Menu") as VBoxContainer
@onready var _ownership_label: Label = get_node_or_null("Menu/Ownership") as Label

var _card_items: Array[Control] = []
var _separators: Array[Control] = []
var _selecting: bool = false
var _selection_count: int = 0

func _ready() -> void:
	_cache_menu_children()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_PASS
	gui_input.connect(_on_gui_input)
	z_as_relative = false
	z_index = 2000

func show_menu(cards: Array, is_opponent: bool) -> void:
	_selecting = false
	if _ownership_label != null:
		_ownership_label.text = "Opponent's Discard Pile" if is_opponent else "Player's Discard Pile"
	var ordered_cards := cards.duplicate()
	ordered_cards.reverse()
	var max_items: int = min(_card_items.size(), ordered_cards.size())
	for i in range(_card_items.size()):
		var item := _card_items[i]
		if i < max_items:
			item.visible = true
			if item.has_method("set_card_from_control"):
				item.call("set_card_from_control", ordered_cards[i])
		else:
			item.visible = false
	for i in range(_separators.size()):
		_separators[i].visible = i < max_items - 1
	visible = true

func choose_cards(cards: Array, is_opponent: bool, count: int) -> Array[Control]:
	show_menu(cards, is_opponent)
	_selecting = true
	_selection_count = max(1, count)
	var chosen: Array[Control] = []
	while chosen.size() < _selection_count:
		var picked: Control = await card_chosen
		if picked == null or chosen.has(picked):
			continue
		chosen.append(picked)
		_hide_item_for_card(picked)
		_update_separators()
	_selecting = false
	hide_menu()
	return chosen

func hide_menu() -> void:
	visible = false

func _cache_menu_children() -> void:
	if _menu == null:
		return
	for child in _menu.get_children():
		if child == _ownership_label:
			continue
		if child.has_method("set_card_from_control"):
			_card_items.append(child)
			if child.has_signal("card_selected"):
				if not child.card_selected.is_connected(_on_item_selected):
					child.card_selected.connect(_on_item_selected)
		elif child is VSeparator:
			_separators.append(child)

func _on_item_selected(card: Control) -> void:
	if not _selecting:
		return
	if _is_replenish_card(card):
		return
	card_chosen.emit(card)

func _hide_item_for_card(card: Control) -> void:
	for item in _card_items:
		if item.has_method("get_card_ref") and item.get_card_ref() == card:
			item.visible = false
			return

func _update_separators() -> void:
	var visible_items: Array[Control] = []
	for item in _card_items:
		if item.visible:
			visible_items.append(item)
	for i in range(_separators.size()):
		_separators[i].visible = i < visible_items.size() - 1

func _on_gui_input(event: InputEvent) -> void:
	if _selecting:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _menu == null:
			hide_menu()
			return
		if not _menu.get_global_rect().has_point(event.position):
			hide_menu()
	if event is InputEventScreenTouch and event.pressed:
		if _menu == null:
			hide_menu()
			return
		if not _menu.get_global_rect().has_point(event.position):
			hide_menu()

func _is_replenish_card(card: Control) -> bool:
	if card == null:
		return false
	var defn: CardDefinition = null
	if card.has_method("get"):
		defn = card.get("definition") as CardDefinition
	if defn == null:
		return false
	return defn.kind == CardDefinition.Kind.REPLENISH
