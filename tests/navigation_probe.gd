extends Node

class ProbeContext extends CombatContext:
 var goal: Vector2
 func objective_for(_unit: BaseGeoUnit) -> Vector2:
  return goal

var failures: int = 0
var passed: int = 0
var probes: Array[Dictionary] = []
var physics_frames: int = 0

func _ready() -> void:
 for map_id: String in MapCatalog.IDS:
  for kind: String in ["triangle","hexagon"]:
   for portals: bool in [false,true]:
    for direction: int in [0,1]:
     for lane: Vector2 in MapCatalog.lane_targets():
      var viewport: SubViewport = SubViewport.new()
      viewport.world_2d = World2D.new()
      viewport.size = Vector2i(MapCatalog.WORLD_SIZE)
      add_child(viewport)
      var context: ProbeContext = ProbeContext.new()
      context.goal = Vector2(2050 if direction == 0 else 350,lane.y)
      viewport.add_child(context)
      context.local_profiles=[TacticalBrain.get_default_profile(),TacticalBrain.get_default_profile()]
      for profile: Dictionary in context.local_profiles:
       for rule: Dictionary in profile["unit_rules"].values(): rule["terrain_strategy"]="auto" if portals else "none"
      var terrain: ArenaObstacles = ArenaObstacles.new()
      terrain.arena = context
      context.navigation = terrain
      context.add_child(terrain)
      terrain.build(map_id)
      var unit: BaseGeoUnit = (load("res://scripts/units/unit_"+kind+".gd") as Script).new() as BaseGeoUnit
      unit.arena = context
      unit.team = direction
      unit.position = Vector2(350 if direction == 0 else 2050,lane.y)
      context.add_child(unit)
      probes.append({"unit":unit,"goal":context.goal,"start":unit.position,"done":false,"map":map_id,"kind":kind,"portals":portals})
func _physics_process(_delta: float) -> void:
 physics_frames += 1
 for probe: Dictionary in probes:
  var unit: BaseGeoUnit = probe["unit"]
  if not bool(probe["done"]) and unit.position.distance_to(probe["goal"]) < 60.0:
   probe["done"] = true
   unit.set_physics_process(false)
   passed += 1
   print("NAV_PASS map=",probe["map"]," start=",probe["start"]," goal=",probe["goal"]," kind=",probe["kind"]," portals=",probe["portals"]," frames=",physics_frames)
 if passed == probes.size() or physics_frames >= 3600:
  for probe: Dictionary in probes:
   if not bool(probe["done"]):
    failures += 1
    push_error("NAV_STUCK map="+probe["map"]+" kind="+str(probe["kind"])+" portals="+str(probe["portals"])+" start="+str(probe["start"])+" pos="+str((probe["unit"] as BaseGeoUnit).position)+" route="+str((probe["unit"] as BaseGeoUnit).arena.navigation.routes.get((probe["unit"] as BaseGeoUnit).get_instance_id())))
  print("NAV_RESULT passed=%d failures=%d frames=%d" % [passed,failures,physics_frames])
  get_tree().quit(0 if failures == 0 else 1)
