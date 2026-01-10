extends Node

@export var min_delay: float = 0.5

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	print("AI Manager autoload: _ready() called")
	_rng.randomize()
	add_to_group("ai_manager")
	print("AI Manager: added to ai_manager group")


func schedule_opponent_play(opponent_hand: Node, round_manager: Node, max_delay: float) -> void:
	if opponent_hand == null or round_manager == null:
		print("AI: opponent_hand or round_manager is null")
		return
	print("AI: scheduling play with max_delay = ", max_delay)
	var delay := _rng.randf_range(min_delay, max_delay)
	print("AI: actual delay = ", delay)
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(opponent_hand) or not is_instance_valid(round_manager):
		print("AI: nodes invalid after delay")
		return
	if round_manager.has_method("has_played_card") and round_manager.call("has_played_card", true):
		print("AI: AI already played")
		return
	var card := _pick_random_card(opponent_hand)
	if card == null:
		print("AI: no card found to play")
		return
	print("AI: playing card ", card)
	if round_manager.has_method("place_played_card"):
		round_manager.call("place_played_card", card, true, false)


func _pick_random_card(hand: Node) -> Control:
	var candidates: Array[Control] = []
	for child in hand.get_children():
		if child is Control and child.has_method("set_face_down"):
			candidates.append(child)
	if candidates.is_empty():
		return null
	var index := _rng.randi_range(0, candidates.size() - 1)
	return candidates[index]
