class_name TerrainRuntime
extends Node2D

signal terrain_event(unit: BaseGeoUnit, event: String, object_id: String)
var arena: CombatContext
var navigation: ArenaObstacles
var clock: float = 0.0
var objects: Array[TerrainObject] = []
var splitters: Array[TriSplitter] = []
var pairs: Dictionary = {}
var pickups: Array[Dictionary] = []
var pending_pickups: Array[Dictionary] = []
var pickup_retry_at: float = 0.0
var topology_version: int = 0
var last_reactor_cycle: int = 0
var warning_cycle: int = -1
var local_flux: Array[int] = [0,0]
var tick_usec: int = 0
var perception_usec: int = 0

func build(data: Dictionary) -> void:
 for spec: Dictionary in data["mechanics"]:
  if spec["kind"]=="splitter":
   var splitter: TriSplitter = TriSplitter.new()
   splitter.arena = arena
   splitter.runtime = self
   splitter.position = spec["position"]
   splitter.set_meta("obstacle_id",spec["id"])
   add_child(splitter)
   splitters.append(splitter)
  else:
   var object: TerrainObject = TerrainObject.new()
   object.spec = spec
   object.runtime = self
   add_child(object)
   objects.append(object)
   if spec["kind"]=="portal":
    var id: String = spec["pair_id"]
    if not pairs.has(id): pairs[id] = {"charges":5,"recharge":0.0,"ends":[]}
    pairs[id]["ends"].append(object)

func _physics_process(delta: float) -> void:
 if not arena.is_combat_active(): return
 var started: int = Time.get_ticks_usec()
 clock += delta
 for pair: Dictionary in pairs.values():
  if pair["charges"]==0:
   pair["recharge"] = maxf(0.0,pair["recharge"]-delta)
   if pair["recharge"]<=0:
    pair["charges"]=5
    topology_changed()
 for unit: BaseGeoUnit in arena.local_units:
  if not is_instance_valid(unit) or unit.dead: continue
  var was_ready: bool = unit.teleport_cooldown<=0
  unit.teleport_cooldown = maxf(0,unit.teleport_cooldown-delta)
  unit.portal_boost_left = maxf(0,unit.portal_boost_left-delta)
  unit.gate_push_velocity = Vector2.ZERO
  if not was_ready and unit.teleport_cooldown<=0: navigation.routes.erase(unit.get_instance_id())
  refresh_regions(unit)
 for object: TerrainObject in objects:
  match object.spec["kind"]:
   "gate": update_gate(object)
   "portal":
    var pair: Dictionary = pairs[object.spec["pair_id"]]
    object.status = "%d/5次" % pair["charges"] if pair["charges"]>0 else "恢复中"
   "reactor":
    var cycle: int = int(floor(clock/55.0))
    object.status = "过载预警" if fmod(clock,55.0)>=49 else "过载 %.0fs" % (55-fmod(clock,55.0))
    if fmod(clock,55.0)>=49 and warning_cycle!=cycle:
     warning_cycle=cycle
     terrain_event.emit(null,"reactor_warning",object.spec["id"])
    if cycle>last_reactor_cycle:
     last_reactor_cycle=cycle
     detonate(object,cycle)
  object.queue_redraw()
 for splitter: TriSplitter in splitters: splitter.queue_redraw()
 if not pending_pickups.is_empty() and clock>=pickup_retry_at: spawn_pending_pickups()
 for unit: BaseGeoUnit in arena.local_units.duplicate():
  if is_instance_valid(unit) and not unit.dead and unit.teleport_cooldown<=0: try_portal(unit)
 collect_pickups()
 tick_usec += Time.get_ticks_usec()-started
 queue_redraw()

func refresh_regions(unit: BaseGeoUnit) -> void:
 unit.nebula_ids.clear()
 for object: TerrainObject in objects:
  if object.spec["kind"]=="nebula" and Geometry2D.is_point_in_polygon(object.to_local(unit.global_position),ProceduralGeo.get_regular_polygon(115,6)):
   unit.nebula_ids.append(str(object.spec["id"]))
 unit.modulate.a = 0.45 if not unit.nebula_ids.is_empty() else 1.0
 # Area enter/exit events lag teleportation by a physics frame; synchronize sources.
 for field: EntropyField in navigation.fields:
  if Geometry2D.is_point_in_polygon(field.to_local(unit.global_position),ProceduralGeo.get_regular_polygon(field.radius,6)):
   field._entered(unit)
  else: field._exited(unit)

