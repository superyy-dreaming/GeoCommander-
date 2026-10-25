extends Node

# Native Metal validation. --camera-before loads the pre-fix artifact only for
# the comparison recording. --camera-titlebar waits for real macOS input.
class ClickArena extends MainArena:
 var track_click: bool = false
 var click_result: Dictionary = {}
 func cast_skill(skill: String, point: Vector2) -> bool:
  var cursor: Vector2 = get_global_mouse_position()
  var applied: bool = super.cast_skill(skill,point)
  if track_click: click_result = {"point":point,"cursor":cursor,"applied":applied}
  return applied

var arena: ClickArena
var checks: int = 0
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var before: bool = false
var capture_video: bool = false
var titlebar: bool = false
var label: String = "after"

func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures.append(message)
  push_error("CAMERA_NATIVE_FAIL "+message)
 print(("PASS " if ok else "FAIL ")+message)

func frames(count: int = 1) -> void:
 for _index: int in range(count): await get_tree().process_frame

func wait_mode(fullscreen: bool) -> bool:
 var deadline: int = Time.get_ticks_msec()+300000
 while Time.get_ticks_msec()<deadline:
  if GameSettings.is_fullscreen_mode(get_window().mode)==fullscreen and (not fullscreen or get_window().size==DisplayServer.screen_get_size()):
   await frames(30)
   if GameSettings.is_fullscreen_mode(get_window().mode)==fullscreen: return true
  await frames()
 return false

func capture(name: String, video: bool = false) -> void:
 var image: Image = get_viewport().get_texture().get_image()
 if video: image.resize(960,540,Image.INTERPOLATE_LANCZOS)
 var path: String = "res://artifacts/camera-jitter/"+name+".pixels"
 var output: FileAccess = FileAccess.open(path,FileAccess.WRITE)
 output.store_buffer(image.get_data())
 var encodings: Dictionary = {Image.FORMAT_RGBH:"RGBH",Image.FORMAT_RGBAH:"RGBAH",Image.FORMAT_RGBF:"RGBF",Image.FORMAT_RGBAF:"RGBAF",Image.FORMAT_RGB8:"RGB8",Image.FORMAT_RGBA8:"RGBA8"}
 captures.append({"name":"camera-jitter/"+name,"image_width":image.get_width(),"image_height":image.get_height(),"raw_encoding":encodings.get(image.get_format(),"UNSUPPORTED")})

func stability(name: String, count: int = 300) -> void:
 await frames(180)
 var origin: Vector2 = arena.camera.position
 var screen_origin: Vector2 = arena.camera.get_screen_center_position()
 var drift: float = 0.0
 var screen_drift: float = 0.0
 for _index: int in range(count):
  await frames()
  drift = maxf(drift,arena.camera.position.distance_to(origin))
  screen_drift = maxf(screen_drift,arena.camera.get_screen_center_position().distance_to(screen_origin))
 var sample: Dictionary = {"case":name,"frames":count,"position_drift":drift,"screen_center_drift":screen_drift,"viewport":str(arena.camera.get_viewport_rect().size),"window":str(get_window().size),"canvas":str(get_window().content_scale_size),"zoom":str(arena.camera.zoom)}
 samples.append(sample)
 check(drift<0.01 and screen_drift<0.1,name+" target/screen stability "+JSON.stringify(sample))

func mouse_skill(name: String) -> void:
 arena.skill_cooldowns["OVERCLOCK"] = 0.0
 arena.flux[0] = 999
 var target: Vector2 = Vector2(1200,660)
 var canvas: Transform2D = arena.get_global_transform_with_canvas()
 var output: Transform2D = get_window().get_final_transform()
 var output_point: Vector2 = output*canvas*target
 var mapped: Vector2 = canvas.affine_inverse()*output.affine_inverse()*output_point
 var applied: bool = arena.cast_skill("OVERCLOCK",mapped)
 var found: bool = false
 for child: Node in arena.get_children():
  if child is OverclockZone and (child as OverclockZone).position.distance_to(target)<0.1: found = true
 check(mapped.distance_to(target)<0.1 and applied and found,name+" output/world roundtrip and real skill placement")

var recording_click: bool = false
var click_world: Vector2 = Vector2.INF
var mouse_world: Vector2 = Vector2.INF

func _input(event: InputEvent) -> void:
 if recording_click and event is InputEventMouseButton and event.is_pressed() and (event as InputEventMouseButton).button_index==MOUSE_BUTTON_LEFT:
  click_world = arena.get_global_transform_with_canvas().affine_inverse()*(event as InputEventMouseButton).position
  mouse_world = arena.get_global_mouse_position()
  print("CAMERA_REAL_CLICK "+JSON.stringify({"event_world":str(click_world),"cursor_world":str(mouse_world)}))

