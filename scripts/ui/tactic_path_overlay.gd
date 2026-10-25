class_name TacticPathOverlay
extends Control

var view: LaboratoryView
var label_font: Font

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 label_font = CommanderTheme.create().default_font

func screen_point(point: Vector2) -> Vector2:
 return (point-view.camera.position)*view.camera.zoom+size*0.5

func _draw() -> void:
 if not is_instance_valid(view) or not is_instance_valid(view.camera): return
 if not view.path_obstacle.is_empty():
  for wall: TerrainWall in view.context.navigation.walls:
   if str(wall.get_meta("obstacle_id",""))!=view.path_obstacle: continue
   var outline: PackedVector2Array=[]
   for point: Vector2 in wall.transform*wall.polygon: outline.append(screen_point(point))
   outline.append(outline[0])
   draw_polyline(outline,Color(1,0.8,0.3),3,true)
   draw_string(label_font,outline[0]+Vector2(6,-6),view.path_obstacle,HORIZONTAL_ALIGNMENT_LEFT,-1,GameSettings.font_px(14),CommanderTheme.TEXT)
 var points: PackedVector2Array = []
 for point: Array in view.path_points: points.append(screen_point(Vector2(point[0],point[1])))
 if points.size()>1: draw_polyline(points,CommanderTheme.ACCENT,2,true)
 for i: int in range(points.size()):
  draw_circle(points[i],7,CommanderTheme.ACCENT)
  draw_string(label_font,points[i]+Vector2(10,-8),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,GameSettings.font_px(14),CommanderTheme.TEXT)
 var unit: BaseGeoUnit = view.selected_unit
 if not is_instance_valid(unit) or unit.execution==null: return
 var run: TacticExecution = unit.execution
 if run.goal.is_finite():
  draw_line(screen_point(unit.global_position),screen_point(run.goal),Color(1,0.8,0.3),1,true)
  draw_arc(screen_point(run.goal),9,0,TAU,24,Color(1,0.8,0.3),2,true)
 if run.cover_point.is_finite():
  draw_arc(screen_point(run.cover_point),14,0,TAU,24,Color(0.3,1,0.5),2,true)
 if is_instance_valid(view.context.navigation):
  var route: Dictionary = view.context.navigation.routes.get(unit.get_instance_id(),{})
  var path: PackedVector2Array = route.get("path",PackedVector2Array())
  var projected: PackedVector2Array = []
  for point: Vector2 in path: projected.append(screen_point(point))
  if projected.size()>1: draw_polyline(projected,Color(0.3,1,0.5,0.6),1,true)
