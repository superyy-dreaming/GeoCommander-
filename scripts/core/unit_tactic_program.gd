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
 "behavior":["normal","hold","retreat"], "skill_usage":["auto","hold","try"]}
const SKILLS: Dictionary = {"triangle":["backstab_or_grav","on_cooldown","travel_and_backstab"],"square":["ally_threatened","reflect_laser","on_cooldown"],"circle":["cluster_3plus","on_cooldown"],"diamond":["refract_or_snipe","on_cooldown"],"hexagon":["always_pulse","on_cooldown"]}
const FACTS: Dictionary = {
 "self_hp":[0.0,1.0], "target_hp":[0.0,1.0], "target_distance":[0.0,3000.0],
 "nearby_allies":[0.0,30.0], "nearby_enemies":[0.0,30.0], "ally_min_hp":[0.0,1.0],
 "hexagon_alive":"bool", "skill_ready":"bool", "target_visible":"bool", "target_cluster":[0.0,30.0],
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
 var extra: String = unknown(data,["movement","priority","skill_cond","retreat_hp","lane_mode","stance","behavior","skill_usage"])
 if not extra.is_empty(): return extra
 for key: String in data:
  var value: Variant = data[key]
  if key == "retreat_hp":
   if not numeric(value) or float(value) < 0 or float(value) > 0.9: return "retreat_hp 必须为 0 至 0.9"
  elif key == "movement":
   var moves: Array = COMMON_MOVES.duplicate()
   if kind == "triangle": moves.append("boundary_infiltrate")
   if kind == "diamond": moves.append_array(["align_with_square","align_with_crystal"])
   if value not in moves: return kind+" 不支持 movement："+str(value)
  elif key == "skill_cond":
   if value not in SKILLS[kind]: return kind+" 不支持 skill_cond："+str(value)
  elif value not in ENUMS[key]: return "无效 "+key+"："+str(value)
 if kind != "hexagon" and data.get("priority","closest") == "none": return "有普攻兵种的 priority 不支持 none"
 if kind == "hexagon" and data.get("priority","none") != "none": return "六边形无直接普攻，priority 必须为 none"
 return ""

static func numeric(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value))

static func condition_error(node: Variant, depth: int, budget: Array[int]) -> String:
 budget[0] += 1
 if budget[0] > MAX_NODES: return "条件节点总数最多 32"
 if depth > MAX_DEPTH: return "条件嵌套深度最多 4"
 if not node is Dictionary: return "条件必须是对象"
 var data: Dictionary = node
 for combo: String in ["all","any","not"]:
  if data.has(combo):
   if data.size() != 1: return "组合条件不可混用字段"
   var children: Variant = data[combo]
   if combo == "not": return condition_error(children,depth+1,budget)
   if not children is Array or children.is_empty(): return combo+" 必须包含至少一个条件"
   for child: Variant in children:
    var error: String = condition_error(child,depth+1,budget)
    if not error.is_empty(): return error
   return ""
 var extra: String = unknown(data,["fact","op","value"])
 if not extra.is_empty(): return extra
 if data.size() != 3 or data.get("fact","") not in FACTS or data.get("op","") not in OPS: return "条件需要合法 fact / op / value"
 var spec: Variant = FACTS[data["fact"]]
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
 if data.has("error"): return failure("模型无法实现："+str(data["error"]))
 var extra: String = unknown(data,["version","unit_type","base","rules"])
 if not extra.is_empty(): return failure(extra)
 if not numeric(data.get("version")) or float(data["version"]) != VERSION: return failure("不支持的战术版本")
 var kind: Variant = data.get("unit_type","")
 if kind not in UnitCatalog.TYPES or (not expected_kind.is_empty() and kind != expected_kind): return failure("兵种与当前编辑对象不一致")
 if not data.get("base") is Dictionary or not data.get("rules") is Array: return failure("需要 base 对象与 rules 数组")
 var defaults: Dictionary = default_program(kind)["base"]
 if data["base"].size() != defaults.size(): return failure("base 必须包含完整的八个战术字段")
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

static func system_prompt(kind: String) -> String:
 return "你是 GeoCommander 战术编译器。只输出一个严格 JSON 对象，不要 Markdown。不能输出代码或更改伤害/冷却/技能。不能实现的要求返回 {\"error\":\"具体原因\"}。只编译当前兵种 "+kind+"。完整格式示例："+JSON.stringify(default_program(kind))+"。base 需要全部八字段。rules 按优先级最多12条，每条 {id,when,actions}，第一条匹配即停止。actions 是 base 字段的非空子集。条件为 {fact,op,value} 或 {all:[条件]} / {any:[条件]} / {not:条件}，all 和 any 数组必须至少含一个条件，禁止空数组。未命中规则时自动使用 base；把默认或否则动作放在 base，不要用空 all 表示默认规则。总共最多32节点，深度4。枚举："+JSON.stringify(ENUMS)+"。movement："+JSON.stringify(COMMON_MOVES)+("，菱形另支持 align_with_square / align_with_crystal" if kind == "diamond" else "，三角另支持 boundary_infiltrate" if kind == "triangle" else "")+"。skill_cond："+JSON.stringify(SKILLS[kind])+"。retreat_hp 在0..0.9。事实及范围："+JSON.stringify(FACTS)+"。附近为自身300px，聚集为目标160px，数量为整数。比较op：eq,ne,lt,lte,gt,gte；类型和布尔仅eq/ne。HP为比例。hold原地防守，retreat主动撤退；skill_usage hold保留技能、try尝试真实技能、auto按技能条件。六边形priority只能none，无直接普攻。priority=diamond_first精确优先敌方菱形，无菱形时选其他敌军。三角的movement=boundary_infiltrate是内置完整机动：开局向前进方向的左/右侧边缘移动（稳定按部署序号分配上/下边路），绕障碍后沿地图边缘推进，再按敌军实际朝向绕到目标背后。三角skill_cond=travel_and_backstab支持用同一冲刺技能赶路并背刺：沿合法路径无目标冲刺加速，接近目标时优先背刺；保留真实4.5秒冷却、0.25秒蓄力、980px/s速度、0.28秒冲刺和碰撞，不修改数值。用户要求边界绕后+技能赶路+优先菱形时用这三个枚举，behavior=normal、skill_usage=auto、retreat_hp=0即可，不需要附加条件或逐帧规则，也不要错误拒绝这些已支持能力。路线只影响当前兵种。技能仍有冷却、控制和碰撞检查，攻击冲刺射程110至340px，背刺110伤害。单位真实配置："+JSON.stringify(UnitCatalog.DATA[kind])
