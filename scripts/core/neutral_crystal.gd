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
 TerrainArt.crystal(self)
