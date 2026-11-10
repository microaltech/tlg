extends Control
## Langit kota yang mengikuti jam HP dan musim: fajar/senja keemasan, malam biru
## berbintang, dan hujan rintik di musim penghujan. Hanya lapisan gambar di atas
## spanduk kota; tidak memengaruhi permainan. Hemat baterai: digambar ulang 10x/detik.

const RAIN_DROPS := 70
const STARS := 40

var season := "kemarau"
var hour_override := -1.0  ## untuk tes/tangkapan layar
var _rng := RandomNumberGenerator.new()
var _drops: Array = []
var _stars: Array = []
var _timer := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 7
	for i in RAIN_DROPS:
		_drops.append(Vector3(_rng.randf(), _rng.randf(), _rng.randf_range(0.6, 1.0)))
	for i in STARS:
		_stars.append(Vector3(_rng.randf(), _rng.randf() * 0.55, _rng.randf_range(1.0, 2.6)))


func hour() -> float:
	if hour_override >= 0.0:
		return hour_override
	var t := Time.get_time_dict_from_system()
	return float(t["hour"]) + float(t["minute"]) / 60.0


## Warna lapisan langit menurut jam (alfa = kekuatan).
static func tint(h: float) -> Color:
	if h < 4.5 or h >= 19.5:
		return Color(0.04, 0.07, 0.22, 0.55)  # malam
	if h < 6.5:
		return Color(0.95, 0.55, 0.3, 0.28 * (1.0 - (h - 4.5) / 2.0) + 0.1)  # fajar
	if h >= 17.0:
		return Color(0.95, 0.45, 0.2, 0.12 + 0.3 * (h - 17.0) / 2.5)  # senja
	return Color(1, 1, 1, 0.0)  # siang


func is_night(h: float) -> bool:
	return h < 4.5 or h >= 19.5


func _process(delta: float) -> void:
	_timer += delta
	if _timer < 0.1:
		return
	_timer = 0.0
	if season == "penghujan" or is_night(hour()):
		queue_redraw()


func _draw() -> void:
	var h := hour()
	var c := tint(h)
	if c.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), c)
	if is_night(h):
		var tw := Time.get_ticks_msec() / 600.0
		for s in _stars:
			var a := 0.5 + 0.5 * sin(tw + s.x * 20.0)
			draw_circle(Vector2(s.x * size.x, s.y * size.y), s.z, Color(1, 1, 0.9, a))
	if season == "penghujan":
		var t := Time.get_ticks_msec() / 1000.0
		for d in _drops:
			var y := fposmod(d.y + t * 0.9 * d.z, 1.0) * (size.y + 30.0) - 30.0
			var x := fposmod(d.x * size.x - y * 0.25, size.x)
			draw_line(Vector2(x, y), Vector2(x - 6, y + 20 * d.z), Color(0.8, 0.88, 1.0, 0.45), 2.0)
