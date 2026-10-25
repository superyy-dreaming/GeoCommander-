class_name MapCatalog
extends RefCounted

## Canonical map geometry, shared by previews, navigation and combat.
const SPACE_VERSION: int = 3
const WORLD_SIZE: Vector2 = Vector2(2400,1350)
const WORLD_RECT: Rect2 = Rect2(Vector2.ZERO,WORLD_SIZE)
const CENTER: Vector2 = WORLD_SIZE*0.5
const UNIT_SAFE_MARGIN: float = 28.0
const IDS: Array[String] = ["balanced","flanks","refraction","spiral_fortress","crossfire","crystal_maze"]
const TITLES: Array[String] = ["均衡前线","双翼迂回","折光阵列","盘旋堡垒","交叉火线","晶脉迷城"]
const DESCRIPTIONS: Array[String] = [
 "标准三路对称防线，中路两侧设量子隐匿星云与动态升降闸门，攻守兼备。",
 "南北外侧铺设顺时针单向矢量加速轨，配合侧翼隐匿星云实现高速包抄。",
 "中央三向分光棱镜与六颗折光晶簇构成激光火力网。分光后每束射程650px。",
 "斜向装甲胸墙构成S型走廊，一对相位虫洞连接两端，实现跨地形奇袭。",
 "X型装甲走廊配两对虫洞、动态闸门与星云，战线瞬息万变。",
 "中央反应堆每55秒过载，预警6秒后造成160伤害，并产生三个各50 Flux的晶体。"
]
static var validation_cache: Dictionary = {}

static func base_positions(_map_id: String = "balanced") -> Array[Vector2]:
 return [Vector2(240,675),Vector2(2160,675)]

static func prism_positions(map_id: String = "balanced") -> Array[Vector2]:
 match map_id:
  "flanks": return [Vector2(880,310),Vector2(1520,1040)]
  "refraction": return [Vector2(1200,260),Vector2(1200,1090)]
  "spiral_fortress": return [Vector2(1380,280),Vector2(1020,1070)]
  "crossfire": return [Vector2(840,280),Vector2(1560,1070)]
  "crystal_maze": return [Vector2(1200,200),Vector2(1200,1150)]
 return [Vector2(1200,230),Vector2(1200,1120)]

static func lane_targets() -> Array[Vector2]:
 return [Vector2(1200,240),CENTER,Vector2(1200,1110)]

static func mirror(point: Vector2) -> Vector2:
 return WORLD_SIZE-point

static func chamfer(w: float,h: float) -> PackedVector2Array:
 var c: float = minf(w,h)*0.28
 return PackedVector2Array([Vector2(-w/2+c,-h/2),Vector2(w/2-c,-h/2),Vector2(w/2,-h/2+c),Vector2(w/2,h/2-c),Vector2(w/2-c,h/2),Vector2(-w/2+c,h/2),Vector2(-w/2,h/2-c),Vector2(-w/2,-h/2+c)])

static func chevron() -> PackedVector2Array:
 return PackedVector2Array([Vector2(-28,-85),Vector2(18,0),Vector2(-28,85),Vector2(6,85),Vector2(50,0),Vector2(6,-85)])

static func trapezoid(w: float,inner: float,h: float) -> PackedVector2Array:
 return PackedVector2Array([Vector2(-w/2,-h/2),Vector2(w/2,-h/2),Vector2(inner/2,h/2),Vector2(-inner/2,h/2)])

static func _wall(list: Array[Dictionary], id: String, point: Vector2, angle: float, polygon: PackedVector2Array, archetype: String) -> void:
 list.append({"id":id,"position":point,"angle":deg_to_rad(angle),"polygon":polygon,"archetype":archetype})

static func _pair(list: Array[Dictionary],id: String,p: Vector2,a: float,poly: PackedVector2Array,kind: String) -> void:
 _wall(list,id,p,a,poly,kind)
 _wall(list,id+"_mirror",mirror(p),a+180,poly,kind)

static func _mechanic(list: Array[Dictionary],id: String,kind: String,p: Vector2,a: float = 0,pair_id: String = "") -> void:
 list.append({"id":id,"kind":kind,"position":p,"angle":deg_to_rad(a),"pair_id":pair_id})

