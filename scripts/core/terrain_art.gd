class_name TerrainArt
extends RefCounted

static func outline(c: CanvasItem, polygon: PackedVector2Array, color: Color, width: float = 1.5) -> void:
 if polygon.is_empty(): return
 var closed: PackedVector2Array = polygon.duplicate()
 closed.append(closed[0])
 c.draw_polyline(closed,color,width,true)

static func wall(c: CanvasItem, polygon: PackedVector2Array) -> void:
 c.draw_colored_polygon(Transform2D(0,Vector2.ZERO).scaled(Vector2.ONE*1.14)*polygon,Color(0.10,0.30,0.52,0.16))
 c.draw_colored_polygon(polygon,Color(0.08,0.13,0.21,0.96))
 var inner: PackedVector2Array = Transform2D(0,Vector2.ZERO).scaled(Vector2.ONE*0.58)*polygon
 for clipped: PackedVector2Array in Geometry2D.intersect_polygons(polygon,inner):
  c.draw_colored_polygon(clipped,Color(0.04,0.07,0.12,0.96))
  outline(c,clipped,Color(0.22,0.45,0.68,0.55),1.0)
 # Clip each rib to the actual concave hull, using sorted boundary crossings.
 for i: int in range(polygon.size()):
  var a: Vector2 = inner[i]
  var b: Vector2 = polygon[i]
  var cuts: Array[float] = [0.0,1.0]
  for k: int in range(polygon.size()):
   var hit: Variant = Geometry2D.segment_intersects_segment(a,b,polygon[k],polygon[(k+1)%polygon.size()])
   if hit != null and a.distance_to(b)>0: cuts.append(a.distance_to(hit)/a.distance_to(b))
  cuts.sort()
  for k: int in range(cuts.size()-1):
   if Geometry2D.is_point_in_polygon(a.lerp(b,(cuts[k]+cuts[k+1])*0.5),polygon):
    c.draw_line(a.lerp(b,cuts[k]),a.lerp(b,cuts[k+1]),Color(0.22,0.45,0.68,0.55),1.0,true)
 outline(c,polygon,Color(0.38,0.70,0.95,0.95),2.2)
 for v: Vector2 in polygon: c.draw_circle(v,2.5,Color(0.65,1.3,1.6))

static func base(c: CanvasItem, team: int, hp: float = 1.0) -> void:
 var tint: Color = ProceduralGeo.BLUE if team == 0 else ProceduralGeo.RED
 var oct: PackedVector2Array = ProceduralGeo.get_regular_polygon(76,8)
 for i: int in range(8): c.draw_line(oct[i],oct[i].lerp(oct[(i+1)%8],0.65),Color(tint,0.6),2,true)
 var hex: PackedVector2Array = ProceduralGeo.get_regular_polygon(54,6)
 c.draw_colored_polygon(hex,Color(tint,0.45))
 outline(c,hex,tint,3)
 c.draw_colored_polygon(ProceduralGeo.get_regular_polygon(26*sqrt(maxf(hp,0.0)),6),Color(tint,0.7))
 for v: Vector2 in hex: c.draw_circle(v,3,Color.WHITE)
 c.draw_line(Vector2(-9,0),Vector2(9,0),Color.WHITE,1.5)
 c.draw_line(Vector2(0,-9),Vector2(0,9),Color.WHITE,1.5)

static func energy(c: CanvasItem, capture_team: int = -1) -> void:
 var gold: Color = ProceduralGeo.GOLD if capture_team<0 else (ProceduralGeo.BLUE if capture_team==0 else ProceduralGeo.RED)
 for i: int in range(16): c.draw_arc(Vector2.ZERO,86,i*TAU/16,i*TAU/16+0.24,4,Color(gold,0.35),1.5,true)
 c.draw_arc(Vector2.ZERO,62,0,TAU,48,gold,2.5,true)
 for i: int in range(4): c.draw_line(Vector2.from_angle(i*PI/2)*57,Vector2.from_angle(i*PI/2)*70,gold,2,true)
 c.draw_colored_polygon(ProceduralGeo.get_regular_polygon(18,4),gold)
 outline(c,ProceduralGeo.get_regular_polygon(25,4),Color(gold,0.5))

static func crystal(c: CanvasItem) -> void:
 var hull: PackedVector2Array = ProceduralGeo.get_regular_polygon(38,4)
 c.draw_colored_polygon(hull,Color(0.3,0.8,1,0.13))
 outline(c,hull,Color(0.55,0.95,1,0.4))
 for angle: float in [0.0,PI/4]:
  var star: PackedVector2Array = Transform2D(angle,Vector2.ZERO)*ProceduralGeo.get_regular_polygon(26,4)
  c.draw_colored_polygon(star,Color(0.55,0.95,1,0.65))
  outline(c,star,Color(1.8,2.4,2.8),1.8)

