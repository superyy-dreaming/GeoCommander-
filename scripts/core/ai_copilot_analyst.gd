class_name AICopilotAnalyst
extends Node

const DEFAULT_DIRECTIVE: String = "均衡分析战场局势，根据敌我兵种克制、中立能源点与晶簇刷新情况，提供三套按推荐度从高到低排列的战术变阵方案。"
const PRESETS: Dictionary = {
 "激进奇袭参谋": "优先推荐利用加速轨、虫洞与三角形绕后刺杀敌方六边形和抢夺晶簇的高机动进攻方案。",
 "折光阵地参谋": "优先推荐正方形展开棱镜配合菱形折射激光、利用隐匿星云防守反击与规避狙击的方案。",
 "经济运营参谋": "优先推荐抢占南北能源点、躲避反应堆过载并循环采集算力晶簇的资源压制方案。"
}

var arena: Node
var elapsed: float = 0.0
var request_pending: bool = false
var major_event_pending: bool = false
var snapshot_serial: int = 0
var batch_serial: int = 0
var request_owner: int = 0
var pending_snapshot_serial: int = -1
var pending_config_generation: int = -1
var pending_tactic_revision: int = -1
var proposal_tactic_revision: int = -1
var pending_arena_id: int = 0
var current_proposals: Array[Dictionary] = []
var current_source: String = "本地启发式"
var diagnosis: String = "等待战场快照"
var auto_delegate: bool = false
var auto_confirm_left: float = 0.0
var accept_left: float = 0.0
var active_copilot: bool = false
var active_profile: Dictionary = {}
var suspended: bool = false
var major_event_cooldown: float = 0.0
var visible_enemy_spawn_counts: Dictionary = {}

func setup(owner: Node) -> void:
 arena = owner
 request_owner = get_instance_id()
 process_mode = Node.PROCESS_MODE_ALWAYS
 if not LLMService.completed.is_connected(_on_llm_completed):
  LLMService.completed.connect(_on_llm_completed)
 if not LLMService.configuration_changed.is_connected(_on_connection_changed):
  LLMService.configuration_changed.connect(_on_connection_changed)

func _exit_tree() -> void:
 if request_pending:
  LLMService.cancel_owner(request_owner)
  request_pending = false
 if LLMService.completed.is_connected(_on_llm_completed):
  LLMService.completed.disconnect(_on_llm_completed)
 if LLMService.configuration_changed.is_connected(_on_connection_changed):
  LLMService.configuration_changed.disconnect(_on_connection_changed)

func _physics_process(delta: float) -> void:
 if not is_instance_valid(arena): return
 if get_tree().paused:
  suspend("战斗已暂停，建议已失效",false)
  return
 if not arena.is_combat_active():
  if request_pending or not current_proposals.is_empty() or active_copilot:
   suspend("对局未进行",true)
  return
 if suspended:
  suspended = false
  elapsed = 0.0
  major_event_pending = true
  SignalBus.copilot_status_changed.emit("战斗已恢复，正在刷新建议")
 if request_pending and pending_tactic_revision != arena.global_tactic_revision:
  LLMService.cancel_owner(request_owner)
  request_pending = false
  major_event_pending = true
  SignalBus.copilot_status_changed.emit("全局战术已改变，旧参谋请求已取消")
 if proposal_tactic_revision >= 0 and proposal_tactic_revision != arena.global_tactic_revision:
  current_proposals.clear()
  proposal_tactic_revision = -1
  auto_confirm_left = 0.0
  SignalBus.copilot_proposals_updated.emit(current_proposals,"建议已失效",snapshot_serial)
  SignalBus.copilot_status_changed.emit("全局战术已改变，正在更新参谋建议")
  major_event_pending = true
 major_event_cooldown = maxf(0.0,major_event_cooldown-delta)
 accept_left = maxf(0.0,accept_left-delta)
 elapsed += delta
 if major_event_pending or elapsed >= 8.0:
  elapsed = 0.0
  major_event_pending = false
  request_snapshot()
 if not _can_auto_accept():
  auto_confirm_left = 0.0
 if auto_confirm_left > 0.0:
   auto_confirm_left = maxf(0.0,auto_confirm_left-delta)
   if auto_confirm_left <= 0.0:
    if not current_proposals.is_empty():
     accept_proposal(int(current_proposals[0].get("slot",-1)),true)

