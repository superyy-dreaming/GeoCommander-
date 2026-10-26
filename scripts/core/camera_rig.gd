extends Camera2D

var arena: Node2D
var target_zoom: float = 0.68
const MIN_ZOOM: float = 0.45
const MAX_ZOOM: float = 2.2
const EDGE_MARGIN: float = 24.0
const PAN_SPEED: float = 920.0
var _is_mmb_dragging: bool = false
var _zoom_anchor_active: bool = false
var _zoom_anchor_world: Vector2 = Vector2.ZERO
var _zoom_anchor_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
 position = MapCatalog.CENTER
 zoom = Vector2.ONE * target_zoom
 position_smoothing_enabled = true
 position_smoothing_speed = 8.0

func _process(delta: float) -> void:
 zoom = zoom.lerp(Vector2.ONE * target_zoom, minf(1.0, delta * 12.0))
 if _zoom_anchor_active:
  position = _zoom_anchor_world - _zoom_anchor_offset / maxf(zoom.x,0.01)
  reset_smoothing()
  if absf(zoom.x-target_zoom)<0.001:
   _zoom_anchor_active = false
 var direction: Vector2 = Vector2.ZERO
 if DisplayServer.get_name() != "headless" and not _input_blocked() and not _is_mmb_dragging and not _zoom_anchor_active:
  var mouse_position: Vector2 = get_viewport().get_mouse_position()
  var viewport_size: Vector2 = get_viewport_rect().size
  if mouse_position.x <= EDGE_MARGIN: direction.x -= 1.0
  elif mouse_position.x >= viewport_size.x - EDGE_MARGIN: direction.x += 1.0
  if mouse_position.y <= EDGE_MARGIN: direction.y -= 1.0
  elif mouse_position.y >= viewport_size.y - EDGE_MARGIN: direction.y += 1.0
 var speed_scale: float = float(GameSettings.values.get("camera_speed", 1.0)) if is_instance_valid(GameSettings) else 1.0
 if not direction.is_zero_approx():
  position += direction.normalized() * delta * PAN_SPEED * speed_scale / maxf(zoom.x, 0.01)
 _clamp_position()

func _clamp_position() -> void:
 var actual_zoom: float = maxf(zoom.x, 0.01)
 var half_view: Vector2 = get_viewport_rect().size * 0.5 / actual_zoom
 var travel: Vector2 = (MapCatalog.WORLD_SIZE * 0.5 - half_view).max(Vector2.ZERO)
 var min_position: Vector2 = MapCatalog.CENTER - travel
 var max_position: Vector2 = MapCatalog.CENTER + travel
 position = position.clamp(min_position, max_position)

func _input_blocked() -> bool:
 var focus: Control = get_viewport().gui_get_focus_owner()
 if focus is LineEdit or focus is TextEdit:
  return true
 var hovered: Control = get_viewport().gui_get_hovered_control()
 if is_instance_valid(hovered):
  return true
 var hud: CanvasLayer = arena.get("hud") as CanvasLayer if is_instance_valid(arena) else null
 return is_instance_valid(hud) and (bool(hud.get("matrix_open")) or is_instance_valid(hud.get("settings")))

func _unhandled_input(event: InputEvent) -> void:
 if _input_blocked():
  return
 if event is InputEventMouseButton:
  var button: InputEventMouseButton = event as InputEventMouseButton
  if button.button_index == MOUSE_BUTTON_MIDDLE:
   _is_mmb_dragging = button.pressed
   get_viewport().set_input_as_handled()
   return
  if not button.pressed:
   return
  if button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
   _zoom_at_cursor(1.12 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 0.89)
   get_viewport().set_input_as_handled()
 elif event is InputEventMagnifyGesture:
  var gesture: InputEventMagnifyGesture = event as InputEventMagnifyGesture
  _zoom_at_position(gesture.factor,gesture.position)
  get_viewport().set_input_as_handled()
 elif event is InputEventMouseMotion and _is_mmb_dragging:
  var motion: InputEventMouseMotion = event as InputEventMouseMotion
  position -= motion.relative / maxf(zoom.x, 0.01)
  _clamp_position()
  get_viewport().set_input_as_handled()

func _zoom_at_cursor(factor: float) -> void:
 _zoom_at_position(factor,get_viewport().get_mouse_position())

func _zoom_at_position(factor: float, cursor: Vector2) -> void:
 if not is_finite(factor) or factor <= 0.0 or is_equal_approx(factor,1.0): return
 var viewport_size: Vector2 = get_viewport_rect().size
 var cursor_offset: Vector2 = cursor - viewport_size * 0.5
 var old_zoom: float = maxf(zoom.x, 0.01)
 var screen_center: Vector2 = get_screen_center_position()
 var world_at_cursor: Vector2 = screen_center + cursor_offset / old_zoom
 target_zoom = clampf(target_zoom * factor, MIN_ZOOM, MAX_ZOOM)
 position = screen_center
 _zoom_anchor_world = world_at_cursor
 _zoom_anchor_offset = cursor_offset
 _zoom_anchor_active = true
 _clamp_position()
