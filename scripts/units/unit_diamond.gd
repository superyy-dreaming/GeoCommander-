extends BaseGeoUnit

var windup_left: float = 0.0
var aim_point: Vector2 = Vector2.ZERO
var last_beam_points: PackedVector2Array = []
var last_beam_bounces: int = 0
var crystal_position: Vector2 = Vector2.INF
var crystal_search_left: float = 0.0

func _init() -> void:
 unit_type = "diamond"

func tick_unit(delta: float) -> void:
 crystal_search_left -= delta
 if windup_left > 0.0:
  windup_left -= delta
  if windup_left <= 0.0:
   fire_beam(global_position.direction_to(aim_point))
   skill_finished()
  return
 if not scripted_control:
  basic_attack()
  automatic_skill()

func try_cast_skill() -> bool:
 if skill_left > 0.0 or windup_left > 0.0 or (requested_skill.is_empty() and (not target_valid() or global_position.distance_to(current_target.global_position) > 650.0)):
  return false
 if not requested_skill.is_empty() and requested_skill.get("aim","auto") in ["auto","target"] and (not target_valid() or global_position.distance_to(current_target.global_position)>650):
  skill_rejection="激光目标失效或超过650px施放范围"
  return false
 aim_point = current_target.global_position if target_valid() else global_position+Vector2.RIGHT*300
 if String(rule.get("skill_cond")) == "refract_or_snipe":
  var reflector: LaserReflector = find_reflector()
  if is_instance_valid(reflector):
   aim_point = reflector.global_position
 if not requested_skill.is_empty() and requested_skill.get("aim","auto") != "auto":
  aim_point = SkillRequest.point(self,requested_skill)
  if global_position.distance_to(aim_point)>650.0:
   skill_rejection = "瞄准点超过650px施放范围"
   return false
 windup_left = 0.5
 skill_left = skill_cd
 skill_started()
 return true

func find_reflector() -> LaserReflector:
 if not target_valid(): return null
 var best: LaserReflector = null
 var best_distance: float = INF
 var prefer_crystal: bool = String(rule.get("movement")) == "align_with_crystal"
 for reflector: LaserReflector in arena.reflectors:
  if not is_instance_valid(reflector) or (reflector is PrismBarrier and reflector.team != team): continue
  if prefer_crystal and not reflector is NeutralCrystal: continue
  if String(rule.get("movement")) == "align_with_splitter" and not reflector is TriSplitter: continue
  var distance: float = global_position.distance_to(reflector.global_position)
  if distance > 380.0 or distance < 15.0: continue
  var trace: BeamTrace = BeamTrace.trace(arena,global_position,global_position.direction_to(reflector.global_position),self)
  if (trace.bounces > 0 or trace.split_count > 0) and trace.hits(current_target.global_position,float(current_target.get("unit_radius"))+8.0) and distance < best_distance:
   best = reflector
   best_distance = distance
 return best

func crystal_firing_position() -> Vector2:
 if crystal_search_left > 0.0: return crystal_position
 crystal_search_left = 0.8
 crystal_position = Vector2.INF
 if not target_valid(): return crystal_position
 var best: float = INF
 for reflector: LaserReflector in arena.reflectors:
  if not reflector is NeutralCrystal and not reflector is TriSplitter: continue
  if String(rule.get("movement"))=="align_with_splitter" and not reflector is TriSplitter: continue
  for index: int in range(12):
   var candidate: Vector2 = reflector.global_position + Vector2.RIGHT.rotated(float(index)*TAU/12.0)*170.0
   if not MapCatalog.WORLD_RECT.grow(-50).has_point(candidate): continue
   if is_instance_valid(arena.navigation) and not arena.navigation.segment_clear(global_position,candidate): continue
   var trace: BeamTrace = BeamTrace.trace(arena,candidate,candidate.direction_to(reflector.global_position),self)
   if (trace.bounces > 0 or trace.split_count > 0) and trace.hits(current_target.global_position,float(current_target.get("unit_radius"))+8.0):
    var distance: float = global_position.distance_to(candidate)
    if distance < best:
     best = distance
     crystal_position = candidate
 return crystal_position

func fire_beam(initial_direction: Vector2) -> void:
 var trace: BeamTrace = BeamTrace.trace(arena,global_position,initial_direction,self)
 var victims: Dictionary = {}
 for segment: Dictionary in trace.segments:
  damage_segment(segment["start"],segment["end"],85.0*segment["gain"],victims)
  TransientVFX.beam(arena,PackedVector2Array([segment["start"],segment["end"]]),Color(1.45,1.45,1.7),9.0*segment["gain"],0.35)
  if not (segment["normal"] as Vector2).is_zero_approx():
   TransientVFX.effect(arena,segment["end"],Color(0.1,0.85,1.0),"ring",18.0,0.45)
 # Settle after all paths have been inspected: a victim receives the maximum
 # intersecting segment once, regardless of traversal or branch order.
 for entry: Dictionary in victims.values():
  var victim: Node2D = entry["unit"]
  if is_instance_valid(victim) and not bool(victim.get("dead")): victim.call("take_damage",entry["damage"],self)
 last_beam_points = trace.points
 last_beam_bounces = trace.bounces

func damage_segment(start: Vector2, finish: Vector2, damage: float, victims: Dictionary) -> void:
 var candidates: Array[Node2D] = []
 for enemy: BaseGeoUnit in actual_enemies(): candidates.append(enemy)
 var base: CoreMatrixBase = arena.base_for(1-team)
 if is_instance_valid(base): candidates.append(base)
 for candidate: Node2D in candidates:
  if bool(candidate.get("dead")): continue
  var closest: Vector2 = Geometry2D.get_closest_point_to_segment(candidate.global_position,start,finish)
  if closest.distance_to(candidate.global_position) < float(candidate.get("unit_radius"))+8.0:
   var id: int = candidate.get_instance_id()
   if not victims.has(id) or damage>float(victims[id]["damage"]): victims[id]={"unit":candidate,"damage":damage}

func movement_velocity(delta: float) -> Vector2:
 return Vector2.ZERO if windup_left > 0.0 else super.movement_velocity(delta)

func cancel_active_skill() -> void:
 windup_left = 0.0
 queue_redraw()

func _draw() -> void:
 super._draw()
 if windup_left > 0.0:
  draw_line(Vector2.ZERO,to_local(aim_point),Color(1.5,0.3,0.5,0.8),1.5,true)
