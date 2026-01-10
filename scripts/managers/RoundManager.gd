extends Node

@export var announcement_path: NodePath
@export var turn_timer_path: NodePath
@export var player_play_area_path: NodePath
@export var opponent_play_area_path: NodePath
@export var opponent_hand_path: NodePath
@export var player_hand_path: NodePath
@export var player_discard_pile_path: NodePath
@export var opponent_discard_pile_path: NodePath
@export var submit_button_path: NodePath
@export var player_deck_path: NodePath
@export var opponent_deck_path: NodePath

@export var round_announcement_duration: float = 1.25
@export var post_announcement_delay: float = 0.35
@export var resolution_slide_duration: float = 0.4
@export var resolution_flyoff_duration: float = 0.35
@export var between_rounds_delay: float = 0.8
@export var pre_turn_reaction_delay: float = 0.8
@export var round_start_hand_size: int = 3

var _announcement: Panel = null
var _turn_timer: Control = null
var _player_play_area: Control = null
var _opponent_play_area: Control = null
var _opponent_hand: Node = null
var _player_hand: Node = null
var _ai_manager: Node = null
var _player_discard_pile: Node = null
var _opponent_discard_pile: Node = null
var _submit_button: Button = null
var _player_deck: Node = null
var _opponent_deck: Node = null
var _round_index: int = 1
var _winning_card: Control = null
var _phase: int = 0
var _player_locked_in: bool = false

enum Phase { DRAW, PLAY, RESOLUTION }

func _ready() -> void:
	_resolve_nodes()
	_connect_signals()
	call_deferred("start_round")


func start_round() -> void:
	_phase = Phase.DRAW
	if _announcement != null:
		await _show_round_announcement()
	await get_tree().create_timer(post_announcement_delay).timeout
	await get_tree().create_timer(pre_turn_reaction_delay).timeout
	await _run_draw_phase()
	_player_locked_in = false
	_start_turn_timer()
	_schedule_opponent_play()
	_phase = Phase.PLAY


func place_played_card(card: Control, is_opponent: bool, reveal: bool = false) -> void:
	if card == null:
		return
	var play_area := _get_play_area(is_opponent)
	if play_area == null:
		return
	var parent_hand := card.get_parent()
	if parent_hand and parent_hand.has_method("remove_card"):
		parent_hand.remove_card(card)
	if card.get_parent() != play_area:
		if card.get_parent():
			card.get_parent().remove_child(card)
		play_area.add_child(card)
	card.global_position = play_area.get_global_rect().get_center()
	card.rotation = 0.0
	if card.has_method("set_shadow_visible"):
		card.set_shadow_visible(false)
	if card.has_method("set_hover_enabled"):
		card.set_hover_enabled(false)
	if card.has_method("set_face_down"):
		card.set_face_down(is_opponent and not reveal)
	if card.has_method("_apply_zoom_mode"):
		card._apply_zoom_mode()
	if card.has_method("set"):
		card.set("_is_in_play_area", true)
	if not is_opponent:
		_set_submit_visible(true)
	else:
		_check_if_both_cards_played()


func reveal_played_card(card: Control) -> void:
	if card == null:
		return
	if card.has_method("set_face_down"):
		card.set_face_down(false)


func has_played_card(is_opponent: bool) -> bool:
	var area := _get_play_area(is_opponent)
	if area == null:
		return false
	for child in area.get_children():
		if child is Control and child.has_method("set_face_down"):
			return true
	return false


func end_play_phase() -> void:
	if _phase != Phase.PLAY:
		return
	_phase = Phase.RESOLUTION
	_stop_turn_timer()
	_set_submit_visible(false)
	await _run_resolution_phase()


func _check_if_both_cards_played() -> void:
	if _player_locked_in and has_played_card(true):
		await get_tree().create_timer(0.3).timeout
		end_play_phase()


func _lock_player_in() -> void:
	_player_locked_in = true
	_set_submit_visible(false)
	_check_if_both_cards_played()


func _show_round_announcement() -> void:
	if _announcement == null:
		return
	if _announcement.has_method("show_message"):
		await _announcement.show_message("ROUND %d" % _round_index, round_announcement_duration)


func _start_turn_timer() -> void:
	if _turn_timer == null:
		return
	_turn_timer.visible = true
	if _turn_timer.has_method("start_player_turn"):
		_turn_timer.start_player_turn()


