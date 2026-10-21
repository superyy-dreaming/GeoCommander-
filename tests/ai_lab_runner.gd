extends Node

var passed: int = 0
var failed: int = 0
var received: Array[Dictionary] = []
func check(condition: bool, title: String) -> void:
 if condition: passed += 1
 else:
  failed += 1
  push_error("AI_LAB_FAIL "+title)

func _ready() -> void:
 await run()
 print("AI_LAB_TEST passed=%d failed=%d" % [passed,failed])
 get_tree().quit(0 if failed == 0 else 1)

func fact(name: String, op: String, value: Variant) -> Dictionary:
 return {"fact":name,"op":op,"value":value}

func run() -> void:
 var saved: Dictionary = LaboratoryStore.records.duplicate(true)
 var opening: Dictionary = TacticalBrain.opening_profile.duplicate(true)
 var prompt: String = TacticalBrain.opening_prompt
 var program: Dictionary = UnitTacticProgram.default_program("triangle")
 check(UnitTacticProgram.validate(program)["ok"],"default valid")
 program["rules"] = [{"id":"low_hp","when":fact("self_hp","lte",0.3),"actions":{"behavior":"retreat","skill_usage":"hold"}},{"id":"always","when":fact("self_hp","gte",0.0),"actions":{"behavior":"hold"}}]
 check(UnitTacticProgram.validate(program)["ok"],"rules valid")
 var evaluated: Dictionary = UnitTacticProgram.evaluate(program,{"self_hp":0.3})
 check(evaluated["matched"] == "low_hp" and evaluated["rule"]["behavior"] == "retreat","first match boundary")
 check(UnitTacticProgram.evaluate(program,{"self_hp":0.8})["matched"] == "always","second match")
 check(UnitTacticProgram.matches({"all":[fact("self_hp","lt",0.5),{"not":fact("skill_ready","eq",false)}]},{"self_hp":0.3,"skill_ready":true}),"all not")
 check(UnitTacticProgram.matches({"any":[fact("self_hp","gt",0.5),fact("self_hp","lte",0.3)]},{"self_hp":0.3}),"any")
 for invalid: Dictionary in [{"damage":999},{"movement":"teleport"},{"retreat_hp":-0.1},{"retreat_hp":1.0},{"skill_cond":"new_skill"},{"lane_mode":"hacked"},{"priority":"invalid"},{"movement":"align_with_crystal"}]:
  var bad: Dictionary = program.duplicate(true)
  bad["rules"][0]["actions"] = invalid
  check(not UnitTacticProgram.validate(bad)["ok"],"reject "+str(invalid))
 check(not UnitTacticProgram.parse("{broken","triangle")["ok"],"invalid JSON")
 check(not UnitTacticProgram.validate({"version":2})["ok"],"version")
 check(not UnitTacticProgram.validate(program,"square")["ok"],"unit mismatch")
 var hex: Dictionary = UnitTacticProgram.default_program("hexagon")
 hex["base"]["priority"] = "closest"
 check(not UnitTacticProgram.validate(hex)["ok"],"hex no basic attack")
 var bad: Dictionary = program.duplicate(true)
 bad["execute"] = "script"
 check(not UnitTacticProgram.validate(bad)["ok"],"root unknown field")
 bad = program.duplicate(true)
 bad["rules"] = []
 for i: int in range(13): bad["rules"].append({"id":str(i),"when":fact("self_hp","lt",0.5),"actions":{"behavior":"hold"}})
 check(not UnitTacticProgram.validate(bad)["ok"],"rule cap")
 bad = program.duplicate(true)
 var deep: Dictionary = fact("self_hp","lt",0.5)
 for i: int in range(4): deep = {"not":deep}
 bad["rules"][0]["when"] = deep
 check(not UnitTacticProgram.validate(bad)["ok"],"depth cap")
 bad = program.duplicate(true)
 var children: Array = []
 for i: int in range(32): children.append(fact("self_hp","lt",0.5))
 bad["rules"][0]["when"] = {"all":children}
 check(not UnitTacticProgram.validate(bad)["ok"],"node cap")
 for condition: Dictionary in [fact("nearby_allies","eq",1.5),fact("skill_ready","lt",true),fact("target_type","eq","robot"),fact("target_distance","gt",3001),fact("self_hp","eq",-0.1),{"all":[]}]:
  bad = program.duplicate(true)
  bad["rules"][0]["when"] = condition
  check(not UnitTacticProgram.validate(bad)["ok"],"reject condition "+str(condition))
 var profile: Dictionary = UnitTacticProgram.apply_to_profile(TacticalBrain.get_default_profile(),program)
 check(profile["unit_rules"]["square"] == TacticalBrain.get_default_profile()["unit_rules"]["square"],"unit isolated merge")
 check(TacticalBrain.save_opening_program(program)["ok"],"save opening program")
 TacticalBrain.begin_match_profiles()
 check(TacticalBrain.team_profiles[0]["unit_rules"]["triangle"].has("program"),"match uses program")
 TacticalBrain.compile_prompt_to_profile(0,"均衡")
 check(not TacticalBrain.team_profiles[0]["unit_rules"]["triangle"].has("program"),"keyword replaces team")
 check(TacticalBrain.opening_profile["unit_rules"]["triangle"].has("program"),"keyword does not modify opening")
 LaboratoryStore.accept_program("triangle",program,"mock-model")
 var valid_saved: Dictionary = LaboratoryStore.records["triangle"]["program"].duplicate(true)
 check(not LaboratoryStore.accept_program("triangle",{"version":9},"bad")["ok"] and LaboratoryStore.records["triangle"]["program"] == valid_saved,"invalid keeps valid")
 LaboratoryStore.applied_programs["triangle"] = program
 var formal: MainArena = MainArena.new()
 formal.ai_enabled = false
 add_child(formal)
 await get_tree().physics_frame
 check(formal.hud.get("matrix_compiled"),"matrix compiled source")
 check(String(formal.hud.get("matrix_preview").text).contains("low_hp"),"matrix displays actual JSON")
 formal.hud.call("apply_matrix")
 check(formal.profile_for(0)["unit_rules"]["triangle"].has("program"),"matrix preserves AI")
 formal.phase = MainArena.Phase.PREPARING
 var formal_unit: BaseGeoUnit = formal.units_for(0).filter(func(u: BaseGeoUnit) -> bool: return u.unit_type == "triangle")[0]
 formal_unit.current_hp = formal_unit.max_hp*0.2
 formal_unit.decide_tactic()
 check(formal_unit.matched_rule == "low_hp","formal rule applied")
 for map_id: String in MapCatalog.IDS:
  var arena: LaboratoryArena = LaboratoryArena.new()
  arena.map_id = map_id
  arena.layout = [LaboratoryPresets.unit("triangle",0,1000,400,0.2),LaboratoryPresets.unit("square",1,1400,400)]
  add_child(arena)
  await get_tree().physics_frame
  var blue: BaseGeoUnit = arena.units_for(0)[0]
  blue.decide_tactic()
  check(blue.matched_rule == formal_unit.matched_rule and blue.rule == formal_unit.rule,"same rule formal/sandbox "+map_id)
  check(arena.profile_for(1) == TacticalBrain.get_default_profile(),"red defaults "+map_id)
  check(not arena.valid_point("triangle",Vector2(1200,140)).is_empty(),"crystal placement "+map_id)
  check(not arena.valid_point("triangle",Vector2(220,675)).is_empty(),"base placement "+map_id)
  var flux: float = formal.flux[0]
  arena.start()
  blue.take_damage(9999)
  check(is_equal_approx(float(arena.totals[1]["damage"]),26.0),"actual overkill accounting "+map_id)
  await get_tree().physics_frame
  await get_tree().physics_frame
  check(arena.state == LaboratoryArena.State.ENDED,"unit wipe ends "+map_id)
  check(formal.flux[0] == flux,"sandbox economy isolated "+map_id)
  arena.queue_free()
  await get_tree().process_frame
 formal.queue_free()
 await get_tree().process_frame
 var duel: LaboratoryArena = LaboratoryArena.new()
 duel.layout = [LaboratoryPresets.unit("square",0,1000,400),LaboratoryPresets.unit("square",1,1400,400)]
 add_child(duel)
 await get_tree().physics_frame
 duel.start()
 duel.toggle_pause()
 var elapsed: float = duel.elapsed
 var position: Vector2 = duel.units_for(0)[0].position
 for i: int in range(20): await get_tree().physics_frame
 check(duel.elapsed == elapsed and duel.units_for(0)[0].position == position,"pause freezes units timer")
 duel.toggle_pause()
 duel.elapsed = 120
 await get_tree().physics_frame
 await get_tree().physics_frame
 check(duel.state == LaboratoryArena.State.ENDED,"timeout ends")
 duel.queue_free()
 await get_tree().process_frame
 # Same initial layout and seed produce matching autonomous simulation.
 for map_id: String in MapCatalog.IDS:
  var snapshots: Array[Array] = []
  for run_index: int in range(2):
   var replay: LaboratoryArena = LaboratoryArena.new()
   replay.map_id = map_id
   replay.layout = LaboratoryPresets.create(1)
   replay.seed_value = 7401
   add_child(replay)
   await get_tree().physics_frame
   replay.start()
   for frame: int in range(90): await get_tree().physics_frame
   var snapshot: Array = []
   for unit: BaseGeoUnit in replay.local_units: snapshot.append([unit.position.snapped(Vector2.ONE*0.01),unit.current_hp,unit.skill_left])
   snapshots.append(snapshot)
   replay.queue_free()
   await get_tree().process_frame
  check(snapshots[0] == snapshots[1],"deterministic replay "+map_id)
 # HTTP mock tests run only when local fixture is explicitly requested.
 if "--http-mock" in OS.get_cmdline_user_args(): await http_tests()
 check(LLMService.normalize_url("https://example.com/v1/chat/completions/")["url"] == "https://example.com/v1","normalize complete endpoint")
 check(not LLMService.normalize_url("https://key@example.com/v1")["ok"],"URL credentials rejected")
 var old_connection: String = LLMService.config_path
 LLMService.config_path = "user://missing-parent/connection.cfg"
 check(not LLMService.save_connection() and LLMService.dirty and LLMService.status.contains("未保存"),"connection save failure visible")
 LLMService.config_path = old_connection
 check(LLMService.save_connection() and not LLMService.dirty and not LLMService.status.contains("未保存"),"connection save retry")
 var old_path: String = LaboratoryStore.path
 LaboratoryStore.path = "user://missing-parent/lab.json"
 check(not LaboratoryStore.save() and LaboratoryStore.dirty and LaboratoryStore.status.contains("未保存"),"save failure visible")
 LaboratoryStore.path = old_path
 LaboratoryStore.records = saved
 LaboratoryStore.applied_programs.clear()
 LaboratoryStore.save()
 TacticalBrain.opening_profile = opening
 TacticalBrain.opening_prompt = prompt
 TacticalBrain.reset_profiles()

