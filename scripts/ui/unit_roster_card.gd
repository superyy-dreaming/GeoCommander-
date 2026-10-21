class_name UnitRosterCard
extends Button

var kind: String = "triangle"
var compact: bool = false
var reduced_motion: bool = false
var phase: float = 0.0

func _ready() -> void:
 toggle_mode = true
 mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 custom_minimum_size = Vector2(0,112)

func _process(delta: float) -> void:
 if not reduced_motion: phase += delta*0.35
 queue_redraw()

func _draw() -> void:
 var radius: float = 17.0 if compact else 25.0
 var center: Vector2 = Vector2(28,size.y*0.5) if compact else Vector2(44,size.y*0.5)
 var transform: Transform2D = Transform2D(phase,center)
 var points: PackedVector2Array = transform*ProceduralGeo.polygon(kind,radius)
 var color: Color = ProceduralGeo.rim(kind,0)
 color = Color(color.r/2.8,color.g/2.8,color.b/2.8)
 draw_colored_polygon(points,Color(color,0.18))
 points.append(points[0])
 draw_polyline(points,color,2.0,true)