func _resolve_nodes() -> void:
	_announcement = _resolve_node_path(announcement_path) as Panel
	_turn_timer = _resolve_node_path(turn_timer_path) as Control
	_player_play_area = _resolve_node_path(player_play_area_path) as Control
	_opponent_play_area = _resolve_node_path(opponent_play_area_path) as Control
	_opponent_hand = _resolve_node_path(opponent_hand_path)
	_player_hand = _resolve_node_path(player_hand_path)
	_player_discard_pile = _resolve_node_path(player_discard_pile_path)
	_opponent_discard_pile = _resolve_node_path(opponent_discard_pile_path)
	_submit_button = _resolve_node_path(submit_button_path) as Button
	_player_deck = _resolve_node_path(player_deck_path)
	_opponent_deck = _resolve_node_path(opponent_deck_path)
	_ai_manager = _resolve_ai_manager()
	if _announcement == null:
		_announcement = get_node_or_null("/root/main/annoucement") as Panel
	if _turn_timer == null:
		_turn_timer = get_node_or_null("/root/main/TurnTimer") as Control
	if _player_play_area == null:
		_player_play_area = get_node_or_null("/root/main/PlayArea") as Control
	if _opponent_play_area == null:
		_opponent_play_area = get_node_or_null("/root/main/OppPlayArea") as Control
	if _opponent_hand == null:
		_opponent_hand = get_node_or_null("/root/main/opp_hand")
	if _player_hand == null:
		_player_hand = get_node_or_null("/root/main/hand")
	if _player_discard_pile == null:
		_player_discard_pile = get_node_or_null("/root/main/discard_pile")
	if _opponent_discard_pile == null:
		_opponent_discard_pile = get_node_or_null("/root/main/opp_discard_pile")
	if _submit_button == null:
		_submit_button = get_node_or_null("/root/main/SubmitButton") as Button
	if _player_deck == null:
		_player_deck = get_node_or_null("/root/main/deck")
	if _opponent_deck == null:
		_opponent_deck = get_node_or_null("/root/main/opp_deck")


func _resolve_ai_manager() -> Node:
	print("RoundManager: Resolving AI manager...")
	var mgr := get_tree().get_first_node_in_group("ai_manager")
	print("RoundManager: Found via group: ", mgr)
	if mgr != null:
		return mgr
	print("RoundManager: Trying autoload name 'AiManager'")
	if has_node("/root/AiManager"):
		mgr = get_node("/root/AiManager")
		print("RoundManager: Found at /root/AiManager: ", mgr)
		return mgr
	print("RoundManager: AI manager not found")
	return null


func _resolve_node_path(path: NodePath) -> Node:
	if path == NodePath(""):
		return null
	return get_node_or_null(path)


func _get_play_area(is_opponent: bool) -> Control:
	if is_opponent:
		return _opponent_play_area
	return _player_play_area


func _schedule_opponent_play() -> void:
	if _ai_manager == null or _opponent_hand == null:
		print("RoundManager: AI manager or opponent hand is null. AI: ", _ai_manager, " Hand: ", _opponent_hand)
		return
	print("RoundManager: Scheduling opponent play")
	var max_delay := 10.0
	if _turn_timer != null and _turn_timer.has_method("get"):
		max_delay = min(float(_turn_timer.get("turn_duration")), 10.0)
	if _ai_manager.has_method("schedule_opponent_play"):
		_ai_manager.call("schedule_opponent_play", _opponent_hand, self, max_delay)


func _set_submit_visible(is_visible: bool) -> void:
	if _submit_button == null:
		return
	_submit_button.visible = is_visible
	_submit_button.disabled = not is_visible


func _connect_signals() -> void:
	if _turn_timer != null and _turn_timer.has_signal("turn_timeout"):
		if not _turn_timer.turn_timeout.is_connected(_on_turn_timeout):
			_turn_timer.turn_timeout.connect(_on_turn_timeout)
	if _submit_button != null and not _submit_button.pressed.is_connected(_on_submit_pressed):
		_submit_button.pressed.connect(_on_submit_pressed)
	if _announcement != null and _announcement.has_signal("resolution_ok"):
		if not _announcement.resolution_ok.is_connected(_on_resolution_ok):
			_announcement.resolution_ok.connect(_on_resolution_ok)


func _on_submit_pressed() -> void:
	_lock_player_in()


func _on_turn_timeout() -> void:
	end_play_phase()


func _on_resolution_ok() -> void:
	if _winning_card != null:
		_play_card_effect(_winning_card)
		_discard_card(_winning_card, _is_opponent_card(_winning_card))
		_winning_card = null
	var mgr := _get_effects_manager()
	if mgr != null:
		await mgr.tick_end_of_round()
	if _announcement != null and _announcement.has_method("hide_all"):
		_announcement.hide_all()
	await get_tree().create_timer(between_rounds_delay).timeout
	_round_index += 1
	start_round()


