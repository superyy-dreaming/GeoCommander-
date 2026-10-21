extends Node

var arena: MainArena
var captures: Array[Dictionary] = []
var overflow: Array[String] = []

func _ready() -> void:
 seed(20261020)
 await get_tree().process_frame
 var scene: PackedScene = load("res://scenes/main_arena.tscn") as PackedScene
 arena = scene.instantiate() as MainArena
 add_child(arena)
 DisplayServer.window_set_size(Vector2i(1440,900))
 await settle()
 await capture("matrix-1440x900")
 arena.start_match()
 for team: int in range(2):
  for index: int in range(21):
   arena.spawn_unit(UnitCatalog.TYPES[index % 4],team)
 await get_tree().create_timer(2.0).timeout
 for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080)]:
  DisplayServer.window_set_size(dimensions)
  await settle()
  await capture("battle-%dx%d" % [dimensions.x,dimensions.y])
 arena.select_skill("EMP_STRIKE")
 get_viewport().warp_mouse(Vector2(1100,480))
 await settle()
 await capture("aiming-1920x1080")
 arena.hud.call("open_matrix")
 await settle()
 await capture("matrix-live-1920x1080")
 arena.hud.call("close_matrix")
 arena.set_reduced_motion(true)
 await settle()
 await capture("reduced-motion-1920x1080")
 arena.finish_match(0,"验证场景：结算界面与重开入口")
 await settle()
 await capture("result-1920x1080")
 var report: Dictionary = {"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"screen_scale":DisplayServer.screen_get_scale(),"screen_size":str(DisplayServer.screen_get_size()),"captures":captures,"overflow":overflow}
 var file: FileAccess = FileAccess.open("res://artifacts/visual-report.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "))
 print("VISUAL_RESULT " + JSON.stringify(report))
 get_tree().quit(0 if overflow.is_empty() else 1)

func settle() -> void:
 for index: int in range(4): await get_tree().process_frame
 await RenderingServer.frame_post_draw

func capture(title: String) -> void:
 await RenderingServer.frame_post_draw
 var image: Image = get_viewport().get_texture().get_image()
 var path: String = "res://artifacts/" + title + ".png"
 var error: Error = image.save_png(path)
 var raw: FileAccess = FileAccess.open("res://artifacts/" + title + ".pixels",FileAccess.WRITE)
 raw.store_buffer(image.get_data())
 var encodings: Dictionary = {Image.FORMAT_RGBH:"RGBH",Image.FORMAT_RGBAH:"RGBAH",Image.FORMAT_RGBF:"RGBF",Image.FORMAT_RGBAF:"RGBAF",Image.FORMAT_RGB8:"RGB8",Image.FORMAT_RGBA8:"RGBA8"}
 var encoding: String = String(encodings.get(image.get_format(),"UNSUPPORTED"))
 scan_overflow(arena.hud.get("root") as Control,title)
 captures.append({"name":title,"image_width":image.get_width(),"image_height":image.get_height(),"window":str(DisplayServer.window_get_size()),"viewport":str(get_viewport().get_visible_rect().size),"fps":Engine.get_frames_per_second(),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,"save_error":error,"raw_encoding":encoding})
 print("CAPTURE " + title + " " + str(image.get_size()))

func scan_overflow(node: Node, title: String) -> void:
 if node is Control:
  var control: Control = node as Control
  if not control.is_visible_in_tree(): return
  var rect: Rect2 = control.get_global_rect()
  var bounds: Rect2 = get_viewport().get_visible_rect().grow(2.0)
  if control.size.x > 1.0 and control.size.y > 1.0 and not bounds.encloses(rect):
   var description: String = title + ": " + str(control.get_path()) + " rect=" + str(rect)
   if not overflow.has(description): overflow.append(description)
 for child: Node in node.get_children(): scan_overflow(child,title)
