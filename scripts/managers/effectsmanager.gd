extends Node

signal effect_queued(effect_id: String)
signal effect_resolving(effect_id: String)
signal effect_resolved(effect_id: String)
signal effect_expired(effect_id: String)
signal damage_applied(amount: int, target_is_opponent: bool)

enum EffectState { QUEUED, RESOLVING, RESOLVED, EXPIRED, CANCELLED }

var _effects_by_id: Dictionary = {}
var _effect_queue: Array[String] = []
var _active_persistent: Array[String] = []
var _effects_by_target: Dictionary = {}

func _ready() -> void:
	add_to_group("effects_manager")
	call_deferred("_wire_debug_health")

func _wire_debug_health() -> void:
	var root := get_tree().root
	var opp_bar := root.find_child("Opp_HealthBar", true, false)
	var player_bar := root.find_child("HealthBar", true, false)
	if damage_applied.is_connected(_on_damage_applied):
		damage_applied.disconnect(_on_damage_applied)
	if opp_bar == null and player_bar == null:
		print("DEBUG effects: no health bars found for debug wiring")
		return
	damage_applied.connect(_on_damage_applied)
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
	_set_effect_state(effect_id, EffectState.RESOLVING)
	effect_resolving.emit(effect_id)
	_apply_effect(effect_id)
	_set_effect_state(effect_id, EffectState.RESOLVED)
	effect_resolved.emit(effect_id)
	return true


func resolve_all() -> void:
	while resolve_next():
		pass


func get_active_effects() -> Array[String]:
	return _effects_by_id.keys()


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
		_apply_effect(effect_id)
		effect_data["duration_rounds"] = duration - 1


func _apply_effect(effect_id: String) -> void:
	var effect_data: Dictionary = _effects_by_id.get(effect_id, {})
	var kind = effect_data.get("kind", null)
	if _is_kind_damage(kind):
		_apply_damage(effect_data)

func _is_kind_damage(kind) -> bool:
	# Handle enum kinds from CardDefinition and string fallbacks
	if typeof(kind) == TYPE_INT:
		return kind == CardDefinition.Kind.DAMAGE
	return str(kind).to_lower() == "damage"


func _apply_damage(effect_data: Dictionary) -> void:
	var amount := int(effect_data.get("amount", 0))
	if amount == 0:
		return
	var target_is_opponent: bool = effect_data.get("target_is_opponent", true)
	damage_applied.emit(amount, target_is_opponent)


func _on_damage_applied(amount: int, target_is_opponent: bool) -> void:
	var root := get_tree().root
	var opp_bar := root.find_child("Opp_HealthBar", true, false)
	var player_bar := root.find_child("HealthBar", true, false)
	var target := opp_bar if target_is_opponent else player_bar
	if target and target.has_method("apply_damage"):
		target.apply_damage(amount)
	else:
		print("DEBUG effects: target bar missing for damage, target_is_opponent=", target_is_opponent)



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
