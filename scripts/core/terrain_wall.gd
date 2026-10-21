class_name TerrainWall
extends StaticBody2D

var polygon: PackedVector2Array = []

func _ready() -> void:
 collision_layer = 16
 collision_mask = 3
 var collision: CollisionPolygon2D = CollisionPolygon2D.new()
 collision.polygon = polygon
 add_child(collision)

func _draw() -> void:
 draw_colored_polygon(polygon,Color(0.04,0.06,0.10,0.95))
 var closed: PackedVector2Array = polygon.duplicate()
 closed.append(polygon[0])
 draw_polyline(closed,Color(0.35,0.55,1.4),3.0,true)
 var inset: PackedVector2Array = []
 for point: Vector2 in polygon:
  inset.append(point * 0.72)
 inset.append(inset[0])
 draw_polyline(inset,Color(0.17,0.28,0.45),1.0,true)
