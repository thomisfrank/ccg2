extends Node

signal effect_queued(effect_id: String)
signal effect_resolving(effect_id: String)
signal effect_resolved(effect_id: String)
signal effect_expired(effect_id: String)
signal effect_ticked(effect_id: String, remaining_rounds: int)
signal damage_applied(amount: int, target_is_opponent: bool)
signal heal_applied(amount: int, target_is_opponent: bool)
signal discard_applied(count: int, target_is_opponent: bool)

enum EffectState { QUEUED, RESOLVING, RESOLVED, EXPIRED, CANCELLED }

var _effects_by_id: Dictionary = {}
var _effect_queue: Array[String] = []
var _active_persistent: Array[String] = []
var _effects_by_target: Dictionary = {}

func _ready() -> void:
	add_to_group("effects_manager")
	call_deferred("_wire_debug_health")

func _wire_debug_health() -> void:
	var root: Node = get_tree().root
	var opp_bar: Node = root.find_child("Opp_HealthBar", true, false)
	var player_bar: Node = root.find_child("HealthBar", true, false)
	if damage_applied.is_connected(_on_damage_applied):
		damage_applied.disconnect(_on_damage_applied)
	if heal_applied.is_connected(_on_heal_applied):
		heal_applied.disconnect(_on_heal_applied)
	if discard_applied.is_connected(_on_discard_applied):
		discard_applied.disconnect(_on_discard_applied)
	if opp_bar == null and player_bar == null:
		print("DEBUG effects: no health bars found for debug wiring")
		return
	damage_applied.connect(_on_damage_applied)
	heal_applied.connect(_on_heal_applied)
	discard_applied.connect(_on_discard_applied)
	print("DEBUG effects: damage routing active (player_bar=", player_bar, " opp_bar=", opp_bar, ")")

func register_effect(effect_data: Dictionary) -> String:
	var effect_id := _ensure_effect_id(effect_data)
	_effects_by_id[effect_id] = effect_data
	return effect_id


func unregister_effect(effect_id: String) -> void:
	if not _effects_by_id.has(effect_id):
		return
	_remove_from_queue(effect_id)
	_remove_from_persistent(effect_id)
	_remove_from_targets(effect_id)
	_effects_by_id.erase(effect_id)


func queue_effect(effect_data: Dictionary) -> String:
	var effect_id := register_effect(effect_data)
	_set_effect_state(effect_id, EffectState.QUEUED)
	_effect_queue.append(effect_id)
	_index_effect_targets(effect_id)
	effect_queued.emit(effect_id)
	return effect_id


func resolve_next() -> bool:
	if _effect_queue.is_empty():
		return false
	var effect_id: String = _effect_queue.pop_front()
	if not _effects_by_id.has(effect_id):
		return false
	var effect_data: Dictionary = _effects_by_id[effect_id]
	_set_effect_state(effect_id, EffectState.RESOLVING)
	effect_resolving.emit(effect_id)
	if _should_apply_on_resolve(effect_data):
		_apply_effect(effect_id)
	_set_effect_state(effect_id, EffectState.RESOLVED)
	effect_resolved.emit(effect_id)
	return true


func resolve_all() -> void:
	while resolve_next():
		pass


func get_active_effects() -> Array[String]:
	return _effects_by_id.keys()

func get_effect_data(effect_id: String) -> Dictionary:
	if not _effects_by_id.has(effect_id):
		return {}
	return _effects_by_id[effect_id]

func claim_effect(effect_id: String, tracker_id: String) -> bool:
	if not _effects_by_id.has(effect_id):
		return false
	var effect_data: Dictionary = _effects_by_id[effect_id]
	if str(effect_data.get("ui_tracker_id", "")) != "":
		return false
	effect_data["ui_tracker_id"] = tracker_id
	return true


func get_effects_on_target(target_key: Dictionary) -> Array[String]:
	var key := _target_key(target_key)
	if not _effects_by_target.has(key):
		return []
	return _effects_by_target[key]


