class_name MainArena
extends CombatContext

@export var terrain_enabled: bool = true
@export var map_id: String = ""

enum Phase { PREPARING, PLAYING, ENDED }
const WORLD_RECT: Rect2 = MapCatalog.WORLD_RECT
var phase: int = Phase.PREPARING
var flux: Array[float] = [180.0, 180.0]
var bases: Array[CoreMatrixBase] = []
var prisms: Array[EnergyPrism] = []
var hex_counts: Array[int] = [0, 0]
var had_hexagon: Array[bool] = [false, false]
var communication_jammed: bool = false
var match_left: float = 600.0
var override_left: float = 0.0
var skill_cooldowns: Dictionary = {"EMP_STRIKE": 0.0, "OVERCLOCK": 0.0, "TOPOLOGY_SWAP": 0.0}
var selected_skill: String = ""
var enemy_spawn_left: float = 4.0
var enemy_tactic_left: float = 18.0
var spawn_serial: Array[int] = [0, 0]
var ai_enabled: bool = true
var hud: CanvasLayer
var camera: Camera2D
var background_material: ShaderMaterial
var winner_team: int = -2
var end_reason: String = ""
var elapsed: float = 0.0
var selected_units: Array[BaseGeoUnit] = []
var selection_active: bool = false
var selection_start: Vector2 = Vector2.ZERO
var selection_current: Vector2 = Vector2.ZERO
var selection_screen_start: Vector2 = Vector2.ZERO
var selection_double_click: bool = false
var tactical_draw_active: bool = false
var tactical_draw_points: Array[Vector2] = []
var tactical_draw_last: Vector2 = Vector2.INF
var pending_squad_skill_class: String = ""
var local_override_left: float = 0.0
var global_tactic_revision: int = 0
var copilot: Node
var last_prism_owners: Array[int] = [-2,-2]

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_PAUSABLE
 map_id = MatchSession.consume_map() if map_id.is_empty() else map_id
 TacticalBrain.begin_match_profiles()
 reduced_motion = bool(GameSettings.values["reduced_motion"])
 GameSettings.settings_changed.connect(_settings_updated)
 flux_pickup_reported.connect(func(unit: BaseGeoUnit, amount: int) -> void:
  if is_combat_active(): flux[unit.team] += amount)
 build_environment()
 build_bounds()
 unit_added.connect(func(unit: BaseGeoUnit) -> void:
  _unit_spawned(unit)
  if unit.team == 1 and is_instance_valid(copilot): copilot.call("on_enemy_unit_spawned",unit)
  SignalBus.unit_spawned.emit(unit))
 unit_removed.connect(func(unit: BaseGeoUnit) -> void:
  _unit_died(unit,unit.team,unit.global_position)
  SignalBus.unit_died.emit(unit,unit.team,unit.global_position))
 gravity_triggered.connect(func(team: int, center: Vector2, radius: float) -> void: SignalBus.gravity_collapsed.emit(team,center,radius))
 SignalBus.tactical_profile_updated.connect(func(team: int, profile: Dictionary, _prompt: String) -> void: profile_changed.emit(team,profile))
 if terrain_enabled:
  navigation = ArenaObstacles.new()
  navigation.arena = self
  add_child(navigation)
  navigation.build(map_id)
  if is_instance_valid(terrain):
   terrain.terrain_event.connect(func(_unit: BaseGeoUnit, event_name: String, _object_id: String) -> void:
    if event_name in ["reactor_warning","reactor_detonated"] and is_instance_valid(copilot): copilot.call("request_major_event",event_name))
 copilot = load("res://scripts/core/ai_copilot_analyst.gd").new() as Node
 copilot.name = "AICopilotAnalyst"
 add_child(copilot)
 copilot.setup(self)
 base_damage_reported.connect(func(_base: CoreMatrixBase, _amount: float, _attacker: Node2D) -> void:
  if is_instance_valid(copilot): copilot.request_major_event("基地受袭"))
 SignalBus.commander_skill_requested.connect(select_skill)
 for team: int in range(2):
  var base: CoreMatrixBase = CoreMatrixBase.new()
  base.team = team
  base.arena = self
  base.position = MapCatalog.base_positions(map_id)[team]
  base.set_meta("obstacle_id",MapCatalog.definition(map_id)["base_specs"][team]["id"])
  add_child(base)
  bases.append(base)
 for index: int in range(2):
  var prism: EnergyPrism = EnergyPrism.new()
  prism.arena = self
  prism.title = "NORTH" if index == 0 else "SOUTH"
  prism.position = MapCatalog.prism_positions(map_id)[index]
  prism.set_meta("obstacle_id",MapCatalog.definition(map_id)["prism_specs"][index]["id"])
  add_child(prism)
  prisms.append(prism)
  local_prisms.append(prism)
 for team: int in range(2):
  for kind: String in ["hexagon", "square", "square", "triangle", "triangle", "triangle", "diamond", "diamond", "circle"]:
   spawn_unit(kind, team)
 var camera_script: Script = load("res://scripts/core/camera_rig.gd")
 camera = camera_script.new() as Camera2D
 camera.set("arena", self)
 add_child(camera)
 var hud_script: Script = load("res://scripts/ui/commander_hud.gd")
 hud = hud_script.new() as CanvasLayer
 hud.set("arena", self)
 add_child(hud)
 emit_base_health()
 if "--autostart" in OS.get_cmdline_user_args():
  start_match()

func is_combat_active() -> bool:
 return phase == Phase.PLAYING

func profile_for(team: int) -> Dictionary:
 return TacticalBrain.team_profiles[team]

func build_environment() -> void:
 background_material = CombatContext.create_environment(self,MapCatalog.WORLD_RECT.grow(400.0))
 background_material.set_shader_parameter("reduced_motion",reduced_motion)

