class_name BaseGeoUnit
extends CharacterBody2D

var team: int = 0
var unit_type: String = "triangle"
var arena: CombatContext
var max_hp: float = 130.0
var current_hp: float = 130.0
var move_speed: float = 270.0
var unit_radius: float = 15.0
var attack_range: float = 36.0
var attack_damage: float = 24.0
var attack_cd: float = 0.9
var skill_cd: float = 4.5
var attack_left: float = 0.0
var skill_left: float = 1.5
var stun_left: float = 0.0
var buff_left: float = 0.0
var overclock_left: float = 0.0
var external_velocity: Vector2 = Vector2.ZERO
var current_target: Node2D
var visual_root: Node2D
var inner_fill: Polygon2D
var outer_border: Line2D
var trail_line: Line2D
var rim_color: Color
var dead: bool = false
var decision_left: float = 0.0
var trail_left: float = 0.0
var flank_sign: float = 1.0
var under_attack_left: float = 0.0
var hit_tween: Tween
var rule: Dictionary = {}
var base_rule: Dictionary = {}
var matched_rule: String = "基础战术"
var action_blocked: String = ""
var last_facts: Dictionary = {}
var in_gravity: bool = false
var gravity_sources: Dictionary = {}
var selected: bool = false
var scripted_control: bool = false
var scripted_direction: Vector2 = Vector2.ZERO
var slow_sources: Dictionary = {}
var nebula_ids: Array[String] = []
var revealed_until: Dictionary = {}
var teleport_cooldown: float = 0.0
var portal_boost_left: float = 0.0
var portal_used_count: int = 0
var flux_collected_count: int = 0
var scan_left: float = 0.0
var scan_serial: int = 0
var active_velocity: Vector2 = Vector2.ZERO
var gate_push_velocity: Vector2 = Vector2.ZERO
var spawn_index: int = 0
var avoid_side: float = 0.0
var avoid_until: int = 0
var execution: TacticExecution
var attack_serial: int = 0
var skill_serial: int = 0
var skill_complete_serial: int = -1
var skill_interrupted_serial: int = -1
var skill_active: bool = false
var requested_skill: Dictionary = {}
var skill_rejection: String = ""
var boundary_maneuver: BoundaryManeuver = BoundaryManeuver.new()

func _ready() -> void:
 var data: Dictionary = UnitCatalog.DATA[unit_type]
 max_hp = float(data["hp"])
 current_hp = max_hp
 move_speed = float(data["speed"])
 unit_radius = float(data["radius"])
 attack_range = float(data["range"])
 attack_damage = float(data["damage"])
 attack_cd = float(data["attack_cd"])
 skill_cd = float(data["skill_cd"])
 rim_color = ProceduralGeo.rim(unit_type, team)
 flank_sign = -1.0 if get_instance_id() % 2 == 0 else 1.0
 collision_layer = 1 << team
 collision_mask = 3 | 4 | 16
 motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
 add_to_group("units_team_" + str(team))
 add_to_group("units")
 var shape: CollisionShape2D = CollisionShape2D.new()
 var circle: CircleShape2D = CircleShape2D.new()
 circle.radius = unit_radius
 shape.shape = circle
 add_child(shape)
 visual_root = Node2D.new()
 add_child(visual_root)
 var polygon: PackedVector2Array = ProceduralGeo.polygon(unit_type, unit_radius)
 inner_fill = Polygon2D.new()
 inner_fill.polygon = polygon
 inner_fill.color = Color(0.05, 0.45, 0.75, 0.55) if team == 0 else Color(0.85, 0.12, 0.22, 0.55)
 visual_root.add_child(inner_fill)
 outer_border = ProceduralGeo.outline(visual_root, polygon, rim_color)
 var dot: Polygon2D = Polygon2D.new()
 dot.polygon = ProceduralGeo.get_regular_polygon(4.0, 12)
 dot.color = ProceduralGeo.BLUE if team == 0 else ProceduralGeo.RED
 visual_root.add_child(dot)
 trail_line = Line2D.new()
 trail_line.top_level = true
 trail_line.width = 8.0
 trail_line.z_index = -1
 var gradient: Gradient = Gradient.new()
 gradient.set_color(0, Color(rim_color, 0.0))
 gradient.set_color(1, Color(rim_color, 0.22))
 trail_line.gradient = gradient
 add_child(trail_line)
 for reflector: LaserReflector in arena.reflectors:
  if reflector is PrismBarrier and reflector.team == team:
   add_collision_exception_with(reflector)
 base_rule = (arena.profile_for(team)["unit_rules"][unit_type] as Dictionary).duplicate(true)
 rule = base_rule.duplicate(true)
 arena.profile_changed.connect(_profile_updated)
 reset_execution()
 arena.register_unit(self)

