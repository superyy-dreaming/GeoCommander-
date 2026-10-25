extends Node
## GitHub documentation captures from real scenes. No network or gameplay overrides.

var captures: Array[Dictionary] = []

func _ready() -> void:
 if "--geo-test" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
  push_error("Use a native window with -- --geo-test for showcase captures")
  get_tree().quit(1)
  return
 process_mode = Node.PROCESS_MODE_ALWAYS
 seed(20261025)
 GameSettings.values = GameSettings.DEFAULTS.duplicate()
 GameSettings.values["resolution"] = Vector2i(1920,1080)
 GameSettings.apply_display()
 # Keep generated documentation fixtures separate from personal and test drafts.
 LaboratoryStore.path = "res://artifacts/showcase-laboratory.json"
 LaboratoryStore.records.clear()
 LaboratoryStore.setup.clear()
 LaboratoryStore.applied_programs.clear()
 LaboratoryStore.status = ""
 LaboratoryStore.selected_kind = "triangle"
 LaboratoryStore.global_prompt = ""
 for kind: String in UnitCatalog.TYPES:
  LaboratoryStore.records[kind] = {"prompt":UnitDossier.DATA[kind]["prompt"],"program":{},"source_model":"","draft_json":"","repair_error":""}
 LLMService.api_key = ""
 MatchSession.selected_map_id = "balanced"
 MatchSession.menu_page = "home"
 await settle()

 var menu: MainMenu = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate() as MainMenu
 add_child(menu)
 await settle()
 await capture("home")
 menu.show_page("single")
 for map_id: String in MapCatalog.IDS:
  menu.select_map(map_id)
  await settle()
  await capture("map-"+map_id)
 menu.open_settings()
 menu.settings.select_category("界面")
 await settle()
 await capture("settings")
 menu.settings.close_panel()
 menu.queue_free()
 await settle()

 var academy: UnitAcademy = (load("res://scenes/unit_academy.tscn") as PackedScene).instantiate() as UnitAcademy
 add_child(academy)
 academy.auto_button.button_pressed = false
 academy.select_unit("circle")
 await settle()
 academy.stage.demonstrate_skill()
 await get_tree().create_timer(1.0).timeout
 await capture("academy")
 academy.queue_free()
 await settle()

 var arena: MainArena = MainArena.new()
 arena.map_id = "refraction"
 add_child(arena)
 await settle()
 await capture("preparation")
 arena.start_match()
 # Exercise the same paid deployment entry point as the player.
 for kind: String in ["square","diamond","circle"]:
  assert(arena.deploy(kind,0),"showcase initial deployment must be legal")
 for index: int in range(8):
  await get_tree().create_timer(3.0).timeout
  var kind: String = ["triangle","diamond","circle","square"][index%4]
  if arena.deployment_reason(kind,0).is_empty(): arena.deploy(kind,0)
 await capture("battle")
 arena.queue_free()
 await settle()

 LaboratoryStore.records["triangle"]["prompt"] = TacticExamples.PROMPT
 LaboratoryStore.records["triangle"]["program"] = TacticExamples.for_unit("triangle")
 var layout: Array[Dictionary] = LaboratoryPresets.create(1)
 # The interactive angle control uses [0, 359]; normalize the preset's facing
 # before loading it through the persisted-layout validation entry point.
 for spec: Dictionary in layout: spec["angle"] = fposmod(float(spec["angle"]),360.0)
 LaboratoryStore.setup = {"map_id":"refraction","seed":7401,"units":layout}
 var lab: TacticLaboratory = (load("res://scenes/tactic_laboratory.tscn") as PackedScene).instantiate() as TacticLaboratory
 add_child(lab)
 await settle()
 assert(lab.view.context.validate_layout().is_empty(),"showcase formation must be legal")
 assert(lab.view.context.units_for(0).size()==2 and lab.view.context.units_for(1).size()==2,"showcase formation must contain both teams")
 var checked: Dictionary = lab.editor.validate_preview()
 assert(checked["ok"],"showcase example must pass real local validation")
 await capture("laboratory")
 lab.editor.tabs.current_tab = 2
 lab.editor.plan_editor.selected = 0
 lab.editor.plan_editor.render()
 await settle()
 await capture("steps")
 lab.editor.apply_and_run()
 assert(lab.view.context.state==LaboratoryArena.State.RUNNING,"showcase must actually run")
 await get_tree().create_timer(0.6).timeout
 lab.view.context.toggle_pause()
 var candidates: Array[BaseGeoUnit] = lab.view.context.units_for(0)
 if not candidates.is_empty():
  lab.view.selected_unit = candidates[0]
  candidates[0].selected = true
 lab.readings.current_tab = 1
 lab.refresh()
 await settle()
 await capture("execution")
 lab.queue_free()
 await settle()

 var report: FileAccess = FileAccess.open("res://artifacts/showcase-report.json",FileAccess.WRITE)
 report.store_string(JSON.stringify({"captures":captures,"engine":Engine.get_version_info()["string"],"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"screen_scale":DisplayServer.screen_get_scale(),"seed":20261025,"network_requests":0},"  "))
 print("SHOWCASE_CAPTURE_OK captures=%d" % captures.size())
 get_tree().quit()

func settle() -> void:
 for index: int in range(12): await get_tree().process_frame
 await RenderingServer.frame_post_draw

func capture(title: String) -> void:
 await RenderingServer.frame_post_draw
 var frame: Image = get_viewport().get_texture().get_image()
 var name: String = "showcase-"+title
 var output: FileAccess = FileAccess.open("res://artifacts/"+name+".pixels",FileAccess.WRITE)
 output.store_buffer(frame.get_data())
 var encodings: Dictionary = {Image.FORMAT_RGBH:"RGBH",Image.FORMAT_RGBAH:"RGBAH",Image.FORMAT_RGBF:"RGBF",Image.FORMAT_RGBAF:"RGBAF",Image.FORMAT_RGB8:"RGB8",Image.FORMAT_RGBA8:"RGBA8"}
 captures.append({"name":name,"image_width":frame.get_width(),"image_height":frame.get_height(),"raw_encoding":encodings.get(frame.get_format(),"UNSUPPORTED")})
 print("SHOWCASE_CAPTURE "+title)
