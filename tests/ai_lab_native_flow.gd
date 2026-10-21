extends Node
var passed: int = 0
var failed: int = 0
var captures: Array[Dictionary] = []
func check(ok: bool, title: String) -> void:
 if ok: passed += 1
 else:
  failed += 1
  push_error("AI_LAB_NATIVE_FAIL "+title)
func frames(count: int = 5) -> void:
 for i: int in range(count): await get_tree().process_frame
func click_point(point: Vector2) -> void:
 for pressed: bool in [true,false]:
  var event: InputEventMouseButton = InputEventMouseButton.new()
  event.position = point
  event.global_position = point
  event.button_index = MOUSE_BUTTON_LEFT
  event.pressed = pressed
  get_viewport().push_input(event,true)
 await frames()
func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 GameSettings.values = GameSettings.DEFAULTS.duplicate()
 LaboratoryStore.setup.clear()
 var lab: TacticLaboratory = (load("res://scenes/tactic_laboratory.tscn") as PackedScene).instantiate() as TacticLaboratory
 add_child(lab)
 await frames()
 var flux: float = 0
 var profile: Dictionary = TacticalBrain.team_profiles[0].duplicate(true)
 LLMService.configure("http://127.0.0.1:18741/v1","local-test-key","good")
 lab.editor.prompt.text = "低生命时撤退"
 lab.editor.request_generate()
 check(lab.editor.busy and lab.editor.generate.disabled and not lab.editor.cancel_button.disabled,"actual generation busy controls")
 for i: int in range(200):
  if not lab.editor.busy: break
  await frames(1)
 check(not lab.editor.busy and lab.editor.tabs.current_tab == 1 and lab.editor.preview.text.contains("low_hp"),"HTTP generated JSON visible")
 check(not lab.editor.apply_button.disabled,"valid result enables apply")
 lab.editor.apply_and_run()
 await frames()
 check(lab.view.context.active and lab.view.context.profile_for(0)["unit_rules"]["triangle"].has("program"),"apply starts real autonomous combat")
 check(TacticalBrain.team_profiles[0] == profile,"lab does not change formal tactics")
 lab.view.rebuild(false,false)
 lab.attach_context()
 # Real viewport click lands on map and adds one unit.
 var before: int = lab.view.layout.size()
 var local: Vector2 = (Vector2(800,200)-lab.view.camera.position)*lab.view.camera.zoom+lab.view.size*0.5
 await click_point(lab.view.global_position+local)
 check(lab.view.layout.size() == before+1,"native click placement")
 GameSettings.set_value("font_scale",1.3,false)
 DisplayServer.window_set_size(Vector2i(1280,720))
 await frames()
 lab.editor.tabs.current_tab = 0
 await frames()
 var valid_program: Dictionary = LaboratoryStore.records["triangle"]["program"].duplicate(true)
 LLMService.configure("http://127.0.0.1:18741/v1","local-test-key","slow")
 lab.editor.request_generate()
 await frames()
 check(lab.editor.busy and focus_visible(lab.editor.cancel_button),"generation cancel visible at minimum window large font")
 await click_point(lab.editor.cancel_button.get_global_rect().get_center())
 check(not lab.editor.busy and LLMService.requests.is_empty() and LaboratoryStore.records["triangle"]["program"] == valid_program,"visible cancel click preserves valid program")
 LLMService.configure("http://127.0.0.1:18741/v1","local-test-key","good")
 lab.editor.prompt.grab_focus()
 var focus_before: Control = lab.editor.prompt
 var panel: SettingsPanel = SettingsPanel.new()
 lab.add_child(panel)
 panel.select_category("LLM")
 panel.open_panel()
 await frames()
 before = lab.view.layout.size()
 await click_point(lab.view.global_position+local)
 check(lab.view.layout.size() == before,"settings blocks map clicks")
 var connection: LLMSettings = panel.content.get_child(0) as LLMSettings
 for target: Control in [connection.model_id,connection.models,connection.fetch_button,connection.test_button]:
  await focus_tab(target)
  check(get_viewport().gui_get_focus_owner() == target and focus_visible(target),"LLM Tab focus visible "+str(target.get_class()))
 await capture("settings-actions-focus")
 send_key(KEY_TAB,true)
 await frames()
 check(get_viewport().gui_get_focus_owner() == connection.fetch_button,"Shift Tab previous action")
 connection.model_id.text = "slow"
 connection.config_changed()
 connection.send("test")
 await focus_tab(connection.cancel_button)
 check(connection.cancel_button.has_focus() and focus_visible(connection.cancel_button),"cancel focus visible while request active")
 await capture("settings-cancel-focus")
 connection.cancel()
 var escape: InputEventKey = InputEventKey.new()
 escape.keycode = KEY_ESCAPE
 escape.pressed = true
 get_viewport().push_input(escape,true)
 await frames()
 check(not get_tree().paused and get_viewport().gui_get_focus_owner() == focus_before,"Esc restores original focus pause state")
 LLMService.configure("http://127.0.0.1:18741/v1","local-test-key","slow")
 lab.editor.tabs.current_tab = 0
 lab.editor.request_generate()
 lab.editor.select_kind("square")
 await get_tree().create_timer(0.4).timeout
 check(lab.editor.kind == "square" and not lab.editor.busy and not lab.editor.preview.text.contains("\"unit_type\": \"triangle\""),"switch unit rejects stale result")
 GameSettings.set_value("reduced_motion",true,false)
 check(lab.view.context.reduced_motion and lab.view.context.background.get_shader_parameter("reduced_motion"),"low motion updates existing world")
 lab.view.rebuild(true,false)
 lab.view.selected_unit = lab.view.context.units_for(0)[0]
 lab.readings.current_tab = 1
 lab.refresh()
 await frames()
 lab.rule_reading.scroll_vertical = 4
 lab.rule_reading.select(1,0,1,2)
 var scroll_before: float = lab.rule_reading.scroll_vertical
 await get_tree().create_timer(2.1).timeout
 check(is_equal_approx(lab.rule_reading.scroll_vertical,scroll_before) and lab.rule_reading.has_selection(),"running reading preserves scroll and selection for 2s")
 await capture("reading-scroll-retained")
 lab.queue_free()
 await frames()
 check(LLMService.requests.is_empty(),"exit cancels requests")
 LLMService.configure("https://api.openai.com/v1","","")
 var report: FileAccess = FileAccess.open("res://artifacts/ai-lab-focus-report.json",FileAccess.WRITE)
 report.store_string(JSON.stringify({"captures":captures},"  "))
 print("AI_LAB_NATIVE_FLOW passed=%d failed=%d" % [passed,failed])
 get_tree().quit(0 if failed == 0 else 1)

