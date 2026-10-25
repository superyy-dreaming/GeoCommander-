extends Node

var checks: int=0
var failures: int=0

func check(ok: bool, message: String) -> void:
 checks+=1
 if ok: print("PASS: "+message)
 else:
  failures+=1
  push_error("FAIL: "+message)

func frames(count: int=3) -> void:
 for i: int in range(count): await get_tree().physics_frame

func fixture(map_id: String) -> CombatContext:
 var viewport: SubViewport=SubViewport.new()
 viewport.world_2d=World2D.new()
 add_child(viewport)
 var context: CombatContext=CombatContext.new()
 context.active=false
 viewport.add_child(context)
 var terrain: ArenaObstacles=ArenaObstacles.new()
 terrain.arena=context
 context.navigation=terrain
 context.add_child(terrain)
 if not map_id.is_empty():
  terrain.build(map_id)
  terrain.runtime.set_physics_process(false)
 return context

func spawn(context: CombatContext,kind: String,team: int,point: Vector2) -> BaseGeoUnit:
 var unit: BaseGeoUnit=(load("res://scripts/units/unit_"+kind+".gd") as Script).new() as BaseGeoUnit
 unit.arena=context
 unit.team=team
 unit.position=point
 unit.scripted_control=true
 context.add_child(unit)
 unit.set_physics_process(false)
 return unit

func object(context: CombatContext,kind: String) -> TerrainObject:
 for item: TerrainObject in context.terrain.objects:
  if item.spec["kind"]==kind: return item
 return null

func _ready() -> void:
 await frames()
 var expected_walls: Array[int]=[6,6,8,6,4,8]
 var expected_crystals: Array[int]=[4,2,6,3,3,6]
 for index: int in range(MapCatalog.IDS.size()):
  var id: String=MapCatalog.IDS[index]
  var data: Dictionary=MapCatalog.definition(id)
  var validated: Dictionary=MapCatalog.validate_layout(id)
  print("MAP_GEOMETRY "+JSON.stringify({"map":id,"walls":data["walls"].size(),"crystals":data["crystals"].size(),"zones":data["zones"].size(),"mechanics":data["mechanics"].size(),"validation":validated}))
  check(validated["ok"],id+" bounds, IDs, solid intersections and rotational symmetry "+str(validated["errors"]))
  check(data["walls"].size()==expected_walls[index] and data["crystals"].size()==expected_crystals[index],id+" object counts")
  var context: CombatContext=fixture(id)
  check(context.navigation.solid_polygons.size()==validated["solid_count"],id+" preview and physical hull counts agree")
  var lab: LaboratoryArena=LaboratoryArena.new()
  lab.map_id=id
  lab.layout=LaboratoryPresets.create(0)
  context.get_parent().add_child(lab)
  check(lab.validate_layout().is_empty(),id+" standard formation fits new geometry: "+lab.validate_layout())
  lab.queue_free()
  for wall: TerrainWall in context.navigation.walls:
   check(wall.get_child_count()>0 and not Geometry2D.decompose_polygon_in_convex(wall.polygon).is_empty(),id+" decomposable physical hull "+str(wall.get_meta("obstacle_id")))
 var map1: Dictionary=MapCatalog.definition("balanced")
 check(is_equal_approx(rad_to_deg(map1["walls"][3]["angle"]),160) and is_equal_approx(rad_to_deg(map1["walls"][5]["angle"]),200),"map1 red wedge corrected to 160/-160 degrees")
 check(is_equal_approx(rad_to_deg(MapCatalog.definition("crystal_maze")["walls"][3]["angle"]),205),"map6 red pocket corrected to 205 degrees")
 await test_scan()
 await test_rails()
 await test_beam()
 await test_mixed_beam()
 await test_portals()
 await test_gates()
 await test_reactor()
 await test_lifecycle()
 await test_migration()
 print("MAP_OVERHAUL_RESULT checks=%d failures=%d" % [checks,failures])
 get_tree().quit(0 if failures==0 else 1)

