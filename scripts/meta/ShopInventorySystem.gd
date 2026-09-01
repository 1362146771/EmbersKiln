extends Node
## Autoload: ShopInventorySystem —— 保存每个商店货架并只刷新未购买槽位。

const PLACEMENT := &"shop_refresh"


func _ready() -> void:
	AdRewardCoordinator.register_placement_handler(PLACEMENT, _is_refresh_eligible, _grant_refresh)


func current_shop_id() -> String:
	return RunState.shop_session_id()


func has_state(shop_id: String) -> bool:
	return not shop_id.is_empty() and RunState.shop_states.has(shop_id)


func get_state(shop_id: String) -> Dictionary:
	return RunState.shop_states.get(shop_id, {}).duplicate(true)


func capture_state(
	shop_id: String,
	card_stock: Array,
	relic_stock: Array,
	potion_stock: Array,
	refresh_count: int = 0
) -> bool:
	if shop_id.is_empty() or refresh_count < 0:
		return false
	RunState.shop_states[shop_id] = {
		"card_stock": card_stock.duplicate(true),
		"relic_stock": relic_stock.duplicate(true),
		"potion_stock": potion_stock.duplicate(true),
		"refresh_count": refresh_count,
	}
	if RunState.is_active:
		SaveManager.save_game()
	return true


func is_refresh_configured() -> bool:
	var value: Variant = GameData.ad_placement_config(PLACEMENT).get("max_per_shop", null)
	return (value is int or value is float) and int(value) > 0


func refresh_limit() -> int:
	return int(GameData.ad_placement_config(PLACEMENT).get("max_per_shop", 0)) if is_refresh_configured() else 0


func remaining_refreshes(shop_id: String) -> int:
	if not is_refresh_configured() or not has_state(shop_id):
		return 0
	return maxi(0, refresh_limit() - int(get_state(shop_id).get("refresh_count", 0)))


func refresh_block_reason(shop_id: String) -> String:
	if not is_refresh_configured():
		return "每个商店的广告刷新次数尚未配置"
	if not RunState.is_active or not has_state(shop_id):
		return "当前商店状态不可用"
	if remaining_refreshes(shop_id) <= 0:
		return "本商店的广告刷新次数已用尽"
	if not _has_alternative(get_state(shop_id)):
		return "商品池中没有可替换的新商品"
	if AdService.is_busy():
		return "正在播放其他广告"
	if not AdService.is_available(PLACEMENT):
		return "当前没有可用广告"
	return ""


func can_offer_refresh(shop_id: String) -> bool:
	return AdRewardCoordinator.can_offer(PLACEMENT, {"run_id": RunState.run_id, "shop_id": shop_id})


func request_refresh(shop_id: String) -> String:
	return AdRewardCoordinator.request_reward(PLACEMENT, {"run_id": RunState.run_id, "shop_id": shop_id})


func commit_card_purchase(shop_id: String, slot_index: int, expected_card_id: StringName, expected_price: int) -> bool:
	if not RunState.is_active or not has_state(shop_id) or not RunState.can_add_permanent_card():
		return false
	var state := get_state(shop_id)
	var stock: Array = state.get("card_stock", [])
	if slot_index < 0 or slot_index >= stock.size():
		return false
	var item: Dictionary = stock[slot_index]
	if bool(item.get("bought", false)) or int(item.get("price", -1)) != expected_price or RunState.gold < expected_price:
		return false
	if StringName(String(item.get("card", {}).get("id", ""))) != expected_card_id:
		return false

	var old_gold := RunState.gold
	var old_deck := RunState.deck.duplicate(true)
	var old_state := get_state(shop_id)
	RunState.gold -= expected_price
	RunState.deck.append({"id": expected_card_id, "upgraded": false, "enchants": []})
	item["bought"] = true
	stock[slot_index] = item
	state["card_stock"] = stock
	RunState.shop_states[shop_id] = state
	if not SaveManager.save_game():
		RunState.gold = old_gold
		RunState.deck.assign(old_deck)
		RunState.shop_states[shop_id] = old_state
		return false
	SignalBus.gold_changed.emit(RunState.gold)
	SignalBus.deck_changed.emit()
	SignalBus.shop_inventory_changed.emit(shop_id)
	return true


func _is_refresh_eligible(context: Dictionary) -> bool:
	if not is_refresh_configured() or not RunState.is_active:
		return false
	if String(context.get("run_id", "")) != RunState.run_id:
		return false
	var shop_id := String(context.get("shop_id", ""))
	if not has_state(shop_id):
		return false
	var state := get_state(shop_id)
	if int(state.get("refresh_count", 0)) >= int(GameData.ad_placement_config(PLACEMENT)["max_per_shop"]):
		return false
	return _has_alternative(state)


func _grant_refresh(transaction_id: String, context: Dictionary) -> void:
	if RunState.has_run_ad_transaction(transaction_id):
		ProfileState.complete_reward_transaction(transaction_id)
		return
	if not _is_refresh_eligible(context):
		return
	var shop_id := String(context["shop_id"])
	var old_state := get_state(shop_id)
	var old_transactions := RunState.ad_reward_transaction_ids.duplicate()
	var next_state := _refreshed_state(old_state)
	if next_state == old_state:
		return
	next_state["refresh_count"] = int(old_state.get("refresh_count", 0)) + 1
	RunState.shop_states[shop_id] = next_state
	RunState.record_run_ad_transaction(transaction_id)
	if not SaveManager.save_game():
		RunState.shop_states[shop_id] = old_state
		RunState.ad_reward_transaction_ids.assign(old_transactions)
		return
	ProfileState.complete_reward_transaction(transaction_id)
	SignalBus.shop_inventory_changed.emit(shop_id)


