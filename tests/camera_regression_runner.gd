extends Node

# Behavior checks use actual Camera2D nodes and independent viewport geometry.
class CameraHUD extends CanvasLayer:
 var matrix_open: bool = false

class CameraArena extends Node2D:
 var hud: CameraHUD

var checks: int = 0
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var viewport: SubViewport
var camera: Camera2D
var host: CameraArena

func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures.append(label)
  push_error("CAMERA_FAIL "+label)
 print(("PASS " if ok else "FAIL ")+label)

func frames(count: int = 1) -> void:
 for _index: int in range(count): await get_tree().process_frame

func key(code: Key, pressed: bool) -> void:
 var event: InputEventKey = InputEventKey.new()
 event.keycode = code
 event.physical_keycode = code
 event.pressed = pressed
 Input.parse_input_event(event)

func fixture(dimensions: Vector2i, zoom_value: float) -> void:
 viewport = SubViewport.new()
 viewport.size = dimensions
 viewport.world_2d = World2D.new()
 add_child(viewport)
 host = CameraArena.new()
 host.hud = CameraHUD.new()
 host.add_child(host.hud)
 viewport.add_child(host)
 camera = (load("res://scripts/core/camera_rig.gd") as Script).new() as Camera2D
 camera.set("arena",host)
 camera.set("target_zoom",zoom_value)
 host.add_child(camera)
 camera.make_current()
 await frames(2)

func clear_fixture() -> void:
 viewport.queue_free()
 await frames(2)

func legal_position() -> bool:
 # Independent per-axis oracle: fitting axes may pan; oversized axes center.
 var half_view: Vector2 = Vector2(viewport.size)*0.5/camera.zoom
 for axis: int in range(2):
  if half_view[axis]>=MapCatalog.WORLD_SIZE[axis]*0.5:
   if absf(camera.position[axis]-MapCatalog.CENTER[axis])>0.01: return false
  elif camera.position[axis]<half_view[axis]-0.01 or camera.position[axis]>MapCatalog.WORLD_SIZE[axis]-half_view[axis]+0.01:
   return false
 return true

func stability(label: String) -> void:
 # Leave smoothing enabled. Test the actual screen center after convergence,
 # not just the requested position, for 300 consecutive rendered frames.
 await frames(180)
 var initial: Vector2 = camera.position
 var screen_initial: Vector2 = camera.get_screen_center_position()
 var position_drift: float = 0.0
 var screen_drift: float = 0.0
 for _index: int in range(300):
  await frames()
  position_drift = maxf(position_drift,camera.position.distance_to(initial))
  screen_drift = maxf(screen_drift,camera.get_screen_center_position().distance_to(screen_initial))
 check(position_drift<0.01 and screen_drift<0.1,label+" 300-frame target/screen stability")
 samples.append({"case":label,"viewport":str(viewport.size),"zoom":camera.zoom.x,"position_drift":position_drift,"screen_center_drift":screen_drift})

func geometry_cases() -> void:
 for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080)]:
  for zoom_value: float in [0.48,0.68,1.4]:
   await fixture(dimensions,zoom_value)
   camera.position = Vector2(-999,9999)
   await frames(2)
   check(legal_position(),str(dimensions)+" zoom="+str(zoom_value)+" legal bounds")
   await stability(str(dimensions)+" zoom="+str(zoom_value))
   await clear_fixture()
 for dimensions: Vector2i in [Vector2i(1440,810),Vector2i(1920,720),Vector2i(1280,1000)]:
  var factor: float = 0.6 if dimensions==Vector2i(1440,810) else 0.68
  await fixture(dimensions,factor)
  camera.position = Vector2(-999,9999)
  await frames(2)
  check(legal_position(),str(dimensions)+" equal/single-axis bounds")
  if dimensions==Vector2i(1440,810):
   check(camera.position.is_equal_approx(MapCatalog.CENTER),"equal viewport pins both axes")
  elif dimensions==Vector2i(1920,720):
   check(is_equal_approx(camera.position.x,MapCatalog.CENTER.x) and camera.position.y>MapCatalog.CENTER.y,"only oversized X pins; Y still pans")
  else:
   check(is_equal_approx(camera.position.y,MapCatalog.CENTER.y) and camera.position.x<MapCatalog.CENTER.x,"only oversized Y pins; X still pans")
  await clear_fixture()