func test_scan() -> void:
 var c: CombatContext=fixture("balanced")
 var enemy: BaseGeoUnit=spawn(c,"square",1,Vector2(1200,460))
 var blue: BaseGeoUnit=spawn(c,"hexagon",0,Vector2(1000,460))
 var red: BaseGeoUnit=spawn(c,"hexagon",1,Vector2(1500,460))
 c.terrain.refresh_regions(enemy)
 c.terrain.refresh_regions(blue)
 check(not c.terrain.can_perceive(blue,enemy) and is_equal_approx(enemy.modulate.a,0.45),"nebula hides distant hostile target and applies alpha")
 check(c.units_for(1).has(enemy) and not blue.enemies().has(enemy),"actual damage entities remain separate from perceived enemies")
 blue.current_target=enemy
 check(not blue.target_valid() and blue.tactic_facts()["target_type"]=="none","hidden target does not leak through target facts")
 check(not SkillRequest.attempt(blue,{"ability":"scan","aim":"self"})["ok"],"scan rejected during preparation")
 c.active=true
 blue.skill_left=5
 blue.stun_left=1
 check(not blue.try_scan() and blue.scan_left==0,"EMP blocks scan without consuming cooldown")
 blue.stun_left=0
 check(SkillRequest.attempt(blue,{"ability":"scan","aim":"self"})["ok"],"hex scan uses shared skill request")
 check(is_equal_approx(blue.scan_left,8) and blue.skill_left==5 and blue.skill_serial==0 and blue.scan_serial==1,"scan cooldown and counters independent of primary treatment")
 check(c.terrain.can_perceive(blue,enemy) and not enemy.revealed_until.has(1),"reveal stored only for observing team")
 c.terrain.clock=3.01
 check(not c.terrain.can_perceive(blue,enemy),"reveal expires after three simulation seconds")
 blue.position=Vector2(1060,460)
 check(c.terrain.can_perceive(blue,enemy),"145px proximity perceives hostile nebula unit")
 blue.position=Vector2(1200,530)
 c.terrain.refresh_regions(blue)
 check(c.terrain.can_perceive(blue,enemy),"same-nebula perception")
 enemy.take_damage(20,blue)
 check(enemy.current_hp==enemy.max_hp-20,"direct real damage still reaches hidden entity")
 blue.position=Vector2(1000,460)
 c.terrain.refresh_regions(blue)
 c.active=false
 c.terrain._physics_process(100)
 check(is_equal_approx(c.terrain.clock,3.01),"paused terrain clock remains frozen")
 check(not SkillRequest.validation_error({"ability":"scan"},"triangle").is_empty(),"non-hex scan capability rejected")
 red.queue_free()

func test_rails() -> void:
 var c: CombatContext=fixture("flanks")
 var unit: BaseGeoUnit=spawn(c,"triangle",0,Vector2(1200,130))
 check(is_equal_approx(c.terrain.speed_multiplier(unit,Vector2.RIGHT),1.75),"rail same direction x1.75")
 check(is_equal_approx(c.terrain.speed_multiplier(unit,Vector2.LEFT),0.65),"rail reverse direction x0.65")
 check(is_equal_approx(c.terrain.speed_multiplier(unit,Vector2.DOWN),1),"rail perpendicular direction neutral")
 unit.slow_sources[1]=0.65
 unit.overclock_left=1
 unit.set("dash_state",2)
 check(is_equal_approx(unit.movement_velocity(0.016).length(),980*0.65*1.6*1.75),"dash, overclock, entropy and rail multiply active movement")
 unit.external_velocity=Vector2(300,0)
 check(unit.external_velocity==Vector2(300,0),"rail never multiplies external force")
 unit.position=Vector2(1200,675)
 c.terrain.refresh_regions(unit)
 check(unit.slow_sources.size()>=1,"entropy sources synchronize immediately")
 unit.position=Vector2(350,675)
 c.terrain.refresh_regions(unit)
 check(unit.slow_sources.size()==1 and unit.slow_sources.has(1),"leaving entropy removes only its own source")

