extends BaseGeoUnit

var dash_state: int = 0
var dash_time: float = 0.0
var dash_dir: Vector2 = Vector2.RIGHT
var dash_previous: Vector2 = Vector2.ZERO
var dash_victims: Dictionary = {}
var gravity_target: Vector2 = Vector2.ZERO
var gravity_hint_left: float = 0.0
var dash_purpose: String = "attack"

func _init() -> void:
 unit_type = "triangle"

func _ready() -> void:
 super._ready()
 arena.gravity_triggered.connect(_gravity_hint)

func _gravity_hint(source_team: int, center: Vector2, _radius: float) -> void:
 if source_team == team and global_position.distance_to(center) < 420.0:
  gravity_target = center
  gravity_hint_left = 1.2

func tick_unit(delta: float) -> void:
 gravity_hint_left = maxf(0.0, gravity_hint_left - delta)
 if dash_state == 1:
  dash_time -= delta
  if dash_time <= 0.0:
   dash_state = 2
   dash_time = 0.28
   collision_mask = 4 | 16
   visual_root.scale = Vector2.ONE
   dash_previous = global_position
  return
 if dash_state == 2:
  hit_dash_segment(dash_previous, global_position)
  dash_previous = global_position
  dash_time -= delta
  if dash_time <= 0.0:
   skill_finished()
   cancel_active_skill()
  return
 if not scripted_control:
  basic_attack()
  automatic_skill()

func try_cast_skill() -> bool:
 if skill_left > 0.0 or dash_state != 0 or dead or stun_left > 0 or not arena.is_combat_active():
  return false
 if not requested_skill.is_empty():
  var direction: Vector2 = global_position.direction_to(SkillRequest.point(self,requested_skill))
  var purpose: String = str(requested_skill.get("purpose","attack"))
  if purpose != "travel":
   if not target_valid(): return false
   var distance: float = global_position.distance_to(current_target.global_position)
   if distance<110 or distance>BoundaryManeuver.attack_reach(self,current_target):
    skill_rejection = "冲刺目标不在真实可达射程"
    return false
   if purpose == "backstab" and not BoundaryManeuver.rear_angle(self,current_target):
    skill_rejection = "尚未进入目标背后"
    return false
   if purpose == "backstab":
    var endpoint: Vector2=global_position+direction*(980.0*0.28*terrain_multiplier(direction)*(1.6 if overclock_left>0 else 1.0))
    var closest: Vector2=Geometry2D.get_closest_point_to_segment(current_target.global_position,global_position,endpoint)
    if closest.distance_to(current_target.global_position)>unit_radius+float(current_target.get("unit_radius")):
     skill_rejection="背刺方向未经过目标，请瞄准目标或修正方向"
     return false
  else:
   var endpoint: Vector2 = global_position+direction*(980.0*0.28*(1.6 if overclock_left>0 else 1.0)+unit_radius+8)
   var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position,endpoint,4|16,arena.friendly_shield_rids(team))
   if not MapCatalog.WORLD_RECT.grow(-35).has_point(endpoint) or (is_instance_valid(arena.navigation) and not arena.navigation.segment_clear(global_position,endpoint)) or not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
    skill_rejection = "赶路冲刺前方不满足安全净空"
    return false
  begin_dash(direction,purpose)
  return true
 if String(rule.get("skill_cond")) == "travel_and_backstab": return try_maneuver_dash()
 if not target_valid(): return false
 var target_pos: Vector2 = gravity_target if gravity_hint_left > 0.0 else current_target.global_position
 var distance: float = global_position.distance_to(target_pos)
 if distance < 110.0 or distance > 340.0:
  return false
 var direction: Vector2 = global_position.direction_to(target_pos)
 var can_dash: bool = (String(rule.get("skill_cond")) == "on_cooldown" or String(rule.get("skill_usage","auto")) == "try") or gravity_hint_left > 0.0
 if current_target is BaseGeoUnit:
  can_dash = can_dash or direction.dot(Vector2.RIGHT.rotated((current_target as BaseGeoUnit).visual_root.rotation)) > 0.25
 else:
  can_dash = true
 if String(rule.get("stance",arena.profile_for(team)["stance"])) == "aggressive":
  can_dash = true
 if can_dash:
  begin_dash(direction,"attack")
  return true
 return false

func begin_dash(direction: Vector2, purpose: String) -> void:
 dash_state = 1
 dash_time = 0.25
 dash_dir = direction.normalized()
 dash_purpose = purpose
 dash_victims.clear()
 skill_left = skill_cd
 visual_root.scale = Vector2(0.65, 1.35)
 skill_started()

func try_maneuver_dash() -> bool:
 if String(rule.get("behavior","normal")) != "normal": return false
 var goal: Vector2 = global_position
 if String(rule.get("movement")) == "boundary_infiltrate": goal = boundary_maneuver.goal_for(self)
 # Offensive use takes precedence and must actually start behind the target.
 if target_valid() and current_target is BaseGeoUnit:
  var distance: float = global_position.distance_to(current_target.global_position)
  if distance >= 110.0 and distance <= BoundaryManeuver.attack_reach(self,current_target) and BoundaryManeuver.rear_angle(self,current_target):
   if boundary_maneuver.phase in ["rear","attack","idle"]:
    begin_dash(global_position.direction_to(current_target.global_position),"backstab")
    return true
 if String(rule.get("movement")) != "boundary_infiltrate" or boundary_maneuver.phase == "attack": return false
 # A dash may leave a slow field while active. Reserve its maximum distance
 # so a speed change cannot skip a planned corner or staging point.
 var travel_length: float = 980.0*0.28*(1.6 if overclock_left > 0 else 1.0)
 if global_position.distance_to(goal) < travel_length+40.0: return false
 var direction: Vector2 = arena.routed_direction(self,goal,boundary_maneuver.intent())
 if direction.is_zero_approx(): return false
 var endpoint: Vector2 = global_position+direction*(travel_length+unit_radius+8.0)
 if not MapCatalog.WORLD_RECT.grow(-35).has_point(endpoint): return false
 if is_instance_valid(arena.navigation) and not arena.navigation.segment_clear(global_position,endpoint): return false
 var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position,endpoint,4|16,arena.friendly_shield_rids(team))
 if not get_world_2d().direct_space_state.intersect_ray(query).is_empty(): return false
 begin_dash(direction,"travel")
 return true

func hit_dash_segment(start: Vector2, end: Vector2) -> void:
 for enemy: BaseGeoUnit in actual_enemies():
  if dash_victims.has(enemy.get_instance_id()):
   continue
  var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, start, end)
  if closest.distance_to(enemy.global_position) <= enemy.unit_radius + unit_radius:
   dash_victims[enemy.get_instance_id()] = true
   var critical: bool = dash_dir.dot(Vector2.RIGHT.rotated(enemy.visual_root.rotation)) > 0.25
   enemy.take_damage(110.0 if critical else 55.0, self)
   if critical:
    TransientVFX.spawn_shatter(arena, enemy.global_position, Color(3.0, 2.5, 0.3), 18.0)

func movement_velocity(delta: float) -> Vector2:
 if dash_state == 1:
  return Vector2.ZERO
 if dash_state == 2:
  return dash_dir * 980.0 * terrain_multiplier(dash_dir) * (1.6 if overclock_left > 0.0 else 1.0)
 return super.movement_velocity(delta)

func cancel_active_skill() -> void:
 dash_state = 0
 collision_mask = 3 | 4 | 16
 if is_instance_valid(visual_root):
  visual_root.scale = Vector2.ONE
