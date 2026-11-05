class_name SvgExporter
extends RefCounted

## Writes a painting as one SVG file, in canvas millimetres.
##
## Shapes go in back to front, one group per sticker and one path per colour
## (even-odd, so holes stay holes), clipped to the canvas, exactly as the
## machine layers them. Opens in Illustrator, Inkscape, Figma or a browser.
## Optionally the machine's tool paths go on top as a hidden layer.


## shapes: Array of {stamp: int, sticker: String, color: Color or "rrggbb",
## polygons: Array of PackedVector2Array (canvas mm)}, back to front.
## toolpaths: optional Array of {color, lines: Array of PackedVector2Array},
## drawn as strokes tool_width wide in a hidden "toolpaths" layer.
static func painting_svg(canvas_mm: Vector2, shapes: Array, title: String = "", toolpaths: Array = [], tool_width: float = 2.0) -> String:
	var w := _n(canvas_mm.x)
	var h := _n(canvas_mm.y)
	var s := PackedStringArray()
	s.append('<?xml version="1.0" encoding="UTF-8"?>')
	s.append('<svg xmlns="http://www.w3.org/2000/svg" xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape" width="%smm" height="%smm" viewBox="0 0 %s %s">' % [w, h, w, h])
	if title != "":
		s.append("<title>%s</title>" % title.xml_escape())
	s.append('<defs><clipPath id="canvas"><rect x="0" y="0" width="%s" height="%s"/></clipPath></defs>' % [w, h])
	s.append('<rect x="0" y="0" width="%s" height="%s" fill="#ffffff"/>' % [w, h])
	s.append('<g id="painting" inkscape:groupmode="layer" inkscape:label="painting" clip-path="url(#canvas)">')
	var open_stamp := -1
	for sh in shapes:
		if sh.stamp != open_stamp:
			if open_stamp >= 0:
				s.append("</g>")
			open_stamp = sh.stamp
			s.append('<g id="stamp-%d" data-sticker="%s">' % [sh.stamp, str(sh.get("sticker", ""))])
		var d := path_data(sh.polygons)
		if d != "":
			s.append('<path fill="#%s" fill-rule="evenodd" d="%s"/>' % [_hex(sh.color), d])
	if open_stamp >= 0:
		s.append("</g>")
	s.append("</g>")
	if not toolpaths.is_empty():
		s.append('<g id="toolpaths" inkscape:groupmode="layer" inkscape:label="toolpaths" style="display:none" fill="none" stroke-linecap="round" stroke-linejoin="round" stroke-width="%s">' % _n(tool_width))
		for tp in toolpaths:
			var parts := PackedStringArray()
			for line in tp.lines:
				parts.append(_poly(line, false))
			s.append('<path stroke="#%s" d="%s"/>' % [_hex(tp.color), " ".join(parts)])
		s.append("</g>")
	s.append("</svg>")
	return "\n".join(s)


## SVG path data for closed rings.
static func path_data(polygons: Array) -> String:
	var parts := PackedStringArray()
	for poly in polygons:
		if poly.size() >= 3:
			parts.append(_poly(poly, true))
	return " ".join(parts)


static func _poly(pts, closed: bool) -> String:
	var b := PackedStringArray()
	for i in pts.size():
		b.append(("M" if i == 0 else "L") + _n(pts[i].x) + " " + _n(pts[i].y))
	if closed:
		b.append("Z")
	return "".join(b)


static func _n(v: float) -> String:
	var t := "%.2f" % v
	t = t.rstrip("0").rstrip(".")
	return "0" if t == "-0" or t == "" else t


static func _hex(c) -> String:
	return c.to_html(false) if c is Color else str(c)
