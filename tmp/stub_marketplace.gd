extends Node
signal marketplace_loaded(listings: Array)
signal listing_step(message: String)
signal listing_complete(listing_id: String)
signal listing_failed(error: String)
signal purchase_complete(sticker_name: String)
signal purchase_failed(error: String)
signal credits_received(amount: int)
var is_listing: bool = false
var is_buying: bool = false
var is_fetching: bool = false
func fetch_marketplace() -> void: pass
func fetch_pending_credits() -> void: pass
func list_sticker(_a: String, _b: int, _c: PackedByteArray) -> void: pass
func buy_sticker(_a: String, _b: int, _c: String, _d: String) -> void: pass