func request_major_event(_event: String) -> void:
 if not is_instance_valid(arena) or not arena.is_combat_active() or get_tree().paused: return
 if major_event_cooldown > 0.0: return
 major_event_cooldown = 2.0
 major_event_pending = true

func on_enemy_unit_spawned(unit: BaseGeoUnit) -> void:
 if not is_instance_valid(arena) or not arena.is_combat_active() or get_tree().paused: return
 var visible_to_blue: bool = false
 for observer: BaseGeoUnit in arena.units_for(0):
  if not is_instance_valid(observer): continue
  if not is_instance_valid(arena.terrain) or arena.terrain.can_perceive(observer,unit):
   visible_to_blue = true
   break
 if not visible_to_blue: return
 var kind: String = unit.unit_type
 visible_enemy_spawn_counts[kind] = int(visible_enemy_spawn_counts.get(kind,0))+1
 if int(visible_enemy_spawn_counts[kind]) >= 2:
  visible_enemy_spawn_counts[kind] = 0
  request_major_event("可见敌方兵种数量增加")

func suspend(message: String, clear_proposals: bool) -> void:
 if request_pending:
  LLMService.cancel_owner(request_owner)
  request_pending = false
 auto_confirm_left = 0.0
 major_event_pending = false
 if clear_proposals:
  current_proposals.clear()
  proposal_tactic_revision = -1
  SignalBus.copilot_proposals_updated.emit(current_proposals,"无有效建议",snapshot_serial)
 if not suspended:
  SignalBus.copilot_status_changed.emit(message)
 suspended = true

func stop_for_match_end() -> void:
 suspend("对局结束，参谋请求已停止",true)
 if active_copilot and is_instance_valid(arena): arena.restore_copilot_profile()
 active_copilot = false
 active_profile.clear()
 auto_delegate = false

func request_snapshot() -> void:
 if request_pending or not is_instance_valid(arena) or not arena.is_combat_active() or get_tree().paused: return
 snapshot_serial += 1
 var snapshot: Dictionary = telemetry_snapshot()
 current_proposals = local_proposals(snapshot)
 current_source = "本地启发式"
 diagnosis = diagnosis_text(snapshot)
 proposal_tactic_revision = arena.global_tactic_revision
 batch_serial += 1
 SignalBus.copilot_proposals_updated.emit(current_proposals,current_source,snapshot_serial)
 SignalBus.copilot_status_changed.emit("本地启发式建议已生成")
 if _llm_available():
  request_pending = true
  pending_snapshot_serial = snapshot_serial
  pending_config_generation = LLMService.generation
  pending_tactic_revision = arena.global_tactic_revision
  pending_arena_id = arena.get_instance_id()
  var prompt: String = JSON.stringify({"snapshot":snapshot,"requirements":"最多三条不同建议，严格 JSON，score 1-99 严格递减，profile_patch 必须是现有 TacticalBrain profile 字段。"})
  var started: Dictionary = LLMService.start(request_owner,"copilot",prompt,"triangle",arena.map_id,TacticalBrain.copilot_system_directive)
  if not bool(started.get("ok",false)):
   request_pending = false
   SignalBus.copilot_status_changed.emit("联网参谋不可用，已使用本地启发式建议")
   _start_auto_confirmation()
  else:
   SignalBus.copilot_status_changed.emit("联网参谋分析中")
 else:
  _start_auto_confirmation()

func _can_auto_accept() -> bool:
 return auto_delegate and is_instance_valid(arena) and arena.is_combat_active() and not get_tree().paused and arena.selected_units.is_empty() and arena.local_override_left <= 0.0 and arena.override_left <= 0.0 and accept_left <= 0.0

func _start_auto_confirmation() -> void:
 auto_confirm_left = 1.2 if _can_auto_accept() and not current_proposals.is_empty() else 0.0

func _llm_available() -> bool:
 return not str(LLMService.model).strip_edges().is_empty() and not str(LLMService.api_key).strip_edges().is_empty() and str(LLMService.status).begins_with("连接通过")

