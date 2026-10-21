class_name LaboratoryArena
extends CombatContext

signal state_changed
signal event_added(message: String)
enum State { ARRANGING, RUNNING, PAUSED, ENDED }
var state: State = State.ARRANGING
var map_id: String = "balanced"
var layout: Array[Dictionary] = []
var elapsed: float = 0.0
var seed_value: int = 7401
var result_text: String = "布阵中，点击空地放置，拖动已有单位调整站位"
var totals: Array[Dictionary] = [{"damage":0.0,"healing":0.0,"skills":0},{"damage":0.0,"healing":0.0,"skills":0}]
var comparison: bool = false
var background: ShaderMaterial

func _ready() -> void:
 active = false
 reduced_motion = bool(GameSettings.values["reduced_motion"])
 background = create_environment(self,Rect2(0,0,2400,1350))
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
  base.position = Vector2(220 if team == 0 else 2180,675)
  add_child(base)
 local_profiles = [TacticalBrain.get_default_profile() if comparison else LaboratoryStore.blue_profile(),TacticalBrain.get_default_profile()]
 for i: int in range(2):
  var prism: EnergyPrism = EnergyPrism.new()
  prism.arena = self
  prism.title = "NORTH" if i == 0 else "SOUTH"
  prism.position = Vector2(1200,320 if i == 0 else 1030)
  add_child(prism)
  local_prisms.append(prism)
 var serial: Array[int] = [0,0]
 for index: int in range(layout.size()):
  var spec: Dictionary = layout[index]
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
  var team: int = 1-victim.team
  if attacker is BaseGeoUnit: team = (attacker as BaseGeoUnit).team
  totals[team]["damage"] += amount)
 base_damage_reported.connect(func(base: CoreMatrixBase, amount: float, _attacker: Node2D) -> void: totals[1-base.team]["damage"] += amount)
 healing_reported.connect(func(unit: BaseGeoUnit, amount: float) -> void: totals[unit.team]["healing"] += amount)
 skill_reported.connect(func(unit: BaseGeoUnit) -> void:
  totals[unit.team]["skills"] += 1
  event_added.emit("%.1fs %s %s 技能启动" % [elapsed,"蓝方" if unit.team == 0 else "红方",UnitCatalog.DATA[unit.unit_type]["zh"]]))
 unit_removed.connect(func(unit: BaseGeoUnit) -> void: event_added.emit("%.1fs %s 阵亡" % [elapsed,UnitCatalog.DATA[unit.unit_type]["zh"]]))

func build_bounds() -> void:
 var walls: StaticBody2D = StaticBody2D.new()
 walls.collision_layer = 16
 add_child(walls)
 for rect: Rect2 in [Rect2(-40,-40,2480,40),Rect2(-40,1350,2480,40),Rect2(-40,0,40,1350),Rect2(2400,0,40,1350)]:
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
 if units_for(0).is_empty() or units_for(1).is_empty():
  result_text = "双方至少各放置一个单位"
  state_changed.emit()
  return false
 state = State.RUNNING
 active = true
 result_text = "默认战术对照运行" if comparison else "已应用蓝方实验战术，红方使用默认战术"
 state_changed.emit()
 return true

func toggle_pause() -> void:
 if state not in [State.RUNNING,State.PAUSED]: return
 state = State.PAUSED if state == State.RUNNING else State.RUNNING
 active = state == State.RUNNING
 state_changed.emit()

func _physics_process(delta: float) -> void:
 if not active: return
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

func valid_point(kind: String, point: Vector2, ignored: int = -1, specs: Array[Dictionary] = layout) -> String:
 if kind not in UnitCatalog.TYPES: return "未知兵种"
 var radius: float = UnitCatalog.DATA[kind]["radius"]
 if not Rect2(radius+4,radius+4,2400-2*(radius+4),1350-2*(radius+4)).has_point(point): return "超出战场边界"
 for polygon: PackedVector2Array in navigation.solid_polygons:
  for expanded: PackedVector2Array in Geometry2D.offset_polygon(polygon,radius+3,Geometry2D.JOIN_MITER):
   if Geometry2D.is_point_in_polygon(point,expanded): return "与掩体或晶簇重叠"
 for team: int in range(2):
  if point.distance_to(Vector2(220 if team == 0 else 2180,675)) < radius+70: return "与基地重叠"
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