func _run_resolution_phase() -> void:
	if _announcement == null:
		return
	var opp_card := _get_played_card(true)
	var player_card := _get_played_card(false)
	if opp_card == null and player_card == null:
		return
	_announcement.show_resolution_phase()
	if opp_card != null:
		_prepare_resolution_card(opp_card, true)
	if player_card != null:
		_prepare_resolution_card(player_card, false)
	await _animate_resolution_cards_in(opp_card, player_card)
	var winner := _determine_winner(player_card, opp_card)
	await _resolve_winner(winner, player_card, opp_card)


func _prepare_resolution_card(card: Control, is_opponent: bool) -> void:
	card.set_meta("is_opponent", is_opponent)
	if card.has_method("set_face_down"):
		card.set_face_down(false)
	if card.has_method("set_hover_enabled"):
		card.set_hover_enabled(false)
	if card.has_method("set_shadow_visible"):
		card.set_shadow_visible(false)
	if card.has_method("_apply_zoom_mode"):
		card._apply_zoom_mode()
	card.z_index = 100


func _animate_resolution_cards_in(opp_card: Control, player_card: Control) -> void:
	var opp_slot := _get_announcement_slot("ResolutionPhase/OppCard")
	var player_slot := _get_announcement_slot("ResolutionPhase/PlayerCard")
	var opp_target := _slot_center(opp_slot)
	var player_target := _slot_center(player_slot)
	if opp_card != null:
		_reparent_to_announcement(opp_card)
		var opp_centered_target := _centered_position_for_card(opp_card, opp_target)
		opp_card.global_position = opp_centered_target + Vector2(-700.0, 0.0)
		var tween := get_tree().create_tween()
		tween.tween_property(opp_card, "global_position", opp_centered_target, resolution_slide_duration)
		await tween.finished
	if player_card != null:
		_reparent_to_announcement(player_card)
		var player_centered_target := _centered_position_for_card(player_card, player_target)
		player_card.global_position = player_centered_target + Vector2(700.0, 0.0)
		var tween := get_tree().create_tween()
		tween.tween_property(player_card, "global_position", player_centered_target, resolution_slide_duration)
		await tween.finished


func _resolve_winner(result: int, player_card: Control, opp_card: Control) -> void:
	var loser: Control = null
	if result > 0:
		_winning_card = player_card
		loser = opp_card
	elif result < 0:
		_winning_card = opp_card
		loser = player_card
	else:
		_winning_card = null
		await _discard_tied_cards(player_card, opp_card)
		if _announcement != null and _announcement.has_method("show_message"):
			await _announcement.show_message("NO WINNER", round_announcement_duration)
		await _on_resolution_ok()
		return
	if loser != null:
		await _animate_loser_discard(loser)
	_announcement.show_resolution_winner()
	if _winning_card != null:
		var winner_slot := _get_announcement_slot("ResolutionWinner/WinningCard")
		var winner_target := _slot_center(winner_slot)
		_reparent_to_announcement(_winning_card)
		var winner_centered_target := _centered_position_for_card(_winning_card, winner_target)
		var tween := get_tree().create_tween()
		tween.tween_property(_winning_card, "global_position", winner_centered_target, resolution_slide_duration)
		await tween.finished


func _discard_tied_cards(player_card: Control, opp_card: Control) -> void:
	if opp_card != null:
		await _animate_loser_discard(opp_card)
	if player_card != null:
		await _animate_loser_discard(player_card)


func _animate_loser_discard(card: Control) -> void:
	var is_opponent := _is_opponent_card(card)
	var discard_pile := _get_discard_pile(is_opponent)
	if discard_pile == null:
		return
	var target := _global_center(discard_pile)
	var tween := get_tree().create_tween()
	tween.tween_property(card, "global_position", target, resolution_flyoff_duration)
	tween.tween_property(card, "modulate:a", 0.0, resolution_flyoff_duration)
	await tween.finished
	card.modulate.a = 1.0
	_discard_card(card, is_opponent)


func _discard_card(card: Control, is_opponent: bool) -> void:
	var discard_pile := _get_discard_pile(is_opponent)
	if discard_pile == null:
		return
	if card.get_parent():
		card.get_parent().remove_child(card)
	if discard_pile.has_method("add_card"):
		discard_pile.call("add_card", card)


func _get_played_card(is_opponent: bool) -> Control:
	var area := _get_play_area(is_opponent)
	if area == null:
		return null
	var children := area.get_children()
	for i in range(children.size() - 1, -1, -1):
		var child := children[i]
		if child is Control and child.has_method("set_face_down"):
			return child as Control
	return null