func _profile_updated(changed_team: int, profile: Dictionary) -> void:
 if changed_team == team:
  base_rule = (profile["unit_rules"][unit_type] as Dictionary).duplicate(true)
  rule = base_rule.duplicate(true)
  decision_left = 0.0
  boundary_maneuver.reset()
  reset_execution()

func reset_execution() -> void:
 execution = null
 var program: Dictionary = base_rule.get("program",{})
 if int(program.get("version",1)) == 2:
  execution = TacticExecution.new()
  execution.install(program)

func is_plan_controlled() -> bool:
 return execution != null and not execution.use_base and not scripted_control

func enemies() -> Array[BaseGeoUnit]:
 return arena.perceived_enemies(self)

func allies() -> Array[BaseGeoUnit]:
 return arena.units_for(team)

func actual_enemies() -> Array[BaseGeoUnit]:
 return arena.units_for(1-team)

func terrain_multiplier(direction: Vector2 = Vector2.ZERO) -> float:
 var multiplier: float = 1.0
 for value: float in slow_sources.values():
  multiplier = minf(multiplier,value)
 if is_instance_valid(arena.terrain): multiplier *= arena.terrain.speed_multiplier(self,direction)
 return multiplier

func try_scan() -> bool:
 return false

func try_cast_skill() -> bool:
 return false

func _physics_process(delta: float) -> void:
 if dead or not is_instance_valid(arena) or not arena.is_combat_active():
  velocity = Vector2.ZERO
  return
 var recovery: float = (1.25 if buff_left > 0.0 else 1.0) * (2.0 if overclock_left > 0.0 else 1.0)
 attack_left = maxf(0.0, attack_left - delta * (1.25 if buff_left > 0.0 else 1.0))
 skill_left = maxf(0.0, skill_left - delta * recovery)
 scan_left = maxf(0.0,scan_left-delta)
 buff_left = maxf(0.0, buff_left - delta)
 overclock_left = maxf(0.0, overclock_left - delta)
 stun_left = maxf(0.0, stun_left - delta)
 under_attack_left = maxf(0.0, under_attack_left - delta)
 if is_plan_controlled():
  var plan_started: int = Time.get_ticks_usec()
  execution.tick(self,delta)
  arena.plan_usec += Time.get_ticks_usec()-plan_started
 decision_left -= delta
 if decision_left <= 0.0 and not scripted_control and not is_plan_controlled():
  decide_tactic()
  decision_left = 0.15
 if stun_left > 0.0:
  velocity = external_velocity+gate_push_velocity
  move_and_slide()
 else:
  tick_unit(delta)
  if not arena.is_combat_active() or dead:
   return
  active_velocity = movement_velocity(delta)
  velocity = active_velocity + external_velocity+gate_push_velocity
  move_and_slide()
 external_velocity = external_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
 if velocity.length_squared() > 25.0:
  visual_root.rotation = lerp_angle(visual_root.rotation, velocity.angle(), minf(1.0, 12.0 * delta))
 trail_left -= delta
 if trail_left <= 0.0 and not bool(arena.get("reduced_motion")):
  trail_left = 0.035
  trail_line.add_point(global_position)
  if trail_line.get_point_count() > 12:
   trail_line.remove_point(0)
 elif bool(arena.get("reduced_motion")):
  trail_line.clear_points()
 queue_redraw()

func decide_tactic() -> void:
 var started: int = Time.get_ticks_usec()
 arena.tactic_decisions += 1
 rule = base_rule.duplicate(true)
 var program: Dictionary = base_rule.get("program",{})
 if not program.is_empty(): rule = program["base"].duplicate(true)
 if int(program.get("version",1)) == 2: program = {}
 evaluate_best_target()
 if program.is_empty():
  arena.tactic_usec += Time.get_ticks_usec()-started
  return
 last_facts = tactic_facts()
 var result: Dictionary = UnitTacticProgram.evaluate(program,last_facts)
 var original_priority: String = String(rule.get("priority","closest"))
 rule = result["rule"]
 matched_rule = result["matched"]
 if rule["priority"] != original_priority: evaluate_best_target()
 arena.tactic_usec += Time.get_ticks_usec()-started