func test_mixed_beam() -> void:
 var c: CombatContext=fixture("")
 var runtime: TerrainRuntime=TerrainRuntime.new()
 runtime.arena=c
 runtime.navigation=c.navigation
 c.add_child(runtime)
 runtime.set_physics_process(false)
 c.terrain=runtime
 var laser: BaseGeoUnit=spawn(c,"diamond",0,Vector2(300,300))
 var shield: PrismBarrier=PrismBarrier.new()
 shield.arena=c
 shield.position=Vector2(500,300)
 shield.rotation=-PI/4
 c.add_child(shield)
 shield.set_physics_process(false)
 var crystal: NeutralCrystal=NeutralCrystal.new()
 crystal.arena=c
 crystal.position=Vector2(500,500)
 c.add_child(crystal)
 var splitter: TriSplitter=TriSplitter.new()
 splitter.arena=c
 splitter.runtime=runtime
 splitter.position=Vector2(300,469)
 c.add_child(splitter)
 var victim: BaseGeoUnit=spawn(c,"square",1,Vector2(300,800))
 await frames()
 var trace: BeamTrace=BeamTrace.trace(c,laser.position,Vector2.RIGHT,laser)
 check(trace.bounces==2 and trace.split_count==1,"real shield and crystal reflections reach splitter with two used bounces")
 var gains: Array[float]=[]
 for segment: Dictionary in trace.segments:
  if segment["branch"]==0: gains.append(segment["gain"])
 check(gains.size()==3 and is_equal_approx(gains[1],1.35) and is_equal_approx(gains[2],1.35*1.25),"actual mixed mirror path multiplies shield35% and crystal25%")
 check(trace.segments.any(func(s: Dictionary) -> bool: return s["branch"]==1 and is_equal_approx(s["gain"],1.35*1.25*0.85) and s["reflections"]==2),"actual splitter inherits both mirror gains and consumed budget")
 var victims: Dictionary={}
 laser.call("damage_segment",Vector2(300,750),Vector2(300,850),50.0,victims)
 laser.call("damage_segment",Vector2(300,750),Vector2(300,850),120.0,victims)
 laser.call("damage_segment",Vector2(300,750),Vector2(300,850),70.0,victims)
 check(victims.size()==1 and victims[victim.get_instance_id()]["damage"]==120,"same target collects only highest segment damage regardless of ordering")
 var hidden: CombatContext=fixture("balanced")
 var hidden_laser: BaseGeoUnit=spawn(hidden,"diamond",0,Vector2(700,675))
 var hidden_target: BaseGeoUnit=spawn(hidden,"square",1,Vector2(1200,460))
 hidden.terrain.refresh_regions(hidden_target)
 var stealth_splitter: TriSplitter=TriSplitter.new()
 stealth_splitter.arena=hidden
 stealth_splitter.runtime=hidden.terrain
 stealth_splitter.position=MapCatalog.CENTER
 hidden.add_child(stealth_splitter)
 await frames()
 var unseen: BeamTrace=BeamTrace.trace(hidden,hidden_laser.position,Vector2.RIGHT,hidden_laser)
 var center: Dictionary={}
 for segment: Dictionary in unseen.segments:
  if segment["branch"]==1: center=segment; break
 check(not center.is_empty() and (center["end"]-center["start"]).normalized().dot(Vector2.LEFT)>0.99,"splitter ignores hidden target and uses hit normal when no perceived enemy")

func test_beam() -> void:
 var c: CombatContext=fixture("refraction")
 var laser: BaseGeoUnit=spawn(c,"diamond",0,Vector2(700,675))
 var target: BaseGeoUnit=spawn(c,"square",1,Vector2(1460,675))
 await frames()
 var trace: BeamTrace=BeamTrace.trace(c,laser.position,Vector2.RIGHT,laser)
 check(trace.split_count==1,"actual ray hits central splitter exactly once")
 var lengths: Dictionary={}
 var gains: Dictionary={}
 for segment: Dictionary in trace.segments:
  var branch: int=segment["branch"]
  lengths[branch]=float(lengths.get(branch,0))+segment["start"].distance_to(segment["end"])
  gains[branch]=segment["gain"]
  check(int(segment["reflections"])<=2,"split branch inherits reflection budget")
 check(lengths.has(1) and lengths.has(2) and lengths.has(3),"three real outgoing branches")
 for branch: int in [1,2,3]: check(lengths.get(branch,INF)<=650.01,"branch total length including reflection <=650")
 check(is_equal_approx(gains.get(1,0),0.85) and is_equal_approx(gains.get(2,0),0.75) and is_equal_approx(gains.get(3,0),0.75),"center and side gains 85/75/75 percent")
 c.active=true
 laser.call("fire_beam",Vector2.RIGHT)
 check(is_equal_approx(target.current_hp,target.max_hp-85*0.85),"split damage uses authoritative trace and hits each victim once")
 var repeated: BeamTrace=BeamTrace.new()
 repeated.trace_branch(c,Vector2(1000,675),Vector2.RIGHT,650,1.35,1,1,true,laser)
 check(repeated.split_count==0 and repeated.segments.size()==1,"second splitter collision terminates without recursive split")
 var inherited: BeamTrace=BeamTrace.new()
 inherited.trace_branch(c,laser.position,Vector2.RIGHT,750,1.35,2,0,false,laser)
 check(inherited.segments.any(func(s: Dictionary) -> bool: return s["branch"]==1 and is_equal_approx(s["gain"],1.35*0.85) and s["reflections"]==2),"splitter inherits gain and consumed reflection count")

