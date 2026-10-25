class_name TacticPlan
extends RefCounted

const ACTIONS: Array[String] = ["move_direction","move_to","follow_path","seek_cover","peek","flank_target","wait","attack_target","cast_skill","retreat"]
const ACTION_TITLES: Array[String] = ["方向移动","移动到点","沿路径","寻找掩体","探出掩体","绕到背后","等待","原地攻击","施放技能","撤退"]
const DIRECTIONS: Dictionary = {"up":Vector2.UP,"down":Vector2.DOWN,"left":Vector2.LEFT,"right":Vector2.RIGHT,"up_left":Vector2(-0.70710678,-0.70710678),"up_right":Vector2(0.70710678,-0.70710678),"down_left":Vector2(-0.70710678,0.70710678),"down_right":Vector2(0.70710678,0.70710678)}
const TARGETS: Array[String] = ["current","nearest","diamond","hexagon","lowest_hp","base","none"]
const ANCHORS: Array[String] = ["point","target","rear","target_left","target_right","home","enemy_base","cover","north_prism","south_prism","rail_entry","rail_exit","portal","nebula","splitter_firing","safe_zone","flux_crystal"]
const EXTRA_FACTS: Dictionary = {"match_time":[0.0,600.0],"unit_time":[0.0,600.0],"step_time":[0.0,600.0],"arrived":"bool","target_lost":"bool","in_cover":"bool","cover_valid":"bool","action_done":"bool","action_failed":"bool","step_attacks":[0.0,10000.0],"step_skills":[0.0,10000.0],"step_portals":[0.0,10000.0],"step_pickups":[0.0,10000.0],"step_scans":[0.0,10000.0],"step_visits":[0.0,10000.0]}

static func step(id: String = "step_1", action: String = "wait") -> Dictionary:
 return {"id":id,"action":action,"seconds":1.0,"timeout":20.0,"target":"current","attack":false,"skill":"hold","next":"end","on_failure":"stop"}

static func default_program(kind: String) -> Dictionary:
 return {"version":2,"unit_type":kind,"base":UnitTacticProgram.default_program(kind)["base"],"plan":{"entry":"step_1","steps":[step()],"interrupts":[],"finish":"hold","map_id":""}}

static func direction(spec: Dictionary, team: int) -> Vector2:
 var name: String = str(spec.get("direction","up"))
 if name == "forward": return Vector2.RIGHT if team == 0 else Vector2.LEFT
 if name == "backward": return Vector2.LEFT if team == 0 else Vector2.RIGHT
 if name == "angle": return Vector2.RIGHT.rotated(deg_to_rad(float(spec.get("angle",0))))
 return DIRECTIONS.get(name,Vector2.UP)

static func error(message: String) -> Dictionary:
 return {"ok":false,"message":message}

static func point_valid(value: Variant) -> bool:
 return value is Array and value.size() == 2 and UnitTacticProgram.numeric(value[0]) and UnitTacticProgram.numeric(value[1]) and MapCatalog.WORLD_RECT.grow(-4.0).has_point(Vector2(value[0],value[1]))

static func goal_error(value: Variant) -> String:
 if not value is Dictionary: return "goal 必须是对象"
 var extra: String = UnitTacticProgram.unknown(value,["anchor","point","distance"])
 if not extra.is_empty(): return extra
 if not value.get("anchor") is String or value["anchor"] not in ANCHORS: return "无效目的地 anchor"
 if value["anchor"] == "point" and not point_valid(value.get("point")): return "point 需要战场内的 [x,y]"
 if value.has("distance") and (not UnitTacticProgram.numeric(value["distance"]) or value["distance"] < 30 or value["distance"] > 600): return "目的地距离必须为30至600px"
 return ""