func can_perceive(observer: BaseGeoUnit, target: BaseGeoUnit) -> bool:
 var started: int = Time.get_ticks_usec()
 var visible: bool = target.nebula_ids.is_empty() or observer.global_position.distance_squared_to(target.global_position)<=145.0*145.0 or float(target.revealed_until.get(observer.team,0))>clock
 if not visible:
  for id: String in observer.nebula_ids:
   if id in target.nebula_ids: visible=true; break
 perception_usec += Time.get_ticks_usec()-started
 return visible

func reveal(team: int, center: Vector2, radius: float, seconds: float = 3.0) -> void:
 for unit: BaseGeoUnit in arena.units_for(1-team):
  if unit.global_position.distance_squared_to(center)<=radius*radius:
   unit.revealed_until[team] = maxf(float(unit.revealed_until.get(team,0)),clock+seconds)

func speed_multiplier(unit: BaseGeoUnit, active_direction: Vector2) -> float:
 var value: float = 1.35 if unit.portal_boost_left>0 else 1.0
 if active_direction.is_zero_approx(): return value
 for object: TerrainObject in objects:
  if object.spec["kind"]!="rail" or not Rect2(-340,-43,680,86).has_point(object.to_local(unit.global_position)): continue
  var dot: float = active_direction.normalized().dot(Vector2.RIGHT.rotated(object.rotation))
  value *= 1.75 if dot>=0.1 else (0.65 if dot< -0.2 else 1.0)
 return value

func topology_changed() -> void:
 topology_version += 1
 navigation.refresh_solids()
 navigation.build_graph()
 navigation.routes.clear()

func gate_occupants(gate: TerrainObject) -> Array[BaseGeoUnit]:
 var result: Array[BaseGeoUnit] = []
 for unit: BaseGeoUnit in arena.local_units:
  if not is_instance_valid(unit) or unit.dead: continue
  var local: Vector2 = gate.to_local(unit.global_position)
  if absf(local.x)<75+unit.unit_radius and absf(local.y)<9+unit.unit_radius+2: result.append(unit)
 return result

func update_gate(gate: TerrainObject) -> void:
 var wants_closed: bool = fmod(clock,35.0)<20.0
 if not wants_closed:
  gate.set_closed(false)
  gate.status="开放"
  gate.blocked_reason=""
  return
 if gate.closed: return
 var occupants: Array[BaseGeoUnit] = gate_occupants(gate)
 if occupants.is_empty():
  gate.blocked_reason=""
  gate.status="闭合"
  gate.set_closed(true)
  return
 gate.status="推离中"
 for unit: BaseGeoUnit in occupants:
  var p: Vector2 = gate.to_local(unit.global_position)
  var side: float = signf(p.y) if absf(p.y)>0.1 else (1.0 if unit.spawn_index%2==0 else -1.0)
  var destination: Vector2 = gate.to_global(Vector2(p.x,side*(unit.unit_radius+13)))
  if not safe_point(destination,unit.unit_radius,unit):
   gate.blocked_reason="关闭受阻：无安全推离空间"
   gate.status="受阻开放"
   return
 gate.blocked_reason=""
 for unit: BaseGeoUnit in occupants:
  var side: float = signf(gate.to_local(unit.global_position).y)
  if side==0: side=1 if unit.spawn_index%2==0 else -1
  unit.gate_push_velocity = Vector2(0,side*150).rotated(gate.rotation)

func safe_point(point: Vector2, radius: float, ignored: BaseGeoUnit = null) -> bool:
 if not MapCatalog.WORLD_RECT.grow(-radius-3).has_point(point): return false
 for polygon: PackedVector2Array in navigation.solid_polygons:
  if Geometry2D.is_point_in_polygon(point,polygon): return false
  for i: int in range(polygon.size()):
   if point.distance_to(Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()]))<radius+3: return false
 var shape: CircleShape2D=CircleShape2D.new()
 shape.radius=radius+2
 var query: PhysicsShapeQueryParameters2D=PhysicsShapeQueryParameters2D.new()
 query.shape=shape
 query.transform=Transform2D(0,point)
 query.collision_mask=4|16
 if ignored!=null: query.exclude=arena.friendly_shield_rids(ignored.team)
 if not get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(): return false
 for unit: BaseGeoUnit in arena.local_units:
  if is_instance_valid(unit) and not unit.dead and unit!=ignored and point.distance_to(unit.global_position)<radius+unit.unit_radius+3: return false
 for base: CoreMatrixBase in arena.local_bases:
  if point.distance_to(base.global_position)<radius+base.unit_radius+3: return false
 return true

