extends Node

# Interactive native fixture: enter with the actual green titlebar button and
# exit with macOS Window > Exit Full Screen. Never assigns Window.mode here.
var checks: int = 0
var failures: int = 0
var events: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var last_state: Dictionary = {}
var phase: String = "setup"
var started_at: int = 0
var provisional_seen: bool = false
var provisional_intact: bool = true
var expected_canvas: Vector2i = Vector2i.ZERO

func check(ok: bool, text: String) -> void:
 checks += 1
 if ok: print("PASS: "+text)
 else:
  failures += 1
  push_error("FAIL: "+text)

func frames(count: int = 8) -> void:
 for _index: int in range(count): await get_tree().process_frame

func wait_fullscreen(fullscreen: bool) -> bool:
 var deadline: int = Time.get_ticks_msec()+120000
 while Time.get_ticks_msec()<deadline:
  if GameSettings.is_fullscreen_mode(get_window().mode)==fullscreen:
   await frames(10)
   if GameSettings.is_fullscreen_mode(get_window().mode)==fullscreen: return true
  await get_tree().process_frame
 return false

func snapshot() -> Dictionary:
 var window: Window = get_window()
 return {"mode":window.mode,"size":str(window.size),"visible":str(get_viewport().get_visible_rect().size),"canvas":str(window.content_scale_size),"last_windowed":str(GameSettings.last_windowed_layout_size),"pending":GameSettings.native_fullscreen_pending,"phase":phase}

func record(event: String) -> void:
 var state: Dictionary = snapshot()
 state["event"] = event
 state["msec"] = Time.get_ticks_msec()-started_at
 events.append(state)
 print("TITLEBAR_TRACE "+JSON.stringify(state))

func _process(_delta: float) -> void:
 var state: Dictionary = snapshot()
 if state != last_state:
  last_state = state
  record("process")
 if phase.ends_with("enter") and GameSettings.native_fullscreen_pending:
  provisional_seen = true
  provisional_intact = provisional_intact and GameSettings.last_windowed_layout_size==expected_canvas and get_window().content_scale_size==expected_canvas

func control_rects(node: Node, result: Dictionary) -> void:
 if node is Control and (node as Control).is_visible_in_tree(): result[str(node.get_path())] = (node as Control).get_global_rect()
 for child: Node in node.get_children(): control_rects(child,result)

func matching_rects(scene: Node, expected: Dictionary) -> bool:
 var actual: Dictionary = {}
 control_rects(scene,actual)
 for path: String in expected:
  if not actual.has(path) or not (actual[path] as Rect2).is_equal_approx(expected[path]): return false
 return true

func capture(name: String) -> void:
 await RenderingServer.frame_post_draw
 var image: Image = get_viewport().get_texture().get_image()
 var file: FileAccess = FileAccess.open("res://artifacts/"+name+".pixels",FileAccess.WRITE)
 file.store_buffer(image.get_data())
 var encodings: Dictionary = {Image.FORMAT_RGBH:"RGBH",Image.FORMAT_RGBAH:"RGBAH",Image.FORMAT_RGBF:"RGBF",Image.FORMAT_RGBAF:"RGBAF",Image.FORMAT_RGB8:"RGB8",Image.FORMAT_RGBA8:"RGBA8"}
 captures.append({"name":name,"image_width":image.get_width(),"image_height":image.get_height(),"raw_encoding":encodings.get(image.get_format(),"UNSUPPORTED")})

func run_case(id: String, scene_path: String, dimensions: Vector2i, scale: float) -> void:
 phase = id+"-setup"
 GameSettings.set_value("font_scale",scale,false)
 get_window().size = dimensions
 await frames(12)
 expected_canvas = dimensions
 var scene: Node = (load(scene_path) as PackedScene).instantiate()
 add_child(scene)
 await frames(12)
 var baseline: Dictionary = {}
 control_rects(scene,baseline)
 var logical_size: Vector2 = get_viewport().get_visible_rect().size
 check(logical_size.is_equal_approx(Vector2(dimensions)),id+" 使用实际窗口布局")
 await capture("titlebar-"+id+"-windowed")
 provisional_seen = false
 provisional_intact = true
 phase = id+"-enter"
 get_window().title = "GeoCommander Titlebar Test: "+id
 print("TITLEBAR_WAIT_ENTER "+id+": click the real green button")
 if not await wait_fullscreen(true):
  check(false,id+" 等待真实系统全屏超时")
  return
 check(provisional_seen and provisional_intact,id+" 全屏确认前的屏幕尺寸不覆盖原布局")
 check(GameSettings.values["window_mode"]==1 and not GameSettings.native_fullscreen_pending,id+" 原生全屏确认并同步设置")
 check(get_window().content_scale_size==dimensions,id+" 全屏继承原逻辑画布")
 check(get_viewport().get_visible_rect().size.is_equal_approx(logical_size),id+" 全屏逻辑尺寸不变")
 check(matching_rects(scene,baseline),id+" 可见控件布局不变，检查 %d 个控件" % baseline.size())
 await capture("titlebar-"+id+"-fullscreen")
 phase = id+"-exit"
 print("TITLEBAR_WAIT_EXIT "+id+": use macOS Window > Exit Full Screen")
 if not await wait_fullscreen(false):
  check(false,id+" 等待系统退出全屏超时")
  return
 check(get_window().size==dimensions and get_window().content_scale_size==Vector2i.ZERO,id+" 退出恢复实际窗口和原生像素布局")
 check(GameSettings.values["window_mode"]==0 and matching_rects(scene,baseline),id+" 退出同步设置且恢复控件布局")
 scene.queue_free()
 await frames(10)

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 started_at = Time.get_ticks_msec()
 GameSettings.values = GameSettings.DEFAULTS.duplicate()
 GameSettings.apply_display()
 get_window().size_changed.connect(func() -> void: record("size_changed"))
 get_window().titlebar_changed.connect(func() -> void: record("titlebar_changed"))
 DisplayServer.window_move_to_foreground()
 get_window().grab_focus()
 await run_case("home", "res://scenes/main_menu.tscn",Vector2i(1440,810),1.5)
 await run_case("academy", "res://scenes/unit_academy.tscn",Vector2i(1920,1080),1.8)
 var report: FileAccess = FileAccess.open("res://artifacts/titlebar-fullscreen-report.json",FileAccess.WRITE)
 report.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"events":events,"screen_scale":DisplayServer.screen_get_scale(),"entry":"real macOS titlebar fullscreen button"},"  "))
 print("TITLEBAR_FULLSCREEN_RESULT checks=%d failures=%d" % [checks,failures])
 get_tree().quit(0 if failures==0 else 1)
