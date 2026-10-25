class_name LaboratoryPresets
extends RefCounted

const TITLES: Array[String] = ["标准初始阵容","绕后","护盾协同","聚怪","折射","治疗"]
static func unit(kind: String, team: int, x: float, y: float, hp: float = 1.0, angle: float = 0.0) -> Dictionary:
 return {"kind":kind,"team":team,"x":x,"y":y,"hp":hp,"angle":angle if team == 0 else 180.0+angle}

static func create(index: int) -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 if index == 0:
  var kinds: Array[String] = ["hexagon","square","square","triangle","triangle","triangle","diamond","diamond","circle"]
  for team: int in range(2):
   for n: int in range(kinds.size()):
    var x: float = 340+float(n%3)*60
    result.append(unit(kinds[n],team,x if team == 0 else MapCatalog.WORLD_SIZE.x-x,500+float(n/3)*150))
 elif index == 1:
  result = [unit("triangle",0,1100,350),unit("triangle",0,1100,410),unit("diamond",1,1300,350,1,180),unit("diamond",1,1300,430,1,180)]
 elif index == 2:
  result = [unit("square",0,1500,350),unit("hexagon",0,1370,350,0.5),unit("diamond",0,1400,410),unit("diamond",1,1800,350),unit("circle",1,1770,440)]
 elif index == 3:
  result = [unit("circle",0,1450,310),unit("square",0,1420,230),unit("triangle",1,1750,250),unit("triangle",1,1810,280),unit("triangle",1,1770,340),unit("square",1,1850,360)]
 elif index == 4:
  result = [unit("diamond",0,1370,320),unit("square",0,1460,380),unit("diamond",1,1900,300),unit("square",1,1900,380),unit("hexagon",1,1900,460)]
 else:
  result = [unit("hexagon",0,1450,350),unit("square",0,1350,370,0.5),unit("triangle",0,1510,310,0.5),unit("circle",0,1480,440,0.5),unit("diamond",1,1950,400),unit("square",1,1950,500)]
 return result
