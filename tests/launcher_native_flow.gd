extends Node

var checks: int = 0
var failures: int = 0

func check(ok: bool, text: String) -> void:
 checks += 1
 if ok: print("PASS: "+text)
 else:
  failures += 1
  push_error("FAIL: "+text)

func frames(count: int = 4) -> void:
 for n: int in range(count): await get_tree().process_frame

func display_matches(mode: Window.Mode, dimensions: Vector2i = Vector2i.ZERO) -> bool:
 # The mode flag changes before macOS completes its native animation. The
 # fullscreen caller retains the original settle interval; also verify the
 # actual dimensions instead of treating the flag as completion evidence.
 var deadline: int = Time.get_ticks_msec()+4000
 while Time.get_ticks_msec()<deadline:
  if get_window().mode==mode and (dimensions==Vector2i.ZERO or get_window().size==dimensions):
   await frames(2)
   if get_window().mode==mode and (dimensions==Vector2i.ZERO or get_window().size==dimensions): return true
  await get_tree().process_frame
 return false

func click(button: Button) -> void:
 var point: Vector2 = button.get_global_rect().get_center()
 for pressed: bool in [true,false]:
  var event: InputEventMouseButton = InputEventMouseButton.new()
  event.position = point
  event.global_position = point
  event.button_index = MOUSE_BUTTON_LEFT
  event.pressed = pressed
  get_viewport().push_input(event,true)
 await frames()