func real_mouse_skill(name: String) -> void:
 arena.skill_cooldowns["OVERCLOCK"] = 0.0
 arena.flux[0] = 999
 arena.select_skill("OVERCLOCK")
 recording_click = true
 arena.track_click = true
 arena.click_result.clear()
 click_world = Vector2.INF
 print("CAMERA_WAIT_REAL_CLICK "+name+": click an open point near the battlefield center")
 var deadline: int = Time.get_ticks_msec()+300000
 var found: bool = false
 while Time.get_ticks_msec()<deadline and not found:
  await frames()
  for child: Node in arena.get_children():
   if child is OverclockZone and not arena.click_result.is_empty() and (child as OverclockZone).position.distance_to(arena.click_result["point"])<0.1: found = true
 recording_click = false
 arena.track_click = false
 # AppKit reports integer output pixels while the stretched cursor may be
 # fractional. Allow one output pixel; the actual zone must match the cursor.
 var pixel_in_world: float = 1.01/(arena.camera.zoom.x*get_window().get_final_transform().get_scale().x)
 check(found and bool(arena.click_result.get("applied",false)) and (arena.click_result.get("point",Vector2.INF) as Vector2).distance_to(arena.click_result.get("cursor",Vector2.ZERO))<=pixel_in_world,name+" real OS click matches world cursor and actual skill zone")
 samples.append({"case":name+" real click","event_world":str(click_world),"cursor_world":str(mouse_world),"matched_zone":found,"skill_call":str(arena.click_result)})

func finish() -> void:
 var output: FileAccess = FileAccess.open("res://artifacts/camera-jitter/native-"+label+("-video" if capture_video else "")+"-report.json",FileAccess.WRITE)
 output.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples,"captures":captures,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"screen_scale":DisplayServer.screen_get_scale(),"screen_size":str(DisplayServer.screen_get_size()),"before":before},"  "))
 print("CAMERA_NATIVE_RESULT "+label+" checks=%d failures=%d" % [checks,failures.size()])
 get_tree().quit(0 if failures.is_empty() else 1)

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 before = "--camera-before" in OS.get_cmdline_user_args()
 titlebar = "--camera-titlebar" in OS.get_cmdline_user_args()
 capture_video = "--camera-video" in OS.get_cmdline_user_args()
 label = "before" if before else ("titlebar" if titlebar else "after")
 GameSettings.values = GameSettings.DEFAULTS.duplicate()
 GameSettings.apply_display()
 get_window().size = Vector2i(1920,1080)
 get_window().title = "GeoCommander Camera Test: "+label
 DisplayServer.window_move_to_foreground()
 get_window().grab_focus()
 await frames(20)
 seed(725104)
 arena = ClickArena.new()
 arena.ai_enabled = false
 add_child(arena)
 if before:
  arena.camera.set_script(load("res://artifacts/camera-jitter/camera_rig.before.gd"))
  arena.camera.set("arena",arena)
  arena.camera.call("_ready")
 arena.camera.set_process_unhandled_input(false)
 await frames(30)
 await RenderingServer.frame_post_draw
 await capture(label+"-preparing")
 arena.start_match()
 if capture_video:
  for index: int in range(90):
   await RenderingServer.frame_post_draw
   await capture("%s-video-%03d" % [label,index],true)
  await stability(label+" recorded battle")
  finish()
  return
 if titlebar:
  await stability("windowed before real titlebar")
  await real_mouse_skill("windowed")
  var canvas: Vector2 = get_viewport().get_visible_rect().size
  print("CAMERA_TITLEBAR_WAIT_ENTER: click actual green titlebar button")
  if not await wait_mode(true):
   check(false,"real titlebar entry timed out")
   finish()
   return
  check(get_viewport().get_visible_rect().size.is_equal_approx(canvas),"real green button retains logical canvas")
  await stability("real green button fullscreen")
  await mouse_skill("real green button fullscreen")
  await real_mouse_skill("real green button fullscreen")
  await RenderingServer.frame_post_draw
  await capture("titlebar-fullscreen")
  print("CAMERA_TITLEBAR_WAIT_EXIT: use macOS Window menu")
  check(await wait_mode(false),"real titlebar exit completed")
  await stability("real titlebar restored window")
  finish()
  return
 for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080)]:
  get_window().size = dimensions
  await frames(20)
  for factor: float in [0.68,0.48]:
   arena.camera.set("target_zoom",factor)
   await stability(str(dimensions)+" zoom="+str(factor))
  await mouse_skill(str(dimensions))
  await RenderingServer.frame_post_draw
  await capture("window-%dx%d" % [dimensions.x,dimensions.y])
 arena.hud.call("open_settings")
 var settings: SettingsPanel = arena.hud.get("settings") as SettingsPanel
 var logical_size: Vector2 = get_viewport().get_visible_rect().size
 settings.preview_display(1,Vector2i(1440,810))
 check(await wait_mode(true),"settings fullscreen transition completed")
 check(get_viewport().get_visible_rect().size.is_equal_approx(logical_size),"settings fullscreen retains logical canvas")
 settings.confirm_display()
 settings.close_panel()
 await stability("settings fullscreen playing")
 await mouse_skill("settings fullscreen")
 if "--camera-mouse" in OS.get_cmdline_user_args(): await real_mouse_skill("settings fullscreen")
 await RenderingServer.frame_post_draw
 await capture("settings-fullscreen")
 arena.hud.call("open_settings")
 settings = arena.hud.get("settings") as SettingsPanel
 settings.preview_display(0,Vector2i(1920,1080))
 check(await wait_mode(false),"settings returns to window")
 settings.confirm_display()
 settings.close_panel()
 await stability("settings restored window playing")
 finish()
