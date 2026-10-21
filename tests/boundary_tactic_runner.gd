extends Node

const ORIGINAL: String = "开局就向左或右边移动，绕过障碍物后，沿着边界向前移动，使用技能加快运动速度，快速推进到敌方单位后方，在技能范围内，使用技能攻击敌方单位，以消灭菱形为主要目标。"
const MODEL: String = "deepseek-ai/DeepSeek-V4.1-Flash"
var passed: int = 0
var failed: int = 0
var response: Dictionary = {}
var requests: Array[Dictionary] = []
var outcomes: Array[Dictionary] = []
var program: Dictionary = {}
var replay: bool = false
var program_source: int = 1

func check(ok: bool, title: String) -> void:
 if ok: passed += 1
 else:
  failed += 1
  push_error("BOUNDARY_FAIL "+title)
 print(("PASS " if ok else "FAIL ")+title)

func _ready() -> void:
 replay = "--replay" in OS.get_cmdline_user_args()
 await run()
 LLMService.cancel_all()
 LLMService.api_key = ""
 var output: FileAccess = FileAccess.open("res://artifacts/boundary-"+("replay" if replay else "real")+"-report.json",FileAccess.WRITE)
 output.store_string(JSON.stringify({"prompt":ORIGINAL,"model":MODEL,"mode":"replay" if replay else "real_provider","passed":passed,"failed":failed,"requests":requests,"outcomes":outcomes},"  "))
 print("BOUNDARY_RESULT passed=%d failed=%d" % [passed,failed])
 get_tree().quit(0 if failed == 0 else 1)

func run() -> void:
 if replay:
  var checked: Dictionary = UnitTacticProgram.parse(FileAccess.get_file_as_string("res://artifacts/boundary-generated-1.json"),"triangle")
  check(checked["ok"],"saved real original prompt JSON valid")
  if not checked["ok"]: return
  program = checked["program"]
 else:
  var key: String = OS.get_environment("GEO_LLM_TEST_KEY")
  OS.unset_environment("GEO_LLM_TEST_KEY")
  if key.is_empty():
   check(false,"in-memory credential required")
   return
  LLMService.config_path = "user://test_boundary_connection.cfg"
  LLMService.configure("https://api.siliconflow.cn/v1/chat/completions",key,MODEL)
  key = ""
  LLMService.completed.connect(func(owner_id: int, _purpose: String, result: Dictionary) -> void:
   if owner_id == get_instance_id(): response = result)
  for attempt: int in range(3):
   response = {}
   var started: Dictionary = LLMService.start(get_instance_id(),"generate",ORIGINAL,"triangle")
   check(started["ok"],"request original prompt %d" % (attempt+1))
   if not started["ok"]: continue
   var start_time: int = Time.get_ticks_msec()
   while response.is_empty() and Time.get_ticks_msec()-start_time < 35000: await get_tree().process_frame
   if response.is_empty(): response = {"ok":false,"message":"test wait exceeded"}
   var safe: Dictionary = response.duplicate(true)
   safe.erase("program")
   requests.append(safe)
   check(response["ok"],"original prompt real valid JSON %d" % (attempt+1))
   if not response["ok"]: continue
   program = response["program"]
   var file: FileAccess = FileAccess.open("res://artifacts/boundary-generated-%d.json" % (attempt+1),FileAccess.WRITE)
   file.store_string(JSON.stringify(program,"  "))
   semantic_checks(program,"generation %d" % (attempt+1))
 if program.is_empty(): return
 if replay: semantic_checks(program,"replay")
 await schema_and_safety()
 if "--generate-only" in OS.get_cmdline_user_args(): return
 await dash_guard_tests()
 await base_attack_test()
 LaboratoryStore.applied_programs["triangle"] = program.duplicate(true)
 for map_id: String in MapCatalog.IDS:
  program_source = MapCatalog.IDS.find(map_id)+1
  var checked: Dictionary = UnitTacticProgram.parse(FileAccess.get_file_as_string("res://artifacts/boundary-generated-%d.json" % program_source),"triangle")
  check(checked["ok"],"runtime uses untouched real generation %d" % program_source)
  if not checked["ok"]: continue
  program = checked["program"]
  for team: int in range(2):
   for side_index: int in range(2): await maneuver(map_id,team,side_index)
 for team: int in range(2): await maneuver("balanced",team,0,180)
 for team: int in range(2): await maneuver("balanced",team,0,0,880,350)
 await formal_consistency()