func key(code: Key, pressed: bool = true) -> void:
 var event: InputEventKey = InputEventKey.new()
 event.keycode = code
 event.physical_keycode = code
 event.pressed = pressed
 Input.parse_input_event(event)

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 await frames()
 GameSettings.values = GameSettings.DEFAULTS.duplicate()
 GameSettings.apply_display()
 check(await display_matches(Window.MODE_WINDOWED,Vector2i(1440,810)),"显示夹具从真实默认窗口尺寸开始")
 var font: Font = CommanderTheme.create().default_font
 var text: String = "敌远围普攻能量归零狙击摧毁"
 var missing: String = ""
 for character: String in text:
  if not font.has_char(character.unicode_at(0)): missing += character
 check(missing.is_empty(),"系统字体覆盖简体中文关键字形："+missing)
 var menu: MainMenu = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate() as MainMenu
 add_child(menu)
 await frames()
 for node: Node in menu.pages["home"].find_children("*","Button",true,false):
  if (node as Button).text == "单人游戏": await click(node as Button)
 check(menu.page == "single","真实 GUI 点击进入单人地图选择")
 await click(menu.map_buttons["flanks"])
 check(menu.map_preview.map_id == "flanks","真实 GUI 点击切换地图")
 menu.open_settings()
 await frames()
 var settings: SettingsPanel = menu.settings
 GameSettings.set_value("font_scale",1.3,false)
 await frames()
 check(settings.display_dialog.get_ok_button().get_theme_font_size("font_size") == 23,"显示确认窗跟随全局字号")
 var windowed_view_size: Vector2 = get_viewport().get_visible_rect().size
 var windowed_map_rect: Rect2 = menu.map_preview.get_global_rect()
 # Native macOS fullscreen needs the test window in the active application.
 # A background window reports the requested mode before AppKit enters the space.
 DisplayServer.window_move_to_foreground()
 get_window().grab_focus()
 await get_tree().create_timer(0.5,true).timeout
 settings.preview_display(1,Vector2i(1440,810))
 await get_tree().create_timer(1.0,true).timeout
 check(await display_matches(Window.MODE_FULLSCREEN,DisplayServer.screen_get_size()) and settings.display_dialog.visible,"Metal 原生窗口真实切换全屏并显示确认")
 check(get_window().content_scale_size==Vector2i(1440,810) and get_window().content_scale_aspect==Window.CONTENT_SCALE_ASPECT_KEEP,"全屏以进入前实际窗口作为等比逻辑画布")
 check(get_viewport().get_visible_rect().size.is_equal_approx(windowed_view_size) and menu.map_preview.get_global_rect().is_equal_approx(windowed_map_rect),"全屏保持窗口模式的逻辑布局与相对大小")
 var output_scale: float = minf(float(get_window().size.x)/windowed_view_size.x,float(get_window().size.y)/windowed_view_size.y)
 check(output_scale>1.0 and is_equal_approx(float(get_window().size.x)/windowed_view_size.x,output_scale),"全屏统一放大文字、控件与战场")
 var dialog_rect: Rect2 = Rect2(settings.display_dialog.position,settings.display_dialog.size)
 check(get_viewport().get_visible_rect().encloses(dialog_rect),"全屏确认窗保持在逻辑画布内")
 settings.revert_display()
 check(await display_matches(Window.MODE_WINDOWED,Vector2i(1440,810)),"取消后真实恢复窗口模式")
 check(get_window().content_scale_size==Vector2i.ZERO and get_viewport().get_visible_rect().size.is_equal_approx(windowed_view_size),"切回窗口恢复原生像素布局")
 settings.preview_display(0,Vector2i(1280,720))
 check(await display_matches(Window.MODE_WINDOWED,Vector2i(1280,720)),"窗口分辨率真实应用")
 settings.display_left = 0.01
 check(await display_matches(Window.MODE_WINDOWED,Vector2i(1440,810)) and not settings.display_pending,"显示倒计时恢复实际窗口尺寸")
 key(KEY_TAB)
 await frames()
 check(is_instance_valid(get_viewport().gui_get_focus_owner()) and settings.root.is_ancestor_of(get_viewport().gui_get_focus_owner()),"Tab 焦点留在设置面板内")
 key(KEY_ESCAPE)
 await frames()
 check(not get_tree().paused and not is_instance_valid(menu.settings),"Esc 关闭设置并恢复暂停状态")
 menu.queue_free()
 await frames()
 var arena: MainArena = (load("res://scenes/main_arena.tscn") as PackedScene).instantiate() as MainArena
 add_child(arena)
 arena.start_match()
 arena.ai_enabled = false
 arena.override_left = 25
 arena.skill_cooldowns["EMP_STRIKE"] = 17.0
 await frames()
 arena.hud.call("open_settings")
 settings = arena.hud.get("settings") as SettingsPanel
 var left: float = arena.match_left
 var cooldown: float = arena.override_left
 var skill: float = arena.skill_cooldowns["EMP_STRIKE"]
 await get_tree().create_timer(0.3,true).timeout
 check(left == arena.match_left and cooldown == arena.override_left and skill == arena.skill_cooldowns["EMP_STRIKE"],"原生对局设置暂停计时与两类冷却")
 GameSettings.set_value("glow",0.0,false)
 var world: WorldEnvironment = arena.find_children("*","WorldEnvironment",true,false)[0] as WorldEnvironment
 check(not world.environment.glow_enabled,"发光为0实际关闭世界发光")
 settings.close_panel()
 await get_tree().create_timer(0.1,true).timeout
 check(arena.match_left < left and arena.override_left < cooldown,"关闭后原生对局与冷却继续推进")
 arena.camera.set_process(false)
 # Keep both samples inside camera bounds so clamping does not affect speed.
 arena.camera.set("target_zoom",1.0)
 arena.camera.zoom = Vector2.ONE
 arena.camera.position = MapCatalog.CENTER
 GameSettings.set_value("camera_speed",1.0,false)
 key(KEY_D)
 await frames(1)
 var start: Vector2 = arena.camera.position
 arena.camera.call("_process",0.1)
 var distance: float = arena.camera.position.distance_to(start)
 arena.camera.position = start
 GameSettings.set_value("camera_speed",2.0,false)
 arena.camera.call("_process",0.1)
 check(is_equal_approx(arena.camera.position.distance_to(start),distance*2) and distance > 0,"镜头速度设置实际控制位移倍率")
 key(KEY_D,false)
 get_tree().paused = false
 print("NATIVE_FLOW_RESULT checks=%d failures=%d" % [checks,failures])
 get_tree().quit(0 if failures == 0 else 1)