static func definition(id: String = "balanced") -> Dictionary:
 assert(id in IDS,"Unknown map: "+id)
 var walls: Array[Dictionary] = []
 var mechanics: Array[Dictionary] = []
 var crystal_points: Array[Vector2] = []
 var fields: Array[Vector2] = []
 match id:
  "balanced":
   _pair(walls,"bastion",Vector2(540,675),0,chamfer(68,150),"bastion")
   _pair(walls,"bunker_north",Vector2(760,350),-20,trapezoid(155,100,36),"bunker")
   _pair(walls,"bunker_south",Vector2(760,1000),20,trapezoid(155,100,36),"bunker")
   crystal_points.assign([Vector2(680,260),Vector2(1720,1090),Vector2(960,940),Vector2(1440,410)])
   fields.assign([Vector2(840,675),Vector2(1560,675)])
   _mechanic(mechanics,"gate_north","gate",Vector2(960,410),-25)
   _mechanic(mechanics,"gate_south","gate",Vector2(1440,940),-25)
   _mechanic(mechanics,"nebula_north","nebula",Vector2(1200,460))
   _mechanic(mechanics,"nebula_south","nebula",Vector2(1200,890))
  "flanks":
   _pair(walls,"bastion",Vector2(980,520),18,chamfer(170,52),"bastion")
   _pair(walls,"wing_north",Vector2(580,380),28,chevron(),"chevron")
   _pair(walls,"wing_south",Vector2(580,970),-28,chevron(),"chevron")
   crystal_points.assign([Vector2(1200,380),Vector2(1200,970)])
   fields.assign([CENTER])
   _mechanic(mechanics,"rail_north","rail",Vector2(1200,130))
   _mechanic(mechanics,"rail_south","rail",Vector2(1200,1220),180)
   _mechanic(mechanics,"nebula_north","nebula",Vector2(1520,310))
   _mechanic(mechanics,"nebula_south","nebula",Vector2(880,1040))
  "refraction":
   for y: float in [450.0,900.0]:
    _pair(walls,"pillar_"+str(int(y)),Vector2(580,y),0,ProceduralGeo.get_regular_polygon(48,6),"pillar")
   for x: float in [960.0,1440.0]:
    _pair(walls,"bunker_"+str(int(x)),Vector2(x,200),0,trapezoid(145,95,34),"bunker")
   crystal_points.assign([Vector2(920,410),Vector2(920,940),Vector2(1480,410),Vector2(1480,940),Vector2(1200,450),Vector2(1200,900)])
   fields.assign([Vector2(740,675),Vector2(1660,675)])
   _mechanic(mechanics,"central_splitter","splitter",CENTER)
  "spiral_fortress":
   _pair(walls,"wing",Vector2(560,460),22,chevron(),"chevron")
   _pair(walls,"rampart_outer",Vector2(740,900),-32,trapezoid(165,110,38),"bunker")
   _pair(walls,"rampart_inner",Vector2(1040,560),-32,trapezoid(165,110,38),"bunker")
   crystal_points.assign([CENTER,Vector2(780,675),Vector2(1620,675)])
   fields.assign([Vector2(940,290),Vector2(1460,1060)])
   _mechanic(mechanics,"portal_a","portal",Vector2(480,200),0,"pair_a")
   _mechanic(mechanics,"portal_b","portal",Vector2(1920,1150),180,"pair_a")
  "crossfire":
   _pair(walls,"cross_north",Vector2(950,490),34,chamfer(160,44),"bastion")
   _pair(walls,"cross_south",Vector2(950,860),-34,chamfer(160,44),"bastion")
   crystal_points.assign([CENTER,Vector2(640,675),Vector2(1760,675)])
   _mechanic(mechanics,"portal_a1","portal",Vector2(520,210),0,"pair_a")
   _mechanic(mechanics,"portal_a2","portal",Vector2(1880,1140),180,"pair_a")
   _mechanic(mechanics,"portal_b1","portal",Vector2(520,1140),0,"pair_b")
   _mechanic(mechanics,"portal_b2","portal",Vector2(1880,210),180,"pair_b")
   _mechanic(mechanics,"gate_north","gate",Vector2(1200,420))
   _mechanic(mechanics,"gate_south","gate",Vector2(1200,930))
   _mechanic(mechanics,"nebula_north","nebula",Vector2(1560,280))
   _mechanic(mechanics,"nebula_south","nebula",Vector2(840,1070))
  "crystal_maze":
   _pair(walls,"reactor_shield",Vector2(1200,410),0,trapezoid(150,96,36),"bunker")
   _pair(walls,"pocket",Vector2(700,980),25,chamfer(145,44),"bastion")
   for y: float in [520.0,830.0]:
    _pair(walls,"pillar_"+str(int(y)),Vector2(540,y),0,ProceduralGeo.get_regular_polygon(46,6),"pillar")
   crystal_points.assign([Vector2(1000,390),Vector2(1400,390),Vector2(1000,960),Vector2(1400,960),Vector2(660,340),Vector2(1740,1010)])
   _mechanic(mechanics,"nebula_blue","nebula",Vector2(740,675))
   _mechanic(mechanics,"nebula_red","nebula",Vector2(1660,675))
   _mechanic(mechanics,"reactor","reactor",CENTER)
 var crystals: Array[Dictionary] = []
 for index: int in range(crystal_points.size()):
  crystals.append({"id":"crystal_"+str(index),"position":crystal_points[index],"radius":38.0})
 var zones: Array[Dictionary] = []
 for index: int in range(fields.size()): zones.append({"id":"entropy_"+str(index),"position":fields[index],"radius":110.0})
 var bases: Array[Dictionary]=[]
 var prisms: Array[Dictionary]=[]
 var lanes: Array[Dictionary]=[]
 for index: int in range(2):
  bases.append({"id":"base_blue" if index==0 else "base_red","position":base_positions(id)[index],"team":index})
  prisms.append({"id":"energy_north" if index==0 else "energy_south","position":prism_positions(id)[index]})
 for index: int in range(3): lanes.append({"id":["lane_north","lane_mid","lane_south"][index],"position":lane_targets()[index]})
 return {"id":id,"title":TITLES[IDS.find(id)],"description":DESCRIPTIONS[IDS.find(id)],"space_version":SPACE_VERSION,"walls":walls,"crystals":crystals,"fields":fields,"zones":zones,"mechanics":mechanics,"bases":base_positions(id),"prisms":prism_positions(id),"lanes":lane_targets(),"base_specs":bases,"prism_specs":prisms,"lane_specs":lanes}

