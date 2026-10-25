extends "res://tests/tactic_plan_runner.gd"

func install(value: Dictionary) -> void:
 unit.scripted_control=false
 var profile: Dictionary=UnitTacticProgram.apply_to_profile(arena.profile_for(unit.team),value)
 arena.local_profiles[unit.team]=profile
 unit._profile_updated(unit.team,profile)
 unit.velocity=Vector2.ZERO

func _ready() -> void:
 baseline = LaboratoryStore.applied_programs.duplicate(true)
 await run()
 LaboratoryStore.applied_programs=baseline
 var file: FileAccess = FileAccess.open("res://artifacts/tactic-v2-extended.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
 print("PLAN_EXTENDED passed=%d failed=%d" % [passed,failed])
 get_tree().quit(0 if failed==0 else 1)

func run() -> void:
 await super.run()
 for kind: String in UnitCatalog.TYPES:
  check(UnitTacticProgram.validate(TacticExamples.for_unit(kind))["ok"],"editable example validates "+kind)
 for bad: Variant in [null,[],1,"x",true]:
  var value: Dictionary=TacticPlan.default_program("triangle")
  value["plan"]["interrupts"]=[bad]
  check(not UnitTacticProgram.validate(value)["ok"],"malformed interrupt rejected "+str(bad))
 for field: String in ["action","seconds","timeout","target","attack","skill","direction","angle","goal","path","obstacle","skill_request","when","next"]:
  var value: Dictionary=TacticPlan.default_program("triangle")
  value["plan"]["steps"][0][field]={"injected":true}
  check(not UnitTacticProgram.validate(value)["ok"],"invalid typed field "+field)
 var value: Dictionary=TacticPlan.default_program("triangle")
 value["plan"]["steps"][0]["next"]="return"
 check(not UnitTacticProgram.validate(value)["ok"],"main flow cannot return without interrupt")
 value=TacticPlan.default_program("triangle")
 value["plan"]["steps"][0].erase("seconds")
 value["plan"]["steps"][0]["when"]={"not":{"not":{"not":{"not":{"fact":"self_hp","op":"lt","value":0.3}}}}}
 check(not UnitTacticProgram.validate(value)["ok"],"condition nesting bounded")
 var nodes: Array=[]
 for i: int in range(128): nodes.append({"fact":"skill_ready","op":"eq","value":true})
 value["plan"]["steps"][0]["when"]={"all":nodes}
 check(not UnitTacticProgram.validate(value)["ok"],"condition budget includes branches")
 for limit: int in [24,25]:
  value=TacticPlan.default_program("triangle")
  value["plan"]["steps"]=[]
  for i: int in range(limit): value["plan"]["steps"].append(TacticPlan.step("step_%d" % (i+1)))
  check(UnitTacticProgram.validate(value)["ok"]==(limit==24),"step count boundary %d" % limit)
 for kind: String in ["triangle","circle","diamond"]:
  check(not SkillRequest.validation_error({"purpose":"support"},kind).is_empty(),"skill ability restricted "+kind)
 await fixture("circle",Vector2(400,200),Vector2(600,200))
 var second: BaseGeoUnit = (load("res://scripts/units/unit_square.gd") as Script).new() as BaseGeoUnit
 second.team=1
 second.arena=arena
 second.position=Vector2(660,200)
 arena.add_child(second)
 second.scripted_control=true
 enemy.max_hp=400
 enemy.current_hp=400
 unit.skill_left=0
 value=program("circle",[{"id":"gravity","action":"cast_skill","skill_request":{"aim":"point","point":[630,200]},"timeout":3.0}])
 value["plan"]["map_id"]="balanced"
 value["base"]["skill_cond"]="on_cooldown"
 install(value)
 await frames(10)
 check(unit.skill_active and unit.execution.status=="运行","gravity step waits real collapse")
 await frames(80)
 check(unit.skill_complete_serial==1 and enemy.current_hp==358,"gravity requested center real collapse damage")
 unit.skill_left=0
 var result: Dictionary=SkillRequest.attempt(unit,{"aim":"point","point":[1500,200]})
 check(not result["ok"] and unit.skill_left==0,"gravity invalid range preserves cooldown")
 await fixture("triangle",Vector2(400,200),Vector2(800,200))
 value=program("triangle",[{"id":"target","action":"flank_target","target":"diamond","on_failure":"fallback"},{"id":"fallback","action":"wait","seconds":0.5}])
 install(value)
 await frames(2)
 var reserve: BaseGeoUnit=(load("res://scripts/units/unit_square.gd") as Script).new() as BaseGeoUnit
 reserve.arena=arena
 reserve.team=1
 reserve.position=Vector2(2000,900)
 arena.add_child(reserve)
 reserve.scripted_control=true
 enemy.dead=true
 await frames(3)
 check(unit.execution.current=="fallback","target loss follows explicit failure edge")
 await fixture("triangle",Vector2(400,200),Vector2(800,200))
 value=program("triangle",[{"id":"blocked","action":"move_to","goal":{"anchor":"point","point":[540,675]},"on_failure":"fallback"},{"id":"fallback","action":"wait","seconds":1.0}])
 install(value) # deliberate invalid runtime fixture, bypass normal validator
 await frames(4)
 check(unit.execution.current=="fallback","no route follows explicit failure edge")
 await fixture("triangle",Vector2(400,200),Vector2(800,200))
 value=program("triangle",[{"id":"cover","action":"seek_cover","obstacle":"missing_wall"}])
 install(value)
 await frames(3)
 check(unit.execution.status=="受阻停止" and "墙体" in unit.execution.reason,"missing cover has explicit failure")
 for map_id: String in MapCatalog.IDS:
  await fixture("triangle",Vector2(800,130),Vector2(2000,130),map_id)
  var found: Dictionary=CoverPlanner.find(unit,enemy)
  await frames(1)
  if found["ok"]:
   var point: Vector2=CoverPlanner.peek(unit,found["point"],enemy)
   check(point.is_finite(),"reachable peek point "+map_id)
   check(not CoverPlanner.hidden(unit,found["point"],null),"lost threat invalidates cover "+map_id)
  var blue_unit: BaseGeoUnit=unit
  for team: int in range(2):
   unit=blue_unit if team==0 else enemy
   unit.position=Vector2(400 if team==0 else 2000,200)
   value=program(unit.unit_type,[{"id":"direction","action":"move_direction","direction":"forward","seconds":0.2}])
   install(value)
   var start: float=unit.position.x
   await frames(16)
   check((unit.position.x-start)*(1 if team==0 else -1)>unit.move_speed*0.15,"relative forward "+map_id+str(team))
  unit=blue_unit
  unit.position=Vector2(700,130)
  value=program("triangle",[{"id":"path","action":"follow_path","path":[[700,130],[1000,130],[1400,130]],"timeout":10.0}])
  value["plan"]["map_id"]=map_id
  install(value)
  await frames(200)
  check(unit.execution.status=="完成待命" and unit.position.distance_to(Vector2(1400,130))<=24,"manual route follows all waypoints "+map_id)
 await storage_and_editor()
 await formal_case()
 await acceptance_case()
 await edge_cases()
 await identical_contexts()
 await map_mismatch_recovery()

func map_mismatch_recovery() -> void:
 var saved: Dictionary=TacticalBrain.opening_profile.duplicate(true)
 var value: Dictionary=program("triangle",[{"id":"path","action":"follow_path","path":[[700,130],[1000,130]]}])
 value["plan"]["map_id"]="balanced"
 TacticalBrain.save_opening_program(value)
 TacticalBrain.save_opening_program(TacticExamples.for_unit("diamond"))
 var viewport: SubViewport=SubViewport.new()
 viewport.world_2d=World2D.new()
 add_child(viewport)
 var formal: MainArena=MainArena.new()
 formal.map_id="flanks"
 formal.ai_enabled=false
 viewport.add_child(formal)
 formal.start_match()
 check(formal.phase==MainArena.Phase.PREPARING and "triangle" in TacticPlan.profile_error(formal.profile_for(0),formal.map_id),"map mismatch blocks match and identifies unit kind")
 formal.hud.selected_kind="triangle"
 formal.hud.reset_selected_program()
 check(not formal.profile_for(0)["unit_rules"]["triangle"].has("program") and formal.profile_for(0)["unit_rules"]["diamond"].has("program"),"preparation recovery resets only mismatched kind")
 formal.start_match()
 check(formal.phase==MainArena.Phase.PLAYING,"preparation can start after single-kind recovery")
 viewport.queue_free()
 await get_tree().process_frame
 TacticalBrain.opening_profile=saved

func identical_contexts() -> void:
 await fixture("triangle",Vector2(800,900),Vector2(1680,500))
 enemy.max_hp=5000
 enemy.current_hp=5000
 enemy.visual_root.rotation=PI
 var value: Dictionary=TacticExamples.for_unit("triangle")
 install(value)
 var saved: Dictionary=TacticalBrain.opening_profile.duplicate(true)
 TacticalBrain.save_opening_program(value)
 var viewport: SubViewport=SubViewport.new()
 viewport.world_2d=World2D.new()
 add_child(viewport)
 var formal: MainArena=MainArena.new()
 formal.ai_enabled=false
 formal.map_id="balanced"
 viewport.add_child(formal)
 for old: BaseGeoUnit in formal.local_units.duplicate():
  old.dead=true
  formal.unregister_unit(old)
  old.queue_free()
 formal.spawn_serial=[0,0]
 var blue: BaseGeoUnit=formal.spawn_unit("triangle",0,Vector2(800,900))
 var red: BaseGeoUnit=formal.spawn_unit("diamond",1,Vector2(1680,500))
 red.scripted_control=true
 red.max_hp=5000
 red.current_hp=5000
 red.visual_root.rotation=PI
 blue.flank_sign=unit.flank_sign
 formal.start_match()
 await frames(900)
 check(blue.execution.current==unit.execution.current and blue.execution.visits==unit.execution.visits and red.current_hp==enemy.current_hp and blue.position.distance_to(unit.position)<2,"same plan and physical layout produce identical formal and laboratory behavior")
 viewport.queue_free()
 await get_tree().process_frame
 TacticalBrain.opening_profile=saved

func edge_cases() -> void:
 await fixture()
 var debug_value: Dictionary=program("triangle",[{"id":"last","action":"wait","seconds":0.1}])
 install(debug_value)
 await frames(2)
 arena.toggle_pause()
 arena.step_transition(unit)
 await frames(12)
 check(arena.state==LaboratoryArena.State.PAUSED and unit.execution.status=="完成待命","run-to-next-step pauses when the plan completes")
 await fixture("triangle",Vector2(400,200),Vector2(650,200))
 unit.skill_left=0
 enemy.visual_root.rotation=0
 var rejected: Dictionary=SkillRequest.attempt(unit,{"aim":"direction","direction":"left","purpose":"backstab"})
 check(not rejected["ok"] and unit.skill_left==0,"invalid backstab aim consumes no cooldown")
 var value: Dictionary=program("triangle",[{"id":"wait","action":"wait","seconds":4.0},{"id":"first","action":"wait","seconds":0.5,"next":"return"},{"id":"second","action":"wait","seconds":0.5,"next":"return"}],[{"id":"priority_one","when":{"fact":"self_hp","op":"lt","value":0.3},"goto":"first"},{"id":"priority_two","when":{"fact":"self_hp","op":"lt","value":0.6},"goto":"second"}])
 install(value)
 unit.current_hp=20
 await frames(3)
 check(unit.execution.current=="first" and unit.execution.suspended["id"]=="wait","interrupt ordering chooses first matching branch without nesting")
 await fixture("diamond",Vector2(400,200),Vector2(1400,200))
 unit.skill_left=0
 unit.evaluate_best_target()
 rejected=SkillRequest.attempt(unit,{"aim":"auto"})
 check(not rejected["ok"] and unit.skill_left==0,"auto laser respects real target range")
 await fixture("hexagon",Vector2(400,200),Vector2(1400,800))
 unit.skill_left=0
 value=program("hexagon",[{"id":"heal","action":"cast_skill","target":"none","skill_request":{"aim":"auto"},"timeout":2.0}])
 install(value)
 await frames(3)
 check(unit.execution.status=="完成待命" and unit.skill_serial==1,"self pulse does not require an enemy target")
 await fixture("triangle",Vector2(400,130),Vector2(700,130))
 value=program("triangle",[{"id":"approach","action":"move_to","goal":{"anchor":"target"},"target":"diamond"}])
 install(value)
 await frames(90)
 check(unit.execution.status=="完成待命","move-to-target arrives outside physical collision radii")
 var saved: Dictionary=TacticalBrain.opening_profile.duplicate(true)
 TacticalBrain.save_opening_program(TacticPlan.default_program("triangle"))
 var formal: MainArena=MainArena.new()
 formal.map_id="balanced"
 formal.ai_enabled=false
 add_child(formal)
 var blue: BaseGeoUnit=formal.units_for(0).filter(func(u: BaseGeoUnit)->bool:return u.unit_type=="triangle")[0]
 formal.start_match()
 await frames(3)
 formal.queue_free()
 await get_tree().process_frame
 formal=MainArena.new()
 formal.map_id="balanced"
 add_child(formal)
 blue=formal.units_for(0).filter(func(u: BaseGeoUnit)->bool:return u.unit_type=="triangle")[0]
 check(blue.execution!=null and blue.execution.state.is_empty() and blue.execution.unit_time==0,"new match retains opening program with fresh clocks")
 formal.queue_free()
 await get_tree().process_frame
 TacticalBrain.opening_profile=saved

func acceptance_case() -> void:
 await fixture("triangle",Vector2(800,900),Vector2(1680,500))
 enemy.max_hp=5000
 enemy.current_hp=5000
 enemy.visual_root.rotation=PI
 install(TacticExamples.for_unit("triangle"))
 for i: int in range(4800):
  await frames(1)
  if unit.execution.status!="运行" or int(unit.execution.visits.get("return_cover",0))>=2: break
 print("ACCEPTANCE_TRACE "+JSON.stringify({"state":unit.execution.readout(),"events":unit.execution.events}))
 check(int(unit.execution.visits.get("return_cover",0))>=2 and enemy.current_hp<=4780,"core scenario completes two real backstab loops")
 unit.current_hp=unit.max_hp*0.2
 await frames(12)
 check(unit.execution.current=="escape","core scenario low-health interrupt retreats")

func storage_and_editor() -> void:
 var store: Node=(load("res://scripts/lab/laboratory_store.gd") as Script).new()
 store.path="user://test_plan_migration_v2.json"
 var old: String=store.path.replace("_v2.json","_v1.json")
 for path: String in [store.path,old,old+".pre-v2"]:
  if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
 var legacy: Dictionary={"version":1,"records":{"triangle":{"prompt":"旧提示词","program":UnitTacticProgram.default_program("triangle")}},"setup":{}}
 var file: FileAccess=FileAccess.open(old,FileAccess.WRITE)
 file.store_string(JSON.stringify(legacy))
 file.close()
 store.load_records()
 check(store.migration_source==old and store.records["triangle"]["prompt"]=="旧提示词","v1 experiment loaded for migration")
 store.records["triangle"]["draft_json"]="{invalid draft"
 check(store.save() and FileAccess.file_exists(old+".pre-v2"),"migration writes v2 only after preserving v1 backup")
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(store.path))
 check(data["version"]==LaboratoryStore.FILE_VERSION and data["records"]["triangle"]["program"]["version"]==1 and data["records"]["triangle"]["draft_json"]=="{invalid draft","migration retains v1 JSON and invalid editable draft")
 check(FileAccess.get_file_as_string(old)==JSON.stringify(legacy),"legacy source remains unchanged")
 store.load_records()
 check(store.records["triangle"]["draft_json"]=="{invalid draft" and store.records["triangle"]["program"]["version"]==1,"restart restores invalid draft and valid legacy program separately")
 var persisted: String=FileAccess.get_file_as_string(store.path)
 store.records["triangle"]["draft_json"]="x".repeat(262145)
 check(not store.save() and FileAccess.get_file_as_string(store.path)==persisted,"oversized draft cannot overwrite persisted experiments")
 store.records["triangle"]["draft_json"]="{invalid draft"
 store.path="user://nonexistent-plan-folder/file.json"
 check(not store.save() and store.dirty and "未保存" in store.status,"save failure is visible and preserves memory")
 store.free()
 var editor: TacticPlanEditor=TacticPlanEditor.new()
 add_child(editor)
 editor.set_program(TacticPlan.default_program("triangle"))
 editor.operate("添加")
 check(editor.program["plan"]["steps"].size()==2,"step editor adds step")
 editor.operate("上移")
 check(editor.selected==0,"step editor reorder")
 editor.undo()
 check(editor.program["plan"]["steps"][0]["id"]=="step_1","step editor undo")
 editor.redo()
 check(editor.program["plan"]["steps"][0]["id"]=="step_2","step editor redo")
 editor.edit_path("step_2",[[700,130],[1000,130]])
 check(editor.program["plan"]["map_id"]=="balanced" and editor.program["plan"]["steps"][0]["action"]=="follow_path","path editing binds map and action")
 editor.operate("删除")
 check(editor.program["plan"]["steps"].size()==1,"step delete repairs graph")
 editor.queue_free()

func formal_case() -> void:
 var saved: Dictionary=TacticalBrain.opening_profile.duplicate(true)
 var value: Dictionary=program("triangle",[{"id":"north","action":"move_direction","direction":"up","seconds":1.0}])
 TacticalBrain.save_opening_program(value)
 var formal: MainArena=MainArena.new()
 formal.ai_enabled=false
 formal.map_id="balanced"
 add_child(formal)
 await frames(1)
 var blue: BaseGeoUnit=formal.units_for(0).filter(func(u: BaseGeoUnit)->bool:return u.unit_type=="triangle")[0]
 check(blue.execution!=null and blue.execution.program==value,"formal units receive identical v2 interpreter")
 formal.start_match()
 await frames(15)
 check(blue.execution.current=="north" and blue.execution.state["time"]>0,"formal physics advances v2 plan")
 var spawned: BaseGeoUnit=formal.spawn_unit("triangle",0)
 check(spawned!=null and spawned.execution!=null and spawned.execution.state.is_empty(),"new deployed unit owns fresh execution state")
 var count: int=blue.execution.transition_serial
 check(spawned.execution!=blue.execution and count>0,"unit execution states are independent")
 formal.queue_free()
 await get_tree().process_frame
 TacticalBrain.opening_profile=saved
