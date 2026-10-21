extends Node

var captures: Array[Dictionary] = []
var overflow: Array[String] = []
var menu: MainMenu
var academy: UnitAcademy
var arena: MainArena
const DIMENSIONS: Array[Vector2i] = [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080)]

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 seed(20261020)
 GameSettings.values = GameSettings.DEFAULTS.duplicate()
 await get_tree().process_frame
 menu = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate() as MainMenu
 add_child(menu)
 for dimensions: Vector2i in DIMENSIONS:
  DisplayServer.window_set_size(dimensions)
  GameSettings.set_value("font_scale",1.0,false)
  menu.show_page("home")
  await settle()
  await capture("home-"+size_name(dimensions),menu.ui)
  GameSettings.set_value("font_scale",1.3,false)
  await settle()
  await capture("home-large-"+size_name(dimensions),menu.ui)
  menu.show_page("single")
  for id: String in MapCatalog.IDS:
   menu.select_map(id)
   await settle()
   await capture("map-"+id+"-large-"+size_name(dimensions),menu.ui)
  menu.open_settings()
  for category: String in ["显示","界面","操作与关于"]:
   menu.settings.select_category(category)
   await settle()
   await capture("settings-"+str(["显示","界面","操作与关于"].find(category))+"-large-"+size_name(dimensions),menu.settings.root)
  if dimensions == DIMENSIONS[0]:
   menu.settings.select_category("显示")
   menu.settings.preview_display(0,Vector2i(1280,720))
   await settle()
   await capture("display-confirm-large-1280x720",menu.settings.root)
   menu.settings.revert_display()
  menu.settings.close_panel()
  await settle()
 DisplayServer.window_set_size(DIMENSIONS[0])
 menu.show_page("multiplayer")
 await settle()
 await capture("multiplayer-large-1280x720",menu.ui)
 menu.queue_free()
 await settle()
 academy = (load("res://scenes/unit_academy.tscn") as PackedScene).instantiate() as UnitAcademy
 add_child(academy)
 academy.auto_button.button_pressed = false
 for kind: String in UnitCatalog.TYPES:
  academy.select_unit(kind)
  await get_tree().create_timer(0.3).timeout
  await settle()
  await capture("academy-"+kind+"-large-1280x720",academy.ui)
 for dimensions: Vector2i in [DIMENSIONS[1],DIMENSIONS[2]]:
  GameSettings.set_value("font_scale",1.0,false)
  DisplayServer.window_set_size(dimensions)
  await settle()
  await capture("academy-"+size_name(dimensions),academy.ui)
 academy.queue_free()
 await settle()
 for id: String in MapCatalog.IDS:
  GameSettings.set_value("font_scale",1.3,false)
  DisplayServer.window_set_size(DIMENSIONS[1])
  arena = (load("res://scenes/main_arena.tscn") as PackedScene).instantiate() as MainArena
  arena.map_id = id
  add_child(arena)
  await settle()
  if id == "balanced":
   DisplayServer.window_set_size(DIMENSIONS[0])
   await settle()
   await capture("prepare-large-1280x720",arena.hud.get("root"))
   arena.hud.call("open_settings")
   (arena.hud.get("settings") as SettingsPanel).select_category("界面")
   await settle()
   await capture("battle-settings-large-1280x720",(arena.hud.get("settings") as SettingsPanel).root)
   (arena.hud.get("settings") as SettingsPanel).close_panel()
   await settle()
  arena.start_match()
  await get_tree().create_timer(1.0).timeout
  DisplayServer.window_set_size(DIMENSIONS[1])
  await settle()
  await capture("battle-"+id+"-large-1440x900",arena.hud.get("root"))
  if id == "balanced":
   DisplayServer.window_set_size(DIMENSIONS[0])
   arena.hud.call("request_menu_exit")
   await settle()
   await capture("return-confirm-large-1280x720",arena.hud.get("root"))
   var dialog: ConfirmationDialog = arena.hud.get("return_dialog") as ConfirmationDialog
   dialog.canceled.emit()
   dialog.hide()
   arena.finish_match(0,"原生验证：大字号结算与返回入口")
   await settle()
   await capture("result-large-1280x720",arena.hud.get("root"))
  arena.queue_free()
  await settle()
 var report: Dictionary = {"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"screen_scale":DisplayServer.screen_get_scale(),"captures":captures,"overflow":overflow}
 var file: FileAccess = FileAccess.open("res://artifacts/launcher-visual-report.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "))
 print("LAUNCHER_VISUAL_RESULT captures=%d overflow=%d" % [captures.size(),overflow.size()])
 get_tree().quit(0 if overflow.is_empty() else 1)

func size_name(dimensions: Vector2i) -> String:
 return "%dx%d" % [dimensions.x,dimensions.y]

func settle() -> void:
 for n: int in range(10): await get_tree().process_frame
 await RenderingServer.frame_post_draw

func capture(title: String, root: Control) -> void:
 await RenderingServer.frame_post_draw
 var frame: Image = get_viewport().get_texture().get_image()
 var file: FileAccess = FileAccess.open("res://artifacts/launcher-"+title+".pixels",FileAccess.WRITE)
 file.store_buffer(frame.get_data())
 var encodings: Dictionary = {Image.FORMAT_RGBH:"RGBH",Image.FORMAT_RGBAH:"RGBAH",Image.FORMAT_RGBF:"RGBF",Image.FORMAT_RGBAF:"RGBAF",Image.FORMAT_RGB8:"RGB8",Image.FORMAT_RGBA8:"RGBA8"}
 captures.append({"name":"launcher-"+title,"image_width":frame.get_width(),"image_height":frame.get_height(),"raw_encoding":encodings.get(frame.get_format(),"UNSUPPORTED")})
 scan(root,title)
 print("CAPTURE "+title)

func scan(node: Node, title: String) -> void:
 if node is Control:
  var control: Control = node as Control
  if not control.is_visible_in_tree(): return
  if control.size.x > 1 and control.size.y > 1 and not get_viewport().get_visible_rect().grow(3).encloses(control.get_global_rect()):
   overflow.append(title+": "+str(control.get_path())+" "+str(control.get_global_rect()))
  if control.clip_contents: return
 for child: Node in node.get_children(): scan(child,title)