func tactic_facts() -> Dictionary:
 var enemy_count: int = 0
 var ally_count: int = 0
 var lowest: float = 1.0
 var has_hex: bool = false
 var cluster: int = 0
 for friend: BaseGeoUnit in allies():
  if friend.unit_type == "hexagon": has_hex = true
  if friend != self and global_position.distance_squared_to(friend.global_position) <= 90000.0:
   ally_count += 1
   lowest = minf(lowest,friend.current_hp/friend.max_hp)
 for enemy: BaseGeoUnit in enemies():
  if global_position.distance_squared_to(enemy.global_position) <= 90000.0: enemy_count += 1
  if target_valid() and current_target.global_position.distance_squared_to(enemy.global_position) <= 25600.0: cluster += 1
 var visible: bool = false
 var kind: String = "none"
 var hp: float = 1.0
 var distance: float = 3000.0
 if target_valid():
  kind = current_target.unit_type if current_target is BaseGeoUnit else "base"
  hp = float(current_target.get("current_hp"))/float(current_target.get("max_hp"))
  distance = global_position.distance_to(current_target.global_position)
  var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position,current_target.global_position,4|16,arena.friendly_shield_rids(team))
  visible = get_world_2d().direct_space_state.intersect_ray(query).is_empty()
 return {"self_hp":current_hp/max_hp,"target_hp":hp,"target_type":kind,"target_distance":distance,"nearby_allies":ally_count,"nearby_enemies":enemy_count,"ally_min_hp":lowest,"hexagon_alive":has_hex,"skill_ready":skill_left<=0 and stun_left<=0,"target_visible":visible,"target_cluster":cluster,"scan_ready":unit_type=="hexagon" and scan_left<=0 and stun_left<=0,"in_nebula":not nebula_ids.is_empty(),"portal_ready":teleport_cooldown<=0,"reactor_warning":is_instance_valid(arena.terrain) and arena.terrain.warning_at(self),"portal_available":is_instance_valid(arena.terrain) and arena.terrain.portal_available(self),"gate_open":is_instance_valid(arena.terrain) and arena.terrain.any_gate_open(),"portal_used":portal_used_count>0,"flux_collected":flux_collected_count>0}

func automatic_skill() -> bool:
 if is_plan_controlled():
  if execution.skill_policy == "hold" or skill_active: return false
  if execution.skill_policy == "travel":
   var heading: Vector2 = execution.move_direction if execution.direct else global_position.direction_to(execution.goal) if execution.goal.is_finite() else Vector2.ZERO
   if heading.is_zero_approx(): return false
   var result: Dictionary = SkillRequest.attempt(self,{"aim":"direction","direction":"angle","angle":rad_to_deg(heading.angle()),"purpose":"travel"})
   action_blocked = result["message"]
   return result["ok"]
 if not is_plan_controlled() and String(rule.get("skill_usage","auto")) == "hold":
  action_blocked = "规则保留技能"
  return false
 if stun_left > 0 or dead or not arena.is_combat_active():
  action_blocked = "受控或战斗未进行"
  return false
 if skill_left > 0:
  action_blocked = "技能冷却 %.1fs" % skill_left
  return false
 var success: bool = try_cast_skill()
 action_blocked = "" if success else "射程、朝向、聚集数量或合法目标不满足"
 return success

func skill_started() -> void:
 skill_serial += 1
 skill_active = true
 arena.skill_reported.emit(self)
 arena.skill_lifecycle.emit(self,"started",skill_serial,"")

func skill_finished() -> void:
 if not skill_active: return
 skill_active = false
 skill_complete_serial = skill_serial
 arena.skill_lifecycle.emit(self,"completed",skill_serial,"")

func skill_interrupted(reason: String) -> void:
 if not skill_active: return
 skill_active = false
 skill_interrupted_serial = skill_serial
 arena.skill_lifecycle.emit(self,"interrupted",skill_serial,reason)

