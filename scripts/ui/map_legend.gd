class_name MapLegend
extends HFlowContainer

class Symbol extends Control:
 var kind: String
 func _draw() -> void:
  draw_set_transform(size*0.5,0,Vector2.ONE*0.13)
  match kind:
   "base": TerrainArt.base(self,0)
   "energy": TerrainArt.energy(self)
   "wall": TerrainArt.wall(self,MapCatalog.chamfer(140,65))
   "crystal": TerrainArt.crystal(self)
   "entropy": TerrainArt.entropy(self,110)
   _: TerrainArt.mechanism(self,kind,0,"闭合" if kind=="gate" else "",0.8)

func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_PASS
 add_theme_constant_override("h_separation",16)
 add_theme_constant_override("v_separation",10)
 for item: Array in [["base","蓝/红基地"],["energy","能源点"],["wall","装甲墙"],["crystal","折射晶簇"],["entropy","熵减区"],["splitter","中央分光"],["rail","单向加速"],["nebula","隐匿星云"],["portal","成对虫洞"],["gate","动态闸门"],["reactor","过载反应堆"]]:
  var row: HBoxContainer=HBoxContainer.new()
  row.mouse_filter=Control.MOUSE_FILTER_PASS
  var badge: PanelContainer=PanelContainer.new()
  badge.mouse_filter=Control.MOUSE_FILTER_PASS
  badge.add_theme_stylebox_override("panel",CommanderTheme.box(Color(0.025,0.08,0.11,0.9),Color(0.12,0.35,0.44)))
  add_child(badge)
  badge.add_child(row)
  var icon: Symbol=Symbol.new()
  icon.kind=item[0]
  icon.custom_minimum_size=Vector2(32,32)
  icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
  row.add_child(icon)
  var label: Label=Label.new()
  label.text=item[1]
  CommanderTheme.font(label,16)
  row.add_child(label)
