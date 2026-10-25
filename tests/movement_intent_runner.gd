extends Node

var passed: int = 0
var failed: int = 0
var outcomes: Array[Dictionary] = []

func check(ok: bool, title: String) -> void:
 if ok: passed += 1
 else:
  failed += 1
  push_error("MOVEMENT_INTENT_FAIL " + title)
 print(("PASS " if ok else "FAIL ") + title)

func _ready() -> void:
 for map_id: String in MapCatalog.IDS:
  for team: int in range(2): await probe(map_id,team)
 var output: FileAccess = FileAccess.open("res://artifacts/movement-intent-report.json",FileAccess.WRITE)
 output.store_string(JSON.stringify({"passed":passed,"failed":failed,"outcomes":outcomes},"  "))
 print("MOVEMENT_INTENT_RESULT passed=%d failed=%d" % [passed,failed])
 get_tree().quit(0 if failed == 0 else 1)

func probe(map_id: String, team: int) -> void:
 var viewport: SubViewport = SubViewport.new()
 viewport.world_2d = World2D.new()
 add_child(viewport)
 var arena: LaboratoryArena = LaboratoryArena.new()
 arena.comparison = true
 arena.map_id = map_id
 arena.layout = [LaboratoryPresets.unit("square",team,1000 if team == 0 else 1400,130),LaboratoryPresets.unit("square",1-team,1400 if team == 0 else 1000,130)]
 viewport.add_child(arena)
 await get_tree().physics_frame
 var unit: BaseGeoUnit = arena.units_for(team)[0]
 for other: BaseGeoUnit in arena.local_units:
  other.attack_left = 999
  other.skill_left = 999
  other.decision_left = 999
  if other != unit: other.scripted_control = true
 unit.decide_tactic()
 unit.decision_left = 999
 var label: String = "%s team=%d" % [map_id,team]
 var queries: int = arena.navigation.route_queries
 unit.movement_velocity(1.0/60)
 check(arena.navigation.route_queries-queries == 1,"one final route query for pursuit/formation " + label)
 var home: Vector2 = arena.base_for(team).position + Vector2(130 if team == 0 else -130,0)
 unit.rule["behavior"] = "retreat"
 unit.rule["skill_usage"] = "hold"
 unit.movement_velocity(1.0/60)
 var entry: Dictionary = arena.navigation.routes.get(unit.get_instance_id(),{})
 check(entry.get("intent") == "retreat" and (entry.get("goal",Vector2.INF) as Vector2).is_equal_approx(home),"retreat owns route immediately before refresh deadline " + label)
 unit.rule["behavior"] = "hold"
 unit.velocity = Vector2.ZERO
 queries = arena.navigation.route_queries
 check(unit.movement_velocity(1.0/60).is_zero_approx() and arena.navigation.route_queries == queries,"hold does not request or follow an intermediate route " + label)
 unit.rule["behavior"] = "normal"
 unit.movement_velocity(1.0/60)
 entry = arena.navigation.routes.get(unit.get_instance_id(),{})
 check(entry.get("intent","") != "retreat" and not entry.is_empty(),"resume replaces retreat without waiting " + label)
 unit.rule["behavior"] = "retreat"
 var initial: Vector2 = unit.position
 arena.start()
 for frame: int in range(300): await get_tree().physics_frame
 check(unit.position.distance_to(home) < initial.distance_to(home)-20 and int(arena.totals[team]["skills"]) == 0,"physical retreat advances home through real terrain " + label)
 outcomes.append({"map":map_id,"team":team,"initial":str(initial),"position":str(unit.position),"initial_home_distance":initial.distance_to(home),"final_home_distance":unit.position.distance_to(home)})
 viewport.queue_free()
 await get_tree().process_frame