func build_bounds() -> void:
 var walls: StaticBody2D = StaticBody2D.new()
 walls.collision_layer = 16
 walls.collision_mask = 3
 add_child(walls)
 var width: float = MapCatalog.WORLD_SIZE.x
 var height: float = MapCatalog.WORLD_SIZE.y
 var rectangles: Array[Rect2] = [Rect2(-40,-40,width+80,40), Rect2(-40,height,width+80,40), Rect2(-40,0,40,height), Rect2(width,0,40,height)]
 for rectangle: Rect2 in rectangles:
  var shape: CollisionShape2D = CollisionShape2D.new()
  var box: RectangleShape2D = RectangleShape2D.new()
  box.size = rectangle.size
  shape.shape = box
  shape.position = rectangle.get_center()
  walls.add_child(shape)

func start_match() -> void:
 if phase != Phase.PREPARING:
  return
 var plan_error: String = TacticPlan.profile_error(profile_for(0),map_id)
 if not plan_error.is_empty():
  notify(plan_error,true)
  return
 phase = Phase.PLAYING
 hud.call("close_matrix")
 notify("指挥链路就绪。占领能源棱镜，摧毁敌方核心。", false)

func _physics_process(delta: float) -> void:
 if phase != Phase.PLAYING:
  queue_redraw()
  return
 elapsed += delta
 local_override_left = maxf(0.0, local_override_left - delta)
 _update_manual_authority(delta)
 match_left = maxf(0.0, match_left - delta)
 for team: int in range(2):
  flux[team] += income(team) * delta
 for index: int in range(prisms.size()):
  var owner: int = prisms[index].capture_owner
  if last_prism_owners[index] == 0 and owner != 0 and is_instance_valid(copilot):
   copilot.call("request_major_event","蓝方失去能源棱镜")
  last_prism_owners[index] = owner
 var recharge: float = commander_recharge()
 override_left = maxf(0.0, override_left - delta * recharge)
 for skill: String in skill_cooldowns:
  skill_cooldowns[skill] = maxf(0.0, float(skill_cooldowns[skill]) - delta * recharge)
 if ai_enabled:
  enemy_spawn_left -= delta
  enemy_tactic_left -= delta
  if enemy_spawn_left <= 0.0:
   enemy_spawn_left = 4.0
   enemy_deploy()
  if enemy_tactic_left <= 0.0:
   enemy_tactic_left = 18.0
   var prompts: Array[String] = ["全军突击", "侧翼切后排", "棱镜折射", "保护六边形", "风筝拉扯"]
   TacticalBrain.compile_prompt_to_profile(1, prompts[int(elapsed / 18.0) % prompts.size()])
 SignalBus.flux_updated.emit(flux[0], income(0))
 if match_left <= 0.0:
  resolve_timeout()
 queue_redraw()

func income(team: int) -> float:
 var rate: float = 12.0
 for prism: EnergyPrism in prisms:
  if prism.capture_owner == team:
   rate += 6.0
 return rate

func commander_recharge() -> float:
 return 1.0 + 0.4 * float(hex_counts[0])

func spawn_unit(kind: String, team: int, spawn_pos: Vector2 = Vector2.INF, validate_position: bool = true) -> BaseGeoUnit:
 var code: Script = load("res://scripts/units/unit_" + kind + ".gd")
 var unit: BaseGeoUnit = code.new() as BaseGeoUnit
 unit.team = team
 unit.arena = self
 var serial: int = spawn_serial[team]
 var sign_x: float = 1.0 if team == 0 else -1.0
 unit.spawn_index = serial
 unit.position = MapCatalog.base_positions(map_id)[team] + Vector2(sign_x * (135.0 + float(serial % 3) * 65.0), float((serial / 3) % 7 - 3) * 72.0)
 if spawn_pos.is_finite():
  unit.position = spawn_pos
 if validate_position and not spawn_clear(unit.position,float(UnitCatalog.DATA[kind]["radius"])):
  var origin: Vector2 = unit.position
  var found: bool = false
  for attempt: int in range(120):
   var point: Vector2 = origin + Vector2.RIGHT.rotated(float(attempt)*2.399963)*sqrt(float(attempt)+1.0)*25.0
   if spawn_clear(point,float(UnitCatalog.DATA[kind]["radius"])):
    unit.position = point
    found = true
    break
  if not found:
   unit.free()
   return null
 spawn_serial[team] += 1
 add_child(unit)
 return unit

func spawn_clear(point: Vector2, radius: float) -> bool:
 if not WORLD_RECT.grow(-radius-2).has_point(point): return false
 for unit: BaseGeoUnit in local_units:
  if not unit.dead and point.distance_to(unit.global_position) < radius+unit.unit_radius+3: return false
 for base: CoreMatrixBase in bases:
  if point.distance_to(base.global_position) < radius+base.unit_radius+3: return false
 if is_instance_valid(navigation):
  for polygon: PackedVector2Array in navigation.solid_polygons:
   if Geometry2D.is_point_in_polygon(point,polygon): return false
   for index: int in range(polygon.size()):
    if Geometry2D.get_closest_point_to_segment(point,polygon[index],polygon[(index+1)%polygon.size()]).distance_to(point) < radius+2: return false
 return true

func deployment_reason(kind: String, team: int = 0) -> String:
 if phase != Phase.PLAYING:
  return "请先开始对局" if phase == Phase.PREPARING else "对局已结束"
 if not UnitCatalog.DATA.has(kind):
  return "未知兵种"
 if units_for(team).size() >= 30:
  return "人口已满，最多 30 单位"
 if kind == "hexagon" and hex_counts[team] >= 2:
  return "指挥官已达上限，最多 2 个"
 if flux[team] < float(UnitCatalog.DATA[kind]["cost"]):
  return "Flux 不足，需要 " + str(UnitCatalog.DATA[kind]["cost"])
 return ""

