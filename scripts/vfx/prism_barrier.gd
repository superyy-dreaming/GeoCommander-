class_name PrismBarrier
extends LaserReflector

var hp: float = 280.0
var life: float = 4.0

func _init() -> void:
 team = 0

func _ready() -> void:
 amplification = 1.35
 collision_layer = 4
 collision_mask = 3
 add_to_group("barriers")
 var shape: CollisionShape2D = CollisionShape2D.new()
 var rectangle: RectangleShape2D = RectangleShape2D.new()
 rectangle.size = Vector2(10.0, 96.0)
 shape.shape = rectangle
 add_child(shape)
 for unit: BaseGeoUnit in arena.units_for(team):
  add_collision_exception_with(unit)
 var points: PackedVector2Array = PackedVector2Array([Vector2(-5,-42),Vector2(0,-48),Vector2(5,-42),Vector2(5,42),Vector2(0,48),Vector2(-5,42)])
 var fill: Polygon2D = Polygon2D.new()
 fill.polygon = points
 fill.color = Color(ProceduralGeo.BLUE if team == 0 else ProceduralGeo.RED, 0.32)
 add_child(fill)
 ProceduralGeo.outline(self, points, ProceduralGeo.rim("square", team), 3.0)

func _physics_process(delta: float) -> void:
 if not arena.is_combat_active():
  return
 life -= delta
 if life <= 0.0:
  queue_free()
 queue_redraw()

func take_damage(amount: float, _attacker: Node2D = null) -> void:
 hp -= amount
 if hp <= 0.0:
  TransientVFX.spawn_shatter(arena, global_position, ProceduralGeo.rim("square", team), 20.0)
  queue_free()

func _draw() -> void:
 var color: Color = Color(ProceduralGeo.BLUE if team == 0 else ProceduralGeo.RED, 0.7)
 for offset: int in range(-36, 37, 12):
  draw_polyline(PackedVector2Array([Vector2(-4,offset-4),Vector2(4,offset),Vector2(-4,offset+4)]), color, 1.0, true)
 draw_line(Vector2(12,-48), Vector2(12,-48 + 96 * life / 4.0), color, 1.0, true)
