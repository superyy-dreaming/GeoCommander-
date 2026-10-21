class_name LaserReflector
extends StaticBody2D

var team: int = -1
var arena: CombatContext
var amplification: float = 1.25

func _enter_tree() -> void:
 if is_instance_valid(arena):
  arena.reflectors.append(self)

func _exit_tree() -> void:
 if is_instance_valid(arena):
  arena.reflectors.erase(self)