static func entropy(c: CanvasItem, radius: float) -> void:
 var hex: PackedVector2Array = ProceduralGeo.get_regular_polygon(radius,6)
 c.draw_colored_polygon(hex,Color(0.65,0.35,0.06,0.22))
 outline(c,hex,Color(1.2,0.65,0.15,0.85),1.8)
 var inner: PackedVector2Array = ProceduralGeo.get_regular_polygon(64,6)
 outline(c,inner,Color(1.2,0.65,0.15,0.5))
 for i: int in range(6): c.draw_line(inner[i],hex[i],Color(0.9,0.6,0.2,0.4),1,true)

static func mechanism(c: CanvasItem, kind: String, time: float, status: String = "", ratio: float = 1.0) -> void:
 match kind:
  "splitter":
   var star: PackedVector2Array = []
   for i: int in range(24): star.append(Vector2.from_angle(i*TAU/24+time*0.25)*(46 if i%2==0 else 30))
   c.draw_colored_polygon(star,Color(0.55,0.9,1,0.4))
   outline(c,star,Color(2.2,2.8,3.2),2)
   outline(c,ProceduralGeo.get_regular_polygon(48,12),Color(0.5,1.1,1.5,0.5))
  "rail":
   c.draw_rect(Rect2(-340,-43,680,86),Color(0.3,0.65,0.45,0.13))
   for y: float in [-43.0,43.0]: c.draw_line(Vector2(-340,y),Vector2(340,y),Color(0.65,1.1,0.5,0.65),2,true)
   for i: int in range(9):
    var x: float = fmod(i*80+time*45,680)-340
    c.draw_polyline(PackedVector2Array([Vector2(x-10,-15),Vector2(x+8,0),Vector2(x-10,15)]),Color(1.3,1.1,0.3,0.7),2,true)
  "nebula":
   var hex: PackedVector2Array = ProceduralGeo.get_regular_polygon(115,6)
   c.draw_colored_polygon(hex,Color(0.38,0.12,0.70,0.28))
   outline(c,hex,Color(1.7,0.4,2.5,0.8),2)
   c.draw_arc(Vector2.ZERO,78,time*0.2,time*0.2+PI*1.6,36,Color(1.1,0.4,1.5,0.5),1,true)
   for i: int in range(12): c.draw_circle(Vector2.from_angle(i*2.4)*(25+i*6),1.5,Color(1,0.7,1.5,0.6))
  "portal":
   for r: float in [30.0,40.0]:
    var angle: float=time if r==30 else -time
    c.draw_arc(Vector2.ZERO,r,angle,angle+TAU*0.9,40,Color(2.2,0.5,2.6,0.9) if status!="恢复中" else Color(0.4,0.4,0.6),2,true)
   c.draw_arc(Vector2.ZERO,19,0,TAU,24,Color(0.2,1.8,2.4),2,true)
  "gate":
   for x: float in [-75.0,75.0]: c.draw_rect(Rect2(x-5,-19,10,38),Color(0.4,0.8,1))
   c.draw_rect(Rect2(-75,-9,150,18),Color(1.3,0.55,0.12,0.85) if status=="闭合" else Color(0.2,1,1.4,0.14))
   c.draw_line(Vector2(-75,-27),Vector2(-75+150*ratio,-27),Color(1,0.8,0.25),3,true)
  "reactor":
   var warning: bool = status=="过载预警"
   c.draw_colored_polygon(ProceduralGeo.get_regular_polygon(210,6),Color(0.8,0.08,0.1,0.14 if warning else 0.035))
   outline(c,ProceduralGeo.get_regular_polygon(210,6),Color(2,0.25,0.15,0.9) if warning else Color(0.8,0.4,0.15,0.35),2)
   outline(c,ProceduralGeo.get_regular_polygon(36,6),Color(1.8,0.7,0.15),3)
   c.draw_arc(Vector2.ZERO,55,-PI/2,-PI/2+TAU*ratio,48,Color(1.6,0.3,0.2),3,true)

static func floor(c: CanvasItem, data: Dictionary) -> void:
 for team: int in range(2):
  var tint: Color = ProceduralGeo.BLUE if team==0 else ProceduralGeo.RED
  var center: Vector2 = data["bases"][team]
  for i: int in range(32): c.draw_arc(center,240,i*TAU/32,i*TAU/32+0.10,4,Color(tint,0.14),2,true)
  c.draw_arc(center,360,0,TAU,80,Color(tint,0.06),1,true)
 for lane: Vector2 in data["lanes"]:
  c.draw_polyline(PackedVector2Array([data["bases"][0],Vector2(data["bases"][0].x+210,lane.y),Vector2(data["bases"][1].x-210,lane.y),data["bases"][1]]),Color(0.14,0.48,0.72,0.20),1.5,true)
 for i: int in range(18): c.draw_line(Vector2(1200,i*75),Vector2(1200,i*75+35),Color(0.2,0.45,0.7,0.18),1,true)
 outline(c,Transform2D(0,MapCatalog.CENTER)*ProceduralGeo.get_regular_polygon(270,8),Color(0.2,0.5,0.7,0.12),1)
