extends "res://tests/ai_lab_visual.gd"

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 GameSettings.values = GameSettings.DEFAULTS.duplicate()
 LaboratoryStore.setup.clear()
 LaboratoryStore.records["triangle"]["program"] = TacticExamples.for_unit("triangle")
 LaboratoryStore.records["triangle"]["draft_json"] = ""
 lab = (load("res://scenes/tactic_laboratory.tscn") as PackedScene).instantiate() as TacticLaboratory
 add_child(lab)
 lab.editor.tabs.current_tab = 2
 lab.editor.plan_editor.selected = 1
 lab.editor.plan_editor.render()
 for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080)]:
  DisplayServer.window_set_size(dimensions)
  for factor: float in [1.0,1.3]:
   GameSettings.set_value("font_scale",factor,false)
   await settle()
   await capture("v2-steps-%dx%d-%d" % [dimensions.x,dimensions.y,roundi(factor*100)],lab.ui)
  if dimensions == Vector2i(1280,720):
   lab.editor.plan_editor.change(TacticPlan.default_program("triangle"))
   lab.view.edit_mode = 1
   lab.edit_select.select(1)
   lab.view.path_step = "step_1"
   lab.editor.plan_editor.edit_path("step_1",[[700,260],[1200,260],[1800,260]])
   lab.refresh_path()
   await settle()
   await capture("v2-path-large",lab.ui)
   lab.editor.tabs.current_tab = 1
   await settle()
   await capture("v2-json-large",lab.ui)
   lab.editor.preview.text = "{\"version\":2,\"damage\":999}"
   lab.editor.validate_preview()
   await settle()
   await capture("v2-error-large",lab.ui)
   lab.editor.plan_editor.change(TacticExamples.for_unit("triangle"))
   lab.view.edit_mode=0
   lab.edit_select.select(0)
   lab.editor.apply_and_run()
   lab.readings.current_tab = 1
   lab.view.selected_unit = lab.view.context.units_for(0).filter(func(u: BaseGeoUnit)->bool:return u.execution!=null)[0]
   lab.view.selected_unit.selected=true
   await get_tree().create_timer(0.5).timeout
   lab.view.context.toggle_pause()
   lab.editor.tabs.current_tab = 2
   await settle()
   await capture("v2-execution-large",lab.ui)
   lab.view.rebuild(false,false)
   lab.attach_context()
 var report: FileAccess = FileAccess.open("res://artifacts/tactic-v2-visual-report.json",FileAccess.WRITE)
 report.store_string(JSON.stringify({"captures":captures,"overflow":overflow,"screen_scale":DisplayServer.screen_get_scale(),"screen_size":str(DisplayServer.screen_get_size())},"  "))
 print("PLAN_VISUAL captures=%d overflow=%d" % [captures.size(),overflow.size()])
 get_tree().quit()
