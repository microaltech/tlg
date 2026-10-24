extends RefCounted
## Pemuat gambar. Mencari PNG/WebP lebih dulu, lalu SVG hasil tools/gen_art.py,
## sehingga gambar buatan ilustrator cukup diletakkan dengan nama yang sama.

static var _cache := {}


static func tex(path_no_ext: String) -> Texture2D:
	if _cache.has(path_no_ext):
		return _cache[path_no_ext]
	var t: Texture2D = null
	for ext in [".png", ".webp", ".svg"]:
		if ResourceLoader.exists(path_no_ext + ext):
			t = load(path_no_ext + ext)
			break
	_cache[path_no_ext] = t
	return t


static func portrait(id: String) -> Texture2D:
	return tex("res://assets/portraits/" + id)


static func icon(name: String) -> Texture2D:
	return tex("res://assets/icons/" + name)


static func bg(name: String) -> Texture2D:
	return tex("res://assets/bg/" + name)