func deploy(kind: String, team: int = 0) -> bool:
 var reason: String = deployment_reason(kind, team)
 if not reason.is_empty():
  if team == 0:
   notify(reason, true)
  return false
 var unit: BaseGeoUnit = spawn_unit(kind,team)
 if not is_instance_valid(unit):
  if team == 0: notify("基地附近没有安全部署位置",true)
  return false
 flux[team] -= float(UnitCatalog.DATA[kind]["cost"])
 if team == 0:
  notify("已部署 " + String(UnitCatalog.DATA[kind]["zh"]), false)
 return true

func _unit_spawned(_unit: CharacterBody2D) -> void:
 refresh_hex_counts()

func _unit_died(_unit: CharacterBody2D, _team: int, _position: Vector2) -> void:
 if _unit is BaseGeoUnit and selected_units.has(_unit):
  selected_units.erase(_unit)
  SignalBus.selection_changed.emit(selected_units.duplicate())
 refresh_hex_counts()

func refresh_hex_counts() -> void:
 for team: int in range(2):
  var count: int = 0
  for unit: BaseGeoUnit in units_for(team):
   if unit.unit_type == "hexagon":
    count += 1
  if count > 0:
   had_hexagon[team] = true
  if hex_counts[team] != count:
   hex_counts[team] = count
   SignalBus.hexagon_count_changed.emit(team, count)
 var jammed: bool = had_hexagon[0] and hex_counts[0] == 0
 if communication_jammed != jammed:
  communication_jammed = jammed
  SignalBus.communication_jammed.emit(jammed)
  if jammed:
   notify("指挥链路中断。部署六边形可恢复战术终端。", true)

func submit_tactic(prompt_text: String, overrides: Dictionary = {}, compiled: Dictionary = {}) -> Dictionary:
 if phase == Phase.ENDED:
  return tactic_error("对局已结束")
 if phase == Phase.PLAYING and not selected_units.is_empty():
  return submit_squad_tactic(prompt_text)
 if phase == Phase.PLAYING:
  if communication_jammed:
   return tactic_error("链路中断，请先部署六边形")
  if override_left > 0.0:
   return tactic_error("战术终端冷却中：" + str(ceili(override_left / commander_recharge())) + " 秒")
 var result: Dictionary = TacticalBrain.parse_prompt(prompt_text) if compiled.is_empty() else {"ok":true,"profile":compiled.duplicate(true)}
 if not bool(result["ok"]):
  return tactic_error(String(result["message"]))
 var profile: Dictionary = result["profile"]
 for kind: String in overrides:
  if UnitCatalog.TYPES.has(kind):
   profile["unit_rules"][kind]["retreat_hp"] = clampf(float(overrides[kind]), 0.0, 0.9)
   if profile["unit_rules"][kind].has("program"): profile["unit_rules"][kind]["program"]["base"]["retreat_hp"] = profile["unit_rules"][kind]["retreat_hp"]
 restore_copilot_profile()
 global_tactic_revision += 1
 TacticalBrain.team_profiles[0] = profile.duplicate(true)
 TacticalBrain.last_prompts[0] = prompt_text
 SignalBus.tactical_profile_updated.emit(0, TacticalBrain.team_profiles[0], prompt_text)
 if phase == Phase.PLAYING:
  override_left = 30.0
 notify("战术已生效：" + prompt_text, false)
 return {"ok": true, "profile": profile}

func apply_copilot_proposal(profile: Dictionary) -> bool:
 if phase != Phase.PLAYING or not profile.has("unit_rules"):
  return false
 restore_copilot_profile()
 var applied: int = 0
 for unit: BaseGeoUnit in units_for(0):
  if unit.authority_state != BaseGeoUnit.ControlAuthority.AUTO_AGENT: continue
  var rule_patch: Variant = profile["unit_rules"].get(unit.unit_type)
  if rule_patch is Dictionary:
   var scoped_rule: Dictionary = rule_patch.duplicate(true)
   scoped_rule["lane_mode"] = profile.get("lane_mode","auto")
   scoped_rule["stance"] = profile.get("stance","balanced")
   unit.apply_copilot_rule(scoped_rule)
   applied += 1
 if applied == 0:
  notify("没有可接收参谋建议的全局自动单位",true)
  return false
 notify("参谋建议已临时接管 %d 个自动单位，可恢复原方案" % applied,false)
 return true

func restore_copilot_profile() -> void:
 for unit: BaseGeoUnit in units_for(0):
  if unit.copilot_active: unit.restore_copilot_rule()

func submit_squad_tactic(prompt_text: String) -> Dictionary:
 if phase == Phase.ENDED:
  return tactic_error("对局已结束")
 if phase != Phase.PLAYING:
  return tactic_error("请先开始对局")
 if local_override_left > 0.0:
  return tactic_error("小队指令冷却中：%d 秒" % ceili(local_override_left))
 var result: Dictionary = TacticalBrain.parse_prompt(prompt_text)
 if not bool(result.get("ok",false)):
  return tactic_error(String(result.get("message","小队指令无法编译")))
 var profile: Dictionary = result["profile"]
 var applied: int = 0
 for unit: BaseGeoUnit in selected_units:
  if not is_instance_valid(unit) or unit.dead or unit.team != 0:
   continue
  var unit_rule: Dictionary = (profile["unit_rules"].get(unit.unit_type,{}) as Dictionary).duplicate(true)
  unit_rule["lane_mode"] = profile.get("lane_mode","auto")
  unit_rule["stance"] = profile.get("stance","balanced")
  unit.set_squad_rule(unit_rule)
  applied += 1
 if applied == 0:
  return tactic_error("没有可接收小队指令的存活蓝方单位")
 local_override_left = 3.0
 SignalBus.squad_command_reported.emit("小队指令已应用：%d 个单位" % applied,true)
 notify("小队指令已应用，仅作用于已选择的 %d 个单位" % applied,false)
 return {"ok":true,"applied":applied,"profile":profile}

