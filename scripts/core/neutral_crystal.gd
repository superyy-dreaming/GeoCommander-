class_name NeutralCrystal
extends LaserReflector

var polygon: PackedVector2Array = PackedVector2Array([Vector2(38,0),Vector2(0,38),Vector2(-38,0),Vector2(0,-38)])

func _ready() -> void:
 collision_layer = 4 | 16
 collision_mask = 3
 var collision: CollisionPolygon2D = CollisionPolygon2D.new()
 collision.polygon = polygon
 add_child(collision)

func _draw() -> void:
 draw_colored_polygon(polygon,Color(0.15,0.35,0.45,0.8))
 var closed: PackedVector2Array = polygon.duplicate()
 closed.append(polygon[0])
 draw_polyline(closed,Color(1.8,2.4,2.8),2.5,true)
 for point: Vector2 in polygon:
  draw_line(Vector2.ZERO,point,Color(0.7,1.1,1.5,0.7),1.2,true)
 draw_polyline(ProceduralGeo.get_regular_polygon(19,4),Color(0.8,1.3,1.8),1.5,true)
