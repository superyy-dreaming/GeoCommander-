class_name MapPreview
extends Control

var map_id: String = "balanced":
 set(value):
  map_id = value
  queue_redraw()

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 custom_minimum_size = Vector2(320,180)
 resized.connect(queue_redraw)

func _draw() -> void:
 var factor: float = minf(size.x/2400.0,size.y/1350.0)
 var origin: Vector2 = (size-Vector2(2400,1350)*factor)*0.5
 draw_rect(Rect2(origin,Vector2(2400,1350)*factor),Color(0.015,0.035,0.055))
 for x: int in range(0,2401,150):
  draw_line(origin+Vector2(x,0)*factor,origin+Vector2(x,1350)*factor,Color(0.06,0.14,0.19))
 for y: int in range(0,1351,150):
  draw_line(origin+Vector2(0,y)*factor,origin+Vector2(2400,y)*factor,Color(0.06,0.14,0.19))
 var data: Dictionary = MapCatalog.definition(map_id)
 for point: Vector2 in data["fields"]:
  var shape: PackedVector2Array = []
  for i: int in range(6): shape.append(origin+(point+Vector2.from_angle(i*TAU/6)*130)*factor)
  draw_colored_polygon(shape,Color(0.8,0.48,0.1,0.14))
  shape.append(shape[0])
  draw_polyline(shape,Color(0.7,0.44,0.15),1.0,true)
 for wall: Dictionary in data["walls"]:
  var shape: PackedVector2Array = Transform2D(wall["angle"],wall["position"])*(wall["polygon"] as PackedVector2Array)
  for i: int in range(shape.size()): shape[i] = origin+shape[i]*factor
  draw_colored_polygon(shape,Color(0.14,0.22,0.29))
  shape.append(shape[0])
  draw_polyline(shape,Color(0.35,0.49,0.6),1.5,true)
 for point: Vector2 in data["crystals"]:
  var shape: PackedVector2Array = []
  for offset: Vector2 in [Vector2(0,-38),Vector2(38,0),Vector2(0,38),Vector2(-38,0)]: shape.append(origin+(point+offset)*factor)
  draw_colored_polygon(shape,Color(0.4,0.86,1.0))
 for point: Vector2 in [Vector2(1200,320),Vector2(1200,1030)]:
  draw_arc(origin+point*factor,85*factor,0,TAU,32,ProceduralGeo.GOLD,2,true)
 for team: int in range(2):
  var point: Vector2 = Vector2(220 if team == 0 else 2180,675)
  var color: Color = CommanderTheme.ACCENT if team == 0 else Color(1,0.35,0.4)
  var shape: PackedVector2Array = ProceduralGeo.polygon("hexagon",65)
  for i: int in range(shape.size()): shape[i] = origin+(shape[i]+point)*factor
  draw_colored_polygon(shape,Color(color,0.3))
  shape.append(shape[0])
  draw_polyline(shape,color,2,true)
 draw_rect(Rect2(origin,Vector2(2400,1350)*factor),Color(0.18,0.4,0.5),false,1)