func tactic_error(message: String) -> Dictionary:
 notify(message, true)
 return {"ok": false, "message": message}

func skill_reason(skill: String) -> String:
 if phase != Phase.PLAYING:
  return "请先开始对局" if phase == Phase.PREPARING else "对局已结束"
 if not UnitCatalog.SKILLS.has(skill):
  return "未知技能"
 if float(skill_cooldowns[skill]) > 0.0:
  return "技能冷却中"
 if flux[0] < float(UnitCatalog.SKILLS[skill]["cost"]):
  return "Flux 不足，需要 " + str(int(UnitCatalog.SKILLS[skill]["cost"]))
 return ""

func select_skill(skill: String) -> void:
 var reason: String = skill_reason(skill)
 if not reason.is_empty():
  notify(reason, true)
  return
 selected_skill = "" if selected_skill == skill else skill
 notify("点击战场施放 " + String(UnitCatalog.SKILLS[skill]["zh"]) + "，Esc 或右键取消", false)

func cast_skill(skill: String, point: Vector2) -> bool:
 var reason: String = skill_reason(skill)
 if not reason.is_empty():
  notify(reason, true)
  return false
 if not WORLD_RECT.grow(-25).has_point(point):
  notify("请选择战场边界内的位置", true)
  return false
 if skill == "TOPOLOGY_SWAP":
  if not topology_swap(point):
   return false
 elif skill == "EMP_STRIKE":
  reveal_targets(0,point,200.0)
  for enemy: BaseGeoUnit in units_for(1):
   if point.distance_to(enemy.global_position) <= 200.0:
    enemy.apply_emp(2.8)
    enemy.take_damage(35.0)
  TransientVFX.effect(self, point, Color(0.3,2.1,3.0), "pulse", 200.0, 0.65)
 elif skill == "OVERCLOCK":
  var zone: OverclockZone = OverclockZone.new()
  zone.arena = self
  zone.position = point
  add_child(zone)
 flux[0] -= float(UnitCatalog.SKILLS[skill]["cost"])
 skill_cooldowns[skill] = float(UnitCatalog.SKILLS[skill]["cd"])
 selected_skill = ""
 notify(String(UnitCatalog.SKILLS[skill]["zh"]) + "已施放", false)
 return true

func topology_swap(point: Vector2) -> bool:
 var offensive: bool = false
 for enemy: BaseGeoUnit in units_for(1):
  if enemy.global_position.distance_to(point) <= 160.0:
   offensive = true
   break
 var moving: Array[BaseGeoUnit] = []
 var center: Vector2 = point
 var anchor: BaseGeoUnit = null
 if not offensive:
  anchor = nearest_hexagon(point, 0)
  if not is_instance_valid(anchor):
   notify("没有友方六边形可作为转移锚点", true)
   return false
  center = anchor.global_position
 for unit: BaseGeoUnit in units_for(0):
  if offensive:
   if unit.unit_type in ["triangle", "square"] and unit.global_position.distance_to(bases[0].global_position) <= 350.0:
    moving.append(unit)
  elif unit != anchor and unit.global_position.distance_to(point) <= 160.0:
   moving.append(unit)
 if moving.is_empty():
  notify("没有可转移单位。进攻模式需要基地附近的三角或方形。", true)
  return false
 var landings: Array[Vector2] = []
 for unit: BaseGeoUnit in moving:
  var landing: Vector2 = find_landing(center, unit, moving, landings)
  if not landing.is_finite():
   notify("目标区域没有足够的安全落点", true)
   return false
  landings.append(landing)
 for index: int in range(moving.size()):
  var unit: BaseGeoUnit = moving[index]
  TransientVFX.effect(self, unit.global_position, Color(0.4,2.0,2.8), "warp", 35.0)
  TransientVFX.beam(self, PackedVector2Array([unit.global_position,landings[index]]), Color(0.2,1.2,1.8,0.4), 1.0, 0.5)
  unit.cancel_active_skill()
  unit.global_position = landings[index]
  unit.velocity = Vector2.ZERO
  unit.external_velocity = Vector2.ZERO
  unit.boundary_maneuver.reset()
  unit.slow_sources.clear()
  if is_instance_valid(terrain): terrain.refresh_regions(unit)
  if is_instance_valid(navigation):
   navigation.routes.erase(unit.get_instance_id())
   for field: EntropyField in navigation.fields:
    if Geometry2D.is_point_in_polygon(field.to_local(unit.global_position),ProceduralGeo.get_regular_polygon(field.radius,6)):
     field._entered(unit)
  unit.trail_line.clear_points()
  TransientVFX.effect(self, unit.global_position, Color(2.0,1.5,0.4), "warp", 35.0)
 return true

func find_landing(center: Vector2, unit: BaseGeoUnit, moving: Array[BaseGeoUnit], reserved: Array[Vector2]) -> Vector2:
 for attempt: int in range(100):
  var angle: float = float(attempt) * 2.399963
  var radius: float = 65.0 + sqrt(float(attempt)) * 19.0
  var point: Vector2 = center + Vector2.RIGHT.rotated(angle) * radius
  if not WORLD_RECT.grow(-unit.unit_radius - 2.0).has_point(point):
   continue
  var blocked: bool = false
  for existing: Vector2 in reserved:
   if point.distance_to(existing) < unit.unit_radius + 28.0:
    blocked = true
  for other: BaseGeoUnit in local_units:
   if not moving.has(other) and point.distance_to(other.global_position) < unit.unit_radius + other.unit_radius + 3.0:
    blocked = true
  for base: CoreMatrixBase in bases:
   if point.distance_to(base.global_position) < unit.unit_radius + base.unit_radius + 3.0:
    blocked = true
  var circle: CircleShape2D = CircleShape2D.new()
  circle.radius = unit.unit_radius + 2.0
  var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
  query.shape = circle
  query.transform = Transform2D(0.0, point)
  query.collision_mask = 4 | 16
  if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
   blocked = true
  if not blocked:
   return point
 return Vector2.INF

