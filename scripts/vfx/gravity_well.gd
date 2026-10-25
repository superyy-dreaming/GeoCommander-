class_name GravityWell
extends Area2D

var team: int = 0
var arena: CombatContext
var age: float = 0.0
var radius: float = 160.0
var caster: WeakRef
var affected: Array[BaseGeoUnit] = []

func _ready() -> void:
 collision_layer = 0
 collision_mask = 1 << (1 - team)
 monitoring = false
 add_to_group("gravity_wells")
 arena.gravity_triggered.emit(team, global_position, radius)

func _physics_process(delta: float) -> void:
 if not arena.is_combat_active():
  return
 age += delta
 for unit: BaseGeoUnit in affected:
  if is_instance_valid(unit):
   unit.gravity_sources.erase(get_instance_id())
   unit.in_gravity = not unit.gravity_sources.is_empty()
 affected.clear()
 for unit: BaseGeoUnit in arena.units_for(1-team):
  if global_position.distance_to(unit.global_position) < radius:
   affected.append(unit)
   unit.gravity_sources[get_instance_id()] = true
   unit.in_gravity = true
   if age < 0.9:
    unit.external_velocity = unit.global_position.direction_to(global_position) * minf(240.0, unit.global_position.distance_to(global_position) / maxf(delta, 0.001))
 if age >= 1.2:
  for unit: BaseGeoUnit in affected:
   if is_instance_valid(unit) and not unit.dead:
    unit.take_damage(42.0, self)
    unit.external_velocity = global_position.direction_to(unit.global_position) * 450.0
    unit.gravity_sources.erase(get_instance_id())
    unit.in_gravity = not unit.gravity_sources.is_empty()
  TransientVFX.effect(arena, global_position, Color(2.0, 0.4, 2.4), "pulse", 200.0, 0.4)
  var unit: BaseGeoUnit = caster.get_ref() as BaseGeoUnit if is_instance_valid(caster) else null
  if is_instance_valid(unit): unit.skill_finished()
  queue_free()
 queue_redraw()

func _exit_tree() -> void:
 for unit: BaseGeoUnit in affected:
  if is_instance_valid(unit):
   unit.gravity_sources.erase(get_instance_id())
   unit.in_gravity = not unit.gravity_sources.is_empty()

func _draw() -> void:
 var color: Color = Color(2.0, 0.4, 2.4, 0.7)
 draw_circle(Vector2.ZERO, radius, Color(0.6, 0.05, 0.7, 0.055))
 for index: int in range(4):
  var ring_radius: float = fmod(float(index) * 40.0 + 160.0 - age * 100.0, 160.0)
  draw_arc(Vector2.ZERO, ring_radius, age * 3.0 + index, age * 3.0 + index + TAU * 0.72, 48, color, 1.8, true)
 draw_circle(Vector2.ZERO, 8.0, Color(3.0, 0.8, 3.0))
