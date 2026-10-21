extends Node

var arena: MainArena
var blue_deploy_left: float = 4.0
var report_left: float = 30.0
var skill_left: float = 15.0
var peak_population: int = 0
var peak_projectiles: int = 0
var frame_count: int = 0
var failures: Array[String] = []
var started_at: int = 0
var blue_cycle: int = 0
var initialized: bool = false
var conditional: bool = false
var generated_boundary: bool = false

func _ready() -> void:
 seed(20261020)
 conditional = "--conditional" in OS.get_cmdline_user_args()
 generated_boundary = "--boundary" in OS.get_cmdline_user_args()
 if conditional:
  for kind: String in UnitCatalog.TYPES:
   var program: Dictionary = UnitTacticProgram.default_program(kind)
   program["rules"] = [{"id":"critical_retreat","when":{"fact":"self_hp","op":"lt","value":0.25},"actions":{"behavior":"retreat","skill_usage":"hold"}},{"id":"visible_skill","when":{"all":[{"fact":"skill_ready","op":"eq","value":true},{"fact":"target_visible","op":"eq","value":true}]},"actions":{"skill_usage":"try"}}]
   TacticalBrain.save_opening_program(program)
 if generated_boundary:
  var checked: Dictionary = UnitTacticProgram.parse(FileAccess.get_file_as_string("res://artifacts/boundary-generated-1.json"),"triangle")
  if not checked["ok"]:
   push_error("Simulation requires valid generated boundary program")
   get_tree().quit(1)
   return
  TacticalBrain.save_opening_program(checked["program"])
 await get_tree().process_frame
 var scene: PackedScene = load("res://scenes/main_arena.tscn") as PackedScene
 arena = scene.instantiate() as MainArena
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--map="): arena.map_id = argument.trim_prefix("--map=")
 add_child(arena)
 for team: int in range(2):
  for index: int in range(21):
   arena.spawn_unit(UnitCatalog.TYPES[index%4],team)
 arena.start_match()
 started_at = Time.get_ticks_msec()
 initialized = true
 print("SIM_START seed=20261020 population=60")

func _physics_process(delta: float) -> void:
 if not initialized:
  return
 frame_count += 1
 var blue: int = arena.units_for(0).size()
 var red: int = arena.units_for(1).size()
 peak_population = maxi(peak_population,blue+red)
 peak_projectiles = maxi(peak_projectiles,get_tree().get_nodes_in_group("projectiles").size())
 if blue > 30 or red > 30:
  failures.append("population limit exceeded")
 if arena.hex_counts[0] > 2 or arena.hex_counts[1] > 2:
  failures.append("commander limit exceeded")
 if arena.flux[0] < 0.0 or arena.flux[1] < 0.0:
  failures.append("negative economy")
 blue_deploy_left -= delta
 skill_left -= delta
 report_left -= delta
 if blue_deploy_left <= 0.0 and arena.phase == MainArena.Phase.PLAYING:
  blue_deploy_left = 4.0
  if arena.hex_counts[0] == 0 and arena.flux[0] >= 120:
   arena.deploy("hexagon")
  else:
   arena.deploy(UnitCatalog.TYPES[blue_cycle%4])
   blue_cycle += 1
 if skill_left <= 0.0 and arena.phase == MainArena.Phase.PLAYING:
  skill_left = 15.0
  var enemy_list: Array[BaseGeoUnit] = arena.units_for(1)
  if not enemy_list.is_empty() and arena.skill_reason("EMP_STRIKE").is_empty():
   arena.cast_skill("EMP_STRIKE",enemy_list[0].global_position)
  if not conditional and arena.override_left == 0.0 and not arena.communication_jammed:
   arena.submit_tactic("侧翼切后排，棱镜折射")
 if report_left <= 0.0:
  report_left = 30.0
  print("SIM_TICK t=%d blue=%d red=%d hp=%.0f/%.0f flux=%.0f/%.0f" % [arena.elapsed,blue,red,arena.bases[0].current_hp,arena.bases[1].current_hp,arena.flux[0],arena.flux[1]])
 if arena.phase == MainArena.Phase.ENDED:
  var report: Dictionary = {
   "conditional":conditional,"generated_boundary":generated_boundary,"map":arena.map_id,"seed":20261020,"winner":arena.winner_team,"reason":arena.end_reason,"simulated_seconds":arena.elapsed,
   "real_seconds":float(Time.get_ticks_msec()-started_at)/1000.0,"physics_frames":frame_count,
   "peak_population":peak_population,"peak_projectiles":peak_projectiles,"failures":failures,
   "blue_hp":arena.bases[0].current_hp,"red_hp":arena.bases[1].current_hp
  }
  var prefix: String = "boundary-original-simulation-" if generated_boundary else "ai-lab-simulation-" if conditional else "launcher-simulation-"
  var file: FileAccess = FileAccess.open("res://artifacts/"+prefix+arena.map_id+".json",FileAccess.WRITE)
  file.store_string(JSON.stringify(report,"  "))
  print("SIM_RESULT " + JSON.stringify(report))
  get_tree().quit(0 if failures.is_empty() and peak_population == 60 else 1)
 elif frame_count > 37000:
  push_error("Simulation did not finish within the match budget")
  get_tree().quit(1)