func nearest_hexagon(point: Vector2, team: int) -> BaseGeoUnit:
 var best: BaseGeoUnit = null
 var distance: float = INF
 for unit: BaseGeoUnit in units_for(team):
  if unit.unit_type == "hexagon" and point.distance_squared_to(unit.global_position) < distance:
   best = unit
   distance = point.distance_squared_to(unit.global_position)
 return best

func objective_for(unit: BaseGeoUnit) -> Vector2:
 return CombatMovement.objective_for(self,unit)

func formation_anchor(unit: BaseGeoUnit) -> Vector2:
 return CombatMovement.formation_anchor(self,unit)

func enemy_deploy() -> void:
 var counts: Dictionary = {"triangle": 0, "square": 0, "circle": 0, "diamond": 0, "hexagon": 0}
 for unit: BaseGeoUnit in units_for(0):
  counts[unit.unit_type] = int(counts[unit.unit_type]) + 1
 var priorities: Array[String] = ["triangle", "circle", "square", "diamond"]
 if hex_counts[1] == 0:
  priorities.push_front("hexagon")
 if int(counts["square"]) >= 3:
  priorities.push_front("diamond")
 elif int(counts["diamond"]) >= 3:
  priorities.push_front("triangle")
 elif int(counts["triangle"]) >= 4:
  priorities.push_front("circle")
 else:
  priorities.push_front(UnitCatalog.TYPES[int(elapsed / 4.0) % 4])
 for kind: String in priorities:
  if deploy(kind, 1):
   return

func emit_base_health() -> void:
 if bases.size() == 2:
  SignalBus.base_hp_updated.emit(bases[0].current_hp, bases[0].max_hp, bases[1].current_hp, bases[1].max_hp)

func resolve_timeout() -> void:
 var blue_ratio: float = bases[0].current_hp / bases[0].max_hp
 var red_ratio: float = bases[1].current_hp / bases[1].max_hp
 var winner: int = -1 if blue_ratio == red_ratio else (0 if blue_ratio > red_ratio else 1)
 finish_match(winner, "时间结束，按核心剩余生命判定")

func finish_match(winner: int, reason: String) -> void:
 if phase != Phase.PLAYING:
  return
 phase = Phase.ENDED
 winner_team = winner
 end_reason = reason
 selected_skill = ""
 if is_instance_valid(copilot): copilot.call("stop_for_match_end")
 SignalBus.match_ended.emit(winner, reason)
 notify("对局结束：" + reason, false)

func restart() -> void:
 get_tree().paused = false
 MatchSession.request_match(map_id)
 get_tree().reload_current_scene()

func notify(message: String, error: bool = false) -> void:
 if is_instance_valid(hud):
  hud.call("show_message", message, error)

func set_reduced_motion(enabled: bool) -> void:
 GameSettings.set_value("reduced_motion",enabled)

func _settings_updated() -> void:
 reduced_motion = bool(GameSettings.values["reduced_motion"])
 background_material.set_shader_parameter("reduced_motion",reduced_motion)

func _unhandled_key_input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.is_pressed() or event.is_echo():
  return
 if not KeybindManager.gameplay_input_allowed() or bool(hud.get("matrix_open")):
  return
 var key_event: InputEventKey = event as InputEventKey
 if KeybindManager.action_matches(key_event,"spawn_triangle"):
  deploy("triangle")
 elif KeybindManager.action_matches(key_event,"spawn_square"):
  deploy("square")
 elif KeybindManager.action_matches(key_event,"spawn_circle"):
  deploy("circle")
 elif KeybindManager.action_matches(key_event,"spawn_diamond"):
  deploy("diamond")
 elif KeybindManager.action_matches(key_event,"spawn_hexagon"):
  deploy("hexagon")
 elif KeybindManager.action_matches(key_event,"cmd_emp"):
  select_skill("EMP_STRIKE")
 elif KeybindManager.action_matches(key_event,"cmd_overclock"):
  select_skill("OVERCLOCK")
 elif KeybindManager.action_matches(key_event,"cmd_swap"):
  select_skill("TOPOLOGY_SWAP")
 elif KeybindManager.action_matches(key_event,"copilot_opt_1"):
  if is_instance_valid(copilot): copilot.accept_proposal(0)
 elif KeybindManager.action_matches(key_event,"copilot_opt_2"):
  if is_instance_valid(copilot): copilot.accept_proposal(1)
 elif KeybindManager.action_matches(key_event,"copilot_opt_3"):
  if is_instance_valid(copilot): copilot.accept_proposal(2)
 elif KeybindManager.action_matches(key_event,"copilot_toggle_auto"):
  if is_instance_valid(copilot): copilot.toggle_auto_delegate()
 elif KeybindManager.action_matches(key_event,"skill_triangle"):
  cast_selected_class_skill("triangle",get_global_mouse_position())
 elif KeybindManager.action_matches(key_event,"skill_square"):
  cast_selected_class_skill("square",get_global_mouse_position())
 elif KeybindManager.action_matches(key_event,"skill_circle"):
  cast_selected_class_skill("circle",get_global_mouse_position())
 elif KeybindManager.action_matches(key_event,"skill_diamond"):
  cast_selected_class_skill("diamond",get_global_mouse_position())
 elif KeybindManager.action_matches(key_event,"skill_hexagon"):
  cast_selected_class_skill("hexagon",get_global_mouse_position())
 elif KeybindManager.action_matches(key_event,"squad_hold_orbit"):
  for unit: BaseGeoUnit in selected_units:
   if is_instance_valid(unit): unit.set_hold_orbit()
  notify("已命令所选单位驻守环绕",false)
 elif KeybindManager.action_matches(key_event,"squad_return_ai"):
  for unit: BaseGeoUnit in selected_units:
   if is_instance_valid(unit): unit.return_to_ai()
  notify("所选单位已归还 AI 托管",false)
 elif KeybindManager.action_matches(key_event,"toggle_tactical_drawer"):
  hud.call("toggle_matrix")
 elif key_event.keycode == KEY_ESCAPE:
  var was_aiming: bool = not selected_skill.is_empty() or not pending_squad_skill_class.is_empty()
  selected_skill = ""
  pending_squad_skill_class = ""
  if not was_aiming and not selection_active: clear_selection()
  hud.call("close_matrix")

