extends Node

const KEYWORDS: Dictionary = {
 "balanced": ["默认", "均衡", "balanced", "reset"],
 "flank": ["绕后", "侧翼", "flank"],
 "assassin": ["切后排", "切菱形", "刺杀指挥", "snipe", "assassin"],
 "guard": ["保护", "死守", "保六边形", "defend", "guard"],
 "refract": ["折射", "反射", "棱镜配合", "refract", "bounce"],
 "rush": ["全军突击", "冲锋", "all in", "rush"],
 "kite": ["拉扯", "风筝", "后撤", "kite", "retreat"],
 "mid": ["中路推进", "走中路", "mid lane"],
 "split": ["分推", "南北包抄", "split push"],
 "crystal": ["利用地形折射", "晶簇折射", "crystal bounce"],
 "rails":["加速轨","加速带","高速包抄"],
 "portals":["虫洞","折跃","奇袭后排"],
 "nebula":["星云","隐匿","埋伏"],
 "splitter":["分光","中央棱镜","三向激光"],
 "hazards":["躲避过载","撤出红圈"],
 "flux":["抢晶簇","拾取晶体"]
}
var team_profiles: Array[Dictionary] = []
var opening_prompt: String = "默认均衡战术"
var opening_profile: Dictionary = {}
var last_prompts: Array[String] = ["默认均衡战术", "默认均衡战术"]
const COPILOT_CONFIG_PATH: String = "user://copilot.cfg"
const COPILOT_DEFAULT: String = "均衡分析战场局势，根据敌我兵种克制、中立能源点与晶簇刷新情况，提供三套按推荐度从高到低排列的战术变阵方案。"
var copilot_system_directive: String = COPILOT_DEFAULT
var copilot_persistence_error: String = ""

func _ready() -> void:
 opening_profile = get_default_profile()
 reset_profiles()
 load_copilot_directive()

func load_copilot_directive() -> void:
 var config: ConfigFile = ConfigFile.new()
 if config.load(COPILOT_CONFIG_PATH) == OK and int(config.get_value("copilot","version",0)) == 1:
  var value: String = str(config.get_value("copilot","directive",COPILOT_DEFAULT))
  if value.length() <= UnitTacticProgram.MAX_PROMPT and not value.strip_edges().is_empty(): copilot_system_directive = value

func save_copilot_directive(value: String) -> Dictionary:
 var trimmed: String = value.strip_edges()
 if trimmed.is_empty() or trimmed.length() > UnitTacticProgram.MAX_PROMPT:
  return {"ok":false,"message":"参谋提示词需为 1 至 4096 字符"}
 copilot_system_directive = trimmed
 var config: ConfigFile = ConfigFile.new()
 config.set_value("copilot","version",1)
 config.set_value("copilot","directive",copilot_system_directive)
 var error: Error = config.save(COPILOT_CONFIG_PATH)
 copilot_persistence_error = "" if error == OK else "本次运行已生效，但参谋提示词未保存"
 return {"ok":error == OK,"message":copilot_persistence_error}

func copilot_presets() -> Dictionary:
 return {
  "激进奇袭参谋": "优先推荐利用加速轨、虫洞与三角形绕后刺杀敌方六边形和抢夺晶簇的高机动进攻方案。",
  "折光阵地参谋": "优先推荐正方形展开棱镜配合菱形折射激光、利用隐匿星云防守反击与规避狙击的方案。",
  "经济运营参谋": "优先推荐抢占南北能源点、躲避反应堆过载并循环采集算力晶簇的资源压制方案。"
 }

func set_copilot_preset(name: String) -> Dictionary:
 var presets: Dictionary = copilot_presets()
 if not presets.has(name): return {"ok":false,"message":"未知参谋预设"}
 return save_copilot_directive(str(presets[name]))

func reset_profiles() -> void:
 team_profiles = [get_default_profile(), get_default_profile()]
 last_prompts = ["默认均衡战术", "默认均衡战术"]

func get_default_profile() -> Dictionary:
 return {"lane_mode":"auto", "stance": "balanced", "focus_fire_pos": Vector2.ZERO, "unit_rules": {
  "triangle": {"movement": "flank_sides", "priority": "ranged_or_commander", "skill_cond": "backstab_or_grav", "retreat_hp": 0.20},
  "square": {"movement": "frontline_screen", "priority": "closest", "skill_cond": "ally_threatened", "retreat_hp": 0.0},
  "circle": {"movement": "midline_support", "priority": "cluster", "skill_cond": "cluster_3plus", "retreat_hp": 0.30},
  "diamond": {"movement": "max_range_kite", "priority": "highest_threat", "skill_cond": "refract_or_snipe", "retreat_hp": 0.45},
  "hexagon": {"movement": "safe_backline", "priority": "none", "skill_cond": "always_pulse", "retreat_hp": 0.60}
 }}

