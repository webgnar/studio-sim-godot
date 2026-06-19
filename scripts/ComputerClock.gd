extends Label3D

# Maps the day/night cycle sun angle to a 12-hour clock display.
# 0° sun = 6:00 AM (sunrise), 180° = 6:00 PM (sunset), 360° wraps back to 6:00 AM.

var _day_night: Node

func _ready() -> void:
	_day_night = get_tree().root.get_node_or_null("World/DayNightCycle")

func _process(_delta: float) -> void:
	if not _day_night:
		return
	var deg: float = _day_night.get_sun_degrees()
	var hour_float: float = fmod((deg / 360.0) * 24.0 + 6.0, 24.0)
	var hour_24: int = int(hour_float)
	var minute: int = int((hour_float - hour_24) * 60.0)

	var suffix := "AM" if hour_24 < 12 else "PM"
	var hour_12: int = hour_24 % 12
	if hour_12 == 0:
		hour_12 = 12
	text = "%d:%02d %s" % [hour_12, minute, suffix]
