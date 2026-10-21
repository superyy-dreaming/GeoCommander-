extends Node

var lab: TacticLaboratory
var captures: Array[Dictionary] = []
var passed: int = 0
var failed: int = 0

func check(ok: bool, title: String) -> void:
 if ok: passed += 1
 else:
  failed += 1
  push_error("BOUNDARY_NATIVE_FAIL "+title)
 print(("PASS " if ok else "FAIL ")+title)

func frames(count: int = 5) -> void:
 for i: int in range(count): await get_tree().process_frame

func _ready() -> void:
 var key: String = OS.get_environment("GEO_LLM_TEST_KEY")
 OS.unset_environment("GEO_LLM_TEST_KEY")
 if key.is_empty():
  check(false,"in-memory credential required")
  get_tree().quit(1)
  return
 LLMService.config_path = "user://test_boundary_native_connection.cfg"
 LLMService.configure("https://api.siliconflow.cn/v1",key,BoundaryOriginal.MODEL)
 key = ""
 LaboratoryStore.selected_kind = "triangle"
 LaboratoryStore.setup.clear()
 LaboratoryStore.applied_programs.clear()
 GameSettings.values = GameSettings.DEFAULTS.duplicate(true)
 DisplayServer.window_set_size(Vector2i(1440,900))
 lab = (load("res://scenes/tactic_laboratory.tscn") as PackedScene).instantiate() as TacticLaboratory
 add_child(lab)
 await frames()
 lab.editor.prompt.text = BoundaryOriginal.ORIGINAL
 lab.editor.generate.pressed.emit()
 check(lab.editor.busy and lab.editor.cancel_button.visible and not lab.editor.cancel_button.disabled,"native UI sends original prompt and allows cancel")
 check(lab.editor.feedback.text.contains("非思考 JSON"),"native UI identifies active provider request mode")
 var started: int = Time.get_ticks_msec()
 while lab.editor.busy and Time.get_ticks_msec()-started <35000: await frames(1)
 var checked: Dictionary = UnitTacticProgram.parse(lab.editor.preview.text,"triangle")
 check(not lab.editor.busy and checked["ok"] and lab.editor.feedback.text.contains("校验通过"),"real provider response passes actual editor callback")
 if checked["ok"]:
  var file: FileAccess = FileAccess.open("res://artifacts/boundary-native-generated.json",FileAccess.WRITE)
  file.store_string(lab.editor.preview.text)
  lab.map_select.item_selected.emit(1)
  lab.view.layout = [LaboratoryPresets.unit("triangle",0,560,675),LaboratoryPresets.unit("triangle",0,390,750),LaboratoryPresets.unit("diamond",1,1650,675),LaboratoryPresets.unit("square",1,720,675)]
  lab.view.rebuild(false,false)
  lab.view.persist()
  lab.show_message("已载入 自定义布阵，可验证边路推进、绕后与菱形优先")
  lab.attach_context()
  lab.editor.apply_button.pressed.emit()
  await frames()
  var unit: BaseGeoUnit = lab.view.context.units_for(0)[0]
  lab.view.selected_unit = unit
  lab.refresh()
  for enemy: BaseGeoUnit in lab.view.context.units_for(1-lab.view.place_team):
   enemy.scripted_control = true
   enemy.attack_left = 999
   enemy.skill_left = 999
  check(lab.view.context.active and unit.base_rule.has("program") and unit.rule["movement"] == "boundary_infiltrate","actual apply button starts generated autonomous maneuver")
  await capture("boundary-native-json")
  lab.editor.tabs.current_tab = 0
  for i: int in range(400):
   await get_tree().physics_frame
   if unit.boundary_maneuver.phase == "edge" and unit.position.x>850: break
  check(unit.boundary_maneuver.phase == "edge" and unit.position.y<130,"native Metal units navigate L cover and advance at boundary")
  await capture("boundary-native-edge")
  GameSettings.set_value("font_scale",1.3,false)
  DisplayServer.window_set_size(Vector2i(1280,720))
  await frames()
  lab.editor.generate.grab_focus()
  await frames()
  var scroll: ScrollContainer = lab.editor.tabs.get_child(0) as ScrollContainer
  check(lab.editor.apply_button.get_global_rect().end.y <=720 and scroll.get_global_rect().grow(2).encloses(lab.editor.generate.get_global_rect()),"minimum window large font reveals generate action on focus")
  await capture("boundary-native-large-font")
  lab.editor.opening_button.pressed.emit()
  check(TacticalBrain.opening_profile["unit_rules"]["triangle"].get("program",{}).get("base",{}).get("movement") == "boundary_infiltrate","actual opening button preserves generated program")
 LLMService.cancel_all()
 LLMService.api_key = ""
 lab.queue_free()
 await frames()
 var report: FileAccess = FileAccess.open("res://artifacts/boundary-native-report.json",FileAccess.WRITE)
 report.store_string(JSON.stringify({"passed":passed,"failed":failed,"captures":captures,"elapsed_ms":Time.get_ticks_msec()-started,"real_provider":true},"  "))
 print("BOUNDARY_NATIVE_RESULT passed=%d failed=%d" % [passed,failed])
 get_tree().quit(0 if failed ==0 else 1)

func capture(title: String) -> void:
 await RenderingServer.frame_post_draw
 var frame: Image = get_viewport().get_texture().get_image()
 var file: FileAccess = FileAccess.open("res://artifacts/"+title+".pixels",FileAccess.WRITE)
 file.store_buffer(frame.get_data())
 var encodings: Dictionary = {Image.FORMAT_RGBH:"RGBH",Image.FORMAT_RGBAH:"RGBAH",Image.FORMAT_RGBF:"RGBF",Image.FORMAT_RGBAF:"RGBAF",Image.FORMAT_RGB8:"RGB8",Image.FORMAT_RGBA8:"RGBA8"}
 captures.append({"name":title,"image_width":frame.get_width(),"image_height":frame.get_height(),"raw_encoding":encodings.get(frame.get_format(),"UNSUPPORTED")})

# Reference the test prompt constants without making the runner a global class.
const BoundaryOriginal = preload("res://tests/boundary_tactic_runner.gd")
