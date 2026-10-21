extends BaseGeoUnit

var core: Line2D
var pulse_phase: float = 0.0

func _init() -> void:
 unit_type = "hexagon"

func _ready() -> void:
 super._ready()
 core = ProceduralGeo.outline(visual_root, ProceduralGeo.get_regular_polygon(15.0, 6), Color(2.0, 1.6, 0.4), 1.8)

func tick_unit(delta: float) -> void:
 pulse_phase += delta
 core.rotation -= delta * 1.4
 if not scripted_control:
  automatic_skill()

func try_cast_skill() -> bool:
 if skill_left > 0.0:
  return false
 var fibers: int = 0
 for friend: BaseGeoUnit in allies():
  if global_position.distance_to(friend.global_position) <= 240.0:
   friend.heal(35.0)
   friend.buff_left = maxf(friend.buff_left, 3.0)
   if friend != self and fibers < 5:
    TransientVFX.beam(arena, PackedVector2Array([global_position, friend.global_position]), Color(2.6, 1.9, 0.3, 0.6), 1.2, 0.7)
    fibers += 1
 TransientVFX.effect(arena, global_position, Color(2.6, 1.9, 0.3, 0.5), "hex_ring", 240.0, 0.7)
 skill_left = skill_cd
 skill_started()
 return true

func _draw() -> void:
 super._draw()
 draw_arc(Vector2.ZERO, 39.0 + sin(pulse_phase * 2.0) * 3.0, 0, TAU, 48, Color(1.8, 1.3, 0.2, 0.42), 1.2, true)