func input_and_zoom() -> void:
 await fixture(Vector2i(1280,720),1.4)
 camera.set_process(false)
 var directions: Array[Key] = [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]
 for code: Key in directions:
  camera.position = MapCatalog.CENTER
  key(code,true)
  await frames()
  camera.call("_process",20.0)
  key(code,false)
  check(legal_position() and not camera.position.is_equal_approx(MapCatalog.CENTER),"arrow movement clamps edge "+str(code))
 camera.position = MapCatalog.CENTER
 camera.set("target_zoom",1.0)
 camera.zoom = Vector2.ONE
 GameSettings.set_value("camera_speed",1.0,false)
 key(KEY_D,true)
 await frames()
 camera.call("_process",0.1)
 var distance: float = camera.position.distance_to(MapCatalog.CENTER)
 camera.position = MapCatalog.CENTER
 GameSettings.set_value("camera_speed",2.0,false)
 camera.call("_process",0.1)
 key(KEY_D,false)
 check(distance>0 and is_equal_approx(camera.position.distance_to(MapCatalog.CENTER),distance*2.0),"existing camera speed multiplier preserved")
 GameSettings.set_value("camera_speed",1.0,false)
 camera.zoom = Vector2.ONE*0.68
 camera.set("target_zoom",1.4)
 camera.position = Vector2.ZERO
 camera.call("_process",0.001)
 check(legal_position() and is_equal_approx(camera.position.x,640.0/camera.zoom.x),"zoom transition uses actual zoom, not target zoom")
 camera.set_process(true)
 for factor: float in [0.48,1.4,0.68,0.48]:
  camera.set("target_zoom",factor)
  var legal: bool = true
  for _index: int in range(120):
   await frames()
   legal = legal and legal_position()
  check(legal,"continuous zoom remains legal "+str(factor))
 host.hud.matrix_open = true
 camera.position = Vector2(-999,9999)
 viewport.size = Vector2i(1920,1080)
 await frames(2)
 check(legal_position(),"matrix blocks input but resize still repairs bounds")
 var original_zoom: float = camera.get("target_zoom")
 var wheel: InputEventMouseButton = InputEventMouseButton.new()
 wheel.button_index = MOUSE_BUTTON_WHEEL_UP
 wheel.pressed = true
 camera.call("_unhandled_input",wheel)
 check(camera.get("target_zoom")==original_zoom,"matrix also blocks wheel operations")
 host.hud.matrix_open = false
 for multiline: bool in [false,true]:
  var editor: Control = TextEdit.new() if multiline else LineEdit.new()
  host.hud.add_child(editor)
  editor.grab_focus()
  await frames()
  camera.position = Vector2(-999,9999)
  key(KEY_D,true)
  await frames(2)
  key(KEY_D,false)
  check(legal_position(),"text focus maintains bounds "+str(multiline))
  camera.call("_unhandled_input",wheel)
  check(camera.get("target_zoom")==original_zoom,"text focus blocks zoom "+str(multiline))
  editor.queue_free()
  await frames()
 await stability("matrix/text resize recovery")
 await clear_fixture()

func match_lifecycle() -> void:
 var arena: MainArena = MainArena.new()
 arena.ai_enabled = false
 add_child(arena)
 await frames(3)
 check(arena.hud.get("matrix_open") and arena.camera.position.is_equal_approx(MapCatalog.CENTER),"preparing matrix maintains centered oversized camera")
 arena.start_match()
 await frames(5)
 check(arena.phase==MainArena.Phase.PLAYING and arena.camera.position.is_equal_approx(MapCatalog.CENTER),"prepare to battle does not displace camera")
 arena.hud.call("toggle_matrix")
 await frames(3)
 arena.hud.call("close_matrix")
 await frames(3)
 check(arena.camera.position.is_equal_approx(MapCatalog.CENTER),"matrix reopen/close remains stable")
 arena.hud.call("open_settings")
 var screen_before: Vector2 = arena.camera.get_screen_center_position()
 await frames(12)
 check(get_tree().paused and arena.camera.get_screen_center_position().distance_to(screen_before)<0.1,"settings pause freezes camera")
 arena.hud.get("settings").call("close_panel")
 await frames(180)
 var origin: Vector2 = arena.camera.get_screen_center_position()
 var drift: float = 0.0
 for _index: int in range(300):
  await frames()
  drift = maxf(drift,arena.camera.get_screen_center_position().distance_to(origin))
 check(not get_tree().paused and drift<0.1,"resume battle actual screen center stable for 300 frames")
 arena.map_id = "flanks"
 Engine.set_meta("camera_restart_checks",{"checks":checks,"failures":failures,"samples":samples})
 arena.restart()

func finish() -> void:
 var report: FileAccess = FileAccess.open("res://artifacts/camera-jitter/regression-report.json",FileAccess.WRITE)
 report.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples},"  "))
 print("CAMERA_RESULT checks=%d failures=%d" % [checks,failures.size()])
 get_tree().quit(0 if failures.is_empty() else 1)

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 if Engine.has_meta("camera_restart_checks"):
  var saved: Dictionary = Engine.get_meta("camera_restart_checks")
  Engine.remove_meta("camera_restart_checks")
  checks = int(saved["checks"])
  failures.assign(saved["failures"])
  samples.assign(saved["samples"])
  var restarted: MainArena = MainArena.new()
  restarted.ai_enabled = false
  add_child(restarted)
  await frames(180)
  check(restarted.map_id=="flanks" and restarted.phase==MainArena.Phase.PREPARING and restarted.camera.position.is_equal_approx(MapCatalog.CENTER),"real scene reload resets camera and retains map")
  finish()
  return
 await geometry_cases()
 await input_and_zoom()
 await match_lifecycle()
