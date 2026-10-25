extends Node

var rows: Array[Dictionary]=[]
var failed: bool=false

func _ready() -> void:
 GameSettings.values=GameSettings.DEFAULTS.duplicate()
 GameSettings.apply_display()
 get_window().size=Vector2i(1440,900)
 RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
 for id: String in MapCatalog.IDS:
  seed(20261025)
  TacticalBrain.opening_profile=TacticalBrain.get_default_profile()
  var arena: MainArena=MainArena.new()
  arena.ai_enabled=false
  arena.map_id=id
  add_child(arena)
  for team: int in range(2):
   for index: int in range(21): arena.spawn_unit(UnitCatalog.TYPES[index%4],team)
  for unit: BaseGeoUnit in arena.local_units:
   unit.max_hp=100000
   unit.current_hp=100000
   # Place both armies near the front, on real safe map positions. Moving a
   # unit in this isolated fixture is setup, never an in-match movement path.
   var anchor: Vector2=Vector2(850 if unit.team==0 else 1550,675)
   for attempt: int in range(160):
    var point: Vector2=anchor+Vector2.from_angle(attempt*2.4)*sqrt(attempt)*28
    if arena.terrain.safe_point(point,unit.unit_radius,unit): unit.position=point; break
  for base: CoreMatrixBase in arena.bases:
   base.max_hp=100000
   base.current_hp=100000
  arena.camera.position_smoothing_enabled=false
  arena.camera.set("target_zoom",0.55)
  arena.start_match()
  # Exercise the interactive state in each map during the same sample.
  if id in ["balanced","crossfire"]: arena.terrain.clock=18.0
  if id=="crystal_maze": arena.terrain.clock=47.0
  await get_tree().create_timer(3.0).timeout
  await measure(arena)
  arena.queue_free()
  for index: int in range(8): await get_tree().process_frame
 var file: FileAccess=FileAccess.open("res://artifacts/map-overhaul-performance.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"screen_scale":DisplayServer.screen_get_scale(),"screen":str(DisplayServer.screen_get_size()),"window":str(get_window().size),"sample_seconds_per_map":8,"rows":rows},"  "))
 print("MAP_PERFORMANCE_RESULT maps=%d failures=%d" % [rows.size(),int(failed)])
 get_tree().quit(1 if failed else 0)

func measure(arena: MainArena) -> void:
 var started: int=Time.get_ticks_msec()
 var frames: int=0
 var before: Dictionary={"route":arena.navigation.route_usec,"rays":arena.navigation.whisker_usec,"graph":arena.navigation.graph_usec,"builds":arena.navigation.graph_builds,"terrain":arena.terrain.tick_usec,"perception":arena.terrain.perception_usec,"plan":arena.plan_usec,"cover":arena.cover_usec}
 var totals: Dictionary={"physics_ms":0.0,"process_ms":0.0,"render_cpu_ms":0.0,"render_gpu_ms":0.0,"render_setup_ms":0.0,"draw_calls":0.0}
 var previous: int=started
 var max_frame: int=0
 while Time.get_ticks_msec()-started<8000:
  await get_tree().process_frame
  frames+=1
  var now: int=Time.get_ticks_msec()
  max_frame=maxi(max_frame,now-previous)
  previous=now
  totals["physics_ms"]+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
  totals["process_ms"]+=Performance.get_monitor(Performance.TIME_PROCESS)*1000
  totals["render_cpu_ms"]+=RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid())
  totals["render_gpu_ms"]+=RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
  totals["render_setup_ms"]+=RenderingServer.get_frame_setup_time_cpu()
  totals["draw_calls"]+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
 var row: Dictionary={"map":arena.map_id,"units":arena.local_units.size(),"fps":frames*1000.0/(Time.get_ticks_msec()-started),"frames":frames,"max_frame_ms":max_frame,"route_ms_total":(arena.navigation.route_usec-int(before["route"]))/1000.0,"ray_ms_total":(arena.navigation.whisker_usec-int(before["rays"]))/1000.0,"graph_ms_total":(arena.navigation.graph_usec-int(before["graph"]))/1000.0,"graph_builds":arena.navigation.graph_builds-int(before["builds"]),"perception_ms_total":(arena.terrain.perception_usec-int(before["perception"]))/1000.0,"terrain_ms_total":(arena.terrain.tick_usec-int(before["terrain"]))/1000.0,"executor_ms_total":(arena.plan_usec-int(before["plan"]))/1000.0,"cover_ms_total":(arena.cover_usec-int(before["cover"]))/1000.0}
 for key: String in totals: row[key]=totals[key]/frames
 rows.append(row)
 failed=failed or row["fps"]<55 or row["units"]!=60
 print("MAP_PERF "+JSON.stringify(row))
