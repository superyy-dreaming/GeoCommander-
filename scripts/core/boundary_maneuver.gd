class_name BoundaryManeuver
extends RefCounted

# A bounded, built-in maneuver. JSON selects it; it never supplies executable
# waypoints or code. Left/right mean the two flanks relative to forward travel.
var phase: String = "idle"
var side: float = -1.0
var entry_x: float = 0.0
var target_id: int = 0

func reset() -> void:
 phase = "idle"
 target_id = 0

func goal_for(unit: BaseGeoUnit) -> Vector2:
 var forward: float = 1.0 if unit.team == 0 else -1.0
 if phase == "idle":
  side = -1.0 if unit.spawn_index % 2 == 0 else 1.0
  if unit.team == 1: side *= -1.0
  entry_x = clampf(unit.global_position.x,100.0,2300.0)
  phase = "exit"
 # Keep goals outside the crystals' miter-expanded navigation clearance even
 # when the rear crossing falls exactly at their X coordinate.
 var edge_y: float = 45.0 if side < 0 else 1305.0
 var target: Node2D = unit.current_target if unit.target_valid() else unit.arena.base_for(1-unit.team)
 if not is_instance_valid(target): return unit.global_position
 var new_id: int = target.get_instance_id()
 if target_id != new_id:
  target_id = new_id
  if phase == "attack": phase = "rear"
 if phase == "exit":
  var exit_point: Vector2 = Vector2(entry_x,edge_y)
  if unit.global_position.distance_to(exit_point) > 38.0: return exit_point
  phase = "edge"
 if phase == "edge":
  var advance_x: float = clampf(target.global_position.x+forward*320.0,100.0,2300.0)
  if (advance_x-unit.global_position.x)*forward > 35.0:
   return Vector2(advance_x,edge_y)
  phase = "rear"
 if target is CoreMatrixBase:
  # Bases have no backstab victim interface. Finish the flank by approaching
  # melee range; waiting at a unit backstab staging point would orbit forever.
  phase = "base"
  return target.global_position
 var facing: Vector2 = facing_of(target)
 var rear: Vector2 = rear_position(unit,target,facing)
 var offset: Vector2 = unit.global_position-target.global_position
 if rear_angle(unit,target) and offset.length() >= 110.0 and offset.length() <= attack_reach(unit,target):
  phase = "attack"
  return unit.global_position
 phase = "rear"
 # When approaching the front, first step around the flank rather than cut
 # through the victim. Terrain navigation handles the resulting safe goal.
 if target is BaseGeoUnit and offset.dot(-facing) < 45.0 and absf(offset.dot(facing.orthogonal())) < 155.0:
  return (target.global_position+facing.orthogonal()*side*230.0).clamp(Vector2(65,65),Vector2(2335,1285))
 return rear

func rear_position(unit: BaseGeoUnit, target: Node2D, facing: Vector2) -> Vector2:
 # A target may stand next to cover. Select a reachable point in its rear
 # hemisphere rather than putting the staging goal inside solid terrain.
 for distance: float in [190.0,250.0,140.0]:
  for angle: float in [0.0,side*30.0,-side*30.0,side*55.0,-side*55.0]:
   var point: Vector2 = target.global_position-facing.rotated(deg_to_rad(angle))*distance
   if not Rect2(45,45,2310,1260).has_point(point): continue
   if not is_instance_valid(unit.arena.navigation) or unit.arena.navigation.segment_clear(point,point): return point
 return unit.global_position

static func attack_reach(unit: BaseGeoUnit, target: Node2D) -> float:
 var multiplier: float = unit.terrain_multiplier()
 if is_instance_valid(unit.arena.navigation):
  for field: EntropyField in unit.arena.navigation.fields:
   var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(field.global_position,unit.global_position,target.global_position)
   if nearest.distance_to(field.global_position) < field.radius+unit.unit_radius: multiplier = minf(multiplier,0.65)
 var radius: float = (target as BaseGeoUnit).unit_radius if target is BaseGeoUnit else 58.0
 return minf(340.0,980.0*0.28*multiplier*(1.6 if unit.overclock_left > 0 else 1.0)+unit.unit_radius+radius-12.0)

static func facing_of(target: Node2D) -> Vector2:
 if target is BaseGeoUnit: return Vector2.RIGHT.rotated((target as BaseGeoUnit).visual_root.rotation)
 return Vector2.LEFT if int(target.get("team")) == 1 else Vector2.RIGHT

static func rear_angle(unit: BaseGeoUnit, target: Node2D) -> bool:
 return unit.global_position.direction_to(target.global_position).dot(facing_of(target)) > 0.5

func intent() -> String:
 return "boundary:"+phase+":"+str(target_id)
