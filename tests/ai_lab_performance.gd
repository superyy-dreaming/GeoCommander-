extends Node
var arena: MainArena
func _ready() -> void:
 seed(7401)
 await get_tree().process_frame
 for kind: String in UnitCatalog.TYPES:
  var program: Dictionary = UnitTacticProgram.default_program(kind)
  for i: int in range(12):
   program["rules"].append({"id":"rule_%d" % i,"when":{"fact":"self_hp","op":"lt","value":float(i)/20.0},"actions":{"behavior":"retreat" if i < 3 else "normal"}})
  TacticalBrain.save_opening_program(program)
 arena = MainArena.new()
 add_child(arena)
 for team: int in range(2):
  for i: int in range(21): arena.spawn_unit(UnitCatalog.TYPES[i%4],team)
  if team == 1: TacticalBrain.team_profiles[1] = TacticalBrain.opening_profile.duplicate(true)
 for unit: BaseGeoUnit in arena.local_units:
  unit._profile_updated(unit.team,TacticalBrain.opening_profile)
  unit.max_hp = 100000
  unit.current_hp = 100000
 arena.ai_enabled = false
 arena.start_match()
 await get_tree().create_timer(3).timeout
 var started: int = Time.get_ticks_msec()
 var before_decisions: int = arena.tactic_decisions
 var before_tactic: int = arena.tactic_usec
 var before_routes: int = arena.navigation.route_usec
 var before_rays: int = arena.navigation.whisker_usec
 var count: int = 0
 var physics_ms: float = 0
 while Time.get_ticks_msec()-started < 3000:
  await get_tree().process_frame
  count += 1
  physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
 var elapsed: int = Time.get_ticks_msec()-started
 var report: Dictionary = {"units":arena.local_units.size(),"rules_per_unit":12,"fps":count*1000.0/elapsed,"physics_ms":physics_ms/count,"rule_decisions":arena.tactic_decisions-before_decisions,"rule_ms_total":(arena.tactic_usec-before_tactic)/1000.0,"route_ms_total":(arena.navigation.route_usec-before_routes)/1000.0,"ray_ms_total":(arena.navigation.whisker_usec-before_rays)/1000.0,"sample_ms":elapsed,"renderer":"Metal Forward+"}
 var file: FileAccess = FileAccess.open("res://artifacts/ai-lab-performance.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "))
 print("AI_LAB_PERF "+JSON.stringify(report))
 get_tree().quit()
