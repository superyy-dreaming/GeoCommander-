class_name TransientVFX
extends Node2D

var mode: String = "ring"
var tint: Color = Color.WHITE
var duration: float = 0.5
var age: float = 0.0
var radius: float = 60.0
var points: PackedVector2Array = []
var count: int = 14
var low_motion: bool = false

static func effect(parent: Node, pos: Vector2, color: Color, effect_mode: String, size: float, lifetime: float = 0.5) -> TransientVFX:
 var node: TransientVFX = TransientVFX.new()
 node.position = pos
 node.tint = color
 node.mode = effect_mode
 node.radius = size
 node.duration = lifetime
 node.z_index = 8
 node.low_motion = bool(parent.get("reduced_motion")) if "reduced_motion" in parent else false
 parent.add_child(node)
 return node

static func spawn_shatter(parent: Node, pos: Vector2, color: Color, size: float) -> void:
 effect(parent, pos, color, "shatter", size * 3.0, 0.55)

static func beam(parent: Node, path: PackedVector2Array, color: Color, width: float = 9.0, lifetime: float = 0.35) -> void:
 var node: TransientVFX = effect(parent, Vector2.ZERO, color, "beam", width, lifetime)
 node.points = path

func _process(delta: float) -> void:
 age += delta
 if age >= duration:
  queue_free()
 else:
  queue_redraw()

func _draw() -> void:
 var progress: float = clampf(age / duration, 0.0, 1.0)
 var color: Color = Color(tint, 1.0 - progress)
 match mode:
  "beam":
   if points.size() > 1:
    draw_polyline(points, Color(tint, (1.0 - progress) * 0.16), radius * 2.5, true)
    draw_polyline(points, color, maxf(1.0, radius * (1.0 - progress)), true)
  "shatter":
   for index: int in range(5 if low_motion else count):
    var direction: Vector2 = Vector2.RIGHT.rotated(TAU * float(index) / float(count) + float(index) * 0.31)
    var location: Vector2 = direction * radius * progress
    draw_line(location, location + direction.rotated(0.7) * 8.0 * (1.0 - progress), color, 2.0, true)
  "warp":
   draw_line(Vector2(-radius, 0), Vector2(radius, 0), color, 3.0, true)
   draw_arc(Vector2.ZERO, radius * (1.0 - progress * 0.7), 0, TAU, 48, color, 2.0, true)
  "hex_ring":
   var outline: PackedVector2Array = ProceduralGeo.get_regular_polygon(maxf(1.0,radius*(0.25+0.75*progress)),6)
   outline.append(outline[0])
   draw_polyline(outline,color,2.5,true)
  "pulse":
   draw_circle(Vector2.ZERO, radius * progress, Color(tint, (1.0 - progress) * 0.08))
   draw_arc(Vector2.ZERO, maxf(1.0, radius * progress), 0, TAU, 64, color, 2.0, true)
  _:
   draw_arc(Vector2.ZERO, maxf(1.0, radius * (0.25 + 0.75 * progress)), 0, TAU, 64, color, 2.5, true)
