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
 settings.preview_display(1,Vector2i(1440,810))
 await get_tree().create_timer(1.0,true).timeout
 check(get_window().mode == Window.MODE_FULLSCREEN and settings.display_dialog.visible,"Metal 原生窗口真实切换全屏并显示确认")
 settings.revert_display()
 await get_tree().create_timer(0.5,true).timeout
 check(get_window().mode == Window.MODE_WINDOWED,"取消后真实恢复窗口模式")
 settings.preview_display(0,Vector2i(1280,720))
 await frames()
 check(get_window().size == Vector2i(1280,720),"窗口分辨率真实应用")
 settings.display_left = 0.01
 await get_tree().create_timer(0.2,true).timeout
 check(not settings.display_pending and get_window().size == Vector2i(1440,810),"显示倒计时恢复实际窗口尺寸")
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
 arena.camera.position = Vector2(1200,675)
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
