extends Resource
class_name CardDefinition

enum Kind { DAMAGE, HEAL, DISCARD, REGENERATE, BLEED, REPLENISH, BALANCE }
enum IconTier { SMALL, MED, BIG, UNIQUE }

@export var icon_tier: IconTier = IconTier.UNIQUE
@export var icon_override: Texture2D

@export var id: String
@export var kind: Kind
@export_enum("red", "yellow", "blue", "white", "black", "green", "gradient") var suit: String = "red"
@export_enum("none", "persistent", "dynamic") var special_value: String = "none"

# Use int, not string, so math is safe
@export var amount: int = 0            # damage or heal or per tick
@export var count: int = 0             # discard count, replenish choose count
@export var duration_rounds: int = 0   # persistent rounds

@export var icon: Texture2D

static func get_suit_colors(suit_value: String) -> Dictionary:
	var normalized := suit_value.to_lower()
	match normalized:
		"red":
			return {
				"a": Color("bc0200"),
				"b": Color("000000")
			}
		"yellow":
			return {
				"a": Color("bc9300"),
				"b": Color("261b00")
			}
		"blue":
			return {
				"a": Color("1f4cff"),
				"b": Color("000000")
			}
		"white":
			return {
				"a": Color("eff4ff"),
				"b": Color("000000")
			}
		"black":
			return {
				"a": Color("555555"),
				"b": Color("000000")
			}
		"green":
			return {
				"a": Color("1c7b43"),
				"b": Color("000000")
			}
		"balance", "gradient":
			return {
				"a": Color("ff8800"),
				"b": Color("7b3fe4")
			}
		_:
			return {}


func get_description() -> String:
	match kind:
		Kind.DAMAGE:
			return "Remove %d points from your opponent’s Health total." % amount
		Kind.HEAL:
			return "Add %d points to your Health total." % amount
		Kind.DISCARD:
			return "Discard the top %d cards from your opponent’s deck." % count
		Kind.REGENERATE:
			return "For the next %d rounds, at the end of the round, add %d points to your Health total." % [duration_rounds, amount]
		Kind.BLEED:
			return "For the next %d rounds, at the end of the round, remove %d points from your opponent’s Health total." % [duration_rounds, amount]
		Kind.REPLENISH:
			return "For the next %d rounds, at the end of the round, choose %d card from your discard pile. Shuffle it into your deck." % [duration_rounds, max(1, count)]
		Kind.BALANCE:
			return "If your opponent’s Health is higher, deal damage equal to the difference. If your Health is lower, restore Health equal to the difference."
		_:
			return "No description available."

func get_icon() -> Texture2D:
	if icon_override:
		return icon_override

	match kind:
		Kind.DAMAGE:
			return _tier_icon("res://assets/Card/Images/", "damage", icon_tier)
		Kind.HEAL:
			return _tier_icon("res://assets/Card/Images/", "heal", icon_tier)
		Kind.DISCARD:
			return _tier_icon("res://assets/Card/Images/", "discard", icon_tier)
		Kind.BALANCE:
			return load("res://assets/Card/Images/balance.png")
		Kind.BLEED:
			return load("res://assets/Card/Images/bleed.png")
		Kind.REGENERATE:
			return load("res://assets/Card/Images/regenerate.png")
		Kind.REPLENISH:
			return load("res://assets/Card/Images/replenish.png")
		_:
			return null

func _tier_icon(base_path: String, prefix: String, tier: IconTier) -> Texture2D:
	if tier == IconTier.UNIQUE:
		var unique_path := base_path + prefix + ".png"
		if ResourceLoader.exists(unique_path):
			return load(unique_path)
		tier = IconTier.SMALL
	var suffix_order: Array[String] = []
	match tier:
		IconTier.BIG:
			suffix_order = ["BIG", "MED", "SMALL"]
		IconTier.MED:
			suffix_order = ["MED", "SMALL", "BIG"]
		_:
			suffix_order = ["SMALL", "MED", "BIG"]
	for suffix in suffix_order:
		var path := base_path + prefix + suffix + ".png"
		if ResourceLoader.exists(path):
			return load(path)
	return null
