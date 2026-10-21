class_name ArenaObstacles
extends Node2D

var arena: CombatContext
var walls: Array[TerrainWall] = []
var crystals: Array[NeutralCrystal] = []
var fields: Array[EntropyField] = []
var solid_polygons: Array[PackedVector2Array] = []
var clearance_polygons: Array[PackedVector2Array] = []
var graph: AStar2D = AStar2D.new()
var routes: Dictionary = {}
var route_queries: int = 0
var whisker_queries: int = 0
var route_usec: int = 0
var whisker_usec: int = 0

func build(map_id: String = "balanced") -> void:
 var data: Dictionary = MapCatalog.definition(map_id)
 for spec: Dictionary in data["walls"]:
  add_wall(spec["position"],spec["angle"],spec["polygon"])
 for point: Vector2 in data["crystals"]:
  var crystal: NeutralCrystal = NeutralCrystal.new()
  crystal.arena = arena
  crystal.position = point
  add_child(crystal)
  crystals.append(crystal)
  add_polygon(crystal.polygon,crystal.transform)
 for point: Vector2 in data["fields"]:
  var field: EntropyField = EntropyField.new()
  field.arena = arena
  field.position = point
  add_child(field)
  fields.append(field)
 build_graph()

func add_wall(point: Vector2, angle: float, shape: PackedVector2Array) -> TerrainWall:
 var wall: TerrainWall = TerrainWall.new()
 wall.position = point
 wall.rotation = angle
 wall.polygon = shape
 add_child(wall)
 walls.append(wall)
 add_polygon(shape,wall.transform)
 return wall

func add_polygon(shape: PackedVector2Array, transform: Transform2D) -> void:
 var world_shape: PackedVector2Array = transform * shape
 solid_polygons.append(world_shape)
 for polygon: PackedVector2Array in Geometry2D.offset_polygon(world_shape,32.0,Geometry2D.JOIN_MITER):
  clearance_polygons.append(polygon)

func segment_clear(start: Vector2, finish: Vector2) -> bool:
 for polygon: PackedVector2Array in clearance_polygons:
  if Geometry2D.is_point_in_polygon(start,polygon) or Geometry2D.is_point_in_polygon(finish,polygon):
   return false
  for index: int in range(polygon.size()):
   if Geometry2D.segment_intersects_segment(start,finish,polygon[index],polygon[(index+1)%polygon.size()]) != null:
    return false
 return true

func build_graph() -> void:
 graph.clear()
 var points: PackedVector2Array = []
 for polygon: PackedVector2Array in solid_polygons:
  for expanded: PackedVector2Array in Geometry2D.offset_polygon(polygon,36.0,Geometry2D.JOIN_MITER):
   for point: Vector2 in expanded:
    if Rect2(40,40,2320,1270).has_point(point):
     points.append(point)
 for y: float in [260.0,675.0,1090.0]:
  for x: float in [700.0,1200.0,1700.0]:
   points.append(Vector2(x,y))
 for index: int in range(points.size()):
  graph.add_point(index,points[index])
 for first: int in range(points.size()):
  for second: int in range(first+1,points.size()):
   if segment_clear(points[first],points[second]):
    graph.connect_points(first,second)

func make_route(start: Vector2, goal: Vector2) -> PackedVector2Array:
 route_queries += 1
 var started: int = Time.get_ticks_usec()
 if segment_clear(start,goal):
  route_usec += Time.get_ticks_usec()-started
  return PackedVector2Array([goal])
 graph.add_point(10000,start)
 graph.add_point(10001,goal)
 for id: int in graph.get_point_ids():
  if id >= 10000:
   continue
  var point: Vector2 = graph.get_point_position(id)
  if segment_clear(start,point): graph.connect_points(10000,id)
  if segment_clear(goal,point): graph.connect_points(10001,id)
 var path: PackedVector2Array = graph.get_point_path(10000,10001)
 graph.remove_point(10000)
 graph.remove_point(10001)
 if path.size() > 1: path.remove_at(0)
 route_usec += Time.get_ticks_usec()-started
 return path

func direction_for(unit: BaseGeoUnit, goal: Vector2, intent: String = "objective") -> Vector2:
 var id: int = unit.get_instance_id()
 var now: int = Engine.get_physics_frames()
 var entry: Dictionary = routes.get(id,{})
 # Reuse a route only for the same movement intent. Target motion may be
 # throttled; switching from pursuit to retreat must take effect this frame.
 if entry.is_empty() or entry.get("intent","") != intent or (now > int(entry["refresh"]) and (entry["goal"] as Vector2).distance_to(goal) > 65.0):
  entry = {"goal":goal,"intent":intent,"path":make_route(unit.global_position,goal),"index":0,"refresh":now+27}
  routes[id] = entry
 var path: PackedVector2Array = entry["path"]
 var index: int = int(entry["index"])
 while index > 0 and not segment_clear(unit.global_position,path[index]):
  index -= 1
 while index < path.size()-1 and segment_clear(unit.global_position,path[index+1]):
  index += 1
 entry["index"] = index
 if path.is_empty():
  return Vector2.ZERO
 return unit.global_position.direction_to(path[index])