static func validate(value: Dictionary, expected_kind: String = "") -> Dictionary:
 if not UnitTacticProgram.numeric(value.get("version")) or float(value["version"]) != 2: return error("不支持的战术版本")
 var extra: String = UnitTacticProgram.unknown(value,["version","unit_type","base","plan"])
 if not extra.is_empty(): return error(extra)
 var kind: String = str(value.get("unit_type",""))
 if kind not in UnitCatalog.TYPES or (not expected_kind.is_empty() and kind != expected_kind): return error("兵种与当前编辑对象不一致")
 if not value.get("base") is Dictionary: return error("base 需要完整八个字段")
 for field: String in UnitTacticProgram.default_program(kind)["base"]:
  if not value["base"].has(field): return error("base 缺少字段："+field)
 extra = UnitTacticProgram.action_error(value["base"],kind)
 if not extra.is_empty(): return error(extra)
 if not value.get("plan") is Dictionary: return error("v2 需要 plan 对象")
 var plan: Dictionary = value["plan"]
 extra = UnitTacticProgram.unknown(plan,["entry","steps","interrupts","finish","map_id"])
 if not extra.is_empty(): return error(extra)
 if not plan.get("steps") is Array or plan["steps"].is_empty() or plan["steps"].size() > 24: return error("方案需要1至24个步骤")
 if not plan.get("interrupts",[]) is Array or plan.get("interrupts",[]).size() > 8: return error("中断最多8条")
 if plan.get("finish","hold") not in ["hold","base","repeat"]: return error("结束行为需为hold/base/repeat")
 if not plan.get("map_id","") is String or (plan.get("map_id","") != "" and plan.get("map_id") not in MapCatalog.IDS): return error("未知绑定地图")
 var ids: Array[String] = []
 var budget: Array[int] = [0]
 var facts: Dictionary = UnitTacticProgram.FACTS.duplicate(true)
 facts.merge(EXTRA_FACTS)
 var requires_map: bool = false
 for entry: Variant in plan["steps"]:
  if not entry is Dictionary: return error("步骤必须是对象")
  extra = UnitTacticProgram.unknown(entry,["id","label","action","seconds","timeout","target","attack","skill","next","on_failure","when","direction","angle","goal","path","obstacle","skill_request","terrain_strategy"])
  if not extra.is_empty(): return error(extra)
  if not entry.get("id") is String or entry["id"].is_empty() or entry["id"].length() > 80 or entry["id"] in ids or entry["id"] in ["end","stop","return"]: return error("步骤id必须唯一，长度1至80，不能用end/stop/return")
  ids.append(entry["id"])
  if not entry.get("action") is String or entry["action"] not in ACTIONS: return error(entry["id"]+"：不支持的动作")
  if entry.has("label") and (not entry["label"] is String or entry["label"].length()>120): return error("步骤名称最多120字符")
  for field: String in ["seconds","timeout"]:
   if entry.has(field) and (not UnitTacticProgram.numeric(entry[field]) or float(entry[field]) <= 0 or float(entry[field]) > 600): return error(entry["id"]+"：时间必须大于0且不超过600秒")
  if not entry.get("target","current") is String or entry.get("target","current") not in TARGETS or entry.get("skill","hold") not in ["hold","auto","travel"] or not entry.get("attack",false) is bool: return error(entry["id"]+"：目标、普攻或技能策略无效")
  if kind != "triangle" and entry.get("skill") == "travel": return error("仅三角支持技能赶路")
  if kind == "hexagon" and (entry.get("attack",false) or entry["action"] == "attack_target"): return error("六边形无直接普攻")
  if entry.has("terrain_strategy") and entry["terrain_strategy"] not in UnitTacticProgram.ENUMS["terrain_strategy"]: return error(entry["id"]+"：未知地形策略")
  if entry.has("direction") and entry["direction"] not in DIRECTIONS and entry["direction"] not in ["forward","backward","angle"]: return error("未知方向")
  if entry.has("angle") and (not UnitTacticProgram.numeric(entry["angle"]) or absf(float(entry["angle"]))>360): return error("角度必须在-360至360之间")
  if entry.has("goal"):
   extra = goal_error(entry["goal"])
   if not extra.is_empty(): return error(entry["id"]+"："+extra)
   requires_map = requires_map or entry["goal"]["anchor"] == "point"
  if entry["action"] == "move_to" and not entry.has("goal"): return error("移动到点需要goal")
  if entry.has("path"):
   if not entry["path"] is Array or entry["path"].is_empty() or entry["path"].size()>32: return error("路径需要1至32个航点")
   for point: Variant in entry["path"]:
    if not point_valid(point): return error("航点必须是战场内[x,y]")
   requires_map = true
  if entry["action"] == "follow_path" and not entry.has("path"): return error("沿路径需要path")
  if entry.has("obstacle"):
   if not entry["obstacle"] is String: return error("obstacle需为标识字符串")
   requires_map = requires_map or not entry["obstacle"].is_empty()
  if entry.has("skill_request"):
   extra = SkillRequest.validation_error(entry["skill_request"],kind)
   if not extra.is_empty(): return error(entry["id"]+"："+extra)
   requires_map = requires_map or entry["skill_request"].get("aim") == "point"
  if entry.has("when"):
   if entry["action"]=="wait" and entry.has("seconds"): return error(entry["id"]+"：条件等待使用timeout表示等待上限，请移除seconds")
   extra = UnitTacticProgram.condition_error(entry["when"],1,budget,facts,128)
   if not extra.is_empty(): return error(entry["id"]+"："+extra)
 for entry: Variant in plan.get("interrupts",[]):
  if not entry is Dictionary: return error("中断必须是对象")
  extra = UnitTacticProgram.unknown(entry,["id","when","goto"])
  if not extra.is_empty(): return error(extra)
  if not entry.get("id") is String or entry["id"].is_empty() or entry["id"].length()>80 or entry["id"] in ids: return error("中断id必须唯一，长度1至80")
  ids.append(entry["id"])
  if not entry.get("goto") is String or entry.get("goto") not in plan["steps"].map(func(s: Dictionary) -> String: return s["id"]): return error("中断引用不存在的步骤")
  extra = UnitTacticProgram.condition_error(entry.get("when"),1,budget,facts,128)
  if not extra.is_empty(): return error(extra)
 var step_ids: Array = plan["steps"].map(func(s: Dictionary) -> String: return s["id"])
 if plan.get("entry") not in step_ids: return error("入口步骤不存在")
 for entry: Dictionary in plan["steps"]:
  for field: String in ["next","on_failure"]:
   var link: Variant = entry.get(field,"end" if field == "next" else "stop")
   if not link is String or (link not in step_ids and link not in ["end","stop","return"]): return error(entry["id"]+"：跳转不存在 "+str(link))
 # A handler may return, but the entry graph must never return without a caller.
 var pending: Array = [plan["entry"]]
 var visited: Array = []
 while not pending.is_empty():
  var id: String = str(pending.pop_back())
  if id in visited: continue
  visited.append(id)
  var entry: Dictionary = plan["steps"][step_ids.find(id)]
  for field: String in ["next","on_failure"]:
   var link: String = str(entry.get(field,"end" if field == "next" else "stop"))
   if link == "return": return error(id+"：主流程不能return，只能由中断处理返回")
   if link in step_ids: pending.append(link)
 if requires_map and plan.get("map_id","").is_empty(): return error("手工航点、定点技能或指定障碍物必须绑定map_id")
 var clean: Dictionary = value.duplicate(true)
 clean["plan"].merge({"interrupts":[],"finish":"hold","map_id":""},false)
 var map_error: String = map_validation(clean,str(clean["plan"]["map_id"])) if not str(clean["plan"]["map_id"]).is_empty() else ""
 if not map_error.is_empty(): return error(map_error)
 return {"ok":true,"program":clean,"message":"v2编排校验通过"}

