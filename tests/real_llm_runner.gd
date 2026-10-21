extends Node

# Opt-in real-provider validation. Credentials arrive only through an inherited
# environment variable; artifacts contain prompts/programs and safe status only.
const MODEL: String = "deepseek-ai/DeepSeek-V4.1-Flash"
const ENDPOINT: String = "https://api.siliconflow.cn/v1/chat/completions"
const PROMPTS: Dictionary = {
 "triangle":"三角形使用侧翼绕后、分推路线、侧翼姿态，优先远程或指挥官。规则按优先级：自身生命严格低于30%时主动撤退并保留技能；否则原地防守，保留普攻，技能就绪并且目标距离在110至340像素之间（含边界）时尝试施放冲刺；其他情况保留技能。撤退阈值为0，不要额外自动撤退。",
 "square":"方形移动策略保护六边形、中路、平衡姿态、优先最近目标，撤退阈值0。规则：自身生命小于等于25%时主动撤退并保留技能；否则原地防守，如果技能就绪且目标距离小于等于220像素则尝试放护盾，否则保留技能。普攻保持正常。",
 "circle":"圆形中排支援、中路、平衡姿态，优先聚集目标，技能条件cluster_3plus，撤退阈值0。始终原地防守保持普攻。仅当目标周围聚集数量大于等于3且技能就绪时尝试引力技能，其他时候保留技能。",
 "diamond":"菱形移动策略max_range_kite，路线auto，姿态kite，优先最高威胁，技能条件on_cooldown，撤退阈值0。始终原地防守保持普攻。仅当目标可见、目标距离小于等于650像素且技能就绪时尝试激光，其余情况保留技能。",
 "hexagon":"六边形移动策略safe_backline，路线auto，防守姿态，无直接普攻priority为none，技能条件always_pulse，撤退阈值0。始终原地防守。当附近友军最低生命严格低于60%且技能就绪时尝试治疗，否则保留技能。不要添加其他条件。"
}
var passed: int = 0
var failed: int = 0
var responses: Array[Dictionary] = []
var programs: Dictionary = {}
var checks: Array[Dictionary] = []
var requests: Array[Dictionary] = []
var outcomes: Array[Dictionary] = []
var baseline_applied: Dictionary
var loaded_only: bool = false

func check(ok: bool, title: String) -> void:
 if ok: passed += 1
 else:
  failed += 1
  push_error("REAL_LLM_FAIL "+title)
 checks.append({"ok":ok,"title":title})
 print(("PASS " if ok else "FAIL ")+title)

func _ready() -> void:
 await run()
 LLMService.cancel_all()
 LLMService.api_key = ""
 LaboratoryStore.applied_programs = baseline_applied
 var report: Dictionary = {"date":"2026-10-21","endpoint":ENDPOINT,"model":MODEL,"mode":"saved_program_replay" if loaded_only else "real_provider","passed":passed,"failed":failed,"requests":requests,"checks":checks,"outcomes":outcomes,"key_persisted":false}
 var path: String = "res://artifacts/real-llm-replay-report.json" if loaded_only else "res://artifacts/real-llm-report.json"
 var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "))
 print("REAL_LLM_RESULT passed=%d failed=%d" % [passed,failed])
 get_tree().quit(0 if failed == 0 else 1)

func on_response(request_owner: int, _purpose: String, result: Dictionary) -> void:
 if request_owner == get_instance_id(): responses.append(result)

func request(purpose: String, kind: String = "triangle") -> Dictionary:
 responses.clear()
 var start: int = Time.get_ticks_msec()
 var launched: Dictionary = LLMService.start(get_instance_id(),purpose,PROMPTS.get(kind,""),kind)
 if not launched["ok"]: return launched
 while responses.is_empty() and Time.get_ticks_msec()-start < 35000:
  await get_tree().process_frame
 var result: Dictionary = responses[0] if not responses.is_empty() else {"ok":false,"message":"test lifecycle exceeded","category":"test_wait"}
 requests.append({"purpose":purpose,"unit":kind if purpose == "generate" else "","ok":result["ok"],"message":result["message"],"category":result.get("category",""),"elapsed_ms":Time.get_ticks_msec()-start})
 return result