func try_portal(unit: BaseGeoUnit) -> bool:
 if unit.dead or unit.teleport_cooldown>0 or not arena.is_combat_active() or not navigation.portal_allowed(unit): return false
 for pair_id: String in pairs:
  var pair: Dictionary = pairs[pair_id]
  if pair["charges"]<=0 or pair["ends"].size()!=2: continue
  for index: int in range(2):
   var entry: TerrainObject = pair["ends"][index]
   if unit.global_position.distance_to(entry.global_position)>40: continue
   var exit: TerrainObject = pair["ends"][1-index]
   var landing: Vector2 = Vector2.INF
   for attempt: int in range(25):
    var candidate: Vector2 = exit.global_position if attempt==0 else exit.global_position+Vector2.from_angle(attempt*2.4)*(45+floor(attempt/8.0)*30)
    if safe_point(candidate,unit.unit_radius,unit): landing=candidate; break
   if not landing.is_finite():
    unit.action_blocked="虫洞出口没有安全落点，未消耗次数"
    return false
   # One synchronous commit, after every prerequisite has passed.
   unit.global_position=landing
   unit.teleport_cooldown=8.0
   unit.portal_boost_left=2.0
   unit.portal_used_count+=1
   if unit.unit_type=="triangle": unit.set("dash_previous",landing)
   unit.active_velocity=Vector2.ZERO
   unit.trail_line.clear_points()
   navigation.routes.erase(unit.get_instance_id())
   pair["charges"]-=1
   if pair["charges"]==0: pair["recharge"]=14.0
   refresh_regions(unit)
   topology_changed()
   terrain_event.emit(unit,"portal_used",str(entry.spec["id"]))
   return true
 return false

func detonate(reactor: TerrainObject, cycle: int) -> void:
 for unit: BaseGeoUnit in arena.local_units.duplicate():
  if is_instance_valid(unit) and not unit.dead and unit.global_position.distance_to(reactor.global_position)<=210: unit.take_damage(160,reactor)
 for index: int in range(3):
  var desired: Vector2 = reactor.global_position+Vector2.from_angle(index*TAU/3+(cycle-1)*PI/3)*225
  pending_pickups.append({"id":"flux_%d_%d" % [cycle,index],"desired":desired,"reactor":reactor,"amount":50})
 spawn_pending_pickups()

func spawn_pending_pickups() -> void:
 # Rewards remain owned by this context until a legal spawn can be committed.
 # Occupancy can change without a topology event, so retry at a simulation-time
 # cadence. Preparation, pause and end never advance this retry clock.
 pickup_retry_at=clock+0.5
 for index: int in range(pending_pickups.size()-1,-1,-1):
  var pending: Dictionary=pending_pickups[index]
  var point: Vector2 = Vector2.INF
  for attempt: int in range(40):
   var candidate: Vector2 = pending["desired"]+Vector2.from_angle(attempt*2.4)*sqrt(attempt)*12
   if safe_point(candidate,12): point=candidate; break
  if point.is_finite():
   pickups.append({"id":pending["id"],"position":point,"amount":pending["amount"]})
   pending_pickups.remove_at(index)
 for object: TerrainObject in objects:
  if object.spec["kind"]!="reactor": continue
  var count: int=0
  for pending: Dictionary in pending_pickups:
   if pending["reactor"]==object: count+=1
  object.blocked_reason="晶体落点受阻：%d个等待安全空间" % count if count>0 else ""

func collect_pickups() -> void:
 for index: int in range(pickups.size()-1,-1,-1):
  var item: Dictionary = pickups[index]
  var winner: BaseGeoUnit = null
  var distance: float = INF
  for unit: BaseGeoUnit in arena.local_units:
   if not is_instance_valid(unit) or unit.dead: continue
   var current: float = unit.global_position.distance_squared_to(item["position"])
   if current>24*24: continue
   if current<distance-0.01 or (absf(current-distance)<0.01 and (winner==null or unit.spawn_index*2+unit.team<winner.spawn_index*2+winner.team)):
    winner=unit
    distance=current
  if winner!=null:
   winner.flux_collected_count+=1
   local_flux[winner.team]+=50
   arena.flux_pickup_reported.emit(winner,50)
   terrain_event.emit(winner,"flux_collected",item["id"])
   pickups.remove_at(index)

func portal_available(unit: BaseGeoUnit) -> bool:
 if unit.teleport_cooldown>0: return false
 for pair: Dictionary in pairs.values():
  if pair["charges"]>0: return true
 return false

func any_gate_open() -> bool:
 for object: TerrainObject in objects:
  if object.spec["kind"]=="gate" and not object.closed: return true
 return false

