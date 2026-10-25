extends Node

func _ready() -> void:
 seed(7401)
 GameSettings.values=GameSettings.DEFAULTS.duplicate()
 for kind: String in UnitCatalog.TYPES:
  var program: Dictionary=TacticPlan.default_program(kind)
  program["plan"]["steps"]=[{"id":"cover","action":"seek_cover","timeout":30.0,"target":"nearest","next":"peek","on_failure":"wait"},{"id":"peek","action":"peek","timeout":15.0,"next":"skill","on_failure":"wait"},{"id":"skill","action":"cast_skill","attack":kind!="hexagon","timeout":3.0,"next":"wait","on_failure":"wait"},{"id":"wait","action":"wait","seconds":0.3,"next":"cover"}]
  program["plan"]["entry"]="cover"
  TacticalBrain.save_opening_program(program)
 var arena: MainArena=MainArena.new()
 arena.ai_enabled=false
 add_child(arena)
 for team: int in range(2):
  for i: int in range(21): arena.spawn_unit(UnitCatalog.TYPES[i%4],team)
 TacticalBrain.team_profiles[1]=TacticalBrain.opening_profile.duplicate(true)
 for unit: BaseGeoUnit in arena.local_units:
  unit._profile_updated(unit.team,TacticalBrain.opening_profile)
  unit.max_hp=100000
  unit.current_hp=100000
 arena.start_match()
 await get_tree().create_timer(2).timeout
 var started: int=Time.get_ticks_msec()
 var plan_before: int=arena.plan_usec
 var routes_before: int=arena.navigation.route_usec
 var rays_before: int=arena.navigation.whisker_usec
 var cover_before: int=arena.cover_usec
 var queries_before: int=arena.cover_queries
 var samples: int=0
 var physics: float=0
 while Time.get_ticks_msec()-started<8000:
  await get_tree().process_frame
  samples+=1
  physics+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
 var elapsed: int=Time.get_ticks_msec()-started
 var active: int=0
 for unit: BaseGeoUnit in arena.local_units:
  if unit.execution!=null and unit.execution.status=="运行": active+=1
 var report: Dictionary={"units":arena.local_units.size(),"active_plans":active,"fps":samples*1000.0/elapsed,"physics_ms":physics/samples,"executor_ms_total":(arena.plan_usec-plan_before)/1000.0,"route_ms_total":(arena.navigation.route_usec-routes_before)/1000.0,"ray_ms_total":(arena.navigation.whisker_usec-rays_before)/1000.0,"cover_ms_total":(arena.cover_usec-cover_before)/1000.0,"cover_queries":arena.cover_queries-queries_before,"cached_cover_geometry":arena.navigation.cover_candidates.size(),"sample_ms":elapsed,"renderer":"Metal Forward+","screen_scale":DisplayServer.screen_get_scale()}
 var file: FileAccess=FileAccess.open("res://artifacts/tactic-v2-performance.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "))
 print("PLAN_PERF "+JSON.stringify(report))
 get_tree().quit(0 if report["fps"]>=55 and active==60 else 1)