func telemetry_snapshot() -> Dictionary:
 var blue: Dictionary = _visible_counts(0)
 var red: Dictionary = _visible_counts(1)
 var prism_state: Array = []
 for prism: EnergyPrism in arena.prisms:
  prism_state.append({"title":prism.title,"owner":prism.capture_owner,"progress":prism.progress})
 return {"elapsed":arena.elapsed,"match_left":arena.match_left,"blue":blue,"red_visible":red,"prisms":prism_state,"blue_flux":arena.flux[0],"red_flux":arena.flux[1],"reactor_warning":_reactor_warning()}

func _visible_counts(team: int) -> Dictionary:
 var counts: Dictionary = {}
 for kind: String in UnitCatalog.TYPES: counts[kind] = 0
 for unit: BaseGeoUnit in arena.units_for(team):
  if team == 1:
   var seen: bool = false
   for observer: BaseGeoUnit in arena.units_for(0):
    if arena.terrain == null or arena.terrain.can_perceive(observer,unit):
     seen = true
     break
   if not seen: continue
  counts[unit.unit_type] = int(counts[unit.unit_type])+1
 return counts

func _reactor_warning() -> bool:
 for unit: BaseGeoUnit in arena.units_for(0):
  if is_instance_valid(arena.terrain) and arena.terrain.warning_at(unit): return true
 return false

func diagnosis_text(snapshot: Dictionary) -> String:
 var red: Dictionary = snapshot["red_visible"]
 return "可见敌方：菱形 %d、三角 %d、方形 %d；能源棱镜状态已纳入分析" % [int(red.get("diamond",0)),int(red.get("triangle",0)),int(red.get("square",0))]

func _has_any(text: String, terms: Array[String]) -> bool:
 for term: String in terms:
  if text.contains(term): return true
 return false

func local_proposals(snapshot: Dictionary) -> Array[Dictionary]:
 var base: Dictionary = TacticalBrain.get_default_profile()
 var aggressive: Dictionary = base.duplicate(true)
 aggressive["stance"] = "aggressive"
 aggressive["unit_rules"]["triangle"]["movement"] = "flank_sides"
 aggressive["unit_rules"]["triangle"]["skill_cond"] = "travel_and_backstab"
 aggressive["unit_rules"]["triangle"]["terrain_strategy"] = "portals"
 var defensive: Dictionary = base.duplicate(true)
 defensive["stance"] = "defensive"
 defensive["unit_rules"]["square"]["movement"] = "protect_hexagon"
 defensive["unit_rules"]["diamond"]["movement"] = "align_with_square"
 defensive["unit_rules"]["diamond"]["terrain_strategy"] = "splitter"
 var economy: Dictionary = base.duplicate(true)
 economy["lane_mode"] = "split"
 economy["unit_rules"]["hexagon"]["terrain_strategy"] = "collect_flux"
 economy["unit_rules"]["circle"]["terrain_strategy"] = "avoid_hazards"
 var red_diamonds: int = int(snapshot["red_visible"].get("diamond",0))
 var directive: String = TacticalBrain.copilot_system_directive.to_lower()
 var aggression_weight: int = 0
 var defense_weight: int = 0
 var economy_weight: int = 0
 if _has_any(directive,["激进","奇袭","突击","进攻","aggressive","ambush"]): aggression_weight += 12
 if _has_any(directive,["防守","保护","折光","阵地","defensive","reflect"]): defense_weight += 12
 if _has_any(directive,["经济","能源","晶体","运营","economy","resource"]): economy_weight += 12
 if bool(snapshot.get("reactor_warning",false)): economy_weight += 8
 if float(snapshot.get("blue_flux",0.0)) < 80.0: economy_weight += 6
 aggression_weight += mini(red_diamonds*3,12)
 var ranked: Array[Dictionary] = [
  {"recommend_score":clampi(70+aggression_weight,1,99),"title":"侧翼绕后与高机动突击","reason":"优先利用侧翼和可用地形接近可见高威胁目标。","profile_patch":aggressive},
  {"recommend_score":clampi(67+defense_weight,1,99),"title":"折光阵地与核心保护","reason":"方形保护六边形，菱形利用现有反射面建立安全火力线。","profile_patch":defensive},
  {"recommend_score":clampi(64+economy_weight,1,99),"title":"分路运营与能源压制","reason":"分配上下路并避开已识别的过载预警，维持能源收益。","profile_patch":economy}
 ]
 ranked.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a["recommend_score"]) > int(b["recommend_score"]))
 var result: Array[Dictionary] = []
 var previous_score: int = 100
 for index: int in range(ranked.size()):
  var proposal: Dictionary = ranked[index].duplicate(true)
  proposal["recommend_score"] = mini(int(proposal["recommend_score"]),previous_score-1)
  proposal["slot"] = index
  result.append(proposal)
  previous_score = int(proposal["recommend_score"])
 return result

