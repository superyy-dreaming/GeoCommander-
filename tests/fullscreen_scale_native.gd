extends Node

var checks: int = 0
var failures: int = 0
var captures: Array[Dictionary] = []

func check(ok: bool, text: String) -> void:
 checks += 1
 if ok:
  print("PASS: "+text)
 else:
  failures += 1
  push_error("FAIL: "+text)

func frames(count: int = 6) -> void:
 for _index: int in range(count): await get_tree().process_frame

func wait_for_display(mode: Window.Mode, dimensions: Vector2i) -> bool:
 var deadline: int = Time.get_ticks_msec()+5000
 while Time.get_ticks_msec()<deadline:
  if get_window().mode==mode and get_window().size==dimensions:
   await frames(2)
   if get_window().mode==mode and get_window().size==dimensions: return true
  await get_tree().process_frame
 return false

func capture(name: String) -> void:
 await RenderingServer.frame_post_draw
 var image: Image = get_viewport().get_texture().get_image()
 var file: FileAccess = FileAccess.open("res://artifacts/"+name+".pixels",FileAccess.WRITE)
 file.store_buffer(image.get_data())
 var encodings: Dictionary = {Image.FORMAT_RGBH:"RGBH",Image.FORMAT_RGBAH:"RGBAH",Image.FORMAT_RGBF:"RGBF",Image.FORMAT_RGBAF:"RGBAF",Image.FORMAT_RGB8:"RGB8",Image.FORMAT_RGBA8:"RGBA8"}
 captures.append({"name":name,"image_width":image.get_width(),"image_height":image.get_height(),"raw_encoding":encodings.get(image.get_format(),"UNSUPPORTED")})

func screen_point(logical_point: Vector2, logical_size: Vector2, output_size: Vector2) -> Vector2:
 var scale: float = minf(output_size.x/logical_size.x,output_size.y/logical_size.y)
 return (output_size-logical_size*scale)*0.5+logical_point*scale

func click_screen(point: Vector2) -> void:
 for pressed: bool in [true,false]:
  var event: InputEventMouseButton = InputEventMouseButton.new()
  event.position = point
  event.global_position = point
  event.button_index = MOUSE_BUTTON_LEFT
  event.pressed = pressed
  Input.parse_input_event(event)
  await frames(1)

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 GameSettings.values = GameSettings.DEFAULTS.duplicate()
 GameSettings.apply_display()
 check(await wait_for_display(Window.MODE_WINDOWED,Vector2i(1440,810)),"演练从保存的 1440×810 窗口开始")
 # Reproduce a user-resized window: the visible layout is 1920×1080 while the
 # persisted resolution remains 1440×810.
 DisplayServer.window_set_size(Vector2i(1920,1080))
 check(await wait_for_display(Window.MODE_WINDOWED,Vector2i(1920,1080)),"窗口手动调整至 1920×1080")
 await frames(6)
 check(GameSettings.values["resolution"]==Vector2i(1440,810),"手动调整窗口不篡改保存分辨率")
 var academy: UnitAcademy = (load("res://scenes/unit_academy.tscn") as PackedScene).instantiate() as UnitAcademy
 add_child(academy)
 await frames(10)
 var logical_size: Vector2 = get_viewport().get_visible_rect().size
 var roster_rect: Rect2 = academy.roster.get_global_rect()
 var dossier_rect: Rect2 = academy.dossier_panel.get_global_rect()
 var stage_rect: Rect2 = academy.stage.get_global_rect()
 await capture("fullscreen-scale-windowed")

 DisplayServer.window_move_to_foreground()
 get_window().grab_focus()
 await get_tree().create_timer(0.5,true).timeout
 # Direct Window.mode regression only. The real macOS green button sends a
 # resize before confirming the mode; fullscreen_titlebar_native covers that
 # distinct sequence through actual system UI input.
 get_window().mode = Window.MODE_FULLSCREEN
 check(await wait_for_display(Window.MODE_FULLSCREEN,DisplayServer.screen_get_size()),"直接 Window.mode 入口进入 Metal 全屏")
 await frames(10)
 check(GameSettings.values["window_mode"]==1,"系统全屏状态同步到游戏设置")
 check(get_window().content_scale_size==Vector2i(1920,1080) and get_window().content_scale_aspect==Window.CONTENT_SCALE_ASPECT_KEEP,"全屏继承进入前实际 1920×1080 布局")
 check(get_viewport().get_visible_rect().size.is_equal_approx(logical_size),"全屏逻辑画布尺寸不变")
 check(academy.roster.get_global_rect().is_equal_approx(roster_rect) and academy.dossier_panel.get_global_rect().is_equal_approx(dossier_rect) and academy.stage.get_global_rect().is_equal_approx(stage_rect),"全屏保持名册、档案与演武场的相对布局")
 var scale: float = minf(float(get_window().size.x)/logical_size.x,float(get_window().size.y)/logical_size.y)
 check(scale>1.0,"全屏输出倍率大于窗口模式")
 var auto_before: bool = academy.auto_button.button_pressed
 await click_screen(screen_point(academy.auto_button.get_global_rect().get_center(),logical_size,Vector2(get_window().size)))
 check(academy.auto_button.button_pressed!=auto_before,"等比全屏下鼠标命中演武控制")
 await capture("fullscreen-scale-fullscreen")

 # Let AppKit finish the fullscreen-space transition before requesting the
 # reverse operation; overlapping native transitions can ignore the resize.
 DisplayServer.window_move_to_foreground()
 get_window().grab_focus()
 await get_tree().create_timer(0.5,true).timeout
 get_window().mode = Window.MODE_WINDOWED
 check(await wait_for_display(Window.MODE_WINDOWED,Vector2i(1920,1080)),"直接 Window.mode 入口退出全屏并恢复原窗口")
 await frames(4)
 check(GameSettings.values["window_mode"]==0 and get_window().content_scale_size==Vector2i.ZERO,"退出系统全屏同步状态并恢复原生像素画布")
 var report: FileAccess = FileAccess.open("res://artifacts/fullscreen-scale-report.json",FileAccess.WRITE)
 report.store_string(JSON.stringify({"captures":captures,"checks":checks,"failures":failures,"screen_scale":DisplayServer.screen_get_scale(),"screen_size":str(DisplayServer.screen_get_size())},"  "))
 print("FULLSCREEN_SCALE_RESULT checks=%d failures=%d" % [checks,failures])
 get_tree().quit(0 if failures==0 else 1)