func parse_prompt(prompt_text: String) -> Dictionary:
 var text: String = prompt_text.to_lower().strip_edges()
 if text.length() > 256:
  return {"ok": false, "message": "战术指令最多 256 个字符"}
 var events: Array[Dictionary] = []
 for action: String in KEYWORDS:
  var words: Array = KEYWORDS[action]
  for word: String in words:
   var start: int = 0
   var index: int = text.find(word, start)
   while index >= 0:
    events.append({"position": index, "action": action, "length":word.length()})
    start = index + word.length()
    index = text.find(word, start)
 if events.is_empty():
  return {"ok": false, "message": "未识别战术。请使用侧翼、保护、折射、冲锋或风筝等关键词。"}
 events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
  return int(a["position"]) < int(b["position"]) if a["position"] != b["position"] else int(a["length"]) > int(b["length"]))
 var filtered: Array[Dictionary] = []
 var consumed: int = -1
 for event: Dictionary in events:
  if int(event["position"]) < consumed: continue
  filtered.append(event)
  consumed = int(event["position"])+int(event["length"])
 events = filtered
 var profile: Dictionary = get_default_profile()
 var rules: Dictionary = profile["unit_rules"]
 for event: Dictionary in events:
  match String(event["action"]):
   "rails","portals","nebula","hazards","flux":
    var policy: String={"rails":"rails","portals":"portals","nebula":"nebula","hazards":"avoid_hazards","flux":"collect_flux"}[event["action"]]
    for kind: String in rules: rules[kind]["terrain_strategy"]=policy
   "splitter":
    rules["diamond"]["terrain_strategy"]="splitter"
    rules["diamond"]["movement"]="align_with_splitter"
   "mid": profile["lane_mode"] = "mid"
   "split": profile["lane_mode"] = "split"
   "crystal":
    rules["diamond"]["movement"] = "align_with_crystal"
    rules["diamond"]["skill_cond"] = "refract_or_snipe"
   "balanced":
    profile = get_default_profile()
    rules = profile["unit_rules"]
   "flank":
    profile["stance"] = "flank"
    rules["triangle"]["movement"] = "flank_sides"
   "assassin": rules["triangle"]["priority"] = "ranged_or_commander"
   "guard":
    profile["stance"] = "defensive"
    rules["square"]["movement"] = "protect_hexagon"
    rules["triangle"]["movement"] = "guard_rear"
   "refract":
    rules["diamond"]["movement"] = "align_with_square"
    rules["diamond"]["skill_cond"] = "refract_or_snipe"
    rules["square"]["skill_cond"] = "reflect_laser"
   "rush":
    profile["stance"] = "aggressive"
    rules["triangle"]["movement"] = "direct_charge"
    for kind: String in rules:
     rules[kind]["retreat_hp"] = 0.0
   "kite":
    profile["stance"] = "kite"
    var defaults: Dictionary = get_default_profile()["unit_rules"]
    for kind: String in rules:
     rules[kind]["retreat_hp"] = minf(float(defaults[kind]["retreat_hp"]) + 0.2, 0.9)
 return {"ok": true, "profile": profile, "message": "战术已编译"}

func save_opening_prompt(prompt: String) -> Dictionary:
 var result: Dictionary = parse_prompt(prompt)
 if bool(result["ok"]):
  opening_prompt = prompt
  opening_profile = (result["profile"] as Dictionary).duplicate(true)
 return result

func begin_match_profiles() -> void:
 reset_profiles()
 team_profiles[0] = opening_profile.duplicate(true)
 last_prompts[0] = opening_prompt

func compile_prompt_to_profile(team: int, prompt_text: String) -> Dictionary:
 var result: Dictionary = parse_prompt(prompt_text)
 if not bool(result["ok"]):
  return result
 if team < 0 or team > 1:
  return {"ok": false, "message": "无效队伍"}
 team_profiles[team] = (result["profile"] as Dictionary).duplicate(true)
 last_prompts[team] = prompt_text
 SignalBus.tactical_profile_updated.emit(team, team_profiles[team], prompt_text)
 return result

func json_preview(profile: Dictionary) -> String:
 var serializable: Dictionary = profile.duplicate(true)
 var focus: Vector2 = serializable.get("focus_fire_pos", Vector2.ZERO)
 serializable["focus_fire_pos"] = {"x": focus.x, "y": focus.y}
 return JSON.stringify(serializable, "  ")

func save_opening_program(program: Dictionary) -> Dictionary:
 var result: Dictionary = UnitTacticProgram.validate(program)
 if not result["ok"]: return result
 opening_profile = UnitTacticProgram.apply_to_profile(opening_profile,program)
 opening_prompt = "自定义兵种战术（已编译 JSON）"
 return {"ok":true,"message":"当前兵种已应用为本次运行开局，其他兵种保留"}