func _unhandled_input(event: InputEvent) -> void:
 if not KeybindManager.gameplay_input_allowed() or bool(hud.get("matrix_open")):
  return
 if event is InputEventMouseButton:
  var button: InputEventMouseButton = event as InputEventMouseButton
  if button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
   if not pending_squad_skill_class.is_empty():
    cast_selected_class_skill(pending_squad_skill_class,get_global_mouse_position())
    pending_squad_skill_class = ""
    get_viewport().set_input_as_handled()
    return
   if not selected_skill.is_empty():
    cast_skill(selected_skill,get_global_mouse_position())
    get_viewport().set_input_as_handled()
    return
   selection_active = true
   selection_start = get_global_mouse_position()
   selection_current = selection_start
   selection_screen_start = button.position
   selection_double_click = button.double_click
   get_viewport().set_input_as_handled()
  elif button.button_index == MOUSE_BUTTON_LEFT and not button.pressed and selection_active:
   selection_current = get_global_mouse_position()
   selection_active = false
   if selection_screen_start.distance_to(button.position) > 6.0:
    select_in_world_rect(Rect2(selection_start,selection_current-selection_start).abs())
   else:
    var clicked: BaseGeoUnit = unit_at_point(selection_current)
    if is_instance_valid(clicked) and clicked.team == 0:
     if selection_double_click:
      select_same_kind(clicked.unit_type)
     else:
      set_selection([clicked])
    else:
     clear_selection()
   get_viewport().set_input_as_handled()
  elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
   if not pending_squad_skill_class.is_empty() or not selected_skill.is_empty():
    pending_squad_skill_class = ""
    selected_skill = ""
    get_viewport().set_input_as_handled()
    return
   if button.shift_pressed:
    tactical_draw_active = true
    tactical_draw_points = [get_global_mouse_position()]
    tactical_draw_last = tactical_draw_points[0]
   elif not selected_units.is_empty():
    issue_right_click_order(get_global_mouse_position())
   get_viewport().set_input_as_handled()
  elif button.button_index == MOUSE_BUTTON_RIGHT and not button.pressed and tactical_draw_active:
   tactical_draw_active = false
   var final_point: Vector2 = get_global_mouse_position()
   if tactical_draw_points.is_empty() or tactical_draw_points.back().distance_to(final_point)>20.0:
    tactical_draw_points.append(final_point)
   if tactical_draw_points.size() >= 2:
    var path_error: String = tactical_path_error(tactical_draw_points)
    if path_error.is_empty():
     for unit: BaseGeoUnit in selected_units:
      if is_instance_valid(unit): unit.set_tactical_path(tactical_draw_points)
     notify("小队航线已下达：%d 个航点" % tactical_draw_points.size(),false)
    else:
     notify(path_error,true)
   tactical_draw_points.clear()
   get_viewport().set_input_as_handled()
 elif event is InputEventMouseMotion:
  var motion: InputEventMouseMotion = event as InputEventMouseMotion
  if selection_active:
   selection_current = get_global_mouse_position()
   queue_redraw()
   get_viewport().set_input_as_handled()
  elif tactical_draw_active:
   var point: Vector2 = get_global_mouse_position()
   if tactical_draw_last.distance_to(point) >= 65.0:
    tactical_draw_points.append(point)
    tactical_draw_last = point
   queue_redraw()
   get_viewport().set_input_as_handled()

func unit_at_point(point: Vector2) -> BaseGeoUnit:
 var best: BaseGeoUnit = null
 var best_distance: float = INF
 for unit: BaseGeoUnit in units_for(0):
  var distance: float = point.distance_to(unit.global_position)
  if distance <= unit.unit_radius + 8.0 and distance < best_distance:
   best = unit
   best_distance = distance
 return best

func set_selection(units: Array[BaseGeoUnit]) -> void:
 clear_selection()
 for unit: BaseGeoUnit in units:
  if is_instance_valid(unit) and not unit.dead and unit.team == 0:
   unit.selected = true
   selected_units.append(unit)
 SignalBus.selection_changed.emit(selected_units.duplicate())
 queue_redraw()

func clear_selection() -> void:
 for unit: BaseGeoUnit in selected_units:
  if is_instance_valid(unit): unit.selected = false
 selected_units.clear()
 SignalBus.selection_changed.emit([])
 queue_redraw()

func select_in_world_rect(rect: Rect2) -> void:
 var result: Array[BaseGeoUnit] = []
 for unit: BaseGeoUnit in units_for(0):
  if rect.has_point(unit.global_position): result.append(unit)
 set_selection(result)

func select_same_kind(kind: String) -> void:
 var result: Array[BaseGeoUnit] = []
 var viewport_rect: Rect2 = Rect2(Vector2.ZERO,get_viewport_rect().size)
 for unit: BaseGeoUnit in units_for(0):
  var screen: Vector2 = get_viewport().get_canvas_transform() * unit.global_position
  if unit.unit_type == kind and viewport_rect.grow(20.0).has_point(screen): result.append(unit)
 set_selection(result)