static func parse_response(content: String, map_id: String = "") -> Dictionary:
 var json_parser: JSON = JSON.new()
 if json_parser.parse(content.strip_edges()) != OK:
  return {"ok":false,"category":"validation","message":"参谋响应不是合法 JSON"}
 var parsed: Variant = json_parser.data
 if not parsed is Dictionary: return {"ok":false,"category":"validation","message":"参谋响应不是 JSON 对象"}
 var root_error: String = UnitTacticProgram.unknown(parsed,["proposals"])
 if not root_error.is_empty(): return {"ok":false,"category":"validation","message":"参谋响应："+root_error}
 var entries: Variant = parsed.get("proposals")
 if not entries is Array or entries.is_empty() or entries.size() > 3: return {"ok":false,"category":"validation","message":"参谋响应需要 1 至 3 条 proposals"}
 var result: Array[Dictionary] = []
 var profiles: Array[Dictionary] = []
 var used_slots: Dictionary = {}
 var previous_score: int = 100
 for index: int in range(entries.size()):
  var item: Variant = entries[index]
  if not item is Dictionary: return {"ok":false,"category":"validation","message":"第 %d 条建议不是对象" % (index+1)}
  var item_error: String = UnitTacticProgram.unknown(item,["slot","recommend_score","title","reason","profile_patch"])
  if not item_error.is_empty(): return {"ok":false,"category":"validation","message":"第 %d 条建议：%s" % [index+1,item_error]}
  if item.size() != 5 or not UnitTacticProgram.numeric(item.get("slot")) or floorf(float(item["slot"])) != float(item["slot"]):
   return {"ok":false,"category":"validation","message":"第 %d 条建议必须提供整数 slot" % (index+1)}
  var slot: int = int(item["slot"])
  if slot < 0 or slot > 2 or used_slots.has(slot):
   return {"ok":false,"category":"validation","message":"建议 slot 必须为不重复的 0 至 2"}
  if not UnitTacticProgram.numeric(item.get("recommend_score")) or floorf(float(item["recommend_score"])) != float(item["recommend_score"]):
   return {"ok":false,"category":"validation","message":"建议推荐度必须为整数"}
  var score: int = int(item["recommend_score"])
  if score < 1 or score > 99 or score >= previous_score: return {"ok":false,"category":"validation","message":"建议推荐度必须严格递减且在 1 至 99"}
  if not item.get("title","") is String or str(item["title"]).strip_edges().is_empty() or str(item["title"]).length()>80 or not item.get("reason","") is String or str(item["reason"]).strip_edges().is_empty() or str(item["reason"]).length()>500 or not item.get("profile_patch",{}) is Dictionary:
   return {"ok":false,"category":"validation","message":"建议标题、原因或 profile_patch 字段类型/长度不正确"}
  var checked_patch: Dictionary = validate_profile_patch(item["profile_patch"],map_id)
  if not bool(checked_patch.get("ok",false)):
   return {"ok":false,"category":"validation","message":"第 %d 条建议不符合战术能力：%s" % [index+1,str(checked_patch.get("message","校验失败"))]}
  var full_profile: Dictionary = checked_patch["profile"]
  for prior: Dictionary in profiles:
   if prior == full_profile: return {"ok":false,"category":"validation","message":"参谋建议必须提供不同的战术方案"}
  profiles.append(full_profile)
  used_slots[slot] = true
  result.append({"slot":slot,"recommend_score":score,"title":str(item["title"]).strip_edges(),"reason":str(item["reason"]).strip_edges(),"profile_patch":full_profile})
  previous_score = score
 return {"ok":true,"proposals":result,"message":"参谋建议已通过本地校验"}

