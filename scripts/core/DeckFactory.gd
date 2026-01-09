extends Node
class_name DeckFactory

static func build_standard_deck() -> Array[CardDefinition]:
	var deck: Array[CardDefinition] = []
	deck.append_array(_make_cards("Damage 25", CardDefinition.Kind.DAMAGE, "red", 25, 0, 1, 0, "none", CardDefinition.IconTier.BIG))
	deck.append_array(_make_cards("Damage 15", CardDefinition.Kind.DAMAGE, "red", 15, 0, 2, 0, "none", CardDefinition.IconTier.MED))
	deck.append_array(_make_cards("Damage 10", CardDefinition.Kind.DAMAGE, "red", 10, 0, 5, 0, "none", CardDefinition.IconTier.SMALL))

	deck.append_array(_make_cards("Heal 15", CardDefinition.Kind.HEAL, "yellow", 15, 0, 2, 0, "none", CardDefinition.IconTier.BIG))
	deck.append_array(_make_cards("Heal 10", CardDefinition.Kind.HEAL, "yellow", 10, 0, 3, 0, "none", CardDefinition.IconTier.MED))
	deck.append_array(_make_cards("Heal 5", CardDefinition.Kind.HEAL, "yellow", 5, 0, 3, 0, "none", CardDefinition.IconTier.SMALL))

	deck.append_array(_make_cards("Discard 2", CardDefinition.Kind.DISCARD, "blue", 0, 2, 6, 0, "none", CardDefinition.IconTier.SMALL))
	deck.append_array(_make_cards("Discard 3", CardDefinition.Kind.DISCARD, "blue", 0, 3, 2, 0, "none", CardDefinition.IconTier.BIG))

	deck.append_array(_make_cards("Regenerate", CardDefinition.Kind.REGENERATE, "white", 4, 0, 1, 3, "persistent"))
	deck.append_array(_make_cards("Bleed", CardDefinition.Kind.BLEED, "black", 4, 0, 1, 3, "persistent"))
	deck.append_array(_make_cards("Replenish", CardDefinition.Kind.REPLENISH, "green", 0, 1, 1, 3, "persistent"))
	deck.append_array(_make_cards("Balance", CardDefinition.Kind.BALANCE, "gradient", 0, 0, 1, 0, "dynamic"))
	return deck


static func _make_cards(
	card_name: String,
	kind: CardDefinition.Kind,
	suit: String,
	amount: int,
	count: int,
	copies: int,
	duration_rounds: int = 0,
	special_value: String = "none",
	icon_tier: CardDefinition.IconTier = CardDefinition.IconTier.UNIQUE
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
		defn.icon_tier = icon_tier
		cards.append(defn)
	return cards
