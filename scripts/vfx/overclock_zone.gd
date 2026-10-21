class_name OverclockZone
extends Node2D

var arena: CombatContext
var team: int = 0
var life: float = 5.0

func _physics_process(delta: float) -> void:
 if not arena.is_combat_active():
  return
 life -= delta
 for unit: BaseGeoUnit in arena.units_for(team):
  if absf(unit.global_position.x - global_position.x) <= 120.0 and absf(unit.global_position.y - global_position.y) <= 120.0:
   unit.overclock_left = 0.1
 if life <= 0.0:
  queue_free()
 queue_redraw()

func _draw() -> void:
 draw_rect(Rect2(-120,-120,240,240), Color(0.2, 0.8, 0.6, 0.045))
 draw_rect(Rect2(-120,-120,240,240), Color(1.8, 1.5, 0.4, 0.75), false, 2.0)
 for index: int in range(-90, 120, 30):
  draw_line(Vector2(index,-120), Vector2(index,120), Color(0.15, 0.7, 0.8, 0.22), 1.0)
  draw_line(Vector2(-120,index), Vector2(120,index), Color(0.15, 0.7, 0.8, 0.22), 1.0)