static func validate_profile_patch(patch: Dictionary, map_id: String) -> Dictionary:
 var defaults: Dictionary = TacticalBrain.get_default_profile()
 var result: Dictionary = defaults.duplicate(true)
 if patch.is_empty(): return {"ok":false,"message":"profile_patch 不能为空"}
 var error_text: String = UnitTacticProgram.unknown(patch,["lane_mode","stance","focus_fire_pos","unit_rules"])
 if not error_text.is_empty(): return {"ok":false,"message":error_text}
 for field: String in ["lane_mode","stance"]:
  if patch.has(field):
   if not patch[field] is String or patch[field] not in UnitTacticProgram.ENUMS[field]:
    return {"ok":false,"message":"无效 "+field+"："+str(patch[field])}
   result[field] = patch[field]
 if patch.has("focus_fire_pos"):
  var focus_value: Variant = patch["focus_fire_pos"]
  var focus_point: Vector2
  if focus_value is Array and focus_value.size() == 2 and UnitTacticProgram.numeric(focus_value[0]) and UnitTacticProgram.numeric(focus_value[1]):
   focus_point = Vector2(float(focus_value[0]),float(focus_value[1]))
  elif focus_value is Dictionary and focus_value.size() == 2 and UnitTacticProgram.numeric(focus_value.get("x")) and UnitTacticProgram.numeric(focus_value.get("y")):
   focus_point = Vector2(float(focus_value["x"]),float(focus_value["y"]))
  else:
   return {"ok":false,"message":"focus_fire_pos 必须是 [x,y] 或 {x,y}"}
  if focus_point != Vector2.ZERO and not MapCatalog.WORLD_RECT.has_point(focus_point):
   return {"ok":false,"message":"focus_fire_pos 超出当前地图边界"}
  result["focus_fire_pos"] = focus_point
 if patch.has("unit_rules"):
  if not patch["unit_rules"] is Dictionary or patch["unit_rules"].is_empty():
   return {"ok":false,"message":"unit_rules 必须包含至少一个兵种补丁"}
  for raw_kind: Variant in patch["unit_rules"]:
   var kind: String = str(raw_kind)
   if kind not in UnitCatalog.TYPES: return {"ok":false,"message":"未知兵种："+kind}
   var raw_rule: Variant = patch["unit_rules"][raw_kind]
   if not raw_rule is Dictionary or raw_rule.is_empty(): return {"ok":false,"message":kind+" 规则必须是非空对象"}
   var rule_error: String = UnitTacticProgram.unknown(raw_rule,["movement","priority","skill_cond","retreat_hp","terrain_strategy","behavior","skill_usage","program"])
   if not rule_error.is_empty(): return {"ok":false,"message":kind+"："+rule_error}
   var action_patch: Dictionary = raw_rule.duplicate(true)
   var program_value: Variant = action_patch.get("program",{})
   action_patch.erase("program")
   rule_error = UnitTacticProgram.action_error(action_patch,kind)
   if not rule_error.is_empty(): return {"ok":false,"message":kind+"："+rule_error}
   if raw_rule.has("program"):
    if not program_value is Dictionary: return {"ok":false,"message":kind+"：program 必须是对象"}
    var program_checked: Dictionary = UnitTacticProgram.validate(program_value,kind)
    if not bool(program_checked.get("ok",false)): return {"ok":false,"message":kind+"："+str(program_checked.get("message","program 校验失败"))}
    var map_error: String = TacticPlan.map_validation(program_checked["program"],map_id)
    if not map_error.is_empty(): return {"ok":false,"message":kind+"："+map_error}
   (result["unit_rules"] as Dictionary)[kind].merge(raw_rule,true)
 if not patch.has("lane_mode") and not patch.has("stance") and not patch.has("focus_fire_pos") and not patch.has("unit_rules"):
  return {"ok":false,"message":"profile_patch 未提供可应用的战术字段"}
 var profile_error: String = TacticPlan.profile_error(result,map_id)
 if not profile_error.is_empty(): return {"ok":false,"message":profile_error}
 return {"ok":true,"profile":result}

