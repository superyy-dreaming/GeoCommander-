extends Camera2D

var arena: Node2D
var target_zoom: float = 0.68

func _ready() -> void:
 position = MapCatalog.CENTER
 zoom = Vector2.ONE * target_zoom
 position_smoothing_enabled = true
 position_smoothing_speed = 8.0

func _process(delta: float) -> void:
 zoom = zoom.lerp(Vector2.ONE * target_zoom, minf(1.0, delta * 10.0))
 var direction: Vector2 = Vector2.ZERO
 if not _input_blocked():
  if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): direction.x -= 1.0
  if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): direction.x += 1.0
  if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): direction.y -= 1.0
  if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): direction.y += 1.0
 # During zoom interpolation the visible area follows zoom, not target_zoom.
 # An axis wider than the map has exactly one legal position: its center.
 var half_view: Vector2 = get_viewport_rect().size * 0.5 / zoom.max(Vector2.ONE * 0.01)
 var travel: Vector2 = (MapCatalog.WORLD_SIZE * 0.5 - half_view).max(Vector2.ZERO)
 var min_pos: Vector2 = MapCatalog.CENTER - travel
 var max_pos: Vector2 = MapCatalog.CENTER + travel
 position = (position + direction.normalized() * delta * 850.0 * float(GameSettings.values["camera_speed"]) / target_zoom).clamp(min_pos,max_pos)

func _input_blocked() -> bool:
 var focus: Control = get_viewport().gui_get_focus_owner()
 var hud: CanvasLayer = arena.get("hud") as CanvasLayer
 return focus is LineEdit or focus is TextEdit or (is_instance_valid(hud) and bool(hud.get("matrix_open")))

func _unhandled_input(event: InputEvent) -> void:
 if _input_blocked():
  return
 if event is InputEventMouseButton and event.is_pressed():
  var button: InputEventMouseButton = event as InputEventMouseButton
  if button.button_index == MOUSE_BUTTON_WHEEL_UP:
   target_zoom = clampf(target_zoom * 1.12, 0.48, 1.4)
  elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
   target_zoom = clampf(target_zoom / 1.12, 0.48, 1.4)
  else:
   return
  get_viewport().set_input_as_handled()
