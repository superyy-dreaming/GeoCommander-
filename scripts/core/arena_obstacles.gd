class_name ArenaObstacles
extends Node2D

var arena: CombatContext
var walls: Array[TerrainWall] = []
var crystals: Array[NeutralCrystal] = []
var fields: Array[EntropyField] = []
var solid_polygons: Array[PackedVector2Array] = []
var clearance_polygons: Array[PackedVector2Array] = []
var graph: TerrainGraph = TerrainGraph.new()
var runtime: TerrainRuntime
var portal_links: Array[Vector2i] = []
var routes: Dictionary = {}
var route_queries: int = 0
var whisker_queries: int = 0
var route_usec: int = 0
var whisker_usec: int = 0
var graph_usec: int = 0
var graph_builds: int = 0
var cover_candidates: Dictionary = {}
var cover_frame: int = -1
var cover_frame_queries: int = 0

func build(map_id: String = "balanced") -> void:
 var data: Dictionary = MapCatalog.definition(map_id)
 for spec: Dictionary in data["walls"]:
  var wall: TerrainWall = add_wall(spec["position"],spec["angle"],spec["polygon"])
  wall.set_meta("obstacle_id",spec["id"])
 for item: Dictionary in data["crystals"]:
  var crystal: NeutralCrystal = NeutralCrystal.new()
  crystal.arena = arena
  crystal.position = item["position"]
  crystal.set_meta("obstacle_id",item.get("id","crystal"))
  add_child(crystal)
  crystals.append(crystal)
  add_polygon(crystal.polygon,crystal.transform)
 for spec: Dictionary in data["zones"]:
  var field: EntropyField = EntropyField.new()
  field.arena = arena
  field.position = spec["position"]
  field.radius = spec["radius"]
  field.set_meta("obstacle_id",spec["id"])
  add_child(field)
  fields.append(field)
 var floor_display: MapDisplay = MapDisplay.new()
 floor_display.map_id = map_id
 add_child(floor_display)
 runtime = TerrainRuntime.new()
 runtime.arena = arena
 runtime.navigation = self
 arena.terrain = runtime
 add_child(runtime)
 runtime.build(data)
 refresh_solids()
 build_graph()

func refresh_solids() -> void:
 solid_polygons.clear()
 clearance_polygons.clear()
 for wall: TerrainWall in walls: add_polygon(wall.polygon,wall.transform)
 for crystal: NeutralCrystal in crystals: add_polygon(crystal.polygon,crystal.transform)
 if is_instance_valid(runtime):
  for splitter: TriSplitter in runtime.splitters: add_polygon(ProceduralGeo.get_regular_polygon(48,32),splitter.transform)
  for object: TerrainObject in runtime.objects:
   if object.spec["kind"]=="gate" and object.closed: add_polygon(object.polygon(),object.transform)
 cover_candidates.clear()

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
 var started: int=Time.get_ticks_usec()
 graph_builds+=1
 graph.clear()
 graph.portal_edges.clear()
 portal_links.clear()
 var points: PackedVector2Array = []
 for polygon: PackedVector2Array in solid_polygons:
  for expanded: PackedVector2Array in Geometry2D.offset_polygon(polygon,36.0,Geometry2D.JOIN_MITER):
   for point: Vector2 in expanded:
    if MapCatalog.WORLD_RECT.grow(-40.0).has_point(point):
     points.append(point)
 for y: float in [130.0,240.0,MapCatalog.CENTER.y,1110.0,1220.0]:
  for x: float in [240.0,600.0,900.0,1200.0,1500.0,1800.0,2160.0]:
   points.append(Vector2(x,y))
 for index: int in range(points.size()):
  if segment_clear(points[index],points[index]): graph.add_point(index,points[index])
 for first: int in range(points.size()):
  for second: int in range(first+1,points.size()):
   if graph.has_point(first) and graph.has_point(second) and segment_clear(points[first],points[second]):
    graph.connect_points(first,second)

 if is_instance_valid(runtime):
  for pair: Dictionary in runtime.pairs.values():
   if pair["charges"]<=0 or pair["ends"].size()!=2: continue
   var ids: Array[int] = []
   for object: TerrainObject in pair["ends"]:
    var id: int = graph.get_available_point_id()
    var point: Vector2 = object.global_position
    graph.add_point(id,point)
    for other: int in graph.get_point_ids():
     if other!=id and segment_clear(point,graph.get_point_position(other)): graph.connect_points(id,other)
    ids.append(id)
   for edge: Vector2i in [Vector2i(ids[0],ids[1]),Vector2i(ids[1],ids[0])]:
    graph.portal_edges[edge]=true
    portal_links.append(edge)
    graph.connect_points(edge.x,edge.y,false)
 graph_usec+=Time.get_ticks_usec()-started

