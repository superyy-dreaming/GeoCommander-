extends Node

var passed: int = 0
var failed: int = 0
var arena: LaboratoryArena
var unit: BaseGeoUnit
var enemy: BaseGeoUnit
var baseline: Dictionary

func check(ok: bool, title: String) -> void:
 if ok: passed+=1
 else:
  failed+=1
  push_error("PLAN_FAIL "+title)
 print(("PASS " if ok else "FAIL ")+title)

func frames(count: int) -> void:
 for i: int in range(count): await get_tree().physics_frame

func program(kind: String, steps: Array, interrupts: Array = []) -> Dictionary:
 var value: Dictionary = TacticPlan.default_program(kind)
 value["plan"]["steps"] = steps
 value["plan"]["entry"] = steps[0]["id"]
 value["plan"]["interrupts"] = interrupts
 return value

func fixture(kind: String = "triangle", pos: Vector2 = Vector2(400,200), victim: Vector2 = Vector2(2000,900), map_id: String = "balanced") -> void:
 if is_instance_valid(arena):
  arena.shutdown()
  arena.queue_free()
  await get_tree().process_frame
 LaboratoryStore.applied_programs.clear()
 arena = LaboratoryArena.new()
 arena.map_id = map_id
 arena.layout = [{"kind":kind,"team":0,"x":pos.x,"y":pos.y,"hp":1.0,"angle":0.0},{"kind":"diamond","team":1,"x":victim.x,"y":victim.y,"hp":1.0,"angle":180.0}]
 add_child(arena)
 unit = arena.units_for(0)[0]
 enemy = arena.units_for(1)[0]
 unit.scripted_control = true
 enemy.scripted_control = true
 arena.start()
 await frames(2)

func install(value: Dictionary) -> void:
 unit.scripted_control = false
 var profile: Dictionary = UnitTacticProgram.apply_to_profile(arena.profile_for(0),value)
 arena.local_profiles[0] = profile
 unit._profile_updated(0,profile)
 unit.velocity = Vector2.ZERO

