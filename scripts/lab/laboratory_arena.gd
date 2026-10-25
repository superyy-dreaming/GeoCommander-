class_name LaboratoryArena
extends CombatContext

signal state_changed
signal event_added(message: String)
enum State { ARRANGING, RUNNING, PAUSED, ENDED }
var state: State = State.ARRANGING
var map_id: String = "balanced"
var layout: Array[Dictionary] = []
var layout_error: String = ""
var elapsed: float = 0.0
var seed_value: int = 7401
var result_text: String = "布阵中，点击空地放置，拖动已有单位调整站位"
var totals: Array[Dictionary] = [{"damage":0.0,"healing":0.0,"skills":0,"scans":0},{"damage":0.0,"healing":0.0,"skills":0,"scans":0}]
var debug_frame: int = -1
var debug_until: int = -1
var debug_unit: WeakRef
var debug_budget: int = 0
var comparison: bool = false
var background: ShaderMaterial

func _ready() -> void:
 active = false
 reduced_motion = bool(GameSettings.values["reduced_motion"])
 background = create_environment(self,MapCatalog.WORLD_RECT)
 background.set_shader_parameter("reduced_motion",reduced_motion)
 GameSettings.settings_changed.connect(settings_updated)
 build_bounds()
 navigation = ArenaObstacles.new()
 navigation.arena = self
 add_child(navigation)
 navigation.build(map_id)
 for team: int in range(2):
  var base: CoreMatrixBase = CoreMatrixBase.new()
  base.arena = self
  base.team = team
  base.position = MapCatalog.base_positions(map_id)[team]
  base.set_meta("obstacle_id",MapCatalog.definition(map_id)["base_specs"][team]["id"])
  add_child(base)
 local_profiles = [TacticalBrain.get_default_profile() if comparison else LaboratoryStore.blue_profile(),TacticalBrain.get_default_profile()]
 for i: int in range(2):
  var prism: EnergyPrism = EnergyPrism.new()
  prism.arena = self
  prism.title = "NORTH" if i == 0 else "SOUTH"
  prism.position = MapCatalog.prism_positions(map_id)[i]
  prism.set_meta("obstacle_id",MapCatalog.definition(map_id)["prism_specs"][i]["id"])
  add_child(prism)
  local_prisms.append(prism)
 var serial: Array[int] = [0,0]
 for index: int in range(layout.size()):
  var spec: Dictionary = layout[index]
  var spec_issue: String=spec_error(spec)
  if not spec_issue.is_empty():
   layout_error="第%d个单位：%s" % [index+1,spec_issue]
   continue
  var script: Script = load("res://scripts/units/unit_"+spec["kind"]+".gd")
  var unit: BaseGeoUnit = script.new() as BaseGeoUnit
  unit.arena = self
  unit.team = int(spec["team"])
  unit.position = Vector2(float(spec["x"]),float(spec["y"]))
  unit.spawn_index = serial[unit.team]
  serial[unit.team] += 1
  add_child(unit)
  unit.flank_sign = -1 if (index+seed_value)%2 == 0 else 1
  unit.visual_root.rotation = deg_to_rad(float(spec["angle"]))
  unit.current_hp = unit.max_hp*float(spec["hp"])
  unit.inner_fill.scale = Vector2.ONE*float(spec["hp"])
  unit.set_meta("layout_index",index)
 actual_damage_reported.connect(func(victim: BaseGeoUnit, amount: float, attacker: Node2D) -> void:
  if attacker is BaseGeoUnit: totals[(attacker as BaseGeoUnit).team]["damage"] += amount)
 base_damage_reported.connect(func(base: CoreMatrixBase, amount: float, _attacker: Node2D) -> void: totals[1-base.team]["damage"] += amount)
 healing_reported.connect(func(unit: BaseGeoUnit, amount: float) -> void: totals[unit.team]["healing"] += amount)
 skill_reported.connect(func(unit: BaseGeoUnit) -> void:
  totals[unit.team]["skills"] += 1
  event_added.emit("%.1fs %s %s 技能启动" % [elapsed,"蓝方" if unit.team == 0 else "红方",UnitCatalog.DATA[unit.unit_type]["zh"]]))
 scan_reported.connect(func(unit: BaseGeoUnit) -> void:
  totals[unit.team]["scans"] += 1
  event_added.emit("%.1fs %s 六边形扫描" % [elapsed,"蓝方" if unit.team==0 else "红方"]))
 flux_pickup_reported.connect(func(unit: BaseGeoUnit, amount: int) -> void: event_added.emit("%.1fs %s 拾取 +%d Flux（实验本地）" % [elapsed,"蓝方" if unit.team==0 else "红方",amount]))
 unit_removed.connect(func(unit: BaseGeoUnit) -> void: event_added.emit("%.1fs %s %s 阵亡" % [elapsed,"蓝方" if unit.team==0 else "红方",UnitCatalog.DATA[unit.unit_type]["zh"]]))

func build_bounds() -> void:
 var walls: StaticBody2D = StaticBody2D.new()
 walls.collision_layer = 16
 add_child(walls)
 var width: float = MapCatalog.WORLD_SIZE.x
 var height: float = MapCatalog.WORLD_SIZE.y
 for rect: Rect2 in [Rect2(-40,-40,width+80,40),Rect2(-40,height,width+80,40),Rect2(-40,0,40,height),Rect2(width,0,40,height)]:
  var shape: CollisionShape2D = CollisionShape2D.new()
  var box: RectangleShape2D = RectangleShape2D.new()
  box.size = rect.size
  shape.shape = box
  shape.position = rect.get_center()
  walls.add_child(shape)

func objective_for(unit: BaseGeoUnit) -> Vector2:
 return CombatMovement.objective_for(self,unit)

