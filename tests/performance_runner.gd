extends Node

var arena: MainArena

func _ready() -> void:
 await get_tree().process_frame
 var scene: PackedScene = load("res://scenes/main_arena.tscn") as PackedScene
 arena = scene.instantiate() as MainArena
 add_child(arena)
 arena.start_match()
 for team: int in range(2):
  for index: int in range(21): arena.spawn_unit(UnitCatalog.TYPES[index%4],team)
 for unit: BaseGeoUnit in arena.local_units:
  unit.max_hp = 100000.0
  unit.current_hp = 100000.0
 await get_tree().create_timer(3.0).timeout
 await measure("60-units-combat-test-hp-100000")
 arena.set_reduced_motion(true)
 await measure("reduced-motion")
 arena.set_physics_process(false)
 for unit: BaseGeoUnit in arena.local_units: unit.set_physics_process(false)
 await measure("physics-frozen")

 var report: FileAccess = FileAccess.open("res://artifacts/launcher-performance.json" if "--launcher" in OS.get_cmdline_user_args() else "res://artifacts/v2-performance.json",FileAccess.WRITE)
 report.store_string(JSON.stringify(rows,"  "))
 get_tree().quit()

var rows: Array[Dictionary] = []
func measure(stage: String) -> void:
 var count: int = 0
 var process_ms: float = 0.0
 var physics_ms: float = 0.0
 var started: int = Time.get_ticks_msec()
 var route_before: int = arena.navigation.route_queries
 var whisker_before: int = arena.navigation.whisker_queries
 var route_time: int = arena.navigation.route_usec
 var whisker_time: int = arena.navigation.whisker_usec
 while Time.get_ticks_msec()-started < 2000:
  await get_tree().process_frame
  count += 1
  process_ms += Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
  physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0
 var row: Dictionary = {"stage":stage,"frames":count,"real_ms":Time.get_ticks_msec()-started,"process_ms":process_ms/float(count),"physics_ms":physics_ms/float(count),"fps":float(count)*1000.0/float(Time.get_ticks_msec()-started),"route_queries":arena.navigation.route_queries-route_before,"whisker_rays":arena.navigation.whisker_queries-whisker_before,"route_ms_total":float(arena.navigation.route_usec-route_time)/1000.0,"whisker_ms_total":float(arena.navigation.whisker_usec-whisker_time)/1000.0,"units":arena.units_for(0).size()+arena.units_for(1).size(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
 rows.append(row)
 print("PERF " + JSON.stringify(row))
