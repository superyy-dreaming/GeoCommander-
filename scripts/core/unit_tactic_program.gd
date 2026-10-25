class_name UnitTacticProgram
extends RefCounted

const VERSION: int = 1
const MAX_RULES: int = 12
const MAX_NODES: int = 32
const MAX_DEPTH: int = 4
const MAX_PROMPT: int = 4096
const COMMON_MOVES: Array[String] = ["direct_charge", "flank_sides", "guard_rear", "protect_hexagon", "frontline_screen", "midline_support", "max_range_kite", "safe_backline"]
const ENUMS: Dictionary = {
 "priority":["closest","ranged_or_commander","diamond_first","lowest_hp","highest_threat","cluster","none"],
 "lane_mode":["auto","mid","split"], "stance":["balanced","flank","defensive","aggressive","kite"],
 "behavior":["normal","hold","retreat"], "skill_usage":["auto","hold","try"], "terrain_strategy":["auto","none","rails","portals","nebula","splitter","avoid_hazards","collect_flux"]}
const SKILLS: Dictionary = {"triangle":["backstab_or_grav","on_cooldown","travel_and_backstab"],"square":["ally_threatened","reflect_laser","on_cooldown"],"circle":["cluster_3plus","on_cooldown"],"diamond":["refract_or_snipe","on_cooldown"],"hexagon":["always_pulse","on_cooldown"]}
const FACTS: Dictionary = {
 "self_hp":[0.0,1.0], "target_hp":[0.0,1.0], "target_distance":[0.0,3000.0],
 "nearby_allies":[0.0,30.0], "nearby_enemies":[0.0,30.0], "ally_min_hp":[0.0,1.0],
 "hexagon_alive":"bool", "skill_ready":"bool", "target_visible":"bool", "target_cluster":[0.0,30.0],
 "scan_ready":"bool", "in_nebula":"bool", "portal_ready":"bool", "portal_available":"bool", "gate_open":"bool", "reactor_warning":"bool", "portal_used":"bool", "flux_collected":"bool",
 "target_type":["triangle","square","circle","diamond","hexagon","base","none"]}
const OPS: Array[String] = ["eq","ne","lt","lte","gt","gte"]

static func default_program(kind: String) -> Dictionary:
 var base: Dictionary = TacticalBrain.get_default_profile()["unit_rules"][kind].duplicate(true)
 base.merge({"lane_mode":"auto","stance":"balanced","behavior":"normal","skill_usage":"auto"})
 return {"version":VERSION,"unit_type":kind,"base":base,"rules":[]}

static func failure(message: String) -> Dictionary:
 return {"ok":false,"message":message}

static func unknown(data: Dictionary, allowed: Array) -> String:
 for key: Variant in data:
  if key not in allowed: return "不支持字段："+str(key)
 return ""

static func action_error(data: Dictionary, kind: String) -> String:
 var extra: String = unknown(data,["movement","priority","skill_cond","retreat_hp","lane_mode","stance","behavior","skill_usage","terrain_strategy"])
 if not extra.is_empty(): return extra
 for key: String in data:
  var value: Variant = data[key]
  if key == "retreat_hp":
   if not numeric(value) or float(value) < 0 or float(value) > 0.9: return "retreat_hp 必须为 0 至 0.9"
  elif not value is String: return key+" 必须是字符串"
  elif key == "movement":
   var moves: Array = COMMON_MOVES.duplicate()
   if kind == "triangle": moves.append("boundary_infiltrate")
   if kind == "diamond": moves.append_array(["align_with_square","align_with_crystal","align_with_splitter"])
   if value not in moves: return kind+" 不支持 movement："+str(value)
  elif key == "skill_cond":
   if value not in SKILLS[kind]: return kind+" 不支持 skill_cond："+str(value)
  elif value not in ENUMS[key]: return "无效 "+key+"："+str(value)
 if kind != "hexagon" and data.get("priority","closest") == "none": return "有普攻兵种的 priority 不支持 none"
 if kind == "hexagon" and data.get("priority","none") != "none": return "六边形无直接普攻，priority 必须为 none"
 return ""

static func numeric(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value))