func evaluate_best_target() -> void:
 var best: float = -INF
 current_target = null
 var priority: String = String(rule.get("priority", "closest"))
 var enemy_list: Array[BaseGeoUnit] = enemies()
 for enemy: BaseGeoUnit in enemy_list:
  var distance: float = global_position.distance_to(enemy.global_position)
  var score: float = 1000.0 - distance * 0.4
  if priority == "ranged_or_commander" and enemy.unit_type in ["diamond", "hexagon"]:
   score += 600.0
  elif priority == "diamond_first" and enemy.unit_type == "diamond":
   score += 10000.0
  elif priority == "lowest_hp":
   score += (1.0 - enemy.current_hp / enemy.max_hp) * 500.0
  elif priority == "highest_threat":
   score += 250.0 if enemy.unit_type in ["diamond", "circle", "hexagon"] else 0.0
  elif priority == "cluster":
   for other: BaseGeoUnit in enemy_list:
    if enemy.global_position.distance_squared_to(other.global_position) < 25600.0:
     score += 90.0
  if enemy.in_gravity:
   score += 450.0
  if score > best:
   best = score
   current_target = enemy
 if not is_instance_valid(current_target):
  current_target = arena.base_for(1-team)

func movement_velocity(delta: float) -> Vector2:
 if is_plan_controlled():
  var planned: Vector2 = execution.movement(self)
  # Direction segments never invoke steering or inherit the old pursuit velocity.
  if not execution.direct: planned = whisker_steering(planned)
  return planned * move_speed * terrain_multiplier(planned) * (1.6 if overclock_left>0 else 1.0)
 if scripted_control:
  return scripted_direction.limit_length(1.0) * move_speed * terrain_multiplier(scripted_direction) * (1.6 if overclock_left > 0 else 1.0)
 var desired: Vector2 = Vector2.ZERO
 var movement: String = String(rule.get("movement", "direct_charge"))
 var stance: String = String(rule.get("stance",arena.profile_for(team).get("stance","balanced")))
 # Resolve the final intent before consulting the unit's single route cache.
 # Intermediate pursuit/formation queries must never own a retreat route.
 var goal: Vector2 = global_position
 var intent: String = ""
 var flank: bool = false
 var behavior: String = String(rule.get("behavior","normal"))
 if behavior == "retreat":
  var home: CoreMatrixBase = arena.base_for(team)
  if is_instance_valid(home):
   goal = home.global_position + Vector2(130 if team == 0 else -130,0)
   if global_position.distance_to(goal) > 25.0: intent = "retreat"
 elif behavior != "hold" and movement == "boundary_infiltrate":
  goal = boundary_maneuver.goal_for(self)
  if global_position.distance_to(goal) > 20.0: intent = boundary_maneuver.intent()
 elif behavior != "hold":
  boundary_maneuver.reset()
  goal = arena.call("objective_for", self)
  if global_position.distance_to(goal) > 25.0: intent = "objective"
  var target_distance: float = INF
  if target_valid():
   target_distance = global_position.distance_to(current_target.global_position)
  var use_target: bool = target_valid() and target_distance < 540.0
  if use_target:
   var stop_range: float = attack_range * 0.85
   if current_target is CoreMatrixBase: stop_range += 58.0
   goal = current_target.global_position
   intent = "target:" + str(current_target.get_instance_id()) if target_distance > stop_range else ""
   flank = (movement == "flank_sides" or (base_rule.has("program") and stance == "flank")) and target_distance > 160.0
  if movement in ["protect_hexagon", "guard_rear", "safe_backline"]:
   var anchor: Vector2 = arena.call("formation_anchor", self)
   if global_position.distance_to(anchor) > (70.0 if movement == "safe_backline" else 125.0):
    goal = anchor
    intent = "formation"
    flank = false
  if movement == "align_with_square":
   for friend: BaseGeoUnit in allies():
    if friend.unit_type == "square" and global_position.distance_to(friend.global_position) < 380.0:
     var staging: Vector2 = friend.global_position - Vector2(95.0 if team == 0 else -95.0, friend.flank_sign * 115.0)
     if global_position.distance_to(staging) > 50.0 and target_distance > 250.0:
      goal = staging
      intent = "square:" + str(friend.get_instance_id())
      flank = false
     break
  if movement == "align_with_crystal" and unit_type == "diamond":
   var firing: Vector2 = call("crystal_firing_position")
   if firing.is_finite() and global_position.distance_to(firing) > 25.0:
    goal = firing
    intent = "crystal"
    flank = false
  var nearest_enemy: BaseGeoUnit = null
  var nearest_distance: float = INF
  for enemy: BaseGeoUnit in enemies():
   var distance: float = global_position.distance_to(enemy.global_position)
   if distance < nearest_distance:
    nearest_distance = distance
    nearest_enemy = enemy
  if is_instance_valid(nearest_enemy):
   if current_hp / max_hp <= float(rule.get("retreat_hp", 0.0)) or (unit_type == "diamond" and nearest_distance < 220.0) or (base_rule.has("program") and stance == "kite" and attack_range > 100 and nearest_distance < attack_range*0.75):
    desired = -global_position.direction_to(nearest_enemy.global_position)
    intent = ""
 if is_instance_valid(arena.terrain) and behavior!="hold":
  var terrain_goal: Vector2 = arena.terrain.strategy_goal(self,goal)
  if terrain_goal.is_finite() and terrain_goal!=goal:
   goal=terrain_goal
   intent="terrain:"+str(rule.get("terrain_strategy","auto"))
   flank=false
 if not intent.is_empty():
  desired = arena.routed_direction(self,goal,intent)
  if flank: desired = (desired + desired.orthogonal() * flank_sign * 0.65).normalized()
 elif is_instance_valid(arena.navigation):
  arena.navigation.routes.erase(get_instance_id())
 var separation: Vector2 = Vector2.ZERO
 for friend: BaseGeoUnit in allies():
  if friend == self:
   continue
  var offset: Vector2 = global_position - friend.global_position
  var minimum: float = (unit_radius + friend.unit_radius) * 1.35
  var distance: float = offset.length()
  if distance < minimum and distance > 0.1:
   separation += offset / distance * (1.0 - distance / minimum) * 2.8
 desired = (desired + separation).limit_length(1.0)
 desired = whisker_steering(desired)
 var speed: float = move_speed * terrain_multiplier(desired) * (1.6 if overclock_left > 0.0 else 1.0)
 return active_velocity.lerp(desired * speed, minf(1.0, delta * 10.0))

