extends Node2D

@onready var _opp_hand: Node = get_node_or_null("opp_hand")
@onready var _opp_play_area: Control = get_node_or_null("OppPlayArea") as Control
@onready var _debug_button: Button = get_node_or_null("DebugOppPlay") as Button

func _ready() -> void:
	if _debug_button:
		_debug_button.pressed.connect(_on_debug_opp_play)


func _on_debug_opp_play() -> void:
	var card: Node = _find_opp_damage_card()
	if card == null:
		print("DEBUG: no damage card found in opponent hand")
		return
	_play_opp_card(card)


func _find_opp_damage_card():
	if _opp_hand == null:
		return null
	for child in _opp_hand.get_children():
		if not child.has_method("apply_definition"):
			continue
		var defn = child.get("definition") if child.has_method("get") else null
		if defn == null:
			continue
		if defn.kind == CardDefinition.Kind.DAMAGE:
			return child
	return null


func _play_opp_card(card: Node) -> void:
	if _opp_play_area == null:
		print("DEBUG: OppPlayArea missing")
		return
	if _opp_hand and _opp_hand.has_method("remove_card"):
		_opp_hand.remove_card(card)
	if card.get_parent():
		card.get_parent().remove_child(card)
	_opp_play_area.add_child(card)
	if card is Control:
		(card as Control).global_position = _opp_play_area.get_global_rect().get_center()
	card.rotation = 0
	if card.has_method("set_shadow_visible"):
		card.set_shadow_visible(false)
	if card.has_method("set_face_down"):
		card.set_face_down(false)
	if card.has_method("set_hover_enabled"):
		card.set_hover_enabled(false)
	if card.has_method("_apply_zoom_mode"):
		card._apply_zoom_mode()
	if card.has_method("set"):
		card.set("_is_in_play_area", true)
		card.set_meta("target_is_opponent", false)
	if card.has_method("_debug_play_effect"):
		card.call_deferred("_debug_play_effect")