func semantic_checks(value: Dictionary, label: String) -> void:
 var rule: Dictionary = UnitTacticProgram.evaluate(value,{"self_hp":1.0,"skill_ready":true,"target_distance":1400.0,"target_type":"diamond","target_visible":true,"nearby_enemies":0,"nearby_allies":0,"target_cluster":1})["rule"]
 check(rule["movement"] == "boundary_infiltrate","complete boundary maneuver "+label)
 check(rule["priority"] == "diamond_first","exact diamond priority "+label)
 check(rule["skill_cond"] == "travel_and_backstab" and rule["skill_usage"] != "hold","travel and attack share real dash "+label)
 check(rule["behavior"] == "normal","not frozen or retreating "+label)

func schema_and_safety() -> void:
 for kind: String in ["square","circle","diamond","hexagon"]:
  var invalid: Dictionary = UnitTacticProgram.default_program(kind)
  invalid["base"]["movement"] = "boundary_infiltrate"
  check(not UnitTacticProgram.validate(invalid)["ok"],"only triangle may select boundary movement "+kind)
  invalid = UnitTacticProgram.default_program(kind)
  invalid["base"]["skill_cond"] = "travel_and_backstab"
  check(not UnitTacticProgram.validate(invalid)["ok"],"only triangle may travel dash "+kind)
 # Known-provider optimization must not leak to arbitrary compatible services.
 var old_url: String = LLMService.base_url
 var old_model: String = LLMService.model
 LLMService.base_url = "https://api.siliconflow.cn/v1"
 LLMService.model = MODEL
 var payload: Dictionary = LLMService.request_payload("generate",ORIGINAL,"triangle")
 check(payload.get("enable_thinking") == false and payload.get("response_format") == {"type":"json_object"},"verified provider non-thinking JSON payload")
 LLMService.base_url = "https://example.com/v1"
 payload = LLMService.request_payload("generate",ORIGINAL,"triangle")
 check(not payload.has("enable_thinking") and not payload.has("response_format"),"generic provider unchanged")
 LLMService.base_url = "https://api.siliconflow.cn/v1"
 LLMService.model = "unknown-model"
 check(LLMService.provider_profile() == "compatible","unknown models keep generic protocol")
 LLMService.base_url = old_url
 LLMService.model = old_model