func tick_unit(_delta: float) -> void:
 if not scripted_control: basic_attack()

func basic_attack() -> void:
 if is_plan_controlled() and not execution.allow_attack: return
 if attack_left > 0.0 or attack_damage <= 0.0 or not target_valid():
  return
 var extra: float = 60.0 if current_target is CoreMatrixBase else 0.0
 if global_position.distance_to(current_target.global_position) > attack_range + extra:
  return
 attack_left = attack_cd
 attack_serial += 1
 if unit_type in ["circle", "diamond"]:
  var projectile: GeoProjectile = GeoProjectile.new()
  projectile.arena = arena
  projectile.team = team
  projectile.damage = attack_damage
  projectile.kind = unit_type
  projectile.tint = rim_color
  projectile.source = weakref(self)
  projectile.direction = global_position.direction_to(current_target.global_position)
  projectile.position = global_position + projectile.direction * (unit_radius + 4.0)
  projectile.speed = 720.0 if unit_type == "circle" else 1250.0
  projectile.distance_left = attack_range + 80.0
  arena.add_child(projectile)
  return
 var excluded: Array[RID] = arena.friendly_shield_rids(team)
 var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, current_target.global_position, 4 | 16, excluded)
 var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
 if not hit.is_empty():
  if hit["collider"].has_method("take_damage"):
   hit["collider"].call("take_damage", attack_damage, self)
  return
 var endpoint: Vector2 = current_target.global_position
 current_target.call("take_damage", attack_damage, self)
 TransientVFX.beam(arena, PackedVector2Array([global_position, endpoint]), rim_color, 2.0, 0.14)
 TransientVFX.effect(arena,endpoint,rim_color,"shatter" if unit_type == "triangle" else "ring",22.0,0.2)

func target_valid() -> bool:
 return is_instance_valid(current_target) and not bool(current_target.get("dead")) and (not current_target is BaseGeoUnit or not is_instance_valid(arena.terrain) or arena.terrain.can_perceive(self,current_target))

func take_damage(amount: float, _attacker: Node2D = null) -> void:
 if dead or not arena.is_combat_active():
  return
 arena.damage_reported.emit(self,amount,_attacker)
 arena.actual_damage_reported.emit(self,minf(current_hp,maxf(0,amount)),_attacker)
 current_hp = maxf(0.0, current_hp - amount)
 under_attack_left = 1.0
 inner_fill.scale = Vector2.ONE * (current_hp / max_hp)
 if is_instance_valid(hit_tween):
  hit_tween.kill()
 outer_border.modulate = Color(4.0, 4.0, 4.0)
 hit_tween = create_tween()
 hit_tween.tween_property(outer_border, "modulate", Color.WHITE, 0.1)
 if current_hp <= 0.0:
  die()

