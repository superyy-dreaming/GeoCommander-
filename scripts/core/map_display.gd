class_name MapDisplay
extends Node2D

var map_id: String = "balanced"
var preview: bool = false
var data: Dictionary = {}
var age: float = 0.0

func _ready() -> void:
 data = MapCatalog.definition(map_id)
 z_index = -10 if not preview else 0

func _process(delta: float) -> void:
 if not preview: return
 if not bool(GameSettings.values["reduced_motion"]): age += delta
 queue_redraw()

func _draw() -> void:
 if data.is_empty(): return
 TerrainArt.floor(self,data)
 if not preview: return
 var portal_pairs: Dictionary={}
 for item: Dictionary in data["mechanics"]:
  if item["kind"]!="portal": continue
  if portal_pairs.has(item["pair_id"]):
   var a: Vector2=portal_pairs[item["pair_id"]]
   var b: Vector2=item["position"]
   for i: int in range(32): draw_line(a.lerp(b,i/32.0),a.lerp(b,(i+0.4)/32.0),Color(0.6,0.3,0.9,0.2),1,true)
  else: portal_pairs[item["pair_id"]]=item["position"]
 for zone: Dictionary in data["zones"]:
  draw_set_transform(zone["position"])
  TerrainArt.entropy(self,zone["radius"])
 for wall: Dictionary in data["walls"]:
  draw_set_transform(wall["position"],wall["angle"])
  TerrainArt.wall(self,wall["polygon"])
 for item: Dictionary in data["crystals"]:
  draw_set_transform(item["position"])
  TerrainArt.crystal(self)
 for item: Dictionary in data["mechanics"]:
  draw_set_transform(item["position"],item["angle"])
  TerrainArt.mechanism(self,item["kind"],age,"闭合" if item["kind"]=="gate" else "",1.0)
 for point: Vector2 in data["prisms"]:
  draw_set_transform(point)
  TerrainArt.energy(self)
 for team: int in range(2):
  draw_set_transform(data["bases"][team])
  TerrainArt.base(self,team)
 draw_set_transform(Vector2.ZERO)