func make_route(start: Vector2, goal: Vector2, use_portals: bool = false) -> PackedVector2Array:
 route_queries += 1
 var started: int = Time.get_ticks_usec()
 if segment_clear(start,goal) and (not use_portals or portal_links.is_empty()):
  route_usec += Time.get_ticks_usec()-started
  return PackedVector2Array([goal])
 for edge: Vector2i in portal_links:
  graph.disconnect_points(edge.x,edge.y,false)
  if use_portals: graph.connect_points(edge.x,edge.y,false)
 graph.add_point(10000,start)
 graph.add_point(10001,goal)
 for id: int in graph.get_point_ids():
  if id >= 10000:
   continue
  var point: Vector2 = graph.get_point_position(id)
  if segment_clear(start,point): graph.connect_points(10000,id)
  if segment_clear(goal,point): graph.connect_points(10001,id)
 if segment_clear(start,goal): graph.connect_points(10000,10001)
 var path: PackedVector2Array = graph.get_point_path(10000,10001)
 graph.remove_point(10000)
 graph.remove_point(10001)
 if path.size() > 1: path.remove_at(0)
 route_usec += Time.get_ticks_usec()-started
 return path

func portal_allowed(unit: BaseGeoUnit) -> bool:
 if unit.teleport_cooldown>0: return false
 if not unit.is_plan_controlled(): return unit.rule.get("terrain_strategy","auto")!="none"
 var strategy: String=unit.execution.steps[unit.execution.current].get("terrain_strategy",unit.execution.program["base"].get("terrain_strategy","none"))
 var anchor: String=unit.execution.steps[unit.execution.current].get("goal",{}).get("anchor","")
 return strategy=="portals" or anchor=="portal"

func is_portal_hop(start: Vector2, finish: Vector2) -> bool:
 for edge: Vector2i in portal_links:
  if start.is_equal_approx(graph.get_point_position(edge.x)) and finish.is_equal_approx(graph.get_point_position(edge.y)):
   return true
 return false

func direction_for(unit: BaseGeoUnit, goal: Vector2, intent: String = "objective") -> Vector2:
 var id: int = unit.get_instance_id()
 var now: int = Engine.get_physics_frames()
 var entry: Dictionary = routes.get(id,{})
 # Reuse a route only for the same movement intent. Target motion may be
 # throttled; switching from pursuit to retreat must take effect this frame.
 var topology: int = runtime.topology_version if is_instance_valid(runtime) else 0
 var portal_ready: bool = portal_allowed(unit)
 if entry.is_empty() or entry.get("topology",-1)!=topology or entry.get("portal_ready",false)!=portal_ready or entry.get("intent","") != intent or (now > int(entry["refresh"]) and (entry["goal"] as Vector2).distance_to(goal) > 65.0):
  entry = {"goal":goal,"intent":intent,"topology":topology,"portal_ready":portal_ready,"path":make_route(unit.global_position,goal,portal_ready),"index":0,"refresh":now+27}
  routes[id] = entry
 var path: PackedVector2Array = entry["path"]
 var index: int = int(entry["index"])
 while index > 0 and unit.global_position.distance_to(path[index-1])>50 and not segment_clear(unit.global_position,path[index]):
  index -= 1
 # Ordinary corners may be skipped when the entire next segment has clearance.
 # A portal edge is an action, not a walkable shortcut: retain its entry until
 # the real teleport event invalidates this route.
 while index < path.size()-1 and not is_portal_hop(path[index],path[index+1]) and segment_clear(unit.global_position,path[index+1]):
  index += 1
 entry["index"] = index
 if path.is_empty():
  return Vector2.ZERO
 return unit.global_position.direction_to(path[index])
