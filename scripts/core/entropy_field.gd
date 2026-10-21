class_name EntropyField
extends Area2D

var arena: CombatContext
var radius: float = 130.0
var age: float = 0.0
var affected: Array[BaseGeoUnit] = []

func _ready() -> void:
 collision_layer = 0
 collision_mask = 3
 var collision: CollisionPolygon2D = CollisionPolygon2D.new()
 collision.polygon = ProceduralGeo.get_regular_polygon(radius,6)
 add_child(collision)
 body_entered.connect(_entered)
 body_exited.connect(_exited)

func _entered(body: Node2D) -> void:
 if body is BaseGeoUnit and (body as BaseGeoUnit).arena == arena:
  var unit: BaseGeoUnit = body as BaseGeoUnit
  unit.slow_sources[get_instance_id()] = 0.65
  if not affected.has(unit):
   affected.append(unit)

func _exited(body: Node2D) -> void:
 if body is BaseGeoUnit:
  var unit: BaseGeoUnit = body as BaseGeoUnit
  unit.slow_sources.erase(get_instance_id())
  affected.erase(unit)

func _exit_tree() -> void:
 for unit: BaseGeoUnit in affected:
  if is_instance_valid(unit):
   unit.slow_sources.erase(get_instance_id())

func _process(delta: float) -> void:
 if arena.is_combat_active() and not arena.reduced_motion:
  age += delta
 queue_redraw()

func _draw() -> void:
 var polygon: PackedVector2Array = ProceduralGeo.get_regular_polygon(radius,6)
 draw_colored_polygon(polygon,Color(0.8,0.35,0.04,0.045))
 for side: int in range(6):
  var start: Vector2 = polygon[side]
  var finish: Vector2 = polygon[(side+1)%6]
  for dash: int in range(6):
   var t: float = fmod(float(dash)/6.0 + age * 0.04,1.0)
   draw_line(start.lerp(finish,t),start.lerp(finish,minf(t+0.08,1.0)),Color(1.8,0.9,0.1,0.65),2.0,true)
 if not arena.reduced_motion:
  for index: int in range(8):
   var point: Vector2 = Vector2(float(index % 4)*48.0-72.0, fmod(float(index)*47.0-age*16.0,140.0)-70.0)
   draw_line(point,point+Vector2(0,-5),Color(1.3,0.65,0.1,0.3),1.0,true)