func _has_alternative(state: Dictionary) -> bool:
	var excluded_cards: Array = []
	var open_card_slots := 0
	for item in state.get("card_stock", []):
		if not bool(item.get("bought", false)):
			open_card_slots += 1
			excluded_cards.append(StringName(String(item.get("card", {}).get("id", ""))))
	if open_card_slots > 0:
		for card_id in GameData.cards:
			var card: CardData = GameData.get_card(card_id)
			if card != null and GameData.is_card_unlocked(card_id) and card.rarity != &"starter" and card.rarity != &"special" and not excluded_cards.has(card_id):
				return true
	var excluded_relics: Array = []
	for item in state.get("relic_stock", []):
		if not bool(item.get("bought", false)):
			excluded_relics.append(StringName(String(item.get("id", ""))))
	if not excluded_relics.is_empty():
		for relic_id in GameData.relics:
			var relic: RelicData = GameData.get_relic(relic_id)
			if relic != null and GameData.is_relic_unlocked(relic_id) and relic.rarity != &"starter" and not RunState.relic_ids.has(relic_id) and not excluded_relics.has(relic_id):
				return true
	var excluded_potions: Array = []
	var open_potion_slots := 0
	for item in state.get("potion_stock", []):
		if not bool(item.get("bought", false)):
			open_potion_slots += 1
			excluded_potions.append(StringName(String(item.get("id", ""))))
	if open_potion_slots > 0:
		for potion_id in GameData.potions:
			if GameData.is_potion_unlocked(potion_id) and not excluded_potions.has(potion_id):
				return true
	return false


func _refreshed_state(state: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	var card_stock: Array = next.get("card_stock", [])
	var excluded_cards: Array = []
	var open_card_indices: Array[int] = []
	for index in card_stock.size():
		if not bool(card_stock[index].get("bought", false)):
			open_card_indices.append(index)
			excluded_cards.append(StringName(String(card_stock[index].get("card", {}).get("id", ""))))
	var new_cards := RewardBuilder.roll_card_choices_excluding(open_card_indices.size(), excluded_cards)
	for offset in mini(open_card_indices.size(), new_cards.size()):
		var index := open_card_indices[offset]
		card_stock[index] = {
			"card": new_cards[offset],
			"price": _card_price(new_cards[offset]),
			"bought": false,
		}
	next["card_stock"] = card_stock

	var relic_stock: Array = next.get("relic_stock", [])
	var excluded_relics: Array = []
	for item in relic_stock:
		if not bool(item.get("bought", false)):
			excluded_relics.append(StringName(String(item.get("id", ""))))
	for index in relic_stock.size():
		if bool(relic_stock[index].get("bought", false)):
			continue
		var relic_id := RewardBuilder.roll_shop_relic_excluding(excluded_relics)
		if relic_id != &"":
			excluded_relics.append(relic_id)
			relic_stock[index] = {"id": relic_id, "price": _relic_price(relic_id), "bought": false}
	next["relic_stock"] = relic_stock

	var potion_stock: Array = next.get("potion_stock", [])
	var excluded_potions: Array = []
	for item in potion_stock:
		if not bool(item.get("bought", false)):
			excluded_potions.append(StringName(String(item.get("id", ""))))
	var potion_candidates: Array = []
	for potion_id in GameData.potions:
		if GameData.is_potion_unlocked(potion_id) and not excluded_potions.has(potion_id):
			potion_candidates.append(potion_id)
	potion_candidates.shuffle()
	var candidate_index := 0
	for index in potion_stock.size():
		if bool(potion_stock[index].get("bought", false)) or candidate_index >= potion_candidates.size():
			continue
		var potion_id := StringName(potion_candidates[candidate_index])
		candidate_index += 1
		potion_stock[index] = {"id": potion_id, "price": _potion_price(potion_id), "bought": false}
	next["potion_stock"] = potion_stock
	return next


func _card_price(card: Dictionary) -> int:
	var prices: Array = GameData.balance.get("shop", {}).get("card_cost", [])
	return int(prices[mini(_rarity_index(StringName(card.get("rarity", "common"))), prices.size() - 1)]) if not prices.is_empty() else 0


func _relic_price(relic_id: StringName) -> int:
	var prices: Array = GameData.balance.get("shop", {}).get("relic_cost", [])
	var relic: RelicData = GameData.get_relic(relic_id)
	return int(prices[mini(_rarity_index(relic.rarity if relic != null else &"common"), prices.size() - 1)]) if not prices.is_empty() else 0


func _potion_price(potion_id: StringName) -> int:
	var prices: Array = GameData.balance.get("shop", {}).get("potion_cost", [])
	var potion: PotionData = GameData.get_potion(potion_id)
	return int(prices[mini(_rarity_index(potion.rarity if potion != null else &"common"), prices.size() - 1)]) if not prices.is_empty() else 0


func _rarity_index(rarity: StringName) -> int:
	match rarity:
		&"uncommon": return 1
		&"rare": return 2
		_: return 0
