extends Node
var captures: Array[Dictionary] = []
var overflow: Array[String] = []
var lab: TacticLaboratory
func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 GameSettings.values = GameSettings.DEFAULTS.duplicate()
 LaboratoryStore.setup.clear()
 LaboratoryStore.records["triangle"]["program"] = UnitTacticProgram.default_program("triangle")
 lab = (load("res://scenes/tactic_laboratory.tscn") as PackedScene).instantiate() as TacticLaboratory
 add_child(lab)
 for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080)]:
  DisplayServer.window_set_size(dimensions)
  for factor: float in [1.0,1.3]:
   GameSettings.set_value("font_scale",factor,false)
   await settle()
   await capture("editor-%dx%d-%d" % [dimensions.x,dimensions.y,roundi(factor*100)],lab)
  if dimensions == Vector2i(1280,720):
   for i: int in range(3):
    lab.view.layout.clear()
    lab.change_map(i)
    lab.load_preset(3)
    await settle()
    await capture("map-%d-large" % i,lab)
   lab.view.rebuild(true,false)
   lab.attach_context()
   await get_tree().create_timer(0.4).timeout
   lab.readings.current_tab = 1
   lab.view.selected_unit = lab.view.context.units_for(0)[0]
   await settle()
   await capture("running-rules-large",lab)
   lab.editor.preview.text = "{\"damage\":999}"
   lab.editor.validate_preview()
   lab.readings.current_tab = 2
   await settle()
   await capture("error-events-large",lab)
   lab.editor.tabs.current_tab = 1
   await settle()
   await capture("json-large",lab)
   lab.editor.tabs.current_tab = 0
   lab.editor.busy = true
   lab.editor.update_buttons()
   lab.editor.feedback.text = "请求进行中，可取消。"
   await settle()
   await capture("generating-large",lab)
   lab.editor.busy = false
   lab.editor.update_buttons()
   var panel: SettingsPanel = SettingsPanel.new()
   panel.category = "LLM"
   lab.add_child(panel)
   panel.open_panel()
   await settle()
   await capture("settings-llm-large",panel.root)
   panel.close_panel()
   await settle()
   lab.view.rebuild(false,false)
   lab.attach_context()
 var report: FileAccess = FileAccess.open("res://artifacts/ai-lab-visual-report.json",FileAccess.WRITE)
 report.store_string(JSON.stringify({"captures":captures,"overflow":overflow,"screen_scale":DisplayServer.screen_get_scale(),"screen_size":str(DisplayServer.screen_get_size())},"  "))
 print("AI_LAB_VISUAL captures=%d overflow=%d" % [captures.size(),overflow.size()])
 get_tree().quit()

func settle() -> void:
 for i: int in range(8): await get_tree().process_frame
 await RenderingServer.frame_post_draw

func capture(title: String, root: Node) -> void:
 var frame: Image = get_viewport().get_texture().get_image()
 var file: FileAccess = FileAccess.open("res://artifacts/ai-lab-"+title+".pixels",FileAccess.WRITE)
 file.store_buffer(frame.get_data())
 var encodings: Dictionary = {Image.FORMAT_RGBH:"RGBH",Image.FORMAT_RGBAH:"RGBAH",Image.FORMAT_RGBF:"RGBF",Image.FORMAT_RGBAF:"RGBAF",Image.FORMAT_RGB8:"RGB8",Image.FORMAT_RGBA8:"RGBA8"}
 captures.append({"name":"ai-lab-"+title,"image_width":frame.get_width(),"image_height":frame.get_height(),"raw_encoding":encodings.get(frame.get_format(),"UNSUPPORTED")})
 scan(root,title)

func scan(node: Node, title: String) -> void:
 if node is Control:
  var control: Control = node as Control
  if not control.is_visible_in_tree(): return
  if control.size.x > 1 and control.size.y > 1 and not get_viewport().get_visible_rect().grow(3).encloses(control.get_global_rect()): overflow.append(title+": "+str(control.get_path())+" "+str(control.get_global_rect()))
  if control.clip_contents: return
 if node is SubViewport: return
 for child: Node in node.get_children(): scan(child,title)
