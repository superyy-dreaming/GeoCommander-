class_name UnitDeployButton
extends Button

var kind: String = "triangle"
var hotkey: int = 1
var hotkey_label: String = ""
const COLORS: Dictionary = {"triangle": Color(1.0,0.85,0.3), "square": Color(0.2,0.85,1.0), "circle": Color(0.88,0.4,1.0), "diamond": Color(0.86,0.92,1.0), "hexagon": Color(1.0,0.77,0.3)}

func _ready() -> void:
 update_metrics()
 mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func centered(value: String, baseline: float, font_size: int, color: Color) -> void:
 font_size = GameSettings.font_px(font_size)
 var font: Font = get_theme_font("font")
 var width: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
 draw_string(font, Vector2((size.x - width) / 2.0, baseline+(float(GameSettings.values["font_scale"])-1.0)*(baseline-45)), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
 var color: Color = COLORS[kind]
 if disabled:
  color = color.lerp(Color(0.4,0.48,0.56), 0.6)
 var points: PackedVector2Array = ProceduralGeo.polygon(kind, 19.0)
 for index: int in range(points.size()):
  points[index] += Vector2(size.x / 2.0, 34)
 draw_colored_polygon(points, Color(color,0.12))
 points.append(points[0])
 draw_polyline(points, color, 2.0, true)
 centered(String(UnitCatalog.DATA[kind]["name"]), 73, 15, Color(0.87,0.94,1.0))
 centered(String(UnitCatalog.DATA[kind]["zh"]), 95, 16, Color(0.65,0.79,0.87))
 centered(str(UnitCatalog.DATA[kind]["cost"]) + " F  /  " + (hotkey_label if not hotkey_label.is_empty() else str(hotkey)), 124, 16, color)

func update_metrics() -> void:
 var extra: float = float(GameSettings.values["font_scale"])-1.0
 custom_minimum_size = Vector2(104+70*extra,138+80*extra)
 var font: Font = get_theme_font("font")
 for entry: Array in [[UnitCatalog.DATA[kind]["name"],15],[UnitCatalog.DATA[kind]["zh"],16],[str(UnitCatalog.DATA[kind]["cost"])+" F  /  "+(hotkey_label if not hotkey_label.is_empty() else str(hotkey)),16]]:
  custom_minimum_size.x = maxf(custom_minimum_size.x,font.get_string_size(str(entry[0]),HORIZONTAL_ALIGNMENT_LEFT,-1,GameSettings.font_px(int(entry[1]))).x+20)
 queue_redraw()
