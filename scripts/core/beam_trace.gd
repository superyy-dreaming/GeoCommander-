class_name BeamTrace
extends RefCounted

# segments is authoritative for both linear and branched beams. points/gains
# retain the legacy linear trace contract for existing callers and recordings.
var points: PackedVector2Array = []
var gains: Array[float] = []
var normals: Array[Vector2] = []
var segments: Array[Dictionary] = []
var bounces: int = 0
var split_count: int = 0

static func trace(context: CombatContext, origin: Vector2, heading: Vector2, caster: BaseGeoUnit = null) -> BeamTrace:
 var result: BeamTrace = BeamTrace.new()
 result.points.append(origin)
 if heading.is_zero_approx(): return result
 result.trace_branch(context,origin,heading.normalized(),750.0,1.0,0,0,false,caster)
 return result

func trace_branch(context: CombatContext, origin: Vector2, heading: Vector2, length: float, gain: float, reflections: int, branch: int, has_split: bool, caster: BaseGeoUnit, emitter: TriSplitter = null) -> void:
 var start: Vector2 = origin
 var direction: Vector2 = heading
 var remaining: float = length
 var ray_start: Vector2 = start
 # A branch is emitted from the prism surface. Its first outgoing ray starts
 # outside the fixed shell, while that distance remains in its 650px budget.
 if is_instance_valid(emitter):
  var offset: Vector2 = start-emitter.global_position
  var along: float = offset.dot(direction)
  var exit_distance: float = -along+sqrt(maxf(0,along*along+emitter.radius*emitter.radius-offset.length_squared()))+0.8
  ray_start = start+direction*maxf(0.8,exit_distance)
 while remaining>0.01:
  var finish: Vector2 = start+direction*remaining
  var hit: Dictionary = {}
  if ray_start.distance_to(start)<remaining:
   var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(ray_start,finish,4|16)
   hit = context.get_world_2d().direct_space_state.intersect_ray(query)
  if not hit.is_empty(): finish=hit["position"]
  var normal: Vector2 = Vector2.ZERO if hit.is_empty() else hit["normal"]
  segments.append({"start":start,"end":finish,"gain":gain,"normal":normal,"branch":branch,"reflections":reflections})
  if branch==0:
   points.append(finish)
   gains.append(gain)
   normals.append(normal)
  remaining -= start.distance_to(finish)
  if hit.is_empty(): return
  var collider: Object = hit["collider"]
  if collider is TriSplitter:
   if has_split: return
   split_count += 1
   var center_direction: Vector2 = normal
   var best: float = INF
   if is_instance_valid(caster):
    for enemy: BaseGeoUnit in context.perceived_enemies(caster):
     var distance: float = finish.distance_squared_to(enemy.global_position)
     if distance<best:
      best=distance
      center_direction=finish.direction_to(enemy.global_position)
   if center_direction.is_zero_approx(): center_direction=-direction
   for index: int in range(3):
    var angle: float = 0.0 if index==0 else deg_to_rad(-26.0 if index==1 else 26.0)
    trace_branch(context,finish,center_direction.rotated(angle),650.0,gain*(0.85 if index==0 else 0.75),reflections,index+1,true,caster,collider as TriSplitter)
   return
  if not collider is LaserReflector or reflections>=2 or remaining<=0.8: return
  direction=direction.bounce(normal).normalized()
  gain *= (collider as LaserReflector).amplification
  reflections += 1
  bounces=maxi(bounces,reflections)
  start=finish+direction*0.8
  ray_start=start
  remaining-=0.8

func hits(point: Vector2, radius: float) -> bool:
 for segment: Dictionary in segments:
  if Geometry2D.get_closest_point_to_segment(point,segment["start"],segment["end"]).distance_to(point)<=radius: return true
 return false