static func solid_specs(data: Dictionary) -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 for wall: Dictionary in data["walls"]:
  result.append({"id":wall["id"],"polygon":Transform2D(wall["angle"],wall["position"])*(wall["polygon"] as PackedVector2Array)})
 for item: Dictionary in data["crystals"]:
  result.append({"id":item["id"],"polygon":Transform2D(0,item["position"])*ProceduralGeo.get_regular_polygon(38,4)})
 for item: Dictionary in data["mechanics"]:
  if item["kind"] in ["gate","splitter"]:
   var shape: PackedVector2Array = PackedVector2Array([Vector2(-75,-9),Vector2(75,-9),Vector2(75,9),Vector2(-75,9)]) if item["kind"]=="gate" else ProceduralGeo.get_regular_polygon(48,32)
   result.append({"id":item["id"],"polygon":Transform2D(item["angle"],item["position"])*shape})
 return result

static func validate_layout(id: String) -> Dictionary:
 if validation_cache.has(id): return validation_cache[id].duplicate(true)
 var data: Dictionary = definition(id)
 var errors: Array[String] = []
 var seen: Dictionary = {}
 for group: String in ["walls","crystals","zones","mechanics","base_specs","prism_specs","lane_specs"]:
  for item: Dictionary in data[group]:
   if seen.has(item["id"]): errors.append("重复ID："+item["id"])
   seen[item["id"]] = true
   if not WORLD_RECT.has_point(item["position"]): errors.append("中心越界："+item["id"])
 for team: int in range(2):
  if not WORLD_RECT.grow(-76).has_point(data["bases"][team]): errors.append("基地越界："+str(team))
  if mirror(data["bases"][team]).distance_to(data["bases"][1-team])>0.05: errors.append("基地不对称")
  if not WORLD_RECT.grow(-86).has_point(data["prisms"][team]): errors.append("能源点越界："+str(team))
  if mirror(data["prisms"][team]).distance_to(data["prisms"][1-team])>0.05: errors.append("能源点不对称")
 var pairs: Dictionary={}
 for group: String in ["zones","mechanics"]:
  for item: Dictionary in data[group]:
   var kind: String=str(item.get("kind","entropy"))
   var shape: PackedVector2Array
   match kind:
    "rail": shape=PackedVector2Array([Vector2(-340,-43),Vector2(340,-43),Vector2(340,43),Vector2(-340,43)])
    "gate": shape=PackedVector2Array([Vector2(-75,-9),Vector2(75,-9),Vector2(75,9),Vector2(-75,9)])
    _: shape=ProceduralGeo.get_regular_polygon(float(item.get("radius",{"nebula":115,"portal":40,"reactor":210,"splitter":48}.get(kind,110))),6)
   for point: Vector2 in Transform2D(item.get("angle",0),item["position"])*shape:
    if not WORLD_RECT.has_point(point): errors.append("区域轮廓越界："+item["id"])
   var symmetric: bool=false
   for counterpart: Dictionary in data[group]:
    if counterpart.get("kind","entropy")==kind and mirror(item["position"]).distance_to(counterpart["position"])<0.05:
     symmetric=true
     if kind=="rail" and absf(wrapf(counterpart["angle"]-item["angle"]-PI,-PI,PI))>0.05: symmetric=false
   if not symmetric: errors.append("区域不对称："+item["id"])
   if kind=="portal":
    var pair_id: String=item["pair_id"]
    pairs[pair_id]=int(pairs.get(pair_id,0))+1
 for pair_id: String in pairs:
  if pairs[pair_id]!=2: errors.append("虫洞配对数量无效："+pair_id)
 var solids: Array[Dictionary] = solid_specs(data)
 var minimum: float = INF
 for i: int in range(solids.size()):
  var a: PackedVector2Array = solids[i]["polygon"]
  for p: Vector2 in a:
   if not WORLD_RECT.has_point(p): errors.append("轮廓越界："+solids[i]["id"])
  for j: int in range(i+1,solids.size()):
   var b: PackedVector2Array = solids[j]["polygon"]
   if not Geometry2D.intersect_polygons(a,b).is_empty(): errors.append("实体相交：%s / %s" % [solids[i]["id"],solids[j]["id"]])
   for p: Vector2 in a:
    for k: int in range(b.size()): minimum = minf(minimum,p.distance_to(Geometry2D.get_closest_point_to_segment(p,b[k],b[(k+1)%b.size()])))
   for p: Vector2 in b:
    for k: int in range(a.size()): minimum = minf(minimum,p.distance_to(Geometry2D.get_closest_point_to_segment(p,a[k],a[(k+1)%a.size()])))
  var matched: bool = false
  for other: Dictionary in solids:
   var b: PackedVector2Array = other["polygon"]
   if b.size()!=a.size(): continue
   var equal: bool = true
   for point: Vector2 in a:
    var nearest: float = INF
    for q: Vector2 in b: nearest = minf(nearest,mirror(point).distance_to(q))
    if nearest>0.05: equal=false; break
   if equal: matched=true; break
  if not matched: errors.append("轮廓不对称："+solids[i]["id"])
 var result: Dictionary = {"ok":errors.is_empty(),"errors":errors,"solid_count":solids.size(),"minimum_clearance":minimum}
 validation_cache[id]=result
 return result.duplicate(true)

