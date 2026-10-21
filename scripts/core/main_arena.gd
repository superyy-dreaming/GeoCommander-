class_name MainArena
extends CombatContext

@export var terrain_enabled: bool = true
@export var map_id: String = ""

enum Phase { PREPARING, PLAYING, ENDED }
const WORLD_RECT: Rect2 = Rect2(0, 0, 2400, 1350)
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

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_PAUSABLE
 map_id = MatchSession.consume_map() if map_id.is_empty() else map_id
 TacticalBrain.begin_match_profiles()
 reduced_motion = bool(GameSettings.values["reduced_motion"])
 GameSettings.settings_changed.connect(_settings_updated)
 build_environment()
 build_bounds()
 unit_added.connect(func(unit: BaseGeoUnit) -> void:
  _unit_spawned(unit)
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
 SignalBus.commander_skill_requested.connect(select_skill)
 for team: int in range(2):
  var base: CoreMatrixBase = CoreMatrixBase.new()
  base.team = team
  base.arena = self
  base.position = Vector2(220.0 if team == 0 else 2180.0, 675.0)
  add_child(base)
  bases.append(base)
 for index: int in range(2):
  var prism: EnergyPrism = EnergyPrism.new()
  prism.arena = self
  prism.title = "NORTH" if index == 0 else "SOUTH"
  prism.position = Vector2(1200, 320 if index == 0 else 1030)
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
 background_material = CombatContext.create_environment(self,Rect2(-400,-400,3200,2150))
 background_material.set_shader_parameter("reduced_motion",reduced_motion)

func build_bounds() -> void:
 var walls: StaticBody2D = StaticBody2D.new()
 walls.collision_layer = 16
 walls.collision_mask = 3
 add_child(walls)
 var rectangles: Array[Rect2] = [Rect2(-40,-40,2480,40), Rect2(-40,1350,2480,40), Rect2(-40,0,40,1350), Rect2(2400,0,40,1350)]
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
 phase = Phase.PLAYING
 hud.call("close_matrix")
 notify("指挥链路就绪。占领能源棱镜，摧毁敌方核心。", false)

func _physics_process(delta: float) -> void:
 if phase != Phase.PLAYING:
  queue_redraw()
  return
 elapsed += delta
 match_left = maxf(0.0, match_left - delta)
 for team: int in range(2):
  flux[team] += income(team) * delta
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
 unit.position = Vector2(220 if team == 0 else 2180, 675) + Vector2(sign_x * (135.0 + float(serial % 3) * 65.0), float((serial / 3) % 7 - 3) * 72.0)
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
 TacticalBrain.team_profiles[0] = profile.duplicate(true)
 TacticalBrain.last_prompts[0] = prompt_text
 SignalBus.tactical_profile_updated.emit(0, TacticalBrain.team_profiles[0], prompt_text)
 if phase == Phase.PLAYING:
  override_left = 30.0
 notify("战术已生效：" + prompt_text, false)
 return {"ok": true, "profile": profile}

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
 var focus: Control = get_viewport().gui_get_focus_owner()
 if focus is LineEdit or focus is TextEdit:
  return
 if bool(hud.get("matrix_open")):
  return
 var key: int = (event as InputEventKey).physical_keycode
 if key >= KEY_1 and key <= KEY_5:
  deploy(UnitCatalog.TYPES[key - KEY_1])
 elif key in [KEY_Z, KEY_X, KEY_C]:
  select_skill(["EMP_STRIKE", "OVERCLOCK", "TOPOLOGY_SWAP"][[KEY_Z, KEY_X, KEY_C].find(key)])
 elif key == KEY_ESCAPE:
  selected_skill = ""
  hud.call("close_matrix")

func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.is_pressed():
  var button: InputEventMouseButton = event as InputEventMouseButton
  if button.button_index == MOUSE_BUTTON_RIGHT:
   selected_skill = ""
  elif button.button_index == MOUSE_BUTTON_LEFT and not selected_skill.is_empty():
   cast_skill(selected_skill, get_global_mouse_position())
   get_viewport().set_input_as_handled()

func _draw() -> void:
 draw_rect(WORLD_RECT, Color(0.08,0.25,0.34,0.6), false, 2.0)
 for index: int in range(1, 8):
  draw_line(Vector2(index * 300, 0), Vector2(index * 300, 14), Color(0.18,0.42,0.55), 2.0)
  draw_line(Vector2(index * 300, 1350), Vector2(index * 300, 1336), Color(0.18,0.42,0.55), 2.0)
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
