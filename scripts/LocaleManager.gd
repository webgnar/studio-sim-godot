extends Node

## LocaleManager - Handles language switching, font fallbacks, and translation loading
## Autoload singleton

const DEFAULT_LOCALE = "en"
const SUPPORTED_LOCALES = ["en", "zh_CN", "ja", "ko"]
const LOCALE_NAMES = {
	"en": "English",
	"zh_CN": "中文",
	"ja": "日本語",
	"ko": "한국어"
}

var current_locale: String = DEFAULT_LOCALE

signal locale_changed(new_locale: String)

func _ready():
	_setup_font_fallbacks()
	_load_translations_from_csv()
	_load_saved_locale()

func _setup_font_fallbacks():
	"""Add CJK fonts as fallbacks on the main game font"""
	var main_font = load("res://fonts/studio-sim.ttf") as FontFile
	var cjk_sc = load("res://fonts/NotoSerifCJKsc-Medium.otf") as FontFile
	var cjk_jp = load("res://fonts/NotoSerifCJKjp-Medium.otf") as FontFile
	var cjk_kr = load("res://fonts/NotoSerifCJKkr-Medium.otf") as FontFile

	if main_font and cjk_sc and cjk_jp and cjk_kr:
		main_font.fallbacks = [cjk_sc, cjk_jp, cjk_kr]
	else:
		push_warning("LocaleManager: Could not load one or more CJK fonts")

func _load_translations_from_csv():
	"""Parse translations.csv and register with TranslationServer"""
	var file = FileAccess.open("res://translations/translations.csv", FileAccess.READ)
	if not file:
		push_error("LocaleManager: Could not open translations.csv")
		return

	# Parse header row: keys,en,zh_CN,ja,ko
	var header = file.get_csv_line()
	var locale_indices = {}
	for i in range(1, header.size()):
		var locale = header[i].strip_edges()
		if locale != "":
			locale_indices[locale] = i

	# Create Translation objects for each locale
	var translations = {}
	for locale in locale_indices:
		translations[locale] = Translation.new()
		translations[locale].locale = locale

	# Parse each row
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() < 2:
			continue
		var key = line[0]
		if key == "" or key.begins_with("#"):
			continue
		for locale in locale_indices:
			var idx = locale_indices[locale]
			if idx < line.size() and line[idx] != "":
				translations[locale].add_message(key, line[idx])

	file.close()

	# Register translations with TranslationServer
	for locale in translations:
		TranslationServer.add_translation(translations[locale])

func set_locale(locale: String):
	"""Change the active locale"""
	if locale not in SUPPORTED_LOCALES:
		push_warning("LocaleManager: Unsupported locale '%s'" % locale)
		return

	current_locale = locale
	TranslationServer.set_locale(locale)
	_update_font_fallback_order(locale)
	_save_locale()
	locale_changed.emit(locale)

func _update_font_fallback_order(locale: String):
	"""Reorder CJK font fallbacks so the matching region is first"""
	var main_font = load("res://fonts/studio-sim.ttf") as FontFile
	var cjk_sc = load("res://fonts/NotoSerifCJKsc-Medium.otf") as FontFile
	var cjk_jp = load("res://fonts/NotoSerifCJKjp-Medium.otf") as FontFile
	var cjk_kr = load("res://fonts/NotoSerifCJKkr-Medium.otf") as FontFile

	if not main_font or not cjk_sc or not cjk_jp or not cjk_kr:
		return

	match locale:
		"zh_CN":
			main_font.fallbacks = [cjk_sc, cjk_jp, cjk_kr]
		"ja":
			main_font.fallbacks = [cjk_jp, cjk_sc, cjk_kr]
		"ko":
			main_font.fallbacks = [cjk_kr, cjk_sc, cjk_jp]
		_:
			main_font.fallbacks = [cjk_sc, cjk_jp, cjk_kr]

func _load_saved_locale():
	"""Load saved locale from settings, or detect from system"""
	if FileAccess.file_exists("user://settings.json"):
		var file = FileAccess.open("user://settings.json", FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				var saved_locale = json.data.get("locale", "")
				if saved_locale != "" and saved_locale in SUPPORTED_LOCALES:
					set_locale(saved_locale)
					file.close()
					return
			file.close()

	# No saved locale — detect from system
	var sys_locale = OS.get_locale()
	if sys_locale.begins_with("zh"):
		set_locale("zh_CN")
	elif sys_locale.begins_with("ja"):
		set_locale("ja")
	elif sys_locale.begins_with("ko"):
		set_locale("ko")
	else:
		set_locale("en")

func _save_locale():
	"""Save current locale to settings file"""
	var settings = {}
	if FileAccess.file_exists("user://settings.json"):
		var read_file = FileAccess.open("user://settings.json", FileAccess.READ)
		if read_file:
			var json = JSON.new()
			if json.parse(read_file.get_as_text()) == OK and json.data is Dictionary:
				settings = json.data
			read_file.close()

	settings["locale"] = current_locale

	var file = FileAccess.open("user://settings.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "\t"))
		file.close()

func get_locale_display_name(locale: String) -> String:
	"""Get the display name for a locale"""
	return LOCALE_NAMES.get(locale, locale)