func maneuver(map_id: String, team: int, serial: int, facing_angle: float = 0.0, enemy_forward_x: float = 1650.0, enemy_y: float = 675.0) -> void:
 var viewport: SubViewport = SubViewport.new()
 viewport.world_2d = World2D.new()
 add_child(viewport)
 var arena: LaboratoryArena = LaboratoryArena.new()
 arena.map_id = map_id
 # The inner deployment column lies directly behind the L cover, forcing the
 # route to go around it before reaching the boundary.
 var spawn_x: float = (560 if serial == 0 else 390) if team == 0 else (1840 if serial == 0 else 2010)
 var enemy_x: float = enemy_forward_x if team == 0 else 2400.0-enemy_forward_x
 var target_y: float = enemy_y if team == 0 else 1350.0-enemy_y
 arena.layout = [LaboratoryPresets.unit("triangle",team,spawn_x,675),LaboratoryPresets.unit("diamond",1-team,enemy_x,target_y,1.0,facing_angle),LaboratoryPresets.unit("square",1-team,spawn_x+(160 if team==0 else -160),675)]
 viewport.add_child(arena)
 var profiles: Array[Dictionary] = [UnitTacticProgram.apply_to_profile(TacticalBrain.get_default_profile(),program),UnitTacticProgram.apply_to_profile(TacticalBrain.get_default_profile(),program)]
 arena.local_profiles = profiles
 var unit: BaseGeoUnit = arena.units_for(team)[0]
 unit.spawn_index = serial
 unit._profile_updated(team,profiles[team])
 for enemy: BaseGeoUnit in arena.units_for(1-team):
  enemy.scripted_control = true
  enemy.attack_left = 999
  enemy.skill_left = 999
 var victim: BaseGeoUnit = arena.units_for(1-team).filter(func(u: BaseGeoUnit) -> bool: return u.unit_type == "diamond")[0]
 var victim_ref: WeakRef = weakref(victim)
 var victim_id: int = victim.get_instance_id()
 var skills: Array[Dictionary] = []
 var hits: Array[Dictionary] = []
 var raw_hits: Array[Dictionary] = []
 var samples: Array[Dictionary] = []
 arena.skill_reported.connect(func(source: BaseGeoUnit) -> void:
  if source == unit: skills.append({"time":arena.elapsed,"purpose":str(unit.get("dash_purpose")),"pos":str(unit.position),"phase":unit.boundary_maneuver.phase,"cooldown":unit.skill_left}))
 arena.actual_damage_reported.connect(func(target: BaseGeoUnit, amount: float, attacker: Node2D) -> void:
  if attacker == unit: hits.append({"target":target.unit_type,"id":target.get_instance_id(),"amount":amount,"purpose":str(unit.get("dash_purpose"))}))
 arena.damage_reported.connect(func(target: BaseGeoUnit, amount: float, attacker: Node2D) -> void:
  if attacker == unit: raw_hits.append({"target":target.unit_type,"id":target.get_instance_id(),"amount":amount}))
 await get_tree().physics_frame
 unit.decide_tactic()
 var label: String = "%s team=%d side=%d angle=%.0f target_x=%.0f" % [map_id,team,serial,facing_angle,enemy_forward_x]
 check(unit.current_target == victim,"diamond selected over nearer square "+label)
 arena.start()
 var touched_edge: bool = false
 var advanced_on_edge: bool = false
 var stayed_in_bounds: bool = true
 var phases: Array[String] = []
 for frame: int in range(2400):
  await get_tree().physics_frame
  if unit.dead: break
  var phase: String = unit.boundary_maneuver.phase
  if phase not in phases: phases.append(phase)
  if unit.position.y <110 or unit.position.y >1240: touched_edge = true
  if touched_edge and absf(unit.position.x-spawn_x)>minf(700.0,absf(enemy_x-spawn_x)*0.6) and (unit.position.y<115 or unit.position.y>1235): advanced_on_edge = true
  if not Rect2(14,14,2372,1322).has_point(unit.position): stayed_in_bounds = false
  if frame%30 == 0: samples.append({"time":arena.elapsed,"pos":str(unit.position),"phase":phase})
  if not is_instance_valid(victim_ref.get_ref()) or (victim_ref.get_ref() as BaseGeoUnit).dead: break
 var killed: bool = not is_instance_valid(victim_ref.get_ref()) or (victim_ref.get_ref() as BaseGeoUnit).dead
 check(touched_edge and advanced_on_edge,"exit then advance along edge "+label)
 check(not skills.filter(func(s: Dictionary) -> bool: return s["purpose"] == "travel").is_empty(),"real travel dash "+label)
 check(not hits.filter(func(h: Dictionary) -> bool: return h["id"] == victim_id and h["purpose"] == "backstab").is_empty(),"real rear skill hits selected diamond "+label)
 check(killed,"diamond eliminated "+label)
 check(not raw_hits.filter(func(h: Dictionary) -> bool: return h["id"] == victim_id and is_equal_approx(float(h["amount"]),110.0)).is_empty(),"actual 110 backstab damage "+label)
 check(stayed_in_bounds,"physics stays inside map "+label)
 var valid_cooldown: bool = true
 for i: int in range(1,skills.size()):
  if float(skills[i]["time"])-float(skills[i-1]["time"])<4.45: valid_cooldown = false
 check(valid_cooldown,"formal cooldown retained "+label)
 outcomes.append({"map":map_id,"team":team,"side":serial,"facing_angle":facing_angle,"target_x":enemy_forward_x,"program_source":program_source,"skills":skills,"hits":hits,"raw_hits":raw_hits,"samples":samples,"phases":phases,"killed":killed})
 viewport.queue_free()
 await get_tree().process_frame

