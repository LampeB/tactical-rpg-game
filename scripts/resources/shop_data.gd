class_name ShopData
extends Resource
## Defines a shop's inventory and pricing.

@export var id: String = ""
@export var display_name: String = ""
@export var shop_type: Enums.ShopType = Enums.ShopType.GENERAL_GOODS
@export var pricing_type: Enums.PricingType = Enums.PricingType.FIXED

## Items available for purchase.
@export var stock: Array = [] ## of ItemData

## Price override per item (by item ID). If not set, uses item's base_price.
@export var price_overrides: Dictionary = {}

## Buy price multiplier (1.0 = normal).
@export var buy_multiplier: float = 1.0
## Sell price multiplier (1.0 = normal, typically 0.5).
@export var sell_multiplier: float = 0.5