func _determine_winner(player_card: Control, opp_card: Control) -> int:
	if player_card == null and opp_card == null:
		return 0
	if player_card != null and opp_card == null:
		return 1
	if player_card == null and opp_card != null:
		return -1
	var player_suit := _get_card_suit(player_card)
	var opp_suit := _get_card_suit(opp_card)
	if _is_gradient(player_suit) or _is_gradient(opp_suit):
		if _is_gradient(player_suit) and _is_gradient(opp_suit):
			return 0
		return 1 if _is_gradient(player_suit) else -1
	var player_special := _is_special(player_suit)
	var opp_special := _is_special(opp_suit)
	if player_special and opp_special:
		return 0
	if player_special:
		return 1
	if opp_special:
		return -1
	if player_suit == opp_suit:
		return 0
	if player_suit == "red" and opp_suit == "yellow":
		return 1
	if player_suit == "yellow" and opp_suit == "blue":
		return 1
	if player_suit == "blue" and opp_suit == "red":
		return 1
	if opp_suit == "red" and player_suit == "yellow":
		return -1
	if opp_suit == "yellow" and player_suit == "blue":
		return -1
	if opp_suit == "blue" and player_suit == "red":
		return -1
	return 0


func _get_card_suit(card: Control) -> String:
	var defn = card.get("definition") if card.has_method("get") else null
	if defn == null:
		return ""
	return str(defn.suit).to_lower()


func _is_special(suit: String) -> bool:
	return suit == "green" or suit == "white" or suit == "black"


func _is_gradient(suit: String) -> bool:
	return suit == "gradient"


func _reparent_to_announcement(card: Control) -> void:
	if _announcement == null:
		return
	if card.get_parent() != _announcement:
		if card.get_parent():
			card.get_parent().remove_child(card)
		_announcement.add_child(card)


func _get_announcement_slot(path: String) -> Control:
	if _announcement == null:
		return null
	return _announcement.get_node_or_null(path) as Control


func _slot_center(slot: Control) -> Vector2:
	if slot == null:
		return Vector2.ZERO
	return slot.get_global_rect().get_center()


func _centered_position_for_card(card: Control, target_center: Vector2) -> Vector2:
	if card == null:
		return target_center
	var size := card.size * card.scale
	if size == Vector2.ZERO:
		return target_center
	return target_center - (size * 0.5)


func _global_center(node: Node) -> Vector2:
	if node is Control:
		return (node as Control).get_global_rect().get_center()
	return Vector2.ZERO


func _get_discard_pile(is_opponent: bool) -> Node:
	if is_opponent:
		return _opponent_discard_pile
	return _player_discard_pile


func _is_opponent_card(card: Control) -> bool:
	if card.has_meta("is_opponent"):
		return bool(card.get_meta("is_opponent"))
	var parent := card.get_parent()
	if parent == _opponent_play_area:
		return true
	return false


func _play_card_effect(card: Control) -> void:
	var defn = card.get("definition") if card.has_method("get") else null
	if defn == null:
		return
	var mgr := _get_effects_manager()
	if mgr == null:
		return
	var source_is_opponent := _is_opponent_card(card)
	var target_is_opponent := _get_effect_target_is_opponent(defn, source_is_opponent)
	var effect_data: Dictionary = {
		"kind": defn.kind,
		"amount": defn.amount,
		"count": defn.count,
		"special_value": defn.special_value,
		"duration_rounds": defn.duration_rounds,
		"source_card": defn.id,
		"source_is_opponent": source_is_opponent,
		"target_is_opponent": target_is_opponent,
	}
	mgr.queue_effect(effect_data)
	mgr.resolve_next()

func _run_draw_phase() -> void:
	await _draw_to_hand_size(_player_hand, _player_deck, round_start_hand_size)
	await _draw_to_hand_size(_opponent_hand, _opponent_deck, round_start_hand_size)

func _draw_to_hand_size(hand: Node, deck: Node, target_size: int) -> void:
	if hand == null or deck == null:
		return
	if not hand.has_method("get_card_count"):
		return
	if not deck.has_method("draw_cards"):
		return
	var current := int(hand.call("get_card_count"))
	var missing: int = max(0, target_size - current)
	if missing <= 0:
		return
	await deck.draw_cards(missing)

func _get_effect_target_is_opponent(defn: CardDefinition, source_is_opponent: bool) -> bool:
	match defn.kind:
		CardDefinition.Kind.HEAL, CardDefinition.Kind.REGENERATE, CardDefinition.Kind.REPLENISH:
			return source_is_opponent
		CardDefinition.Kind.DAMAGE, CardDefinition.Kind.DISCARD, CardDefinition.Kind.BLEED:
			return not source_is_opponent
		_:
			return not source_is_opponent


func _get_effects_manager() -> Node:
	var mgr := get_tree().get_first_node_in_group("effects_manager")
	if mgr != null:
		return mgr
	if get_tree().has_node("/root/EffectsManager"):
		return get_tree().get_node("/root/EffectsManager")
	return null


func _stop_turn_timer() -> void:
	if _turn_timer == null:
		return
	if _turn_timer.has_method("stop_player_turn"):
		_turn_timer.stop_player_turn()
