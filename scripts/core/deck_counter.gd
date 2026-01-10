extends Control

@export var deck_path: NodePath
@export var discard_pile_path: NodePath
@export var include_discard: bool = true

var _deck: Node = null
var _discard_pile: Node = null
var _label: Label = null
var _last_count: int = -1

func _ready() -> void:
	_resolve_nodes()
	_update_count()

func _process(_delta: float) -> void:
	_update_count()

func _resolve_nodes() -> void:
	_deck = _resolve_node(deck_path)
	_discard_pile = _resolve_node(discard_pile_path)
	_label = get_node_or_null("Panel/number") as Label

func _resolve_node(path: NodePath) -> Node:
	if path == NodePath(""):
		return null
	return get_node_or_null(path)

func _update_count() -> void:
	var deck_count := _get_deck_count()
	var discard_count := _get_discard_count() if include_discard else 0
	var total := deck_count + discard_count
	if total == _last_count:
		return
	_last_count = total
	if _label != null:
		_label.text = str(total)

func _get_deck_count() -> int:
	if _deck == null:
		return 0
	if _deck.has_method("get_remaining_count"):
		return int(_deck.call("get_remaining_count"))
	return 0

func _get_discard_count() -> int:
	if _discard_pile == null:
		return 0
	if _discard_pile.has_method("get_card_count"):
		return int(_discard_pile.call("get_card_count"))
	return 0
