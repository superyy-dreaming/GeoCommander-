extends Node

var captures: Array[Dictionary]=[]
var failures: Array[String]=[]
var checks: int=0

func check(ok: bool, reason: String) -> void:
 checks+=1
 if not ok:
  failures.append(reason)
  push_error("MAP_NATIVE_FAIL "+reason)

func settle(count: int=10) -> void:
 for index: int in range(count): await get_tree().process_frame
 await RenderingServer.frame_post_draw

func visible_rect(node: Control) -> Rect2:
 var rect: Rect2=node.get_global_rect().intersection(get_viewport().get_visible_rect())
 var parent: Node=node.get_parent()
 while parent!=null:
  if parent is Control and (parent as Control).clip_contents: rect=rect.intersection((parent as Control).get_global_rect())
  parent=parent.get_parent()
 return rect

func visible(node: Control) -> bool:
 return node.is_visible_in_tree() and visible_rect(node).grow(1).encloses(node.get_global_rect())

func capture(name: String) -> void:
 await RenderingServer.frame_post_draw
 var frame: Image=get_viewport().get_texture().get_image()
 var output: FileAccess=FileAccess.open("res://artifacts/map-native-"+name+".pixels",FileAccess.WRITE)
 output.store_buffer(frame.get_data())
 var encodings: Dictionary={Image.FORMAT_RGBH:"RGBH",Image.FORMAT_RGBAH:"RGBAH",Image.FORMAT_RGBF:"RGBF",Image.FORMAT_RGBAF:"RGBAF",Image.FORMAT_RGB8:"RGB8",Image.FORMAT_RGBA8:"RGBA8"}
 captures.append({"name":"map-native-"+name,"image_width":frame.get_width(),"image_height":frame.get_height(),"raw_encoding":encodings.get(frame.get_format(),"UNSUPPORTED")})
 print("MAP_NATIVE_CAPTURE "+name)

func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 seed(20261025)
 GameSettings.values=GameSettings.DEFAULTS.duplicate()
 GameSettings.apply_display()
 var menu: MainMenu=(load("res://scenes/main_menu.tscn") as PackedScene).instantiate() as MainMenu
 add_child(menu)
 menu.show_page("single")
 for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080)]:
  get_window().size=dimensions
  for factor: float in [1.0,1.3,1.8]:
   GameSettings.set_value("font_scale",factor,false)
   for id: String in MapCatalog.IDS:
    menu.select_map(id)
    await settle()
    var tag: String="%s-%dx%d-%d" % [id,dimensions.x,dimensions.y,roundi(factor*100)]
    check(visible(menu.launch_button),tag+" launch button fully visible")
    check(visible(menu.map_title) and visible(menu.map_preview),tag+" title and preview fully visible")
    check(menu.map_preview.size.x>=320 and menu.map_preview.size.y>=180,tag+" preview usable")
    check(menu.map_preview.viewport.world_2d!=get_viewport().world_2d and menu.map_preview.viewport.use_hdr_2d,tag+" isolated HDR preview")
    check(menu.map_preview.display.get_child_count()==0,tag+" preview creates no combat or runtime nodes")
    check(not menu.map_preview.get_global_rect().intersects(menu.launch_button.get_global_rect()),tag+" footer does not overlap preview")
    await capture(tag)
 menu.queue_free()
 await settle()
 get_window().size=Vector2i(1440,900)
 GameSettings.set_value("font_scale",1.3,false)
 for id: String in MapCatalog.IDS:
  var arena: MainArena=MainArena.new()
  arena.map_id=id
  arena.ai_enabled=false
  add_child(arena)
  arena.camera.position_smoothing_enabled=false
  arena.camera.position=MapCatalog.CENTER
  arena.camera.set("target_zoom",0.55)
  await settle()
  await capture("prepare-"+id)
  arena.start_match()
  arena.terrain.set_physics_process(false)
  if id in ["balanced","crossfire"]:
   arena.terrain.clock=21
   for object: TerrainObject in arena.terrain.objects:
    if object.spec["kind"]=="gate": arena.terrain.update_gate(object)
  elif id=="crystal_maze": arena.terrain.clock=52
  else: arena.terrain.clock=12
  for object: TerrainObject in arena.terrain.objects: object.queue_redraw()
  await get_tree().create_timer(0.3).timeout
  arena.phase=MainArena.Phase.ENDED
  await settle()
  check(visible(arena.hud.tool_tabs) or visible(arena.hud.bottom_layout),id+" tool frame fully visible")
  check(visible(arena.hud.matrix_button),id+" matrix action visible")
  await capture("live-"+id)
  if id=="crystal_maze":
   arena.reduced_motion=true
   for object: TerrainObject in arena.terrain.objects: object.queue_redraw()
   await settle()
   await capture("low-motion-warning-"+id)
  arena.queue_free()
  await settle()
 var hud_arena: MainArena=MainArena.new()
 hud_arena.ai_enabled=false
 add_child(hud_arena)
 hud_arena.hud.close_matrix()
 for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080)]:
  get_window().size=dimensions
  for factor: float in [1.0,1.3,1.8]:
   GameSettings.set_value("font_scale",factor,false)
   await settle()
   var hud: CanvasLayer=hud_arena.hud
   check(visible(hud.tool_tabs) or visible(hud.bottom_layout),"battle tools fit "+str(dimensions)+str(factor))
   check(visible(hud.blue_label) and visible(hud.red_label) and visible(hud.matrix_button),"battle header fits "+str(dimensions)+str(factor))
   for label: Label in [hud.blue_label,hud.red_label]:
    check(label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x<=label.size.x+1,"core health text fits without clipping")
   check(not hud.top_frame.get_global_rect().intersects(hud.actions_layout.get_global_rect()),"battle actions never cover resource header")
   if hud.tool_tabs.visible:
    for tab: int in range(3):
     hud.tool_tabs.current_tab=tab
     await settle()
     check(visible(hud.tool_pages[tab]),"battle page viewport visible "+str(tab))
     await capture("tools-%dx%d-%d-%d" % [dimensions.x,dimensions.y,roundi(factor*100),tab])
   else: await capture("tools-%dx%d-%d" % [dimensions.x,dimensions.y,roundi(factor*100)])
 hud_arena.queue_free()
 await settle()
 var report: FileAccess=FileAccess.open("res://artifacts/map-overhaul-native-report.json",FileAccess.WRITE)
 report.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"screen_scale":DisplayServer.screen_get_scale(),"screen_size":str(DisplayServer.screen_get_size())},"  "))
 print("MAP_NATIVE_RESULT checks=%d failures=%d captures=%d" % [checks,failures.size(),captures.size()])
 get_tree().quit(0 if failures.is_empty() else 1)
