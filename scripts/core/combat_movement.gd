class_name CombatMovement
extends RefCounted

static func objective_for(context: CombatContext, unit: BaseGeoUnit) -> Vector2:
 var direction: float = 1.0 if unit.team == 0 else -1.0
 var profile: Dictionary = context.profile_for(unit.team)
 var stance: String = String(unit.rule.get("stance",profile["stance"]))
 var lane: String = String(unit.rule.get("lane_mode",profile.get("lane_mode","auto")))
 if lane != "auto":
  var y: float = 675.0 if lane == "mid" else (260.0 if unit.spawn_index % 2 == 0 else 1090.0)
  var progress_x: float = unit.global_position.x if unit.team == 0 else 2400.0-unit.global_position.x
  for gate: float in [700.0,1200.0,1750.0]:
   if progress_x < gate-70.0:
    return Vector2(gate if unit.team == 0 else 2400.0-gate,y)
  return context.base_for(1-unit.team).global_position
 if stance == "defensive":
  return Vector2(700 if unit.team == 0 else 1700, 675)
 if stance == "aggressive" or unit.spawn_index % 3 == 0:
  return context.base_for(1-unit.team).global_position
 return context.capture_objective(unit)

static func formation_anchor(context: CombatContext, unit: BaseGeoUnit) -> Vector2:
 var direction: float = 1.0 if unit.team == 0 else -1.0
 if unit.unit_type != "hexagon":
  var commander: BaseGeoUnit = null
  var nearest: float = INF
  for friend: BaseGeoUnit in context.units_for(unit.team):
   var distance: float = unit.global_position.distance_squared_to(friend.global_position)
   if friend.unit_type == "hexagon" and distance < nearest:
    nearest = distance
    commander = friend
  if is_instance_valid(commander):
   return commander.global_position + Vector2(direction * (85.0 if unit.unit_type == "square" else -85.0), unit.flank_sign * 55.0)
 var center: Vector2 = Vector2.ZERO
 var count: int = 0
 for friend: BaseGeoUnit in context.units_for(unit.team):
  if friend.unit_type in ["triangle", "square", "circle"]:
   center += friend.global_position
   count += 1
 if count == 0:
  return context.base_for(unit.team).global_position + Vector2(direction * 160.0, 0)
 return (center / float(count) - Vector2(direction * 185.0, 0)).clamp(Vector2(130,130), Vector2(2270,1220))