func tick_end_of_round() -> void:
	# Resolve or expire persistent effects at end of round.
	for effect_id in _active_persistent.duplicate():
		if not _effects_by_id.has(effect_id):
			_active_persistent.erase(effect_id)
			continue
		var effect_data: Dictionary = _effects_by_id[effect_id]
		var duration := int(effect_data.get("duration_rounds", 0))
		if duration <= 0:
			_set_effect_state(effect_id, EffectState.EXPIRED)
			effect_expired.emit(effect_id)
			unregister_effect(effect_id)
			continue
		var kind = effect_data.get("kind", null)
		if _is_kind_replenish(kind):
			await _apply_replenish_async(effect_data)
		else:
			_apply_effect(effect_id)
		effect_data["duration_rounds"] = duration - 1
		effect_ticked.emit(effect_id, duration - 1)


func _apply_effect(effect_id: String) -> void:
	var effect_data: Dictionary = _effects_by_id.get(effect_id, {})
	var kind = effect_data.get("kind", null)
	if _is_kind_damage(kind):
		_apply_damage(effect_data)
	elif _is_kind_heal(kind):
		_apply_heal(effect_data)
	elif _is_kind_discard(kind):
		_apply_discard(effect_data)
	elif _is_kind_bleed(kind):
		_apply_bleed(effect_data)
	elif _is_kind_regenerate(kind):
		_apply_regenerate(effect_data)
	elif _is_kind_replenish(kind):
		_apply_replenish(effect_data)

func _is_kind_damage(kind) -> bool:
	# Handle enum kinds from CardDefinition and string fallbacks
	if typeof(kind) == TYPE_INT:
		return kind == CardDefinition.Kind.DAMAGE
	return str(kind).to_lower() == "damage"


func _is_kind_heal(kind) -> bool:
	if typeof(kind) == TYPE_INT:
		return kind == CardDefinition.Kind.HEAL
	return str(kind).to_lower() == "heal"


func _is_kind_discard(kind) -> bool:
	if typeof(kind) == TYPE_INT:
		return kind == CardDefinition.Kind.DISCARD
	return str(kind).to_lower() == "discard"

func _is_kind_bleed(kind) -> bool:
	if typeof(kind) == TYPE_INT:
		return kind == CardDefinition.Kind.BLEED
	return str(kind).to_lower() == "bleed"

func _is_kind_regenerate(kind) -> bool:
	if typeof(kind) == TYPE_INT:
		return kind == CardDefinition.Kind.REGENERATE
	return str(kind).to_lower() == "regenerate"

func _is_kind_replenish(kind) -> bool:
	if typeof(kind) == TYPE_INT:
		return kind == CardDefinition.Kind.REPLENISH
	return str(kind).to_lower() == "replenish"


func _apply_damage(effect_data: Dictionary) -> void:
	var amount := int(effect_data.get("amount", 0))
	if amount == 0:
		return
	var target_is_opponent: bool = effect_data.get("target_is_opponent", true)
	damage_applied.emit(amount, target_is_opponent)


func _apply_heal(effect_data: Dictionary) -> void:
	var amount := int(effect_data.get("amount", 0))
	if amount == 0:
		return
	var target_is_opponent: bool = effect_data.get("target_is_opponent", false)
	heal_applied.emit(amount, target_is_opponent)


func _apply_discard(effect_data: Dictionary) -> void:
	var count := int(effect_data.get("count", 0))
	if count == 0:
		return
	var source_is_opponent: bool = effect_data.get("source_is_opponent", false)
	var target_is_opponent: bool = effect_data.get("target_is_opponent", not source_is_opponent)
	discard_applied.emit(count, target_is_opponent)

func _apply_bleed(effect_data: Dictionary) -> void:
	var amount := int(effect_data.get("amount", 0))
	if amount == 0:
		return
	var source_is_opponent: bool = effect_data.get("source_is_opponent", false)
	var target_is_opponent: bool = effect_data.get("target_is_opponent", not source_is_opponent)
	damage_applied.emit(amount, target_is_opponent)

