class_name ProceduralGeo
extends RefCounted

const BLUE: Color = Color(0.12, 0.74, 1.0)
const RED: Color = Color(1.0, 0.22, 0.32)
const GOLD: Color = Color(1.0, 0.77, 0.30)

static func get_regular_polygon(radius: float, sides: int, rotation_offset: float = 0.0) -> PackedVector2Array:
 var points: PackedVector2Array = []
 for index: int in range(sides):
  points.append(Vector2.RIGHT.rotated(rotation_offset + TAU * float(index) / float(sides)) * radius)
 return points

static func get_diamond_polygon(length: float, width: float) -> PackedVector2Array:
 return PackedVector2Array([Vector2(length, 0), Vector2(0, width), Vector2(-length * 0.6, 0), Vector2(0, -width)])

static func polygon(kind: String, radius: float) -> PackedVector2Array:
 match kind:
  "triangle": return get_regular_polygon(radius, 3)
  "square": return get_regular_polygon(radius, 4, PI / 4.0)
  "circle": return get_regular_polygon(radius, 40)
  "diamond": return get_diamond_polygon(radius * 1.35, radius * 0.7)
  _: return get_regular_polygon(radius, 6)

static func rim(kind: String, team: int) -> Color:
 var blue: Dictionary = {"triangle": Color(2.2, 2.0, 0.3), "square": Color(0.2, 2.0, 2.5), "circle": Color(2.0, 0.4, 2.4), "diamond": Color(2.4, 2.5, 2.8), "hexagon": Color(2.6, 1.9, 0.3)}
 var red: Dictionary = {"triangle": Color(2.5, 1.1, 0.2), "square": Color(2.4, 0.3, 0.6), "circle": Color(2.4, 0.2, 1.2), "diamond": Color(2.8, 1.4, 1.2), "hexagon": Color(2.6, 0.8, 0.2)}
 return blue[kind] if team == 0 else red[kind]

static func outline(parent: Node, points: PackedVector2Array, color: Color, width: float = 3.0) -> Line2D:
 var line: Line2D = Line2D.new()
 line.points = points
 line.closed = true
 line.width = width
 line.default_color = color
 line.antialiased = true
 parent.add_child(line)
 return line