func test_portals() -> void:
 var c: CombatContext=fixture("spiral_fortress")
 var pair: Dictionary=c.terrain.pairs["pair_a"]
 var entry: TerrainObject=pair["ends"][0]
 var exit: TerrainObject=pair["ends"][1]
 var unit: BaseGeoUnit=spawn(c,"triangle",0,entry.position)
 unit.set("dash_state",2)
 unit.set("dash_previous",Vector2(300,100))
 c.active=true
 var block: PackedVector2Array=Transform2D(0,exit.position)*PackedVector2Array([Vector2(-250,-190),Vector2(250,-190),Vector2(250,190),Vector2(-250,190)])
 c.navigation.solid_polygons.append(block)
 check(not c.terrain.try_portal(unit) and pair["charges"]==5 and unit.teleport_cooldown==0 and unit.position==entry.position,"unsafe portal exit atomically preserves position, charges, cooldown")
 c.navigation.refresh_solids()
 check(c.terrain.try_portal(unit),"portal succeeds after safe exit validation")
 check(pair["charges"]==4 and unit.teleport_cooldown==8 and unit.portal_boost_left==2 and unit.portal_used_count==1,"portal commits shared charge, 8s unit CD and 2s boost")
 check(unit.get("dash_state")==2 and unit.get("dash_previous")==unit.position,"teleport preserves active action but resets dash collision trail")
 var between: BaseGeoUnit=spawn(c,"square",1,entry.position.lerp(exit.position,0.5))
 unit.call("hit_dash_segment",unit.get("dash_previous"),unit.position)
 check(between.current_hp==between.max_hp,"teleported dash never damages units along the skipped portal span")
 check(not c.terrain.try_portal(unit),"unit cooldown prevents immediate reverse teleport")
 pair["charges"]=1
 unit.teleport_cooldown=0
 unit.position=entry.position
 check(c.terrain.try_portal(unit) and pair["charges"]==0 and pair["recharge"]==14,"fifth shared use enters 14s recharge")
 unit.position=Vector2(350,200)
 unit.teleport_cooldown=100
 c.terrain._physics_process(14)
 check(pair["charges"]==5,"pair restores all five charges at recharge completion")
 var route: PackedVector2Array=c.navigation.make_route(Vector2(350,200),Vector2(2050,1150),true)
 check(route.size()>=2,"directed portal navigation uses zero-heuristic graph")
 var plan: Dictionary=TacticPlan.default_program("triangle")
 plan["plan"]["steps"]=[{"id":"wait","action":"wait","seconds":3,"next":"wait"}]
 plan["plan"]["entry"]="wait"
 unit.scripted_control=false
 unit.base_rule["program"]=plan
 unit.reset_execution()
 unit.teleport_cooldown=0
 unit.position=entry.position
 check(not c.terrain.try_portal(unit),"precise plan does not use portals without authorization")

