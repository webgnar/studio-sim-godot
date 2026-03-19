extends Node

## LocaleManager - Handles language switching, font fallbacks, and translation loading
## Autoload singleton

const DEFAULT_LOCALE = "en"
const SUPPORTED_LOCALES = ["en", "zh_CN", "ru", "es", "pt_BR", "ko", "ja"]
const LOCALE_NAMES = {
	"en": "English",
	"zh_CN": "中文",
	"ja": "日本語",
	"ko": "한국어",
	"pt_BR": "Português (BR)",
	"es": "Español",
	"ru": "Русский",
}

var current_locale: String = DEFAULT_LOCALE

signal locale_changed(new_locale: String)

func _ready():
	_setup_font_fallbacks()
	_load_translations_from_csv()
	_load_saved_locale()

func _setup_font_fallbacks():
	"""Add Cyrillic and CJK fonts as fallbacks on the main game font"""
	var main_font = load("res://fonts/studio-sim.ttf") as FontFile
	var cyrillic = load("res://fonts/NotoSerif-Regular.ttf") as FontFile
	var cjk_sc = load("res://fonts/NotoSerifCJKsc-Medium.otf") as FontFile
	var cjk_jp = load("res://fonts/NotoSerifCJKjp-Medium.otf") as FontFile
	var cjk_kr = load("res://fonts/NotoSerifCJKkr-Medium.otf") as FontFile

	if main_font and cyrillic and cjk_sc and cjk_jp and cjk_kr:
		main_font.fallbacks = [cyrillic, cjk_sc, cjk_jp, cjk_kr]
	else:
		push_warning("LocaleManager: Could not load one or more fallback fonts")

func _load_translations_from_csv():
	"""Load compiled translation resources and register with TranslationServer."""
	var locale_paths := {
		"en":    "res://translations/translations.en.translation",
		"zh_CN": "res://translations/translations.zh_CN.translation",
		"ja":    "res://translations/translations.ja.translation",
		"ko":    "res://translations/translations.ko.translation",
		"pt_BR": "res://translations/translations.pt_BR.translation",
		"es":    "res://translations/translations.es.translation",
		"ru":    "res://translations/translations.ru.translation",
	}
	for locale in locale_paths:
		var path: String = locale_paths[locale]
		if ResourceLoader.exists(path):
			var t := load(path) as Translation
			if t:
				TranslationServer.add_translation(t)
			else:
				push_warning("LocaleManager: Failed to load translation for %s" % locale)
		else:
			push_warning("LocaleManager: Missing translation file: %s" % path)

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
	"""Reorder font fallbacks so the matching script is first"""
	var main_font = load("res://fonts/studio-sim.ttf") as FontFile
	var cyrillic = load("res://fonts/NotoSerif-Regular.ttf") as FontFile
	var cjk_sc = load("res://fonts/NotoSerifCJKsc-Medium.otf") as FontFile
	var cjk_jp = load("res://fonts/NotoSerifCJKjp-Medium.otf") as FontFile
	var cjk_kr = load("res://fonts/NotoSerifCJKkr-Medium.otf") as FontFile

	if not main_font or not cyrillic or not cjk_sc or not cjk_jp or not cjk_kr:
		return

	match locale:
		"zh_CN":
			main_font.fallbacks = [cyrillic, cjk_sc, cjk_jp, cjk_kr]
		"ja":
			main_font.fallbacks = [cyrillic, cjk_jp, cjk_sc, cjk_kr]
		"ko":
			main_font.fallbacks = [cyrillic, cjk_kr, cjk_sc, cjk_jp]
		_:
			main_font.fallbacks = [cyrillic, cjk_sc, cjk_jp, cjk_kr]

func _load_saved_locale():
	"""Load saved locale from settings, or detect from Steam/system.
	Priority: user's explicit in-game choice > Steam language > OS locale > English.
	Steam is checked before saved settings unless the user explicitly changed the
	language in-game (locale_explicitly_set == true), so that the Steam language
	dropdown always takes effect on first launch or after clearing preferences."""
	if FileAccess.file_exists("user://settings.json"):
		var file = FileAccess.open("user://settings.json", FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				# Only respect saved locale when the user explicitly chose it in-game.
				# If locale_explicitly_set is absent/false the Steam dropdown takes priority.
				if json.data.get("locale_explicitly_set", false):
					var saved_locale = json.data.get("locale", "")
					if saved_locale != "" and saved_locale in SUPPORTED_LOCALES:
						set_locale(saved_locale)
						file.close()
						return
			file.close()

	# No explicit user preference — check Steam language (authoritative for Steam users)
	var steam_locale = _get_steam_locale()
	if steam_locale != "":
		set_locale(steam_locale)
		return

	# Fall back to OS system locale
	var sys_locale = OS.get_locale()
	if sys_locale.begins_with("zh"):
		set_locale("zh_CN")
	elif sys_locale.begins_with("ja"):
		set_locale("ja")
	elif sys_locale.begins_with("ko"):
		set_locale("ko")
	elif sys_locale.begins_with("pt"):
		set_locale("pt_BR")
	elif sys_locale.begins_with("es"):
		set_locale("es")
	elif sys_locale.begins_with("ru"):
		set_locale("ru")
	else:
		set_locale("en")

func _get_steam_locale() -> String:
	"""Map Steam's current app language to a supported locale code.
	Returns "" if Steam is unavailable or the language isn't supported."""
	if not Engine.has_singleton("Steam"):
		return ""
	var steam = Engine.get_singleton("Steam")
	# Use call() to avoid parser errors on the GDExtension singleton
	var steam_lang: String = ""
	if steam.has_method("getCurrentGameLanguage"):
		steam_lang = steam.call("getCurrentGameLanguage")
	elif steam.has_method("getAppLanguage"):
		steam_lang = steam.call("getAppLanguage")
	if steam_lang == "":
		return ""
	var steam_to_locale = {
		"english": "en",
		"japanese": "ja",
		"koreana": "ko",
		"schinese": "zh_CN",
		"tchinese": "zh_CN",
		"brazilian": "pt_BR",
		"spanish":   "es",
		"latam":     "es",
		"russian":   "ru",
	}
	return steam_to_locale.get(steam_lang, "")

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
	settings["locale_explicitly_set"] = true

	var file = FileAccess.open("user://settings.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "\t"))
		file.close()

func get_locale_display_name(locale: String) -> String:
	"""Get the display name for a locale"""
	return LOCALE_NAMES.get(locale, locale)
