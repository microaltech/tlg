extends Node
## Autoload "Store": proses pembayaran pembelian dalam aplikasi.
##
## - Google Play Billing: aktif otomatis bila plugin GodotGooglePlayBilling terpasang di build
##   Android. Ditulis mengikuti API plugin v1 (startConnection, querySkuDetails, purchase,
##   consumePurchase, acknowledgePurchase, queryPurchases) dan BELUM diuji di perangkat;
##   uji dulu lewat jalur pengujian internal Play Console sebelum rilis.
## - Mode Uji: pembayaran disimulasikan. Hanya di build debug, supaya build rilis tanpa
##   plugin tidak membagikan emas gratis (toko dinonaktifkan).
##
## Isi produk diberikan oleh GameModel.grant_purchase (aman dari transaksi ganda).

signal purchase_completed(result: Dictionary)
signal purchase_failed(message: String)
signal prices_updated

const Data := preload("res://scripts/core/game_data.gd")
const PURCHASED := 1  ## purchase_state "PURCHASED" pada plugin.

enum Mode { PLAY_BILLING, TEST, UNAVAILABLE }

var mode := Mode.UNAVAILABLE
var connected := false
## id produk -> harga lokal dari Google Play (mis. "Rp 75.000").
var prices := {}
var _billing: Object = null


func _ready() -> void:
	if Engine.has_singleton("GodotGooglePlayBilling"):
		_billing = Engine.get_singleton("GodotGooglePlayBilling")
		mode = Mode.PLAY_BILLING
		_connect_signal("connected", _on_connected)
		_connect_signal("disconnected", func(): connected = false)
		_connect_signal("connect_error", func(_code, msg): push_warning("Billing gagal terhubung: %s" % msg))
		_connect_signal("purchases_updated", _on_purchases_updated)
		_connect_signal("purchase_error", func(_code, msg): purchase_failed.emit("Pembelian gagal: %s" % msg))
		_connect_signal("sku_details_query_completed", _on_sku_details)
		_connect_signal("query_purchases_response", _on_query_purchases)
		_billing.startConnection()
	elif OS.is_debug_build():
		mode = Mode.TEST


func _connect_signal(sig: String, callable: Callable) -> void:
	if _billing.has_signal(sig):
		_billing.connect(sig, callable)
	else:
		push_warning("Plugin billing tidak punya sinyal '%s'; periksa versi plugin." % sig)


func available() -> bool:
	return mode == Mode.TEST or (mode == Mode.PLAY_BILLING and connected)


func price_text(id: String) -> String:
	return prices.get(id, Data.format_idr(int(Data.iap_def(id).get("price_idr", 0))))


## Mulai pembelian. Di Mode Uji, UI menampilkan konfirmasi lalu memanggil complete_test_purchase.
func purchase(id: String) -> void:
	match mode:
		Mode.PLAY_BILLING:
			if not connected:
				purchase_failed.emit("Belum terhubung ke Google Play. Coba lagi sebentar.")
				return
			_billing.purchase(id)
		Mode.TEST:
			complete_test_purchase(id)
		_:
			purchase_failed.emit("Toko belum tersedia di versi ini.")


func complete_test_purchase(id: String) -> void:
	var token := "uji-%d-%d" % [Time.get_ticks_usec(), randi()]
	_grant(id, token)


func restore() -> void:
	if mode == Mode.PLAY_BILLING and connected:
		_billing.queryPurchases("inapp")
	else:
		purchase_failed.emit("Tidak ada pembelian yang perlu dipulihkan.")


func _grant(id: String, token: String) -> Dictionary:
	var r: Dictionary = Game.model.grant_purchase(id, token, Game.now())
	if r["ok"]:
		Game.save_game()
		purchase_completed.emit(r)
	elif not r.get("duplicate", false):
		purchase_failed.emit(r["msg"])
	return r


# --- Callback Google Play Billing ------------------------------------------

func _on_connected() -> void:
	connected = true
	var ids := []
	for p in Data.IAP_PRODUCTS:
		ids.append(p["id"])
	_billing.querySkuDetails(ids, "inapp")
	# Pulihkan pembelian yang belum sempat diproses (mis. aplikasi tertutup saat membayar).
	_billing.queryPurchases("inapp")


func _on_sku_details(details: Array) -> void:
	for d in details:
		if d.has("sku") and d.has("price"):
			prices[d["sku"]] = d["price"]
	prices_updated.emit()


func _on_query_purchases(result: Dictionary) -> void:
	if int(result.get("status", 1)) == OK:
		_on_purchases_updated(result.get("purchases", []))


func _on_purchases_updated(purchases: Array) -> void:
	for p in purchases:
		if int(p.get("purchase_state", 0)) != PURCHASED:
			continue  # tertunda (mis. bayar di minimarket): diproses saat statusnya berubah
		var id: String = p["sku"] if p.has("sku") else (p.get("skus", [""])[0])
		var token: String = p.get("purchase_token", "")
		var r := _grant(id, token)
		if not r["ok"] and not r.get("duplicate", false):
			continue
		# Habiskan produk yang bisa dibeli ulang; produk sekali beli cukup di-acknowledge.
		if Data.iap_def(id).get("type", "") == "once":
			if not p.get("is_acknowledged", false):
				_billing.acknowledgePurchase(token)
		else:
			_billing.consumePurchase(token)
