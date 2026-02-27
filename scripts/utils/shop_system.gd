class_name ShopSystem
extends RefCounted
## Stateless utility for shop price calculations.
## All methods are static, no scene tree or autoload dependency.
## The authoritative shop configuration lives in ShopData resources.


## Returns the gold cost the player must pay to BUY an item from a shop.
## Respects per-item price overrides in the shop data, then applies buy_multiplier.
static func get_buy_price(item: ItemData, shop_data: ShopData) -> int:
	if not shop_data:
		return item.base_price
	var base: int = shop_data.price_overrides.get(item.id, item.base_price)
	return roundi(base * shop_data.buy_multiplier)


## Returns the gold the player receives when SELLing an item to a shop.
## This is the base sell value (base_price * sell_multiplier).
## Session-specific refund logic (e.g. full refund for items bought this visit)
## is handled by the caller.
static func get_sell_price(item: ItemData, shop_data: ShopData) -> int:
	if not shop_data:
		return item.base_price
	return roundi(item.base_price * shop_data.sell_multiplier)
