extends Camera2D

var arena: Node2D
var target_zoom: float = 0.68

func _ready() -> void:
 position = Vector2(1200, 675)
 zoom = Vector2.ONE * target_zoom
 position_smoothing_enabled = true
 position_smoothing_speed = 8.0

func _process(delta: float) -> void:
 zoom = zoom.lerp(Vector2.ONE * target_zoom, minf(1.0, delta * 10.0))
 var focus: Control = get_viewport().gui_get_focus_owner()
 if focus is LineEdit or focus is TextEdit or bool(arena.get("hud").get("matrix_open")):
  return
 var direction: Vector2 = Vector2.ZERO
 if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): direction.x -= 1.0
 if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): direction.x += 1.0
 if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): direction.y -= 1.0
 if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): direction.y += 1.0
 position = (position + direction.normalized() * delta * 850.0 * float(GameSettings.values["camera_speed"]) / target_zoom).clamp(Vector2(450,350), Vector2(1950,1000))

func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.is_pressed():
  var button: InputEventMouseButton = event as InputEventMouseButton
  if button.button_index == MOUSE_BUTTON_WHEEL_UP:
   target_zoom = clampf(target_zoom * 1.12, 0.48, 1.4)
  elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
   target_zoom = clampf(target_zoom / 1.12, 0.48, 1.4)
  else:
   return
  get_viewport().set_input_as_handled()
