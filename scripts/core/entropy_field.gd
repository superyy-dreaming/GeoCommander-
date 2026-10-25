class_name EntropyField
extends Area2D

var arena: CombatContext
var radius: float = 110.0
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
 TerrainArt.entropy(self,radius)
