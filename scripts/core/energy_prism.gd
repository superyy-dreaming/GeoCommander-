class_name EnergyPrism
extends Area2D

var arena: CombatContext
var title: String = "NORTH"
var capture_owner: int = -1
var capturing_team: int = -1
var progress: float = 0.0
var radius: float = 110.0
var phase_time: float = 0.0

func _ready() -> void:
 collision_layer = 8
 collision_mask = 3
 monitoring = false
 var shape: CollisionShape2D = CollisionShape2D.new()
 var circle: CircleShape2D = CircleShape2D.new()
 circle.radius = radius
 shape.shape = circle
 add_child(shape)

func update_capture(delta: float, blue_count: int, red_count: int) -> void:
 if blue_count == red_count:
  return
 var advantage: int = 0 if blue_count > red_count else 1
 if advantage == capture_owner:
  progress = 0.0
  capturing_team = -1
  return
 if advantage != capturing_team:
  progress = 0.0
  capturing_team = advantage
 progress += delta
 if progress >= 5.0:
  capture_owner = advantage
  progress = 0.0
  capturing_team = -1
  if is_instance_valid(arena):
   arena.call("notify", ("北部" if title == "NORTH" else "南部") + "棱镜已被" + ("蓝方" if capture_owner == 0 else "红方") + "占领", false)

func _physics_process(delta: float) -> void:
 if not arena.is_combat_active():
  return
 phase_time += delta
 var counts: Array[int] = [0, 0]
 for unit: BaseGeoUnit in arena.local_units:
  if global_position.distance_squared_to(unit.global_position) <= radius * radius:
   counts[unit.team] += 1
 update_capture(delta, counts[0], counts[1])
 queue_redraw()

func _draw() -> void:
 var color: Color = Color(0.32, 0.48, 0.62) if capture_owner < 0 else (ProceduralGeo.BLUE if capture_owner == 0 else ProceduralGeo.RED)
 draw_circle(Vector2.ZERO, radius, Color(color, 0.035))
 draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(color, 0.4), 1.2, true)
 for index: int in range(8):
  var angle: float = float(index) * TAU / 8.0
  draw_arc(Vector2.ZERO, radius - 6.0, angle, angle + 0.10, 3, color, 3.0, true)
 var points: PackedVector2Array = ProceduralGeo.get_regular_polygon(24.0, 4)
 draw_colored_polygon(points, Color(color, 0.16))
 points.append(points[0])
 draw_polyline(points, Color(color.r * 1.5, color.g * 1.5, color.b * 1.5), 2.5, true)
 draw_circle(Vector2.ZERO, 5.0, color)
 if capturing_team >= 0:
  var progress_color: Color = ProceduralGeo.BLUE if capturing_team == 0 else ProceduralGeo.RED
  draw_arc(Vector2.ZERO, radius + 5.0, -PI / 2.0, -PI / 2.0 + TAU * progress / 5.0, 64, progress_color, 4.0, true)