func _apply_regenerate(effect_data: Dictionary) -> void:
	var amount := int(effect_data.get("amount", 0))
	if amount == 0:
		return
	var source_is_opponent: bool = effect_data.get("source_is_opponent", false)
	var target_is_opponent: bool = effect_data.get("target_is_opponent", source_is_opponent)
	heal_applied.emit(amount, target_is_opponent)

func _apply_replenish(effect_data: Dictionary) -> void:
	var count := int(effect_data.get("count", 0))
	if count == 0:
		return
	var source_is_opponent: bool = effect_data.get("source_is_opponent", false)
	var target_is_opponent: bool = effect_data.get("target_is_opponent", source_is_opponent)
	_replenish_from_discard_auto(count, target_is_opponent)

func _should_apply_on_resolve(effect_data: Dictionary) -> bool:
	if not _is_persistent(effect_data):
		return true
	var kind = effect_data.get("kind", null)
	if _is_kind_bleed(kind):
		return false
	if _is_kind_regenerate(kind):
		return false
	if _is_kind_replenish(kind):
		return false
	return true

func _is_persistent(effect_data: Dictionary) -> bool:
	return str(effect_data.get("special_value", "")).to_lower() == "persistent"

func _replenish_from_discard(count: int, target_is_opponent: bool) -> void:
	var root: Node = get_tree().root
	var target_deck: Node = root.find_child("opp_deck", true, false) if target_is_opponent else root.find_child("deck", true, false)
	var target_discard: Node = root.find_child("opp_discard_pile", true, false) if target_is_opponent else root.find_child("discard_pile", true, false)
	if target_deck == null or target_discard == null:
		print("DEBUG effects: replenish target missing, target_is_opponent=", target_is_opponent)
		return
	_replenish_from_discard_auto(count, target_is_opponent)

func _replenish_from_discard_auto(count: int, target_is_opponent: bool) -> void:
	var root: Node = get_tree().root
	var target_deck: Node = root.find_child("opp_deck", true, false) if target_is_opponent else root.find_child("deck", true, false)
	var target_discard: Node = root.find_child("opp_discard_pile", true, false) if target_is_opponent else root.find_child("discard_pile", true, false)
	if target_deck == null or target_discard == null:
		print("DEBUG effects: replenish target missing, target_is_opponent=", target_is_opponent)
		return
	if not target_discard.has_method("pop_top_card"):
		print("DEBUG effects: discard pile missing pop_top_card")
		return
	if not target_deck.has_method("add_card_to_deck"):
		print("DEBUG effects: deck missing add_card_to_deck")
		return
	for i in range(count):
		var card: Control = target_discard.pop_top_card()
		if card == null:
			return
		target_deck.add_card_to_deck(card, true)

func _apply_replenish_async(effect_data: Dictionary) -> void:
	var count := int(effect_data.get("count", 0))
	if count == 0:
		return
	var target_is_opponent: bool = effect_data.get("target_is_opponent", false)
	if target_is_opponent:
		_replenish_from_discard_auto(count, true)
		return
	var root: Node = get_tree().root
	var menu: Node = root.find_child("DiscardPile_Menu", true, false)
	var target_discard: Node = root.find_child("discard_pile", true, false)
	var target_deck: Node = root.find_child("deck", true, false)
	if menu == null or target_discard == null or target_deck == null:
		_replenish_from_discard_auto(count, target_is_opponent)
		return
	if not menu.has_method("choose_cards"):
		_replenish_from_discard_auto(count, target_is_opponent)
		return
	if not target_discard.has_method("get_cards") or not target_discard.has_method("remove_card"):
		_replenish_from_discard_auto(count, target_is_opponent)
		return
	if not target_deck.has_method("add_card_to_deck"):
		_replenish_from_discard_auto(count, target_is_opponent)
		return
	var cards: Array = target_discard.get_cards()
	if cards.is_empty():
		return
	var chosen: Array = await menu.choose_cards(cards, false, count)
	for card in chosen:
		if card == null:
			continue
		target_discard.remove_card(card)
		target_deck.add_card_to_deck(card, true)