func _on_llm_completed(owner: int, purpose: String, result: Dictionary) -> void:
 if owner != request_owner or purpose != "copilot" or not request_pending:
  return
 request_pending = false
 var response_is_current: bool = is_instance_valid(arena) and arena.is_combat_active() and not get_tree().paused and pending_snapshot_serial == snapshot_serial and pending_config_generation == LLMService.generation and pending_tactic_revision == arena.global_tactic_revision and pending_arena_id == arena.get_instance_id()
 if not response_is_current:
  auto_confirm_left = 0.0
  SignalBus.copilot_status_changed.emit("参谋响应已过期，未应用")
  return
 if not bool(result.get("ok",false)):
  current_source = "本地启发式"
  SignalBus.copilot_status_changed.emit("联网参谋失败，已使用本地启发式建议："+str(result.get("message","未知错误")))
  _start_auto_confirmation()
  return
 var received: Variant = result.get("proposals",current_proposals)
 if received is Array:
  current_proposals.assign(received)
 current_source = "联网模型："+str(result.get("source_model",LLMService.model))
 proposal_tactic_revision = arena.global_tactic_revision
 batch_serial += 1
 SignalBus.copilot_proposals_updated.emit(current_proposals,current_source,snapshot_serial)
 SignalBus.copilot_status_changed.emit("联网参谋建议已生成")
 _start_auto_confirmation()

func _on_connection_changed() -> void:
 if request_pending:
  LLMService.cancel_owner(request_owner)
  request_pending = false
  pending_config_generation = -1
  current_source = "本地启发式"
  SignalBus.copilot_status_changed.emit("连接配置已改变，当前批次保留本地建议")
  _start_auto_confirmation()

func toggle_auto_delegate() -> void:
 auto_delegate = not auto_delegate
 auto_confirm_left = 0.0
 SignalBus.copilot_status_changed.emit("自动代理："+ ("开启" if auto_delegate else "关闭"))

func on_directive_updated() -> void:
 if request_pending:
  LLMService.cancel_owner(request_owner)
  request_pending = false
 snapshot_serial += 1
 pending_snapshot_serial = -1
 current_proposals.clear()
 proposal_tactic_revision = -1
 auto_confirm_left = 0.0
 SignalBus.copilot_proposals_updated.emit(current_proposals,"提示词已更改",snapshot_serial)
 if is_instance_valid(arena) and arena.is_combat_active():
  major_event_pending = true
 SignalBus.copilot_status_changed.emit("参谋提示词已更改，旧建议已失效")

func accept_proposal(slot: int, automatic: bool = false) -> bool:
 if not is_instance_valid(arena) or get_tree().paused or accept_left > 0.0 or not arena.is_combat_active(): return false
 if proposal_tactic_revision != arena.global_tactic_revision:
  SignalBus.copilot_status_changed.emit("建议已过期，请等待新的战场分析")
  return false
 if not automatic and not arena.selected_units.is_empty():
  SignalBus.copilot_status_changed.emit("已有小队选择，参谋只作用于全局自动单位")
  return false
 if automatic and not _can_auto_accept(): return false
 var proposal: Dictionary = {}
 for entry: Dictionary in current_proposals:
  if int(entry.get("slot",-1)) == slot:
   proposal = entry
   break
 if proposal.is_empty(): return false
 if not arena.apply_copilot_proposal(proposal["profile_patch"]): return false
 accept_left = 3.0
 active_copilot = true
 active_profile = proposal["profile_patch"].duplicate(true)
 auto_confirm_left = 0.0
 SignalBus.copilot_status_changed.emit(("自动采纳" if automatic else "已采纳")+"方案 "+str(slot+1))
 return true

func restore_original() -> void:
 if active_copilot:
  arena.restore_copilot_profile()
 active_copilot = false
 active_profile.clear()
 SignalBus.copilot_status_changed.emit("已恢复原战术方案")
