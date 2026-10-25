class_name CoverPlanner
extends RefCounted

static func claim_query(nav: ArenaObstacles) -> bool:
 var frame: int=Engine.get_physics_frames()
 if nav.cover_frame!=frame:
  nav.cover_frame=frame
  nav.cover_frame_queries=0
 if nav.cover_frame_queries>=2: return false
 nav.cover_frame_queries+=1
 return true

static func hidden(unit: BaseGeoUnit, point: Vector2, threat: Node2D) -> bool:
 if not is_instance_valid(threat) or not is_instance_valid(unit.arena.navigation): return false
 var side: Vector2 = threat.global_position.direction_to(point).orthogonal()*unit.unit_radius*0.8
 for offset: Vector2 in [Vector2.ZERO,side,-side]:
  var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(threat.global_position,point+offset,16|4,unit.arena.friendly_shield_rids(1-unit.team))
  var excluded: Array[RID]=ray.exclude
  excluded.append(unit.get_rid())
  ray.exclude = excluded
  var hit: Dictionary = unit.get_world_2d().direct_space_state.intersect_ray(ray)
  # Only opaque walls count as reliable cover. Crystals can reflect lasers.
  if hit.is_empty() or not hit["collider"] is TerrainWall: return false
 return true

static func find(unit: BaseGeoUnit, threat: Node2D, obstacle: String = "") -> Dictionary:
 if not is_instance_valid(threat): return {"ok":false,"message":"没有可遮挡的威胁目标"}
 if not is_instance_valid(unit.arena.navigation): return {"ok":false,"message":"当前场景没有掩体"}
 var nav: ArenaObstacles = unit.arena.navigation
 # Bound expensive route checks. Requests remain visible and wait their turn;
 # physics time continues, and no alternate behavior is substituted.
 if not claim_query(nav): return {"ok":false,"pending":true,"message":"掩体查询排队中"}
 var started: int = Time.get_ticks_usec()
 var candidates: Array[Dictionary] = []
 var cache_key: String = obstacle+":"+str(ceili(unit.unit_radius))
 if not nav.cover_candidates.has(cache_key):
  var geometry: Array[Dictionary] = []
  for wall: TerrainWall in nav.walls:
   var id: String = str(wall.get_meta("obstacle_id",""))
   if not obstacle.is_empty() and id != obstacle: continue
   for polygon: PackedVector2Array in Geometry2D.offset_polygon(wall.transform*wall.polygon,maxf(40,unit.unit_radius+12)):
    for i: int in range(polygon.size()):
     for point: Vector2 in [polygon[i],(polygon[i]+polygon[(i+1)%polygon.size()])*0.5]:
      if not MapCatalog.WORLD_RECT.grow(-40.0).has_point(point) or not nav.segment_clear(point,point): continue
      geometry.append({"point":point,"obstacle":id})
  nav.cover_candidates[cache_key]=geometry
 for candidate: Dictionary in nav.cover_candidates[cache_key]:
  candidates.append({"point":candidate["point"],"obstacle":candidate["obstacle"],"score":unit.global_position.distance_squared_to(candidate["point"])})
 candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a["score"]<b["score"])
 var result: Dictionary = {"ok":false,"message":"没有可达且遮挡该目标直射的墙体后方"}
 for candidate: Dictionary in candidates:
  var point: Vector2 = candidate["point"]
  if hidden(unit,point,threat):
   var route: PackedVector2Array=nav.make_route(unit.global_position,point)
   if not route.is_empty():
    result = {"ok":true,"point":point,"route":route,"obstacle":candidate["obstacle"],"message":"遮挡指定目标直射，不免疫范围攻击"}
    break
 unit.arena.cover_queries += 1
 unit.arena.cover_usec += Time.get_ticks_usec()-started
 return result

static func peek(unit: BaseGeoUnit, origin: Vector2, threat: Node2D) -> Vector2:
 return peek_route(unit,origin,threat).get("point",Vector2.INF)

static func peek_route(unit: BaseGeoUnit, origin: Vector2, threat: Node2D) -> Dictionary:
 if not is_instance_valid(threat) or not is_instance_valid(unit.arena.navigation): return {}
 var nav: ArenaObstacles = unit.arena.navigation
 if not claim_query(nav): return {"pending":true,"message":"探出点查询排队中"}
 var started: int=Time.get_ticks_usec()
 unit.arena.cover_queries+=1
 for radius: float in [60.0,110.0,180.0,260.0,360.0,480.0,640.0]:
  for index: int in range(16):
   var point: Vector2 = origin+Vector2.RIGHT.rotated(index*TAU/16.0)*radius
   if not MapCatalog.WORLD_RECT.grow(-40.0).has_point(point) or not nav.segment_clear(point,point): continue
   var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(point,threat.global_position,4|16,unit.arena.friendly_shield_rids(unit.team))
   if unit.get_world_2d().direct_space_state.intersect_ray(query).is_empty():
    var route: PackedVector2Array=nav.make_route(unit.global_position,point)
    if not route.is_empty():
     unit.arena.cover_usec+=Time.get_ticks_usec()-started
     return {"point":point,"route":route}
 unit.arena.cover_usec+=Time.get_ticks_usec()-started
 return {}