func run() -> void:
 baseline_applied = LaboratoryStore.applied_programs.duplicate(true)
 loaded_only = "--replay" in OS.get_cmdline_user_args()
 if loaded_only:
  for kind: String in UnitCatalog.TYPES:
   var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/real-llm-"+kind+".json"))
   var valid: Dictionary = UnitTacticProgram.validate(data,kind)
   check(valid["ok"],"saved generated JSON valid "+kind)
   if valid["ok"]: programs[kind] = valid["program"]
 else:
  var key: String = OS.get_environment("GEO_LLM_TEST_KEY")
  OS.unset_environment("GEO_LLM_TEST_KEY")
  if key.is_empty():
   check(false,"GEO_LLM_TEST_KEY required in memory")
   return
  LLMService.config_path = "user://test_real_llm_connection.cfg"
  LLMService.configure(ENDPOINT,key,MODEL)
  LLMService.completed.connect(on_response)
  var connected: Dictionary = await request("test")
  check(connected["ok"],"real provider model connection")
  if not connected["ok"]: return
  var listed: Dictionary = await request("models")
  check(listed["ok"] and MODEL in listed.get("models",[]),"model listed by provider")
  for kind: String in UnitCatalog.TYPES:
   if "--resume" in OS.get_cmdline_user_args() and "--refresh="+kind not in OS.get_cmdline_user_args() and FileAccess.file_exists("res://artifacts/real-llm-"+kind+".json"):
    var saved: Dictionary = UnitTacticProgram.validate(JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/real-llm-"+kind+".json")),kind)
    if saved["ok"]:
     programs[kind] = saved["program"]
     check(true,"retained prior real generated JSON "+kind)
     continue
   var generated: Dictionary = await request("generate",kind)
   check(generated["ok"],"real generated JSON valid "+kind)
   if generated["ok"]:
    programs[kind] = generated["program"]
    var output: FileAccess = FileAccess.open("res://artifacts/real-llm-"+kind+".json",FileAccess.WRITE)
    output.store_string(JSON.stringify(generated["program"],"  "))
  var connection: String = FileAccess.get_file_as_string(LLMService.config_path)
  var experiments: String = FileAccess.get_file_as_string(LaboratoryStore.path)
  check(not connection.contains(key) and not experiments.contains(key),"key absent from connection and experiment files")
  key = ""
 for kind: String in programs:
  semantic_tests(kind,programs[kind])
 if programs.size() != 5: return
 LaboratoryStore.applied_programs = programs.duplicate(true)
 for kind: String in UnitCatalog.TYPES:
  await runtime_case(kind)
  await runtime_negative_case(kind)
 await formal_consistency()

func facts() -> Dictionary:
 return {"self_hp":1.0,"target_hp":1.0,"target_distance":180.0,"nearby_allies":2,"nearby_enemies":3,"ally_min_hp":0.5,"hexagon_alive":true,"skill_ready":true,"target_visible":true,"target_cluster":3,"target_type":"diamond"}

func effective(program: Dictionary, state: Dictionary) -> Dictionary:
 return UnitTacticProgram.evaluate(program,state)["rule"]

func semantic_tests(kind: String, program: Dictionary) -> void:
 var state: Dictionary = facts()
 var current: Dictionary = effective(program,state)
 check(current["behavior"] == "hold" and current["skill_usage"] == "try","normal state hold and cast "+kind)
 state["skill_ready"] = false
 check(effective(program,state)["skill_usage"] == "hold","not ready reserves skill "+kind)
 state = facts()
 if kind in ["triangle","square"]:
  var threshold: float = 0.3 if kind == "triangle" else 0.25
  state["self_hp"] = threshold-0.001
  current = effective(program,state)
  check(current["behavior"] == "retreat" and current["skill_usage"] == "hold","critical health retreat takes priority "+kind)
  state["self_hp"] = threshold
  check(effective(program,state)["behavior"] == ("hold" if kind == "triangle" else "retreat"),"health strict/inclusive boundary "+kind)
  state = facts()
  for distance: float in ([109.0,110.0,340.0,341.0] if kind == "triangle" else [220.0,221.0]):
   state["target_distance"] = distance
   var should_cast: bool = distance >=110 and distance<=340 if kind == "triangle" else distance<=220
   check(effective(program,state)["skill_usage"] == ("try" if should_cast else "hold"),"distance boundary %s %.0f" % [kind,distance])
 elif kind == "circle":
  state["target_cluster"] = 2
  check(effective(program,state)["skill_usage"] == "hold","circle two targets hold")
  state["target_cluster"] = 3
  check(effective(program,state)["skill_usage"] == "try","circle three targets cast")
 elif kind == "diamond":
  state["target_visible"] = false
  check(effective(program,state)["skill_usage"] == "hold","diamond occlusion holds")
  state["target_visible"] = true
  for distance: float in [650.0,651.0]:
   state["target_distance"] = distance
   check(effective(program,state)["skill_usage"] == ("try" if distance ==650 else "hold"),"diamond range %.0f" % distance)
 else:
  state["ally_min_hp"] = 0.6
  check(effective(program,state)["skill_usage"] == "hold","hexagon 60 percent holds")
  state["ally_min_hp"] = 0.599
  check(effective(program,state)["skill_usage"] == "try","hexagon below 60 heals")
  check(program["base"]["priority"] == "none","hexagon no attack capability")
 check(float(program["base"]["retreat_hp"]) == 0,"no implicit retreat "+kind)

func fixture(kind: String) -> Array[Dictionary]:
 var result: Array[Dictionary] = [LaboratoryPresets.unit(kind,0,1000,350),LaboratoryPresets.unit("square",1,1180,350)]
 if kind == "circle":
  result.append(LaboratoryPresets.unit("square",1,1230,300))
  result.append(LaboratoryPresets.unit("square",1,1230,400))
 if kind == "hexagon":
  result[1]["x"] = 1400.0
  result.append(LaboratoryPresets.unit("square",0,1060,300,0.5))
 return result

func runtime_case(kind: String) -> void:
 var viewport: SubViewport = SubViewport.new()
 viewport.world_2d = World2D.new()
 add_child(viewport)
 var arena: LaboratoryArena = LaboratoryArena.new()
 arena.layout = fixture(kind)
 viewport.add_child(arena)
 await get_tree().physics_frame
 var blue: BaseGeoUnit = arena.units_for(0)[0]
 for unit: BaseGeoUnit in arena.local_units:
  if unit != blue:
   unit.scripted_control = true
   unit.scripted_direction = Vector2.ZERO
   unit.visual_root.rotation = 0
   unit.attack_left = 999
   unit.skill_left = 999
 blue.attack_left = 999
 blue.skill_left = 0
 blue.decide_tactic()
 var initial: Vector2 = blue.position
 var matched: String = blue.matched_rule
 check(blue.rule["behavior"] == "hold" and blue.rule["skill_usage"] == "try","real facts match AI program "+kind)
 arena.start()
 for i: int in range(100): await get_tree().physics_frame
 check(int(arena.totals[0]["skills"]) == 1,"autonomous actual skill starts once "+kind)
 if kind == "hexagon":
  check(float(arena.totals[0]["healing"]) >0,"actual healing by generated rules")
 elif kind in ["triangle","circle","diamond"]:
  check(float(arena.totals[0]["damage"]) >0,"actual skill damage "+kind)
 else:
  check(not arena.reflectors.filter(func(r: LaserReflector) -> bool: return r is PrismBarrier and r.team ==0).is_empty(),"actual shield exists")
 if kind != "triangle": check(blue.position.distance_to(initial)<1,"hold prevents active movement "+kind)
 outcomes.append({"unit":kind,"matched":matched,"totals":arena.totals.duplicate(true),"position_delta":blue.position.distance_to(initial),"elapsed":arena.elapsed})
 viewport.queue_free()
 await get_tree().process_frame
 if kind in ["triangle","square"]:
  viewport = SubViewport.new()
  viewport.world_2d = World2D.new()
  add_child(viewport)
  arena = LaboratoryArena.new()
  arena.layout = fixture(kind)
  arena.layout[0]["hp"] = 0.2
  viewport.add_child(arena)
  await get_tree().physics_frame
  blue = arena.units_for(0)[0]
  for enemy: BaseGeoUnit in arena.units_for(1): enemy.scripted_control=true
  blue.decide_tactic()
  initial = blue.position
  arena.start()
  for i: int in range(300): await get_tree().physics_frame
  var home: Vector2 = arena.base_for(0).position+Vector2(130,0)
  check(blue.rule["behavior"] == "retreat" and blue.position.distance_to(home)<initial.distance_to(home)-20 and int(arena.totals[0]["skills"]) ==0,"physical retreat toward home without casting "+kind)
  outcomes.append({"unit":kind,"case":"retreat","initial":str(initial),"position":str(blue.position),"rule":blue.rule})
  viewport.queue_free()
  await get_tree().process_frame

func runtime_negative_case(kind: String) -> void:
 var viewport: SubViewport = SubViewport.new()
 viewport.world_2d = World2D.new()
 add_child(viewport)
 var arena: LaboratoryArena = LaboratoryArena.new()
 arena.layout = fixture(kind)
 if kind == "triangle": arena.layout[1]["x"] = 1080.0
 elif kind == "square": arena.layout[1]["x"] = 1260.0
 elif kind == "circle": arena.layout.pop_back()
 elif kind == "hexagon": arena.layout[2]["hp"] = 1.0
 viewport.add_child(arena)
 if kind == "diamond":
  var wall: TerrainWall = TerrainWall.new()
  wall.position = Vector2(1100,350)
  wall.polygon = PackedVector2Array([Vector2(-10,-60),Vector2(10,-60),Vector2(10,60),Vector2(-10,60)])
  arena.add_child(wall)
 for i: int in range(3): await get_tree().physics_frame
 var blue: BaseGeoUnit = arena.units_for(0)[0]
 for unit: BaseGeoUnit in arena.local_units:
  if unit != blue: unit.scripted_control = true
  unit.attack_left = 999
 blue.skill_left = 0
 blue.decide_tactic()
 check(blue.rule["skill_usage"] == "hold","actual negative facts reserve skill "+kind)
 arena.start()
 for i: int in range(120): await get_tree().physics_frame
 check(int(arena.totals[0]["skills"]) ==0 and blue.action_blocked =="规则保留技能","actual negative condition prevents skill "+kind)
 viewport.queue_free()
 await get_tree().process_frame

func formal_consistency() -> void:
 for kind: String in UnitCatalog.TYPES: TacticalBrain.save_opening_program(programs[kind])
 var arena: MainArena = MainArena.new()
 arena.ai_enabled = false
 add_child(arena)
 await get_tree().physics_frame
 check(String(arena.hud.matrix_preview.text).contains("program"),"formal preparation matrix preserves generated programs")
 for kind: String in UnitCatalog.TYPES:
  var unit: BaseGeoUnit = arena.units_for(0).filter(func(u: BaseGeoUnit) -> bool: return u.unit_type==kind)[0]
  unit.current_hp = unit.max_hp*0.2
  unit.decide_tactic()
  check(unit.rule == effective(programs[kind],unit.last_facts),"formal and laboratory interpreter agree "+kind)
 arena.queue_free()
 await get_tree().process_frame
