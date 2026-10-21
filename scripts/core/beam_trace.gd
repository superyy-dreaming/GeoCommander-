class_name BeamTrace
extends RefCounted

var points: PackedVector2Array = []
var gains: Array[float] = []
var normals: Array[Vector2] = []
var bounces: int = 0

static func trace(context: CombatContext, origin: Vector2, heading: Vector2) -> BeamTrace:
 var result: BeamTrace = BeamTrace.new()
 result.points.append(origin)
 var start: Vector2 = origin
 var direction: Vector2 = heading.normalized()
 var remaining: float = 750.0
 var gain: float = 1.0
 for segment: int in range(3):
  var finish: Vector2 = start + direction * remaining
  var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(start,finish,4 | 16)
  var hit: Dictionary = context.get_world_2d().direct_space_state.intersect_ray(query)
  if not hit.is_empty():
   finish = hit["position"]
  result.points.append(finish)
  result.gains.append(gain)
  result.normals.append(Vector2.ZERO if hit.is_empty() else hit["normal"])
  remaining -= start.distance_to(finish)
  if hit.is_empty() or not hit["collider"] is LaserReflector or segment == 2 or remaining < 1.0:
   break
  var reflector: LaserReflector = hit["collider"] as LaserReflector
  direction = direction.bounce(hit["normal"]).normalized()
  gain *= reflector.amplification
  result.bounces += 1
  start = finish + direction * 0.8
  remaining -= 0.8
 return result

func hits(point: Vector2, radius: float) -> bool:
 for index: int in range(points.size()-1):
  if Geometry2D.get_closest_point_to_segment(point,points[index],points[index+1]).distance_to(point) <= radius:
   return true
 return false