func heal(amount: float) -> void:
 if dead:
  return
 var restored: float = minf(max_hp-current_hp,maxf(0,amount))
 current_hp += restored
 arena.healing_reported.emit(self,restored)
 inner_fill.scale = Vector2.ONE * (current_hp / max_hp)

func apply_emp(duration: float) -> void:
 stun_left = maxf(stun_left, duration)
 skill_interrupted("EMP中断")
 cancel_active_skill()

func cancel_active_skill() -> void:
 pass

func die() -> void:
 if dead:
  return
 skill_interrupted("单位阵亡")
 dead = true
 remove_from_group("units")
 remove_from_group("units_team_" + str(team))
 collision_layer = 0
 collision_mask = 0
 TransientVFX.spawn_shatter(arena, global_position, rim_color, unit_radius)
 slow_sources.clear()
 nebula_ids.clear()
 revealed_until.clear()
 portal_boost_left=0
 gate_push_velocity=Vector2.ZERO
 arena.unregister_unit(self)
 queue_free()

func whisker_steering(desired: Vector2) -> Vector2:
 if desired.length_squared() < 0.01:
  return desired
 var started: int = Time.get_ticks_usec()
 var direction: Vector2 = desired.normalized()
 var avoidance: Vector2 = Vector2.ZERO
 var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
 for offset: float in [0.0,-38.0,38.0]:
  var length: float = unit_radius + 60.0
  var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position,global_position+direction.rotated(deg_to_rad(offset))*length,16)
  var hit: Dictionary = space.intersect_ray(query)
  if is_instance_valid(arena.navigation): arena.navigation.whisker_queries += 1
  if hit.is_empty(): continue
  var normal: Vector2 = hit["normal"]
  var tangent: Vector2 = normal.orthogonal()
  var sign_value: float = signf(tangent.dot(direction))
  if absf(tangent.dot(direction)) < 0.15:
   if Engine.get_physics_frames() > avoid_until:
    avoid_side = flank_sign
    avoid_until = Engine.get_physics_frames()+54
   sign_value = avoid_side
  avoidance += (normal+tangent*sign_value).normalized()
 if is_instance_valid(arena.navigation): arena.navigation.whisker_usec += Time.get_ticks_usec()-started
 if avoidance.length_squared() > 0.01:
  return (direction*0.35+avoidance.normalized()*0.95).normalized()*desired.length()
 return desired

func _exit_tree() -> void:
 if is_instance_valid(arena):
  arena.local_units.erase(self)
  if is_instance_valid(arena.navigation): arena.navigation.routes.erase(get_instance_id())

func _draw() -> void:
 var faction_color: Color = ProceduralGeo.BLUE if team == 0 else ProceduralGeo.RED
 # The badge is deliberately independent from the unit silhouette and rim
 # color, so faction remains legible in dense fights and for color-blind users.
 draw_circle(Vector2.ZERO,5.5,faction_color.darkened(0.42))
 draw_arc(Vector2.ZERO,5.5,0,TAU,16,Color.WHITE,1.0,true)
 var font: Font = ThemeDB.fallback_font
 draw_string(font,Vector2(-4.5,4.0),"B" if team == 0 else "R",HORIZONTAL_ALIGNMENT_CENTER,9,8,Color.WHITE)
 if selected:
  var title: String = ("蓝方" if team == 0 else "红方")+" · "+str(UnitCatalog.DATA[unit_type]["zh"])
  var width: float = maxf(78.0,GameSettings.font_px(14)*title.length()*0.58)
  draw_rect(Rect2(-width*0.5,-unit_radius-25.0,width,18.0),Color(0.015,0.03,0.05,0.92),true)
  draw_rect(Rect2(-width*0.5,-unit_radius-25.0,width,18.0),faction_color, false,1.0)
  draw_string(font,Vector2(-width*0.5+5.0,-unit_radius-11.0),title,HORIZONTAL_ALIGNMENT_LEFT,width-10.0,GameSettings.font_px(11),Color.WHITE)
 if not slow_sources.is_empty():
  draw_arc(Vector2.ZERO,unit_radius+7.0,0,TAU,24,Color(1.8,0.9,0.1),2.0,true)
 if stun_left > 0.0:
  draw_arc(Vector2.ZERO, unit_radius + 9.0, 0, TAU, 24, Color(1.0, 2.0, 3.0), 1.5, true)
 if buff_left > 0.0:
  draw_arc(Vector2.ZERO, unit_radius + 5.0, 0, TAU * 0.65, 24, ProceduralGeo.GOLD, 1.2, true)