func response(owner: int, _purpose: String, result: Dictionary) -> void:
 received.append({"owner":owner,"result":result})

func request(purpose: String, model_id: String = "good") -> Dictionary:
 received.clear()
 LLMService.configure("http://127.0.0.1:18741/v1","test-memory-only-key",model_id)
 var launched: Dictionary = LLMService.start(9001,purpose,"低生命时撤退","triangle")
 check(launched["ok"],"request launched "+purpose+model_id)
 for i: int in range(500):
  if not received.is_empty(): return received[0]["result"]
  await get_tree().create_timer(0.01,true,false,true).timeout
 return {"ok":false,"message":"fixture wait exceeded","category":"timeout"}

func http_tests() -> void:
 LLMService.completed.connect(response)
 var result: Dictionary = await request("models")
 check(result["ok"] and "good" in result["models"],"GET models")
 received.clear()
 LLMService.configure("http://127.0.0.1:18741/no-models","","manual-model")
 LLMService.start(9001,"models")
 for i: int in range(100):
  if not received.is_empty(): break
  await get_tree().create_timer(0.01,true,false,true).timeout
 check(not received.is_empty() and not received[0]["result"]["ok"],"model list unavailable distinct")
 received.clear()
 LLMService.start(9001,"test")
 for i: int in range(100):
  if not received.is_empty(): break
  await get_tree().create_timer(0.01,true,false,true).timeout
 check(not received.is_empty() and received[0]["result"]["ok"],"manual model works when list unavailable")
 result = await request("test","manual-model")
 check(result["ok"],"manual model works")
 result = await request("generate")
 check(result["ok"] and result["program"]["unit_type"] == "triangle","AI valid program")
 for model_id: String in ["auth","missing","invalid","bad-json","redirect","oversize"]:
  result = await request("generate",model_id)
  check(not result["ok"],"reject mock "+model_id)
 received.clear()
 LLMService.configure("http://127.0.0.1:18741/v1","test-memory-only-key","slow")
 LLMService.start(9001,"test")
 LLMService.cancel_owner(9001)
 for i: int in range(15): await get_tree().create_timer(0.01,true,false,true).timeout
 check(received.is_empty() and LLMService.requests.is_empty(),"cancellation no callback")
 LLMService.start(9001,"test")
 LLMService.configure("http://127.0.0.1:18741/v1","changed-memory-only-key","good")
 for i: int in range(30): await get_tree().create_timer(0.01,true,false,true).timeout
 check(received.is_empty(),"configuration rejects stale callback")
 LLMService.configure("http://127.0.0.1:18741/v1","test-memory-only-key","slow")
 received.clear()
 LLMService.start(9001,"test")
 LLMService.configure("invalid-url","test-memory-only-key","slow")
 for i: int in range(30): await get_tree().create_timer(0.01,true,false,true).timeout
 check(received.is_empty() and LLMService.requests.is_empty(),"invalid URL also cancels stale request")
 var config_text: String = FileAccess.get_file_as_string(LLMService.config_path)
 var lab_text: String = FileAccess.get_file_as_string(LaboratoryStore.path)
 check(not config_text.contains("memory-only-key") and not lab_text.contains("memory-only-key"),"key never persisted")
 LLMService.request_timeout = 0.1
 result = await request("test","slow")
 check(not result["ok"] and result["category"] == "timeout","timeout reported")
 LLMService.request_timeout = 30
 LLMService.configure("https://api.openai.com/v1","","")