static func condition_error(node: Variant, depth: int, budget: Array[int], facts: Dictionary = FACTS, limit: int = MAX_NODES) -> String:
 budget[0] += 1
 if budget[0] > limit: return "条件节点总数最多 %d" % limit
 if depth > MAX_DEPTH: return "条件嵌套深度最多 4"
 if not node is Dictionary: return "条件必须是对象"
 var data: Dictionary = node
 for combo: String in ["all","any","not"]:
  if data.has(combo):
   if data.size() != 1: return "组合条件不可混用字段"
   var children: Variant = data[combo]
   if combo == "not": return condition_error(children,depth+1,budget,facts,limit)
   if not children is Array or children.is_empty(): return combo+" 必须包含至少一个条件"
   for child: Variant in children:
    var error: String = condition_error(child,depth+1,budget,facts,limit)
    if not error.is_empty(): return error
   return ""
 var extra: String = unknown(data,["fact","op","value"])
 if not extra.is_empty(): return extra
 if data.size() != 3 or data.get("fact","") not in facts or data.get("op","") not in OPS: return "条件需要合法 fact / op / value"
 var spec: Variant = facts[data["fact"]]
 var value: Variant = data["value"]
 if spec is String:
  if not value is bool or data["op"] not in ["eq","ne"]: return "布尔条件仅支持 eq / ne 与布尔值"
 elif data["fact"] == "target_type":
  if value not in spec or data["op"] not in ["eq","ne"]: return "target_type 需要合法兵种，使用 eq / ne"
 else:
  if not numeric(value) or float(value) < float(spec[0]) or float(value) > float(spec[1]): return String(data["fact"])+" 数值超出范围"
  if data["fact"] in ["nearby_allies","nearby_enemies","target_cluster"] and float(value) != floorf(float(value)): return "单位数量必须为整数"
 return ""

static func validate(value: Variant, expected_kind: String = "") -> Dictionary:
 if not value is Dictionary: return failure("JSON 根节点必须是对象")
 var data: Dictionary = value
 if data.get("version") == 2 and data.has("plan"): return TacticPlan.validate(data,expected_kind)
 if data.has("error"): return failure("模型无法实现："+str(data["error"]))
 var extra: String = unknown(data,["version","unit_type","base","rules"])
 if not extra.is_empty(): return failure(extra)
 if not numeric(data.get("version")) or float(data["version"]) != VERSION: return failure("不支持的战术版本")
 var kind: Variant = data.get("unit_type","")
 if not kind is String or kind not in UnitCatalog.TYPES or (not expected_kind.is_empty() and kind != expected_kind): return failure("兵种与当前编辑对象不一致")
 if not data.get("base") is Dictionary or not data.get("rules") is Array: return failure("需要 base 对象与 rules 数组")
 var defaults: Dictionary = default_program(kind)["base"]
 for field: String in defaults:
  if not data["base"].has(field): return failure("base 缺少字段："+field)
 var error: String = action_error(data["base"],kind)
 if not error.is_empty(): return failure(error)
 if data["rules"].size() > MAX_RULES: return failure("每兵种最多 12 条规则")
 var budget: Array[int] = [0]
 var ids: Array[String] = []
 for entry: Variant in data["rules"]:
  if not entry is Dictionary: return failure("规则必须是对象")
  error = unknown(entry,["id","when","actions"])
  if not error.is_empty(): return failure(error)
  if entry.size() != 3 or not entry.get("id") is String or entry["id"].is_empty() or entry["id"].length() > 80 or entry["id"] in ids: return failure("规则 id 必须唯一，长度为 1 至 80")
  ids.append(entry["id"])
  error = condition_error(entry.get("when"),1,budget)
  if not error.is_empty(): return failure(entry["id"]+"："+error)
  if not entry.get("actions") is Dictionary or entry["actions"].is_empty(): return failure("actions 需要至少一个动作")
  error = action_error(entry["actions"],kind)
  if not error.is_empty(): return failure(entry["id"]+"："+error)
 return {"ok":true,"program":data.duplicate(true),"message":"校验通过"}

static func parse(text: String, kind: String) -> Dictionary:
 var parser: JSON = JSON.new()
 var error: Error = parser.parse(text)
 if error != OK: return failure("JSON 第 %d 行：%s" % [parser.get_error_line()+1,parser.get_error_message()])
 return validate(parser.data,kind)

