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
 TerrainArt.wall(self,polygon)
