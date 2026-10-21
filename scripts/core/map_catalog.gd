class_name MapCatalog
extends RefCounted

const IDS: Array[String] = ["balanced", "flanks", "refraction"]
const TITLES: Array[String] = ["均衡前线", "双翼迂回", "折光阵列"]
const DESCRIPTIONS: Array[String] = ["标准对局。利用掩体稳住前线，争夺南北能源点。", "中央长墙迫使部队绕行。分推上下两路，寻找包抄时机。", "开放中场，六处晶簇提供折射机会。让菱形与前线协同。"]

static func definition(id: String = "balanced") -> Dictionary:
 assert(id in IDS, "Unknown map: " + id)
 var index: int = IDS.find(id)
 var walls: Array[Dictionary] = []
 var pillar: PackedVector2Array = PackedVector2Array([Vector2(-70,-22),Vector2(53,-22),Vector2(70,22),Vector2(-53,22)])
 if id == "balanced":
  walls.append({"position":Vector2(1020,520),"angle":deg_to_rad(25),"polygon":pillar})
  walls.append({"position":Vector2(1380,830),"angle":deg_to_rad(205),"polygon":pillar})
 elif id == "flanks":
  var slab: PackedVector2Array = PackedVector2Array([Vector2(-60,-180),Vector2(60,-180),Vector2(60,180),Vector2(-60,180)])
  walls.append({"position":Vector2(1040,675),"angle":0.0,"polygon":slab})
  walls.append({"position":Vector2(1360,675),"angle":PI,"polygon":slab})
 var bunker: PackedVector2Array = PackedVector2Array([Vector2(-80,-70),Vector2(80,-70),Vector2(80,70),Vector2(52,70),Vector2(52,-42),Vector2(-80,-42)])
 for y: float in [380.0,970.0]:
  var oriented: PackedVector2Array = bunker.duplicate()
  if y > 675:
   for n: int in range(oriented.size()): oriented[n].y *= -1
  walls.append({"position":Vector2(560,y),"angle":0.0,"polygon":oriented})
  walls.append({"position":Vector2(1840,1350-y),"angle":PI,"polygon":oriented})
 var crystals: Array[Vector2] = [Vector2(1200,140),Vector2(1200,1210),Vector2(880,675),Vector2(1520,675)]
 if id == "refraction": crystals.append_array([Vector2(1080,470),Vector2(1320,880)])
 return {"id":id,"title":TITLES[index],"description":DESCRIPTIONS[index],"walls":walls,"crystals":crystals,"fields":[Vector2(920,320),Vector2(1480,1030)]}