func tactical_path_error(points: Array[Vector2]) -> String:
 if points.size() < 2:
  return "小队航线至少需要两个航点"
 var largest_radius: float = 0.0
 for unit: BaseGeoUnit in selected_units:
  if is_instance_valid(unit): largest_radius = maxf(largest_radius,unit.unit_radius)
 for index: int in range(points.size()):
  var point: Vector2 = points[index]
  if not WORLD_RECT.grow(-largest_radius-3.0).has_point(point):
   return "航点 %d 超出地图边界" % (index+1)
  if is_instance_valid(navigation):
   for polygon: PackedVector2Array in navigation.solid_polygons:
    if Geometry2D.is_point_in_polygon(point,polygon):
     return "航点 %d 位于障碍物内" % (index+1)
    for edge: int in range(polygon.size()):
     if Geometry2D.get_closest_point_to_segment(point,polygon[edge],polygon[(edge+1)%polygon.size()]).distance_to(point) < largest_radius+3.0:
      return "航点 %d 离障碍物过近" % (index+1)
 return ""

func issue_right_click_order(point: Vector2) -> void:
 var clicked_enemy: BaseGeoUnit = null
 for enemy: BaseGeoUnit in units_for(1):
  var perceived: bool = false
  for observer: BaseGeoUnit in selected_units:
   if is_instance_valid(observer) and (not is_instance_valid(terrain) or terrain.can_perceive(observer,enemy)):
    perceived = true
    break
  if perceived and point.distance_to(enemy.global_position) <= enemy.unit_radius + 12.0:
   clicked_enemy = enemy
   break
 if is_instance_valid(clicked_enemy):
  for unit: BaseGeoUnit in selected_units:
   if is_instance_valid(unit): unit.set_manual_attack(clicked_enemy,6.0)
  notify("已下达集火：红方"+String(UnitCatalog.DATA[clicked_enemy.unit_type]["zh"]),false)
  return
 var enemy_base: CoreMatrixBase = base_for(1)
 if is_instance_valid(enemy_base) and point.distance_to(enemy_base.global_position) <= enemy_base.unit_radius + 24.0:
  for unit: BaseGeoUnit in selected_units:
   if is_instance_valid(unit): unit.set_manual_attack(enemy_base,6.0)
  notify("已下达集火：红方基地",false)
  return
 var columns: int = maxi(1,ceili(sqrt(float(selected_units.size()))))
 var formation_units: Array[BaseGeoUnit] = []
 var destinations: Array[Vector2] = []
 var radii: Array[float] = []
 for index: int in range(selected_units.size()):
  var unit: BaseGeoUnit = selected_units[index]
  if not is_instance_valid(unit): continue
  var offset: Vector2 = Vector2((index % columns) - (columns-1)*0.5, floori(index/columns) - (ceil(float(selected_units.size())/columns)-1)*0.5) * 65.0
  var destination: Vector2 = _find_formation_destination(point+offset,unit.unit_radius,destinations,radii,selected_units)
  if not destination.is_finite():
   notify("该位置无法容纳完整编队，请选择更开阔的区域",true)
   return
  formation_units.append(unit)
  destinations.append(destination)
  radii.append(unit.unit_radius)
 for index: int in range(formation_units.size()):
  var unit: BaseGeoUnit = formation_units[index]
  if is_instance_valid(unit): unit.set_manual_move(destinations[index],4.0)
 notify("已下达编队移动：%d 个单位" % selected_units.size(),false)

func _find_formation_destination(origin: Vector2, radius: float, reserved: Array[Vector2], reserved_radii: Array[float], moving_units: Array[BaseGeoUnit]) -> Vector2:
 for attempt: int in range(72):
  var candidate: Vector2 = origin
  if attempt > 0:
   var ring: float = ceil(sqrt(float(attempt)))
   candidate += Vector2.RIGHT.rotated(float(attempt)*2.399963) * ring * 24.0
  if not WORLD_RECT.grow(-radius-3.0).has_point(candidate): continue
  var blocked: bool = false
  for base: CoreMatrixBase in bases:
   if candidate.distance_to(base.global_position) < radius+base.unit_radius+6.0:
    blocked = true
    break
  if blocked: continue
  for other: BaseGeoUnit in local_units:
   if not is_instance_valid(other) or other.dead or moving_units.has(other): continue
   if candidate.distance_to(other.global_position) < radius+other.unit_radius+6.0:
    blocked = true
    break
  if blocked: continue
  if is_instance_valid(navigation):
   for polygon: PackedVector2Array in navigation.solid_polygons:
    if Geometry2D.is_point_in_polygon(candidate,polygon):
     blocked = true
     break
    for edge: int in range(polygon.size()):
     if Geometry2D.get_closest_point_to_segment(candidate,polygon[edge],polygon[(edge+1)%polygon.size()]).distance_to(candidate) < radius+3.0:
      blocked = true
      break
    if blocked: break
  if blocked: continue
  for index: int in range(reserved.size()):
   if candidate.distance_to(reserved[index]) < radius+reserved_radii[index]+8.0:
    blocked = true
    break
  if not blocked: return candidate
 return Vector2.INF

