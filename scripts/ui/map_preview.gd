class_name MapPreview
extends Control

var map_id: String = "balanced":
 set(value):
  map_id = value
  if is_node_ready(): rebuild()
var viewport: SubViewport
var display: MapDisplay
var telemetry: Label

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 custom_minimum_size = Vector2(320,180)
 viewport = SubViewport.new()
 viewport.size = Vector2i(1200,675)
 viewport.world_2d = World2D.new()
 viewport.use_hdr_2d = true
 viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
 add_child(viewport)
 CombatContext.create_environment(viewport,MapCatalog.WORLD_RECT)
 var camera: Camera2D = Camera2D.new()
 camera.position = MapCatalog.CENTER
 camera.zoom = Vector2.ONE*0.5
 viewport.add_child(camera)
 var texture: TextureRect = TextureRect.new()
 texture.texture = viewport.get_texture()
 texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
 texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(texture)
 telemetry = Label.new()
 telemetry.mouse_filter = Control.MOUSE_FILTER_IGNORE
 CommanderTheme.font(telemetry,13)
 telemetry.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 telemetry.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
 telemetry.offset_left=10
 telemetry.offset_right=-10
 telemetry.offset_top=10
 add_child(telemetry)
 resized.connect(queue_redraw)
 rebuild()

func rebuild() -> void:
 if is_instance_valid(display):
  viewport.remove_child(display)
  display.queue_free()
 display = MapDisplay.new()
 display.map_id = map_id
 display.preview = true
 viewport.add_child(display)
 var checked: Dictionary = MapCatalog.validate_layout(map_id)
 telemetry.text = "2400×1350 · "+("几何检查通过" if checked["ok"] else "布局待修复："+"；".join(checked["errors"]))
 telemetry.tooltip_text = "实际最小实体间距 %.1fpx；通行以路由测试为准" % checked["minimum_clearance"]
 queue_redraw()

func _draw() -> void:
 var factor: float = minf(size.x/MapCatalog.WORLD_SIZE.x,size.y/MapCatalog.WORLD_SIZE.y)
 var rect: Rect2 = Rect2((size-MapCatalog.WORLD_SIZE*factor)*0.5,MapCatalog.WORLD_SIZE*factor)
 for point: Vector2 in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
  var toward: Vector2 = (rect.get_center()-point).sign()
  draw_line(point,point+Vector2(toward.x*22,0),Color(0.35,0.85,1),2,true)
  draw_line(point,point+Vector2(0,toward.y*22),Color(0.35,0.85,1),2,true)
 for y: int in range(int(rect.position.y),int(rect.end.y),8):
  draw_line(Vector2(rect.position.x,y),Vector2(rect.end.x,y),Color(0.2,0.6,0.8,0.025),1)