func _ready() -> void:
 if "--export-examples" in OS.get_cmdline_user_args():
  DirAccess.make_dir_recursive_absolute("res://tests/fixtures")
  for kind: String in UnitCatalog.TYPES:
   var sample: FileAccess=FileAccess.open("res://tests/fixtures/tactic-v2-"+kind+".json",FileAccess.WRITE)
   sample.store_string(JSON.stringify(TacticExamples.for_unit(kind),"  "))
 baseline = LaboratoryStore.applied_programs.duplicate(true)
 await run()
 LaboratoryStore.applied_programs = baseline
 if is_instance_valid(arena): arena.queue_free()
 var file: FileAccess = FileAccess.open("res://artifacts/tactic-v2-rules.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
 print("PLAN_RESULT passed=%d failed=%d" % [passed,failed])
 get_tree().quit(0 if failed==0 else 1)

func run() -> void:
 for kind: String in UnitCatalog.TYPES:
  check(UnitTacticProgram.validate(TacticPlan.default_program(kind))["ok"],"default v2 "+kind)
  check(UnitTacticProgram.validate(UnitTacticProgram.default_program(kind))["ok"],"legacy v1 "+kind)
 var invalid: Dictionary = TacticPlan.default_program("triangle")
 invalid["plan"]["steps"][0]["next"] = "missing"
 check(not UnitTacticProgram.validate(invalid)["ok"],"missing transition rejected")
 invalid = TacticPlan.default_program("hexagon")
 invalid["plan"]["steps"][0]["attack"] = true
 check(not UnitTacticProgram.validate(invalid)["ok"],"hex no basic attack")
 invalid = TacticPlan.default_program("square")
 invalid["plan"]["steps"][0]["skill"] = "travel"
 check(not UnitTacticProgram.validate(invalid)["ok"],"square no travel dash")
 invalid = program("triangle",[{"id":"go","action":"move_to","goal":{"anchor":"point","point":[540,675]}}])
 check(not UnitTacticProgram.validate(invalid)["ok"],"hand waypoint requires map binding")
 invalid["plan"]["map_id"] = "balanced"
 check(not UnitTacticProgram.validate(invalid)["ok"],"point inside wall rejected")
 invalid["plan"]["steps"][0]["goal"]["point"] = [400,200]
 check(UnitTacticProgram.validate(invalid)["ok"],"legal point accepted")
 check(not TacticPlan.map_validation(invalid,"flanks").is_empty(),"map mismatch rejected")
 await fixture()
 var value: Dictionary = program("triangle",[{"id":"go","action":"move_direction","direction":"up","seconds":2.0,"timeout":3.0}])
 install(value)
 var start: Vector2 = unit.position
 await frames(61)
 check(unit.execution.current == "go" and unit.execution.status=="运行","step retains state past decision interval")
 var clock: float = unit.execution.state["time"]
 arena.toggle_pause()
 var paused_position: Vector2 = unit.position
 await frames(20)
 check(is_equal_approx(clock,unit.execution.state["time"]) and unit.position.is_equal_approx(paused_position),"pause freezes clocks and movement")
 arena.step_frame()
 await frames(3)
 check(absf(float(unit.execution.state["time"])-clock-1.0/60)<0.001,"debug single physical frame")
 arena.toggle_pause()
 await frames(64)
 check(unit.execution.status == "完成待命","direction duration completes")
 check(absf(unit.position.x-start.x)<1,"direction never steers sideways")
 check(unit.position.y >= unit.unit_radius-1,"direction collides with boundary")
 check(unit.attack_serial==0 and unit.skill_serial==0,"plan disables unrequested attacks and skills")
 await fixture()
 value = program("triangle",[{"id":"go","action":"move_direction","direction":"right","seconds":2.0,"timeout":4.0}])
 install(value)
 await frames(20)
 clock = unit.execution.state["time"]
 unit.apply_emp(0.5)
 await frames(20)
 check(is_equal_approx(clock,unit.execution.state["time"]),"stun freezes action clock")
 await frames(120)
 check(unit.execution.status=="完成待命","resumes after stun")
 await fixture()
 value = program("triangle",[{"id":"go","action":"wait","seconds":3.0,"timeout":5.0},{"id":"escape","action":"wait","seconds":0.2,"next":"return"}],[{"id":"low","when":{"fact":"self_hp","op":"lt","value":0.3},"goto":"escape"}])
 install(value)
 await frames(15)
 clock = unit.execution.state["time"]
 unit.current_hp = 20
 await frames(10)
 check(unit.execution.current=="escape","priority interrupt fires")
 await frames(15)
 check(unit.execution.current=="go" and float(unit.execution.state["time"])<clock+0.4,"interrupt restores remaining step clock")
 await frames(30)
 check(unit.execution.visits.get("escape",0)==1,"interrupt does not retrigger while condition remains")
 unit.current_hp = 130
 await frames(12)
 unit.current_hp = 20
 await frames(12)
 check(unit.execution.visits.get("escape",0)==2,"interrupt rearms after condition clears")
 await fixture()
 value = program("triangle",[{"id":"a","action":"wait","seconds":0.01,"next":"b"},{"id":"b","action":"wait","seconds":0.01,"next":"a"}])
 install(value)
 await frames(10)
 check(unit.execution.transition_serial<=11 and unit.execution.visits.size()==2,"cyclic graph bounded to one transition per frame")
 await fixture()
 value = program("triangle",[{"id":"wait","action":"wait","when":{"fact":"match_time","op":"gte","value":arena.elapsed+0.5},"timeout":1.0}])
 install(value)
 await frames(35)
 check(unit.execution.status=="完成待命","absolute match time condition")
 await fixture()
 value = program("triangle",[{"id":"wait","action":"wait","when":{"fact":"skill_ready","op":"eq","value":true},"timeout":0.1}])
 unit.skill_left = 5
 install(value)
 await frames(10)
 check(unit.execution.status=="受阻停止" and "超时" in unit.execution.reason,"timeout stops with reason")
 for map_id: String in MapCatalog.IDS:
  await fixture("triangle",Vector2(800,130),Vector2(2000,130),map_id)
  var cover: Dictionary = CoverPlanner.find(unit,enemy)
  check(cover["ok"],"reachable cover "+map_id)
  if cover["ok"]: check(CoverPlanner.hidden(unit,cover["point"],enemy),"wall blocks body rays "+map_id)
  value = program("triangle",[{"id":"route","action":"move_to","goal":{"anchor":"enemy_base"},"timeout":30.0}])
  install(value)
  await frames(180)
  check(unit.position.x>850 and unit.position.distance_to(enemy.position)>0,"routed movement advances "+map_id)
 await fixture("triangle",Vector2(400,200),Vector2(650,200))
 unit.skill_left = 0
 enemy.max_hp = 220
 enemy.current_hp = 220
 enemy.visual_root.rotation = 0
 value = program("triangle",[{"id":"dash","action":"cast_skill","target":"diamond","skill_request":{"aim":"target","purpose":"backstab"},"timeout":2.0}])
 install(value)
 await frames(45)
 check(unit.skill_serial==1 and unit.skill_complete_serial==1,"dash waits actual windup and completion")
 check(enemy.current_hp==110,"real 110 backstab damage")
 await fixture("triangle",Vector2(400,130),Vector2(1200,800))
 unit.skill_left = 0
 value = program("triangle",[{"id":"dash","action":"cast_skill","skill_request":{"aim":"direction","direction":"right","purpose":"travel"}}])
 install(value)
 await frames(45)
 check(unit.position.x>650 and unit.skill_complete_serial==1,"directional travel shares real dash")
 await fixture("triangle",Vector2(400,675),Vector2(1400,520))
 unit.skill_left = 0
 var cd: float = unit.skill_left
 var rejected: Dictionary = SkillRequest.attempt(unit,{"aim":"direction","direction":"right","purpose":"travel"})
 check(not rejected["ok"] and unit.skill_left==cd,"unsafe dash rejected without cooldown")
 await fixture("square",Vector2(400,200),Vector2(1400,800))
 unit.skill_left = 0
 var cast: Dictionary = SkillRequest.attempt(unit,{"aim":"direction","direction":"down","purpose":"support"})
 check(cast["ok"] and unit.skill_complete_serial==1,"square immediate shield lifecycle")
 check(arena.reflectors[-1] is PrismBarrier and absf(arena.reflectors[-1].rotation-PI/2)<0.01,"shield uses requested orientation")
 await fixture("diamond",Vector2(400,200),Vector2(700,200))
 unit.skill_left = 0
 value = program("diamond",[{"id":"laser","action":"cast_skill","skill_request":{"aim":"direction","direction":"right"},"timeout":2.0}])
 install(value)
 await frames(10)
 check(unit.skill_active and unit.execution.status=="运行","laser windup remains active")
 unit.apply_emp(0.25)
 await frames(30)
 check(unit.skill_interrupted_serial==1 and unit.execution.status=="受阻停止","EMP interrupts skill and plan reports failure")
 await fixture("diamond",Vector2(400,200),Vector2(700,200))
 unit.skill_left = 0
 install(value)
 await frames(40)
 check(enemy.current_hp==20 and unit.skill_complete_serial==1,"direction laser uses actual 85 damage")
 await fixture("hexagon",Vector2(400,200),Vector2(1400,800))
 unit.skill_left = 0
 unit.current_hp = 100
 cast = SkillRequest.attempt(unit,{"aim":"self","purpose":"support"})
 check(cast["ok"] and unit.current_hp==135 and unit.skill_complete_serial==1,"hex self pulse actual healing")
