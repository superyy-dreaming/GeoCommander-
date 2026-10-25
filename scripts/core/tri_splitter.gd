class_name TriSplitter
extends LaserReflector

var runtime: TerrainRuntime
var radius: float = 48.0

func _ready() -> void:
 collision_layer = 4|16
 collision_mask = 3
 var shape: CollisionShape2D = CollisionShape2D.new()
 var circle: CircleShape2D = CircleShape2D.new()
 circle.radius = radius
 shape.shape = circle
 add_child(shape)

func _draw() -> void:
 TerrainArt.mechanism(self,"splitter",runtime.clock if not arena.reduced_motion else 0.0)