func test_gates() -> void:
 var c: CombatContext=fixture("balanced")
 var gate: TerrainObject=object(c,"gate")
 check(gate.closed,"gate initially closed")
 c.active=true
 c.terrain.clock=20
 c.terrain.update_gate(gate)
 await frames()
 check(not gate.closed and gate.shape.disabled,"gate opens after 20s and releases collision")
 var unit: BaseGeoUnit=spawn(c,"square",0,gate.position)
 c.terrain.clock=35
 var block: PackedVector2Array=Transform2D(0,gate.position)*PackedVector2Array([Vector2(-160,-160),Vector2(160,-160),Vector2(160,160),Vector2(-160,160)])
 c.navigation.solid_polygons.append(block)
 c.terrain.update_gate(gate)
 check(not gate.closed and not gate.blocked_reason.is_empty(),"blocked push keeps gate open with explicit reason")
 c.navigation.refresh_solids()
 c.terrain.update_gate(gate)
 check(not gate.closed and not unit.gate_push_velocity.is_zero_approx(),"gate retries on topology change using physical normal push")
 unit.set_physics_process(true)
 await frames(25)
 unit.set_physics_process(false)
 c.terrain.update_gate(gate)
 await frames()
 check(gate.closed and unit.position.distance_to(gate.position)>unit.unit_radius+9,"gate closes only after occupant physically clears")

func test_reactor() -> void:
 var c: CombatContext=fixture("crystal_maze")
 var unit: BaseGeoUnit=spawn(c,"square",0,MapCatalog.CENTER)
 c.active=true
 c.terrain.clock=49
 check(c.terrain.warning_at(unit),"reactor warning begins at49s")
 c.terrain._physics_process(6)
 check(is_equal_approx(unit.current_hp,unit.max_hp-160),"reactor deals160 real area damage at55s")
 check(c.terrain.pickups.size()==3,"reactor produces three persistent safe Flux crystals")
 var first: Vector2=c.terrain.pickups[0]["position"]
 var other: BaseGeoUnit=spawn(c,"square",1,first)
 unit.position=first
 unit.spawn_index=0
 other.spawn_index=1
 c.terrain.collect_pickups()
 check(c.terrain.pickups.size()==2 and unit.flux_collected_count==1 and c.terrain.local_flux[0]==50 and c.terrain.local_flux[1]==0,"same-frame pickup contest resolves distance then stable deployment serial")
 c.active=false
 var time: float=c.terrain.clock
 c.terrain._physics_process(55)
 check(c.terrain.clock==time and c.terrain.pickups.size()==2,"paused/ended reactor and pickups stop settlement")
 var reset: CombatContext=fixture("crystal_maze")
 check(reset.terrain.clock==0 and reset.terrain.pickups.is_empty(),"new context resets reactor cycle and pickups")
 var reactor: TerrainObject=object(reset,"reactor")
 var block: PackedVector2Array=PackedVector2Array([Vector2(700,200),Vector2(1700,200),Vector2(1700,1150),Vector2(700,1150)])
 reset.navigation.solid_polygons.append(block)
 reset.terrain.detonate(reactor,1)
 check(reset.terrain.pickups.is_empty() and reset.terrain.pending_pickups.size()==3 and not reactor.blocked_reason.is_empty(),"blocked reactor rewards remain pending with explicit feedback")
 reset.terrain._physics_process(1)
 check(reset.terrain.pending_pickups.size()==3 and reset.terrain.clock==0,"pending rewards do not retry while inactive")
 reset.navigation.refresh_solids()
 reset.active=true
 reset.terrain._physics_process(0.6)
 check(reset.terrain.pickups.size()==3 and reset.terrain.pending_pickups.is_empty() and reactor.blocked_reason.is_empty(),"pending rewards spawn once when space becomes safe")

