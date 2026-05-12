extends VBoxContainer
## Vertical party rail. Composes one `PartyCard` per squad member.
## Owns selection state and emits `character_selected`.

signal character_selected(character_id: String)

const PartyCardScene: PackedScene = preload("res://scenes/ui/components/party_card.tscn")

var _current_id: String = ""
var _cards: Dictionary = {}  ## character_id -> PartyCard


func setup(squad: Array, roster: Dictionary) -> void:
	for child in get_children():
		child.queue_free()
	_cards.clear()
	add_theme_constant_override("separation", 8)

	for i in range(squad.size()):
		var char_id: String = squad[i]
		var char_data: CharacterData = roster.get(char_id)
		if not char_data:
			continue
		var card: PartyCard = PartyCardScene.instantiate()
		add_child(card)
		var hp_cur: int = char_data.max_hp
		var mp_cur: int = char_data.max_mp
		if GameManager.party:
			hp_cur = GameManager.party.get_current_hp(char_id)
			mp_cur = GameManager.party.get_current_mp(char_id)
		card.setup(char_id, char_data, hp_cur, mp_cur)
		card.card_pressed.connect(_on_card_pressed)
		_cards[char_id] = card


func select(character_id: String) -> void:
	_current_id = character_id
	for id in _cards:
		_cards[id].button_pressed = (id == character_id)


func _on_card_pressed(character_id: String) -> void:
	if character_id == _current_id:
		_cards[character_id].button_pressed = true
		return
	select(character_id)
	character_selected.emit(character_id)