static func matches(node: Dictionary, facts: Dictionary) -> bool:
 if node.has("all"):
  for child: Dictionary in node["all"]:
   if not matches(child,facts): return false
  return true
 if node.has("any"):
  for child: Dictionary in node["any"]:
   if matches(child,facts): return true
  return false
 if node.has("not"): return not matches(node["not"],facts)
 var actual: Variant = facts.get(node["fact"])
 var expected: Variant = node["value"]
 match String(node["op"]):
  "eq": return actual == expected
  "ne": return actual != expected
  "lt": return float(actual) < float(expected)
  "lte": return float(actual) <= float(expected)
  "gt": return float(actual) > float(expected)
  "gte": return float(actual) >= float(expected)
 return false

static func evaluate(program: Dictionary, facts: Dictionary) -> Dictionary:
 var effective: Dictionary = program["base"].duplicate(true)
 var matched: String = "基础战术"
 for entry: Dictionary in program["rules"]:
  if matches(entry["when"],facts):
   effective.merge(entry["actions"],true)
   matched = entry["id"]
   break
 return {"rule":effective,"matched":matched}

static func apply_to_profile(profile: Dictionary, program: Dictionary) -> Dictionary:
 var copy: Dictionary = profile.duplicate(true)
 var kind: String = program["unit_type"]
 copy["unit_rules"][kind] = program["base"].duplicate(true)
 copy["unit_rules"][kind]["program"] = program.duplicate(true)
 return copy

static func terrain_prompt() -> String:
 return "地形能力：base及v1规则actions可选terrain_strategy=auto/none/rails/portals/nebula/splitter/avoid_hazards/collect_flux。v2步骤也可显式terrain_strategy，未设置不擅自改动行动。语义goal.anchor支持rail_entry/rail_exit/portal/nebula/splitter_firing/safe_zone/flux_crystal。机关在地图不存在、出口不安全或不可达必须报错，不保证成功。虫洞完成以step_portals>=1，拾取以step_pickups>=1判定，不可仅接近点。scan_ready独立于skill_ready，六边形cast_skill.skill_request={ability:scan,aim:self,purpose:support}冷却8秒自身240px显形3秒，不治疗也不增加主技能计数。星云内的地形隐匿允许；任意隐身/无敌不支持。加速轨仅影响主动移动，中央分光保留真实物理折射。普通AI默认避开过载预警，v2必须用safe_zone步骤/中断或显式terrain_strategy授权。机关事实portal_available/gate_open/reactor_warning/in_nebula/portal_ready/scan_ready为布尔。"

static func system_prompt(kind: String) -> String:
 return terrain_prompt()+TacticPlan.system_prompt(kind)+"\n自然语言归一化词典：方向同义表达‘向上/北/上路/north/向地图上方’=up，‘向下/南/下路/south’=down，‘向左/west/左翼’=left，‘向右/east/右翼’=right，‘前进/压向敌方/推进/forward’=forward，‘后退/回撤/backward’=backward；时间‘持续2秒/前2秒’=move_direction.seconds:2，‘等待最多5秒/最多等5秒’=wait.timeout:5，‘开局第10秒’=when.match_time gte 10。路线‘沿左侧/贴边/绕开’使用方向或follow_path，‘经过航点’使用path，‘从目标左侧/右侧绕后’使用target_left/target_right或flank_target。掩体‘躲在墙后/寻找遮挡直射的位置’=seek_cover并指定obstacle或威胁目标，‘探头攻击’=peek+attack:true，‘暴露后换掩体’=seek_cover的失败或中断分支。技能‘技能就绪后施放/等待冷却结束’=skill_ready条件加cast_skill，‘保留技能’=skill:hold，‘用冲刺赶路’仅三角skill:travel，‘对目标方向施放’=skill_request aim:direction，‘等待合法范围’=timeout而非擅自追敌。条件‘生命低于30%’=self_hp lt 0.3，‘附近有3个敌人’=nearby_enemies gte 3，‘目标丢失/目标死亡’=target_lost eq true，‘技能冷却结束’=skill_ready eq true，‘对局时间达到10秒’=match_time gte 10。必须区分：保持指定方向是move_direction，遇障受阻时停止；自动绕障只允许move_to或follow_path。省略字段可填现有默认值，但无法可靠表达、地图点越界、要求任意隐身/无敌/修改数值时必须返回具体error（进入地图星云的地形隐匿允许），不能静默改写。请在生成前先在内部归一化这些表达，最终仍只输出严格JSON。"
