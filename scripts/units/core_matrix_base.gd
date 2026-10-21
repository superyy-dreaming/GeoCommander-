class_name CoreMatrixBase
extends StaticBody2D

var team: int = 0
var max_hp: float = 2500.0
var current_hp: float = 2500.0
var unit_radius: float = 66.0
var dead: bool = false
var arena: CombatContext
var phase_time: float = 0.0

func _ready() -> void:
 collision_layer = 1 << team
 collision_mask = 3 | 4 | 16
 add_to_group("base_team_" + str(team))
 arena.local_bases.append(self)
 var shape: CollisionShape2D = CollisionShape2D.new()
 var circle: CircleShape2D = CircleShape2D.new()
 circle.radius = unit_radius
 shape.shape = circle
 add_child(shape)

func take_damage(amount: float, _attacker: Node2D = null) -> void:
 if dead or not arena.is_combat_active():
  return
 arena.base_damage_reported.emit(self,minf(current_hp,maxf(0,amount)),_attacker)
 current_hp = maxf(0.0, current_hp - amount)
 TransientVFX.effect(arena, global_position, Color(ProceduralGeo.BLUE if team == 0 else ProceduralGeo.RED, 0.9), "ring", 75.0, 0.25)
 arena.call("emit_base_health")
 if current_hp <= 0.0:
  dead = true
  TransientVFX.spawn_shatter(arena, global_position, Color(3.0, 2.0, 1.0), 90.0)
  arena.call("finish_match", 1 - team, "核心矩阵被摧毁")
 queue_redraw()

func _process(delta: float) -> void:
 phase_time += delta
 queue_redraw()

func _draw() -> void:
 var color: Color = ProceduralGeo.BLUE if team == 0 else ProceduralGeo.RED
 var border: PackedVector2Array = ProceduralGeo.get_regular_polygon(66.0, 6, PI / 6.0)
 draw_circle(Vector2.ZERO, 104.0, Color(color, 0.035))
 draw_arc(Vector2.ZERO, 92.0, 0, TAU, 64, Color(color, 0.35), 1.5, true)
 for index: int in range(6):
  var angle: float = TAU * float(index) / 6.0
  draw_line(Vector2.RIGHT.rotated(angle) * 81.0, Vector2.RIGHT.rotated(angle) * 96.0, Color(color, 0.7), 3.0, true)
 draw_colored_polygon(border, Color(color, 0.10))
 var closed: PackedVector2Array = border.duplicate()
 closed.append(closed[0])
 draw_polyline(closed, Color(color.r * 1.8, color.g * 1.8, color.b * 1.8, 1.0), 3.0, true)
 var inner: PackedVector2Array = ProceduralGeo.get_regular_polygon(48.0 * sqrt(maxf(0.0, current_hp / max_hp)), 6, -phase_time * 0.12)
 draw_colored_polygon(inner, Color(color, 0.5))
 draw_circle(Vector2.ZERO, 10.0, color)