func dash_guard_tests() -> void:
 for blocker: String in ["wall","enemy_shield","friendly_shield","none"]:
  var viewport: SubViewport = SubViewport.new()
  viewport.world_2d = World2D.new()
  add_child(viewport)
  var arena: LaboratoryArena = LaboratoryArena.new()
  arena.layout = [LaboratoryPresets.unit("triangle",0,1010,350),LaboratoryPresets.unit("diamond",1,1200,350,1,180)]
  viewport.add_child(arena)
  var unit: BaseGeoUnit = arena.units_for(0)[0]
  var victim: BaseGeoUnit = arena.units_for(1)[0]
  victim.scripted_control = true
  unit.base_rule = program["base"].duplicate(true)
  unit.rule = unit.base_rule.duplicate(true)
  unit.current_target = victim
  unit.boundary_maneuver.phase = "rear"
  unit.decision_left = 999
  unit.skill_left = 0
  unit.attack_left = 999
  if blocker == "wall":
   var wall: TerrainWall = TerrainWall.new()
   wall.position = Vector2(1100,350)
   wall.polygon = PackedVector2Array([Vector2(-10,-80),Vector2(10,-80),Vector2(10,80),Vector2(-10,80)])
   arena.add_child(wall)
  elif blocker.ends_with("shield"):
   var shield: PrismBarrier = PrismBarrier.new()
   shield.arena = arena
   shield.team = 1 if blocker == "enemy_shield" else 0
   shield.position = Vector2(1100,350)
   shield.life = 100
   arena.add_child(shield)
  for i: int in range(3): await get_tree().physics_frame
  arena.start()
  unit.stun_left = 1
  check(not unit.try_cast_skill() and unit.skill_left == 0,"EMP prevents maneuver dash "+blocker)
  unit.stun_left = 0
  unit.rule["behavior"] = "hold"
  check(not unit.try_cast_skill(),"hold prevents travel and attack dash "+blocker)
  unit.rule["behavior"] = "retreat"
  check(not unit.try_cast_skill(),"retreat never dashes forward "+blocker)
  unit.rule["behavior"] = "normal"
  var victim_ref: WeakRef = weakref(victim)
  check(unit.try_cast_skill() and unit.skill_left == unit.skill_cd,"same real skill consumes formal cooldown "+blocker)
  check(not unit.try_cast_skill(),"active charge cannot be queued "+blocker)
  unit.rule["behavior"] = "hold"
  for i: int in range(65): await get_tree().physics_frame
  var dead: bool = not is_instance_valid(victim_ref.get_ref()) or (victim_ref.get_ref() as BaseGeoUnit).dead
  if blocker in ["wall","enemy_shield"]:
   check(not dead and unit.position.x <1090 and (victim_ref.get_ref() as BaseGeoUnit).current_hp ==105,"real collision stops new attack mode "+blocker)
  else:
   check(dead,"new attack passes friendly shields and hits once "+blocker)
  viewport.queue_free()
  await get_tree().process_frame

func formal_consistency() -> void:
 check(TacticalBrain.save_opening_program(program)["ok"],"install original prompt as opening")
 var arena: MainArena = MainArena.new()
 arena.ai_enabled = false
 add_child(arena)
 await get_tree().physics_frame
 var unit: BaseGeoUnit = arena.units_for(0).filter(func(u: BaseGeoUnit) -> bool: return u.unit_type == "triangle")[0]
 unit.decide_tactic()
 check(unit.rule["movement"] == "boundary_infiltrate" and unit.rule["priority"] == "diamond_first" and unit.rule["skill_cond"] == "travel_and_backstab","formal match uses same generated maneuver")
 check(arena.hud.matrix_preview.text.contains("boundary_infiltrate"),"preparation matrix preserves original AI program")
 arena.queue_free()
 await get_tree().process_frame

func base_attack_test() -> void:
 var viewport: SubViewport = SubViewport.new()
 viewport.world_2d = World2D.new()
 add_child(viewport)
 var arena: LaboratoryArena = LaboratoryArena.new()
 arena.layout = [LaboratoryPresets.unit("triangle",0,2000,675),LaboratoryPresets.unit("square",1,2200,200)]
 viewport.add_child(arena)
 var unit: BaseGeoUnit = arena.units_for(0)[0]
 arena.units_for(1)[0].scripted_control = true
 unit.rule = program["base"].duplicate(true)
 unit.base_rule = unit.rule.duplicate(true)
 unit.current_target = arena.base_for(1)
 unit.boundary_maneuver.phase = "rear"
 unit.decision_left = 999
 var hp: float = arena.base_for(1).current_hp
 arena.start()
 for i: int in range(180): await get_tree().physics_frame
 check(arena.base_for(1).current_hp <hp,"after infiltrating, no unit target still permits real base attacks")
 viewport.queue_free()
 await get_tree().process_frame