static func map_validation(program: Dictionary, map_id: String) -> String:
 if int(program.get("version",1)) != 2: return ""
 var plan: Dictionary = program["plan"]
 var bound: String = plan.get("map_id","")
 if not bound.is_empty() and bound != map_id: return "%s方案绑定%s，请编辑或恢复该兵种默认方案" % [program["unit_type"],bound]
 var data: Dictionary = MapCatalog.definition(map_id)
 var radius: float = UnitCatalog.DATA[program["unit_type"]]["radius"]+3.0
 var polygons: Array[PackedVector2Array] = []
 var obstacle_ids: Array[String] = []
 for item: Dictionary in MapCatalog.solid_specs(data):
  polygons.append(item["polygon"])
 for wall: Dictionary in data["walls"]: obstacle_ids.append(wall["id"])
 for entry: Dictionary in plan["steps"]:
  if not str(entry.get("obstacle","")).is_empty() and entry["obstacle"] not in obstacle_ids: return entry["id"]+"：指定墙体不存在"
  var points: Array = entry.get("path",[]).duplicate(true)
  if entry.get("goal",{}).get("anchor") == "point": points.append(entry["goal"]["point"])
  if entry.get("skill_request",{}).get("aim") == "point": points.append(entry["skill_request"]["point"])
  for point: Array in points:
   var location: Vector2 = Vector2(point[0],point[1])
   if not MapCatalog.WORLD_RECT.grow(-radius).has_point(location): return entry["id"]+"：落点太靠近边界"
   for polygon: PackedVector2Array in polygons:
    for expanded: PackedVector2Array in Geometry2D.offset_polygon(polygon,radius):
     if Geometry2D.is_point_in_polygon(location,expanded): return entry["id"]+"：落点与掩体或晶簇重叠"
 return ""

static func profile_error(profile: Dictionary, map_id: String) -> String:
 for kind: String in UnitCatalog.TYPES:
  if not str(profile["unit_rules"][kind].get("repair_error","")).is_empty(): return kind+"：待修复："+str(profile["unit_rules"][kind]["repair_error"])
  var program: Dictionary=profile["unit_rules"][kind].get("program",{})
  if not program.is_empty():
   var checked: Dictionary=UnitTacticProgram.validate(program,kind)
   if not checked["ok"]: return kind+"：待修复："+checked["message"]
  var error_text: String = map_validation(program,map_id)
  if not error_text.is_empty(): return error_text
 return ""