func _update_manual_authority(delta: float) -> void:
 for unit: BaseGeoUnit in local_units:
  if not is_instance_valid(unit) or unit.authority_state != BaseGeoUnit.ControlAuthority.MANUAL_OVERRIDE:
   continue
  if unit.manual_mode == "orbit": continue
  var arrived: bool = unit.manual_move_target.is_finite() and unit.global_position.distance_to(unit.manual_move_target) <= 30.0
  var target_lost: bool = false
  var target_unseen: bool = false
  if unit.manual_mode == "attack":
   target_lost = not is_instance_valid(unit.manual_attack_target) or bool(unit.manual_attack_target.get("dead"))
   if not target_lost and unit.manual_attack_target is BaseGeoUnit and is_instance_valid(terrain):
    target_unseen = not terrain.can_perceive(unit,unit.manual_attack_target as BaseGeoUnit)
  var wants_move: bool = false
  var movement_goal: Vector2 = Vector2.INF
  if unit.manual_mode == "move" and unit.manual_move_target.is_finite():
   movement_goal = unit.manual_move_target
   wants_move = unit.global_position.distance_to(movement_goal) > 30.0
  elif unit.manual_mode == "attack" and not target_lost and not target_unseen and is_instance_valid(unit.manual_attack_target):
   movement_goal = unit.manual_attack_target.global_position
   var stop_range: float = unit.attack_range*0.82 + (58.0 if unit.manual_attack_target is CoreMatrixBase else 0.0)
   wants_move = unit.global_position.distance_to(movement_goal) > stop_range
  if wants_move and unit.stun_left <= 0.0:
   unit.manual_block_sample_time += delta
   if unit.manual_block_sample_time >= 0.5:
    var actual_motion: float = unit.global_position.distance_to(unit.manual_block_sample_position)
    if actual_motion < 3.0:
     unit.manual_blocked_time += unit.manual_block_sample_time
    else:
     unit.manual_blocked_time = 0.0
    unit.manual_block_sample_time = 0.0
    unit.manual_block_sample_position = unit.global_position
  elif not wants_move:
   unit.manual_blocked_time = 0.0
   unit.manual_block_sample_time = 0.0
   unit.manual_block_sample_position = unit.global_position
  else:
   unit.manual_block_sample_time = 0.0
   unit.manual_block_sample_position = unit.global_position
  if target_lost or target_unseen:
   unit.action_blocked = "集火目标已失去可感知，已归还 AI" if target_unseen else "集火目标已丢失，已归还 AI"
   unit.release_manual_control()
   continue
  if unit.manual_blocked_time >= 1.5:
   unit.action_blocked = "手动指令持续受阻，已归还 AI"
   unit.release_manual_control()
   continue
  if unit.manual_hold_timer <= 0.0:
   if not arrived and unit.manual_mode == "move": unit.action_blocked = "手动移动窗口结束，已归还 AI"
   unit.release_manual_control()

func cast_selected_class_skill(kind: String, point: Vector2) -> void:
 if phase != Phase.PLAYING:
  notify("请先开始对局",true)
  return
 var count: int = 0
 for unit: BaseGeoUnit in selected_units:
  if not is_instance_valid(unit) or unit.dead or unit.unit_type != kind: continue
  if kind == "triangle" and not unit.target_valid():
   var nearest: BaseGeoUnit = null
   var distance: float = INF
   for enemy: BaseGeoUnit in unit.enemies():
    if point.distance_squared_to(enemy.global_position) < distance:
     nearest = enemy
     distance = point.distance_squared_to(enemy.global_position)
   unit.current_target = nearest
  var spec: Dictionary = {"aim":"point","point":[point.x,point.y],"purpose":"attack"}
  if kind == "hexagon": spec = {"aim":"self","purpose":"support"}
  var result: Dictionary = SkillRequest.attempt(unit,spec)
  if bool(result.get("ok",false)): count += 1
 if count == 0:
  notify("没有可施放的"+String(UnitCatalog.DATA[kind]["zh"])+"技能",true)
 else:
  notify(String(UnitCatalog.DATA[kind]["zh"])+"技能已对 %d 个单位发出" % count,false)

func _draw() -> void:
 draw_rect(WORLD_RECT, Color(0.08,0.25,0.34,0.6), false, 2.0)
 for index: int in range(1, 8):
  draw_line(Vector2(index * 300, 0), Vector2(index * 300, 14), Color(0.18,0.42,0.55), 2.0)
  draw_line(Vector2(index * 300, WORLD_RECT.size.y), Vector2(index * 300, WORLD_RECT.size.y-14), Color(0.18,0.42,0.55), 2.0)
 if selection_active:
  var selection_rect: Rect2 = Rect2(selection_start,selection_current-selection_start).abs()
  draw_rect(selection_rect,Color(0.15,0.85,1.0,0.18),true)
  draw_rect(selection_rect,Color(0.35,1.3,1.8,0.95),false,2.0,true)
 if tactical_draw_points.size()>1:
  draw_polyline(PackedVector2Array(tactical_draw_points),Color(1.0,1.8,2.0,0.86),4.0,true)
 if not pending_squad_skill_class.is_empty() and phase == Phase.PLAYING:
  var point: Vector2 = get_global_mouse_position()
  draw_arc(point,24.0,0,TAU,32,Color(1.0,1.8,2.0,0.9),2.0,true)
  draw_line(point+Vector2(-10,0),point+Vector2(10,0),Color(1.0,1.8,2.0),1.5)
  draw_line(point+Vector2(0,-10),point+Vector2(0,10),Color(1.0,1.8,2.0),1.5)
 if not selected_skill.is_empty() and phase == Phase.PLAYING:
  var point: Vector2 = get_global_mouse_position()
  var radius: float = UnitCatalog.SKILLS[selected_skill]["radius"]
  var color: Color = Color(0.2,1.2,1.8,0.8)
  if selected_skill == "OVERCLOCK":
   draw_rect(Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), color, false, 2.0)
  else:
   draw_arc(point, radius, 0, TAU, 64, color, 2.0, true)
  draw_line(point-Vector2(12,0), point+Vector2(12,0), color, 1.5)
  draw_line(point-Vector2(0,12), point+Vector2(0,12), color, 1.5)
