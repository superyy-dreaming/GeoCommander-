class_name GeoProjectile
extends Node2D

var arena: CombatContext
var team: int = 0
var damage: float = 18.0
var kind: String = "circle"
var speed: float = 720.0
var distance_left: float = 300.0
var direction: Vector2 = Vector2.RIGHT
var tint: Color = Color.WHITE
var source: WeakRef

func _ready() -> void:
 rotation = direction.angle()
 z_index = 5
 add_to_group("projectiles")

func _physics_process(delta: float) -> void:
 if not arena.is_combat_active():
  queue_free()
  return
 var distance: float = minf(speed * delta, distance_left)
 var endpoint: Vector2 = global_position + direction * distance
 var excluded: Array[RID] = arena.friendly_shield_rids(team)
 var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, endpoint, (1 << (1-team)) | 4 | 16, excluded)
 var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
 if not hit.is_empty():
  var attacker: Node2D = source.get_ref() as Node2D if is_instance_valid(source) else null
  if hit["collider"].has_method("take_damage"):
   hit["collider"].call("take_damage",damage,attacker)
  TransientVFX.effect(arena,hit["position"],tint,"ring",12.0,0.15)
  queue_free()
  return
 global_position = endpoint
 distance_left -= distance
 if distance_left <= 0.0:
  queue_free()

func _draw() -> void:
 if kind == "circle":
  draw_circle(Vector2.ZERO,4.0,tint)
  draw_arc(Vector2.ZERO,7.0,0,TAU,16,Color(tint,0.45),1.0,true)
 else:
  draw_line(Vector2(-13,0),Vector2(5,0),tint,2.5,true)