func formation_anchor(unit: BaseGeoUnit) -> Vector2:
 return CombatMovement.formation_anchor(self,unit)

func start() -> bool:
 var placement_error: String=validate_layout()
 if not placement_error.is_empty():
  result_text=placement_error
  state_changed.emit()
  return false
 var plan_error: String = TacticPlan.profile_error(profile_for(0),map_id)
 if not plan_error.is_empty():
  result_text = plan_error
  state_changed.emit()
  return false
 if units_for(0).is_empty() or units_for(1).is_empty():
  result_text = "双方至少各放置一个单位"
  state_changed.emit()
  return false
 state = State.RUNNING
 active = true
 result_text = "默认战术对照运行" if comparison else "已应用蓝方实验战术，红方使用默认战术"
 state_changed.emit()
 return true

func is_combat_active() -> bool:
 return active or Engine.get_physics_frames() == debug_frame

func step_frame() -> void:
 if state != State.PAUSED: return
 debug_frame = Engine.get_physics_frames()+1

func step_transition(unit: BaseGeoUnit) -> void:
 if state != State.PAUSED or not is_instance_valid(unit) or unit.execution == null: return
 if unit.execution.status!="运行":
  result_text="该单位方案已结束或受阻，请应用并重跑"
  state_changed.emit()
  return
 debug_unit = weakref(unit)
 debug_until = unit.execution.transition_serial+1
 debug_budget = 3600
 active = true
 state = State.RUNNING
 state_changed.emit()

func toggle_pause() -> void:
 if state not in [State.RUNNING,State.PAUSED]: return
 state = State.PAUSED if state == State.RUNNING else State.RUNNING
 active = state == State.RUNNING
 state_changed.emit()

func _physics_process(delta: float) -> void:
 if not is_combat_active(): return
 if debug_until>=0:
  var observed: BaseGeoUnit = debug_unit.get_ref() as BaseGeoUnit if debug_unit != null else null
  debug_budget -= 1
  if not is_instance_valid(observed) or observed.execution == null or observed.execution.transition_serial>=debug_until or debug_budget<=0:
   active = false
   state = State.PAUSED
   debug_until = -1
   state_changed.emit()
   return
 elapsed += delta
 if units_for(0).is_empty() or units_for(1).is_empty():
  finish_match(0 if units_for(1).is_empty() else 1,"一方单位全部阵亡")
 elif elapsed >= 120: finish_match(-1,"120 秒验证结束")

func emit_base_health() -> void:
 pass

func finish_match(winner: int, reason: String) -> void:
 if state == State.ENDED: return
 active = false
 state = State.ENDED
 result_text = reason+("，蓝方胜" if winner == 0 else ("，红方胜" if winner == 1 else ""))
 event_added.emit(result_text)
 state_changed.emit()

static func spec_error(entry: Variant) -> String:
 if not entry is Dictionary or entry.get("kind") not in UnitCatalog.TYPES: return "未知兵种或格式错误"
 if not UnitTacticProgram.numeric(entry.get("team")) or float(entry["team"]) not in [0.0,1.0]: return "阵营无效"
 for key: String in ["x","y","hp","angle"]:
  if not UnitTacticProgram.numeric(entry.get(key)): return key+"必须为有限数字"
 if float(entry["hp"])<0.01 or float(entry["hp"])>1: return "生命比例超出0.01至1"
 if float(entry["angle"])<0 or float(entry["angle"])>359: return "朝向超出0至359"
 return ""

func validate_layout() -> String:
 if not layout_error.is_empty(): return layout_error
 var counts: Array[int]=[0,0]
 var hexes: Array[int]=[0,0]
 for index: int in range(layout.size()):
  var spec: Dictionary=layout[index]
  var error: String=spec_error(spec)
  if error.is_empty(): error=valid_point(spec["kind"],Vector2(spec["x"],spec["y"]),index,layout)
  if not error.is_empty(): return "第%d个单位待修复：%s" % [index+1,error]
  var team: int=int(spec["team"])
  counts[team]+=1
  if spec["kind"]=="hexagon": hexes[team]+=1
  if counts[team]>30 or hexes[team]>2: return "每方最多30单位、2个六边形"
 return ""

func valid_point(kind: String, point: Vector2, ignored: int = -1, specs: Array[Dictionary] = layout) -> String:
 if kind not in UnitCatalog.TYPES: return "未知兵种"
 var radius: float = UnitCatalog.DATA[kind]["radius"]
 if not MapCatalog.WORLD_RECT.grow(-(radius+4)).has_point(point): return "超出战场边界"
 for polygon: PackedVector2Array in navigation.solid_polygons:
  for expanded: PackedVector2Array in Geometry2D.offset_polygon(polygon,radius+3,Geometry2D.JOIN_MITER):
   if Geometry2D.is_point_in_polygon(point,expanded): return "与掩体或晶簇重叠"
 for team: int in range(2):
  if point.distance_to(MapCatalog.base_positions(map_id)[team]) < radius+70: return "与基地重叠"
 for index: int in range(specs.size()):
  if index == ignored: continue
  var spec: Dictionary = specs[index]
  if point.distance_to(Vector2(spec["x"],spec["y"])) < radius+float(UnitCatalog.DATA[spec["kind"]]["radius"])+4: return "与其他单位重叠"
 return ""

func shutdown() -> void:
 active = false
 process_mode = Node.PROCESS_MODE_DISABLED

func notify(message: String, _error: bool = false) -> void:
 event_added.emit(message)

func settings_updated() -> void:
 reduced_motion = bool(GameSettings.values["reduced_motion"])
 if is_instance_valid(background): background.set_shader_parameter("reduced_motion",reduced_motion)
