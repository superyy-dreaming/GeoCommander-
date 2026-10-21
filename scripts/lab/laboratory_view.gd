class_name LaboratoryView
extends Control

signal layout_edited
signal changed
signal message(text: String)
signal selected(unit: BaseGeoUnit)
var viewport: SubViewport
var image: TextureRect
var context: LaboratoryArena
var camera: Camera2D
var map_id: String = "balanced"
var layout: Array[Dictionary] = []
var place_kind: String = "triangle"
var place_team: int = 0
var place_hp: float = 1.0
var place_angle: float = 0.0
var selection: int = -1
var dragging: bool = false
var panning: bool = false
var zoom_factor: float = 1.0
var selected_unit: BaseGeoUnit
var seed_value: int = 7401

func _ready() -> void:
 custom_minimum_size = Vector2(300,160)
 mouse_filter = Control.MOUSE_FILTER_STOP
 focus_mode = Control.FOCUS_ALL
 viewport = SubViewport.new()
 viewport.size = Vector2i(960,540)
 viewport.world_2d = World2D.new()
 viewport.use_hdr_2d = true
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 add_child(viewport)
 image = TextureRect.new()
 image.texture = viewport.get_texture()
 image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 image.stretch_mode = TextureRect.STRETCH_SCALE
 image.mouse_filter = Control.MOUSE_FILTER_IGNORE
 image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(image)
 resized.connect(fit)
 gui_input.connect(input_event)
 fit()
 rebuild(false,false)

func fit() -> void:
 if not is_instance_valid(viewport): return
 viewport.size = Vector2i(maxf(size.x,1),maxf(size.y,1))
 if is_instance_valid(camera): camera.zoom = Vector2.ONE*maxf(0.01,minf(size.x/2400.0,size.y/1350.0))*zoom_factor

func rebuild(run: bool, compare: bool) -> void:
 if is_instance_valid(context):
  context.shutdown()
  viewport.remove_child(context)
  context.queue_free()
 context = LaboratoryArena.new()
 context.map_id = map_id
 context.layout = layout.duplicate(true)
 context.seed_value = seed_value
 context.comparison = compare
 viewport.add_child(context)
 camera = Camera2D.new()
 camera.position = Vector2(1200,675)
 context.add_child(camera)
 fit()
 selection = -1
 selected_unit = null
 context.state_changed.connect(func() -> void: changed.emit())
 if run: context.start()
 changed.emit()

func world_point(point: Vector2) -> Vector2:
 return camera.position+(point-size*0.5)/camera.zoom

func persist() -> void:
 LaboratoryStore.setup = {"map_id":map_id,"seed":seed_value,"units":layout.duplicate(true)}
 LaboratoryStore.save()
 layout_edited.emit()
 changed.emit()

func add_unit(point: Vector2) -> void:
 var count: int = 0
 var hexes: int = 0
 for spec: Dictionary in layout:
  if int(spec["team"]) == place_team:
   count += 1
   if spec["kind"] == "hexagon": hexes += 1
 if count >= 30 or (place_kind == "hexagon" and hexes >= 2):
  message.emit("每方最多 30 单位、2 个六边形")
  return
 var error: String = context.valid_point(place_kind,point,-1,layout)
 if not error.is_empty():
  message.emit(error)
  return
 layout.append({"kind":place_kind,"team":place_team,"x":point.x,"y":point.y,"hp":place_hp,"angle":place_angle})
 rebuild(false,false)
 persist()

func delete_selected() -> void:
 if context.state != LaboratoryArena.State.ARRANGING or selection < 0: return
 layout.remove_at(selection)
 rebuild(false,false)
 persist()

func edit_selected(hp: float, angle: float) -> void:
 place_hp = hp
 place_angle = angle
 if context.state != LaboratoryArena.State.ARRANGING or selection < 0: return
 layout[selection]["hp"] = hp
 layout[selection]["angle"] = angle
 var index: int = selection
 rebuild(false,false)
 selection = index
 persist()

func input_event(event: InputEvent) -> void:
 if not is_instance_valid(context): return
 if event is InputEventMouseButton:
  var mouse: InputEventMouseButton = event as InputEventMouseButton
  if mouse.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and mouse.pressed:
   zoom_factor = clampf(zoom_factor*(1.15 if mouse.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0/1.15),1.0,3.5)
   fit()
   accept_event()
  if mouse.button_index == MOUSE_BUTTON_MIDDLE:
   panning = mouse.pressed
  if mouse.button_index == MOUSE_BUTTON_LEFT:
   if mouse.pressed:
    grab_focus()
    var point: Vector2 = world_point(mouse.position)
    selected_unit = null
    var best: float = 36.0/camera.zoom.x
    for unit: BaseGeoUnit in context.local_units:
     var distance: float = point.distance_to(unit.global_position)
     if distance < best:
      selected_unit = unit
      best = distance
    for unit: BaseGeoUnit in context.local_units: unit.selected = unit == selected_unit
    if is_instance_valid(selected_unit):
     selection = int(selected_unit.get_meta("layout_index",-1))
     selected.emit(selected_unit)
     dragging = context.state == LaboratoryArena.State.ARRANGING
    elif context.state == LaboratoryArena.State.ARRANGING:
     add_unit(point)
   elif dragging:
    dragging = false
    if selection >= 0 and is_instance_valid(selected_unit):
     var point: Vector2 = world_point(mouse.position)
     var error: String = context.valid_point(selected_unit.unit_type,point,selection,layout)
     if error.is_empty():
      layout[selection]["x"] = point.x
      layout[selection]["y"] = point.y
      selected_unit.position = point
      persist()
     else: message.emit("移动未应用："+error)
   accept_event()
 elif event is InputEventMouseMotion and panning:
  camera.position = (camera.position-(event as InputEventMouseMotion).relative/camera.zoom).clamp(Vector2.ZERO,Vector2(2400,1350))
 elif event is InputEventKey and event.is_pressed():
  if (event as InputEventKey).keycode in [KEY_DELETE,KEY_BACKSPACE]: delete_selected()

func _exit_tree() -> void:
 if is_instance_valid(context): context.shutdown()