func _on_damage_applied(amount: int, target_is_opponent: bool) -> void:
	var root: Node = get_tree().root
	var opp_bar: Node = root.find_child("Opp_HealthBar", true, false)
	var player_bar: Node = root.find_child("HealthBar", true, false)
	var target: Node = opp_bar if target_is_opponent else player_bar
	if target and target.has_method("apply_damage"):
		target.apply_damage(amount)
	else:
		print("DEBUG effects: target bar missing for damage, target_is_opponent=", target_is_opponent)


func _on_heal_applied(amount: int, target_is_opponent: bool) -> void:
	var root: Node = get_tree().root
	var opp_bar: Node = root.find_child("Opp_HealthBar", true, false)
	var player_bar: Node = root.find_child("HealthBar", true, false)
	var target: Node = opp_bar if target_is_opponent else player_bar
	if target and target.has_method("apply_heal"):
		target.apply_heal(amount)
	else:
		print("DEBUG effects: target bar missing for heal, target_is_opponent=", target_is_opponent)


func _on_discard_applied(count: int, target_is_opponent: bool) -> void:
	var root: Node = get_tree().root
	var opp_deck: Node = root.find_child("opp_deck", true, false)
	var player_deck: Node = root.find_child("deck", true, false)
	var opp_discard: Node = root.find_child("opp_discard_pile", true, false)
	var player_discard: Node = root.find_child("discard_pile", true, false)
	
	# Target opponent's deck or player's deck
	var target_deck: Node = opp_deck if target_is_opponent else player_deck
	var target_discard: Node = opp_discard if target_is_opponent else player_discard
	
	if target_deck == null:
		print("DEBUG effects: target deck missing for discard, target_is_opponent=", target_is_opponent)
		return
	
	if target_discard == null:
		print("DEBUG effects: target discard pile missing, target_is_opponent=", target_is_opponent)
		return
	
	if target_deck.has_method("discard_top_cards"):
		target_deck.discard_top_cards(count, target_discard)
	else:
		print("DEBUG effects: deck doesn't have discard_top_cards method")



func _ensure_effect_id(effect_data: Dictionary) -> String:
	if effect_data.has("id") and str(effect_data["id"]) != "":
		return str(effect_data["id"])
	var id := "effect_%s" % str(Time.get_ticks_msec())
	effect_data["id"] = id
	return id


func _set_effect_state(effect_id: String, state: int) -> void:
	if not _effects_by_id.has(effect_id):
		return
	_effects_by_id[effect_id]["state"] = state


func _remove_from_queue(effect_id: String) -> void:
	_effect_queue.erase(effect_id)


func _remove_from_persistent(effect_id: String) -> void:
	_active_persistent.erase(effect_id)


func _index_effect_targets(effect_id: String) -> void:
	var effect_data: Dictionary = _effects_by_id.get(effect_id, {})
	var targets: Array = effect_data.get("targets", [])
	for target in targets:
		var key := _target_key(target)
		if not _effects_by_target.has(key):
			_effects_by_target[key] = []
		_effects_by_target[key].append(effect_id)
	if effect_data.get("special_value", "none") == "persistent":
		if not _active_persistent.has(effect_id):
			_active_persistent.append(effect_id)


func _remove_from_targets(effect_id: String) -> void:
	for key in _effects_by_target.keys():
		var list: Array = _effects_by_target[key]
		list.erase(effect_id)
		if list.is_empty():
			_effects_by_target.erase(key)


func _target_key(target: Dictionary) -> String:
	var target_type := str(target.get("target_type", ""))
	var target_is_opponent := str(target.get("target_is_opponent", false))
	var target_id := str(target.get("target_id", ""))
	return "%s:%s:%s" % [target_type, target_is_opponent, target_id]