func test_lifecycle() -> void:
 var c: CombatContext=fixture("balanced")
 var unit: BaseGeoUnit=spawn(c,"square",0,Vector2(840,675))
 var field: EntropyField=c.navigation.fields[0]
 c.terrain.refresh_regions(unit)
 check(unit.slow_sources.has(field.get_instance_id()) and field.affected.has(unit),"synchronous region refresh registers its lifecycle owner")
 unit.nebula_ids.append("old_region")
 unit.revealed_until[1]=3.0
 unit.portal_boost_left=2
 unit.gate_push_velocity=Vector2(0,150)
 c.navigation.queue_free()
 await frames()
 check(unit.slow_sources.is_empty() and unit.nebula_ids.is_empty() and unit.revealed_until.is_empty() and unit.portal_boost_left==0 and unit.gate_push_velocity==Vector2.ZERO,"terrain release clears slow, stealth, reveal, boost and gate effects")
 var arena: MainArena=MainArena.new()
 arena.map_id="crystal_maze"
 arena.ai_enabled=false
 add_child(arena)
 arena.start_match()
 arena.set_physics_process(false)
 arena.terrain.set_physics_process(false)
 var formal: BaseGeoUnit=arena.units_for(0)[0]
 var before: float=arena.flux[0]
 arena.terrain.pickups.append({"id":"formal","position":formal.position,"amount":50})
 arena.terrain.collect_pickups()
 check(arena.flux[0]==before+50 and arena.terrain.local_flux[0]==50,"MainArena owns formal Flux settlement of real pickup event")
 var local: CombatContext=fixture("crystal_maze")
 var local_unit: BaseGeoUnit=spawn(local,"square",0,Vector2(350,130))
 local.active=true
 local.terrain.pickups.append({"id":"local","position":local_unit.position,"amount":50})
 local.terrain.collect_pickups()
 check(local.terrain.local_flux[0]==50 and arena.flux[0]==before+50,"isolated pickup accounting never modifies formal Flux")
 arena.finish_match(0,"terrain lifecycle fixture")
 var stopped: float=arena.terrain.clock
 arena.terrain._physics_process(60)
 check(arena.terrain.clock==stopped and arena.flux[0]==before+50,"formal ended phase stops terrain, rewards and economy")
 arena.queue_free()
 await frames()

func test_migration() -> void:
 var p: Dictionary=TacticPlan.default_program("triangle")
 p["plan"]["map_id"]="balanced"
 p["plan"]["steps"]=[{"id":"point","action":"move_to","goal":{"anchor":"point","point":[400,400]},"path":[[800,800]],"skill_request":{"aim":"point","point":[1200,800]}}]
 var migrated: Dictionary=MapCatalog.migrate_program_coordinates(p,2)
 check(Vector2(migrated["plan"]["steps"][0]["goal"]["point"][0],migrated["plan"]["steps"][0]["goal"]["point"][1])==Vector2(300,300) and is_equal_approx(migrated["plan"]["steps"][0]["path"][0][0],600) and is_equal_approx(migrated["plan"]["steps"][0]["skill_request"]["point"][0],900),"space2 migrates points, paths and skill positions by0.75")
 check(is_equal_approx(MapCatalog.migrate_program_coordinates(p,1)["plan"]["steps"][0]["goal"]["point"][0],400) and MapCatalog.migrate_program_coordinates(migrated,3)==migrated,"space1 and3 coordinates remain unchanged")
 var store: Node=load("res://scripts/lab/laboratory_store.gd").new()
 store.path="user://map_overhaul_migration_fixture.json"
 var raw: Dictionary={"version":3,"map_space_version":2,"records":{"triangle":{"program":["invalid","retained"],"applied_program":{"invalid":true},"prompt":"original"}},"setup":{"map_id":"balanced","seed":7,"units":[{"kind":"triangle","team":0,"x":400,"y":400,"hp":1,"angle":0}]}}
 var file: FileAccess=FileAccess.open(store.path,FileAccess.WRITE)
 file.store_string(JSON.stringify(raw));file.close()
 store.load_records()
 check(store.records["triangle"]["program"] is Dictionary and store.records["triangle"].get("repair_original")==["invalid","retained"],"invalid raw candidate retained separately from executable dictionary")
 check(not TacticPlan.profile_error(store.blue_profile(),"balanced").is_empty(),"invalid applied program blocks start without feeding invalid data to units")
 check(store.setup["units"][0]["x"]==300 and FileAccess.file_exists(store.migration_backup),"migration backs up original before atomic save")
 store.load_records()
 check(store.setup["units"][0]["x"]==300 and store.records["triangle"].get("repair_original")==["invalid","retained"],"reload migrates only once and retains pending repairs")
 DirAccess.remove_absolute(store.path)
 store.free()
 var parsed: Dictionary=TacticalBrain.parse_prompt("利用虫洞，再走加速轨")
 check(parsed["ok"] and parsed["profile"]["unit_rules"]["triangle"]["terrain_strategy"]=="rails","independent terrain keywords override in text order")