static func system_prompt(kind: String) -> String:
 return "编译必须忠实逐项对应用户要求。未明确要求的普攻、自动技能或赶路冲刺一律attack:false、skill:hold，禁止擅自添加。条件等待必须when配timeout:X，不允许seconds字段；用户说最多5秒就timeout:5。背刺技能通常用skill_request:{aim:target,purpose:backstab}，根据敌方真实朝向锁定目标，不能用forward代替瞄准目标。赶路冲刺只有用户明确要求技能加速时才添加skill:travel。用户要求返回掩体后循环，应next回找掩体或等待步骤，不能重复首次开局移动。合法的本兵种编排示例（仅当用户要求相关动作时选用）："+JSON.stringify(TacticExamples.for_unit(kind))+"。中文和英文同义词先归一化再映射字段：向上/北/上路/north=up，向下/南/south=down，左/西/左翼/west=left，右/东/右翼/east=right，前进/推进/压向敌方/forward=forward，后退/回撤/backward=backward；持续N秒或前N秒写seconds，等待最多N秒写timeout，开局第N秒写match_time条件；沿边、绕开、经过航点分别对应方向、move_to/follow_path；墙后、遮挡直射、探头、换掩体对应seek_cover/peek及中断。保持方向遇障停止，目的地移动才允许绕障。不能表达的要求必须返回具体error。"+schema_prompt(kind)

## Extracts stable intent hints before an LLM request. This is deliberately
## explanatory only: the model still emits JSON and the local validator remains
## authoritative. Keeping it deterministic makes ambiguous prompts visible to
## the player instead of silently changing a plan.
static func normalize_prompt(prompt: String) -> Dictionary:
 var text: String = prompt.strip_edges()
 var hints: Array[String] = []
 var unsupported: Array[String] = []
 var direction: String = ""
 var direction_terms: Array[Array] = [
  ["up",["向上","北方","北侧","上路","north","地图上方"]],
  ["down",["向下","南方","南侧","下路","south","地图下方"]],
  ["left",["向左","西侧","左翼","左边","west"]],
  ["right",["向右","东侧","右翼","右边","east"]],
  ["forward",["前进","推进","压向敌方","向敌方基地","forward"]],
  ["backward",["后退","回撤","返回己方","backward"]]
 ]
 for term: Array in direction_terms:
  for word: String in term[1]:
   if text.to_lower().contains(word.to_lower()):
    direction = term[0]
    break
  if not direction.is_empty(): break
 if not direction.is_empty(): hints.append("方向="+direction+("（保持方向，遇障停止）" if direction not in ["forward","backward"] else "（按基地方向推进）"))
 var duration: String = _extract_number(text,["秒","s","second","seconds"])
 if not duration.is_empty(): hints.append("时间="+duration+"秒")
 if _has_any(text,["沿边","贴边","边界","绕开","绕过","避开"]): hints.append("路线=沿边或绕障意图（目的地/航点才自动寻路）")
 if _has_any(text,["航点","路径","waypoint","path"]): hints.append("路线=手工路径，需要地图绑定")
 if _has_any(text,["墙后","掩体","遮挡","躲藏","藏在","cover"]): hints.append("掩体=寻找能遮挡指定威胁直射的可达墙体")
 if _has_any(text,["探头","探出","peek"]): hints.append("掩体动作=探出后再攻击，范围技能不因此免疫")
 if _has_any(text,["技能就绪","冷却结束","准备好技能","skill ready"]): hints.append("技能=等待skill_ready后施放")
 if _has_any(text,["保留技能","不要用技能","留技能"]): hints.append("技能策略=hold，不自动施放")
 if _has_any(text,["冲刺赶路","用冲刺加速","加速推进","dash"]): hints.append("技能用途=赶路冲刺（仅三角且必须明确允许）")
 if _has_any(text,["背刺","绕后","后方","rear","flank"]): hints.append("目标=真实目标背后，使用flank_target/backstab校验")
 if _has_any(text,["生命低于","血量低于","hp below","低血量"]): hints.append("条件=生命阈值中断，需写self_hp比较")
 if _has_any(text,["目标丢失","目标死亡","target lost","target dead"]): hints.append("条件=target_lost")
 for forbidden: String in ["无敌","免疫伤害","修改伤害","无限冷却","永久加速"]:
  if text.contains(forbidden): unsupported.append(forbidden)
 return {"text":text,"hints":hints,"unsupported":unsupported,"summary":("；".join(hints) if not hints.is_empty() else "未识别到可确定的方向、时间或技能意图")}

