extends Node

var menu: UnitAcademy
var arena: MainArena
var captures: Array[Dictionary] = []
var overflow: Array[String] = []

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 seed(20261020)
 await get_tree().process_frame
 if not OS.get_cmdline_user_args().has("--battle-only"):
  menu = (load("res://scenes/unit_academy.tscn") as PackedScene).instantiate() as UnitAcademy
  add_child(menu)
  menu.auto_button.button_pressed = false
  for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080)]:
   DisplayServer.window_set_size(dimensions)
   await settle()
   for kind: String in UnitCatalog.TYPES:
    menu.select_unit(kind)
    await get_tree().create_timer(0.3).timeout
    await settle()
    await capture("menu-"+kind+"-%dx%d" % [dimensions.x,dimensions.y],menu.ui)
  for kind: String in UnitCatalog.TYPES:
   menu.select_unit(kind)
   if kind != "hexagon":
    menu.stage.demonstrate_attack()
    await get_tree().create_timer(0.55 if kind == "triangle" else 0.25).timeout
    await capture("attack-"+kind,menu.ui)
    await get_tree().create_timer(1.0).timeout
   menu.stage.demonstrate_skill()
   await get_tree().create_timer(0.6 if kind != "circle" else 1.0).timeout
   await capture("skill-"+kind,menu.ui)
   await get_tree().create_timer(1.5).timeout
  menu.set_reduced_motion(true)
  await settle()
  await capture("menu-low-motion",menu.ui)
  menu.queue_free()
  await get_tree().process_frame
 arena = (load("res://scenes/main_arena.tscn") as PackedScene).instantiate() as MainArena
 add_child(arena)
 for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080)]:
  DisplayServer.window_set_size(dimensions)
  await settle()
  await capture("prepare-%dx%d" % [dimensions.x,dimensions.y],arena.hud.get("root"))
 arena.start_match()
 for team: int in range(2):
  for index: int in range(21): arena.spawn_unit(UnitCatalog.TYPES[index%4],team)
 await get_tree().create_timer(2.0).timeout
 for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080)]:
  DisplayServer.window_set_size(dimensions)
  await settle()
  await capture("battle-%dx%d" % [dimensions.x,dimensions.y],arena.hud.get("root"))
 arena.hud.call("request_menu_exit")
 await settle()
 await capture("return-confirm",arena.hud.get("root"))
 var dialog: ConfirmationDialog = arena.hud.get("return_dialog") as ConfirmationDialog
 dialog.canceled.emit()
 dialog.hide()
 arena.finish_match(0,"V2 原生验证：完整结算及返回入口")
 await settle()
 await capture("result",arena.hud.get("root"))
 var report: Dictionary = {"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"screen_scale":DisplayServer.screen_get_scale(),"screen_size":str(DisplayServer.screen_get_size()),"captures":captures,"overflow":overflow}
 var file: FileAccess = FileAccess.open("res://artifacts/v2-battle-visual-report.json" if OS.get_cmdline_user_args().has("--battle-only") else "res://artifacts/v2-visual-report.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "))
 print("V2_VISUAL_RESULT captures=%d overflow=%d" % [captures.size(),overflow.size()])
 get_tree().quit()

func settle() -> void:
 for index: int in range(8): await get_tree().process_frame
 await RenderingServer.frame_post_draw

func capture(title: String, ui: Control) -> void:
 await RenderingServer.frame_post_draw
 var image: Image = get_viewport().get_texture().get_image()
 var raw: FileAccess = FileAccess.open("res://artifacts/v2-"+title+".pixels",FileAccess.WRITE)
 raw.store_buffer(image.get_data())
 var encodings: Dictionary = {Image.FORMAT_RGBH:"RGBH",Image.FORMAT_RGBAH:"RGBAH",Image.FORMAT_RGBF:"RGBF",Image.FORMAT_RGBAF:"RGBAF",Image.FORMAT_RGB8:"RGB8",Image.FORMAT_RGBA8:"RGBA8"}
 scan_overflow(ui,title)
 captures.append({"name":"v2-"+title,"image_width":image.get_width(),"image_height":image.get_height(),"window":str(DisplayServer.window_get_size()),"viewport":str(get_viewport().get_visible_rect().size),"raw_encoding":encodings.get(image.get_format(),"UNSUPPORTED")})
 print("CAPTURE v2-"+title+" "+str(image.get_size()))

func scan_overflow(node: Node, title: String) -> void:
 if node is Control:
  var control: Control = node as Control
  if not control.is_visible_in_tree(): return
  var rect: Rect2 = control.get_global_rect()
  if control.size.x > 1.0 and control.size.y > 1.0 and not get_viewport().get_visible_rect().grow(3).encloses(rect):
   overflow.append(title+": "+str(control.get_path())+" rect="+str(rect))
  if control.clip_contents: return
 for child: Node in node.get_children(): scan_overflow(child,title)