static func prompt_summary(map_id: String) -> String:
 var data: Dictionary = definition(map_id if map_id in IDS else IDS[0])
 var objects: Array = []
 for group: String in ["walls","crystals","zones","mechanics"]:
  for item: Dictionary in data[group]:
   objects.append({"id":item["id"],"kind":item.get("kind",group),"center":[item["position"].x,item["position"].y]})
 return "。当前地图=%s，空间版本=%d，大小=2400x1350，对象=%s。方向移动不转向，目的地移动自动绕障。地形语义目标可用rail_entry/rail_exit/portal/nebula/splitter_firing/safe_zone/flux_crystal；传送与拾取完成必须检查portal_used/flux_collected真实事件。" % [data["id"],SPACE_VERSION,JSON.stringify(objects)]

static func migrate_point(point: Vector2, source_version: int) -> Vector2:
 return point*0.75 if source_version == 2 else point

static func migrate_program_coordinates(program: Variant, source_version: int) -> Dictionary:
 # Space 2 used 3200x1800; spaces 1 and 3 both use 2400x1350.
 # Keep semantic anchors untouched and migrate only explicit map coordinates.
 if not program is Dictionary or source_version >= SPACE_VERSION:
  return program.duplicate(true) if program is Dictionary else {}
 var migrated: Dictionary = program.duplicate(true)
 if not migrated.get("plan") is Dictionary:
  return migrated
 var plan: Dictionary = migrated["plan"]
 if not plan.get("steps") is Array:
  return migrated
 for raw_step: Variant in plan["steps"]:
  if not raw_step is Dictionary:
   continue
  var step: Dictionary = raw_step
  if step.get("path") is Array:
   var path: Array = []
   for raw_point: Variant in step["path"]:
    if _numeric_point(raw_point):
     var point := migrate_point(Vector2(float(raw_point[0]),float(raw_point[1])),source_version)
     path.append([point.x,point.y])
    else:
     path.append(raw_point)
   step["path"] = path
  if step.get("goal") is Dictionary:
   var goal: Dictionary = step["goal"]
   if goal.get("anchor","") == "point" and _numeric_point(goal.get("point")):
    var goal_point := migrate_point(Vector2(float(goal["point"][0]),float(goal["point"][1])),source_version)
    goal["point"] = [goal_point.x,goal_point.y]
   step["goal"] = goal
  if step.get("skill_request") is Dictionary:
   var request: Dictionary = step["skill_request"]
   if request.get("aim","") == "point" and _numeric_point(request.get("point")):
    var aim_point := migrate_point(Vector2(float(request["point"][0]),float(request["point"][1])),source_version)
    request["point"] = [aim_point.x,aim_point.y]
   step["skill_request"] = request
  raw_step = step
 migrated["plan"] = plan
 return migrated

static func _numeric_point(value: Variant) -> bool:
 return value is Array and value.size()==2 and UnitTacticProgram.numeric(value[0]) and UnitTacticProgram.numeric(value[1])