static func _has_any(text: String, terms: Array[String]) -> bool:
 for term: String in terms:
  if text.to_lower().contains(term.to_lower()): return true
 return false

static func _extract_number(text: String, units: Array[String]) -> String:
 var regex: RegEx = RegEx.new()
 if regex.compile("(?:持续|前|等待最多|最多等|第)?\\s*(\\d+(?:\\.\\d+)?)\\s*(?:秒|s|second|seconds)") != OK: return ""
 var match: RegExMatch = regex.search(text)
 return match.get_string(1) if match else ""

static func schema_prompt(kind: String) -> String:
 return "你是GeoCommander战术编译器，只输出严格JSON，不要Markdown或代码。不支持的要求返回{\"error\":\"具体原因\"}，不能静默简化。生成version:2，兵种"+kind+"，格式："+JSON.stringify(default_program(kind))+"。plan.steps最多24步，interrupts最多8条，条件128节点深度4。action枚举："+JSON.stringify(ACTIONS)+"。步骤可包含id,label,action,seconds(0..600),timeout(0..600),target("+JSON.stringify(TARGETS)+"),attack(布尔),skill(hold/auto/travel，仅三角travel),next,on_failure,when,direction,angle,goal,path,obstacle,skill_request,terrain_strategy("+JSON.stringify(UnitTacticProgram.ENUMS["terrain_strategy"])+")。next/on_failure填步骤id或end/stop/return；return从中断恢复，不能在主流程使用。finish=hold/base/repeat。direction=up/down/left/right/up_left/up_right/down_left/down_right/forward/backward/angle；角度0向右90向下。上下左右为地图方向，前后为基地进攻方向。move_direction保持方向，seconds后完成；move_to需goal；follow_path需path:[[x,y]]；seek_cover寻找遮挡指定目标直射的可达墙体，peek探出上次掩体，flank_target到目标背后，wait等待seconds或when，attack_target原地攻击至目标死亡，cast_skill等待技能就绪及合法性并完整施放，retreat回基地。goal={anchor:point/target/rear/target_left/target_right/home/enemy_base/cover/north_prism/south_prism/rail_entry/rail_exit/portal/nebula/splitter_firing/safe_zone/flux_crystal,point:[x,y](point时必填),distance:30..600(可选)}。无配置超时20秒，失败stop并显示原因。未指定普攻默认false、技能hold，步骤不擅自追敌。自动赶路设skill:travel。when为{fact,op,value}或非空all/any/not，比较eq/ne/lt/lte/gt/gte，布尔及类型仅eq/ne。基础事实："+JSON.stringify(UnitTacticProgram.FACTS)+"。新增事实："+JSON.stringify(EXTRA_FACTS)+"。interrupts每条{id,when,goto}，按优先级，不嵌套，handler的next:return恢复原步骤；解除后重置触发。目标死亡可用target_lost。步骤时间冻结于控制和中断，对局时间只冻结于暂停。使用技能参数skill_request={ability:primary/scan(省略为primary，仅六边形scan独立扫描，自身240px冷却8秒且初始可用，不消耗治疗),aim:auto/target/direction/point/self,direction:方向,angle:角度,point:[x,y],purpose:attack/travel/backstab/support/reflect}，字段按用途填写。三角支持方向冲刺和backstab真实背刺检查；方形可定盾朝向或reflect；圆形支持point且320px内160px至少2敌人；菱形支持指向/定点和真实折射；六边形只能auto/self，不能普攻。手工坐标/指定障碍物必须plan.map_id绑定"+JSON.stringify(MapCatalog.IDS)+"；纯语义留空。常用顺序可为向上2秒、seek_cover、wait到skill_ready最多5秒、flank_target、cast_skill purpose:backstab、move_to goal:cover、循环；低血量interrupt到retreat后return。不能修改冷却/速度/伤害，不能保证无敌或任意隐身，只有真实星云可隐匿；晶簇反射激光、减速区非掩体。基础配置枚举沿用："+JSON.stringify(UnitTacticProgram.ENUMS)+"；movement："+JSON.stringify(UnitTacticProgram.COMMON_MOVES)+"；skill_cond："+JSON.stringify(UnitTacticProgram.SKILLS[kind])+"；retreat_hp为0..0.9；六边形priority=none，其他兵种不能none。真实兵种数值："+JSON.stringify(UnitCatalog.DATA[kind])