func send_key(code: Key, shift: bool = false) -> void:
 var event: InputEventKey = InputEventKey.new()
 event.keycode = code
 event.pressed = true
 event.shift_pressed = shift
 get_viewport().push_input(event,true)

func focus_tab(target: Control) -> void:
 for i: int in range(50):
  if target.has_focus(): return
  send_key(KEY_TAB)
  await frames(2)

func focus_visible(target: Control) -> bool:
 var ancestor: Node = target.get_parent()
 while ancestor != null:
  if ancestor is ScrollContainer:
   return (ancestor as ScrollContainer).get_global_rect().grow(2).encloses(target.get_global_rect())
  ancestor = ancestor.get_parent()
 return get_viewport().get_visible_rect().encloses(target.get_global_rect())

func capture(title: String) -> void:
 await RenderingServer.frame_post_draw
 var frame: Image = get_viewport().get_texture().get_image()
 var file: FileAccess = FileAccess.open("res://artifacts/ai-lab-"+title+".pixels",FileAccess.WRITE)
 file.store_buffer(frame.get_data())
 var encodings: Dictionary = {Image.FORMAT_RGBH:"RGBH",Image.FORMAT_RGBAH:"RGBAH",Image.FORMAT_RGBF:"RGBF",Image.FORMAT_RGBAF:"RGBAF",Image.FORMAT_RGB8:"RGB8",Image.FORMAT_RGBA8:"RGBA8"}
 captures.append({"name":"ai-lab-"+title,"image_width":frame.get_width(),"image_height":frame.get_height(),"raw_encoding":encodings.get(frame.get_format(),"UNSUPPORTED")})
