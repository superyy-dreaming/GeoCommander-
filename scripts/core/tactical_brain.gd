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
 "crystal": ["利用地形折射", "晶簇折射", "crystal bounce"]
}
var team_profiles: Array[Dictionary] = []
var opening_prompt: String = "默认均衡战术"
var opening_profile: Dictionary = {}
var last_prompts: Array[String] = ["默认均衡战术", "默认均衡战术"]

func _ready() -> void:
 opening_profile = get_default_profile()
 reset_profiles()

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