func strategy_goal(unit: BaseGeoUnit, original: Vector2, policy: String = "") -> Vector2:
 if policy.is_empty(): policy=str(unit.rule.get("terrain_strategy","auto"))
 if policy in ["auto","avoid_hazards","collect_flux"] and warning_at(unit):
  return semantic_goal(unit,"safe_zone")
 if policy=="collect_flux":
  var item: Vector2=semantic_goal(unit,"flux_crystal")
  return item if item.is_finite() else original
 if policy=="nebula" and unit.unit_type in ["diamond","triangle"]:
  var pocket: Vector2=semantic_goal(unit,"nebula")
  return pocket if pocket.is_finite() else original
 if policy=="splitter" and unit.unit_type=="diamond":
  var firing: Vector2=semantic_goal(unit,"splitter_firing")
  return firing if firing.is_finite() else original
 if policy=="portals" and portal_available(unit):
  var best: Vector2=Vector2.INF
  var cost: float=unit.global_position.distance_to(original)
  for pair: Dictionary in pairs.values():
   if pair["charges"]<=0: continue
   for index: int in range(2):
    var entry: TerrainObject=pair["ends"][index]
    var exit: TerrainObject=pair["ends"][1-index]
    var trial: float=unit.global_position.distance_to(entry.global_position)+exit.global_position.distance_to(original)
    if trial<cost: cost=trial; best=entry.global_position
  return best if best.is_finite() else original
 if policy=="rails":
  var forward: Vector2=Vector2.RIGHT if unit.team==0 else Vector2.LEFT
  for object: TerrainObject in objects:
   if object.spec["kind"]!="rail": continue
   var heading: Vector2=Vector2.RIGHT.rotated(object.rotation)
   if heading.dot(forward)<0.1: continue
   var local: Vector2=object.to_local(unit.global_position)
   if local.x>300: continue
   return object.to_global(Vector2(-300 if local.x< -280 or absf(local.y)>70 else 310,0))
 return original

func semantic_goal(unit: BaseGeoUnit, anchor: String) -> Vector2:
 var best: Vector2 = Vector2.INF
 var score: float = INF
 if anchor=="portal" and unit.teleport_cooldown>0: return Vector2.INF
 if anchor=="flux_crystal":
  for item: Dictionary in pickups:
   var d: float = unit.global_position.distance_squared_to(item["position"])
   if d<score: best=item["position"]; score=d
  return best
 for object: TerrainObject in objects:
  var kind: String = object.spec["kind"]
  var candidate: Vector2 = object.global_position
  if anchor in ["rail_entry","rail_exit"] and kind=="rail": candidate += Vector2(-300 if anchor=="rail_entry" else 300,0).rotated(object.rotation)
  elif anchor=="safe_zone" and kind=="reactor":
   var heading: Vector2=object.global_position.direction_to(unit.global_position)
   if heading.is_zero_approx(): heading=Vector2.LEFT if unit.team==0 else Vector2.RIGHT
   var safe: Vector2=Vector2.INF
   for index: int in range(24):
    var trial: Vector2=object.global_position+heading.rotated(index*TAU/24)*280
    if safe_point(trial,unit.unit_radius,unit): safe=trial; break
   if not safe.is_finite(): continue
   candidate=safe
  elif anchor!=kind: continue
  if kind=="portal" and pairs[object.spec["pair_id"]]["charges"]<=0: continue
  var d: float = unit.global_position.distance_squared_to(candidate)
  if d<score: best=candidate; score=d
 if anchor=="splitter_firing" and not splitters.is_empty():
  best=unit.call("crystal_firing_position") if unit.unit_type=="diamond" else Vector2.INF
 return best

func warning_at(unit: BaseGeoUnit) -> bool:
 for object: TerrainObject in objects:
  if object.spec["kind"]=="reactor" and fmod(clock,55.0)>=49 and unit.global_position.distance_to(object.global_position)<=250: return true
 return false

func _draw() -> void:
 for pair: Dictionary in pairs.values():
  if pair["ends"].size()!=2: continue
  var a: Vector2=pair["ends"][0].position
  var b: Vector2=pair["ends"][1].position
  for i: int in range(24): draw_line(a.lerp(b,i/24.0),a.lerp(b,(i+0.3)/24.0),Color(0.6,0.3,0.9,0.15),1,true)
 for item: Dictionary in pickups:
  draw_set_transform(item["position"])
  draw_colored_polygon(ProceduralGeo.get_regular_polygon(12,4),Color(1.6,1.1,0.2))
  draw_string(ThemeDB.fallback_font,Vector2(-12,-18),"+50",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(1,0.9,0.5))
 draw_set_transform(Vector2.ZERO)

func _exit_tree() -> void:
 for unit: BaseGeoUnit in arena.local_units:
  if is_instance_valid(unit):
   unit.nebula_ids.clear()
   unit.revealed_until.clear()
   unit.modulate.a=1.0
   unit.portal_boost_left=0
   unit.gate_push_velocity=Vector2.ZERO
