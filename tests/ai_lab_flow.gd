extends Node
var passed: int = 0
var failed: int = 0
func check(value: bool, name: String) -> void:
 if value: passed += 1
 else:
  failed += 1
  push_error("AI_LAB_FLOW_FAIL "+name)
func frames(count: int = 5) -> void:
 for i: int in range(count): await get_tree().process_frame
func _ready() -> void:
 GameSettings.values = GameSettings.DEFAULTS.duplicate()
 LaboratoryStore.setup.clear()
 var lab: TacticLaboratory = (load("res://scenes/tactic_laboratory.tscn") as PackedScene).instantiate() as TacticLaboratory
 add_child(lab)
 await frames()
 check(lab.view.context.units_for(0).size() == 9 and lab.view.context.units_for(1).size() == 9,"standard roster")
 for map_id: String in MapCatalog.IDS:
  lab.view.layout.clear()
  lab.change_map(MapCatalog.IDS.find(map_id))
  for index: int in range(6):
   lab.load_preset(index)
   check(lab.view.layout.size() == LaboratoryPresets.create(index).size(),"preset valid "+map_id+str(index))
   for i: int in range(lab.view.layout.size()):
    var spec: Dictionary = lab.view.layout[i]
    check(lab.view.context.valid_point(spec["kind"],Vector2(spec["x"],spec["y"]),i,lab.view.layout).is_empty(),"preset safe "+map_id+str(index)+str(i))
 lab.load_preset(1)
 var starting: Array[Dictionary] = lab.view.layout.duplicate(true)
 lab.view.rebuild(true,false)
 await frames()
 check(lab.start_button.disabled and lab.map_select.disabled and not lab.hp_input.editable,"running locks edit controls")
 lab.view.context.toggle_pause()
 var position: Vector2 = lab.view.context.local_units[0].position
 var elapsed: float = lab.view.context.elapsed
 await frames(20)
 check(position == lab.view.context.local_units[0].position and elapsed == lab.view.context.elapsed,"local pause")
 lab.view.rebuild(false,false)
 check(lab.view.layout == starting,"reset preserves initial layout")
 lab.view.rebuild(true,true)
 check(lab.view.context.profile_for(0) == TacticalBrain.get_default_profile(),"default comparison uses same layout defaults")
 check(lab.view.layout == starting,"comparison same positions")
 lab.view.rebuild(false,false)
 lab.editor.select_kind("triangle")
 lab.editor.prompt.text = "低生命时撤退"
 lab.editor.select_kind("square")
 lab.editor.select_kind("triangle")
 check(lab.editor.prompt.text == "低生命时撤退","per unit prompt saved")
 var program: Dictionary = UnitTacticProgram.default_program("triangle")
 program["rules"] = [{"id":"hold","when":{"fact":"self_hp","op":"lt","value":0.3},"actions":{"behavior":"hold"}}]
 lab.editor.preview.text = JSON.stringify(program)
 lab.editor.apply_and_run()
 check(lab.view.context.profile_for(0)["unit_rules"]["triangle"].has("program"),"apply run context program")
 var original_square: Dictionary = TacticalBrain.opening_profile["unit_rules"]["square"].duplicate(true)
 lab.editor.apply_opening()
 check(TacticalBrain.opening_profile["unit_rules"]["triangle"].has("program") and TacticalBrain.opening_profile["unit_rules"]["square"] == original_square,"opening one kind")
 var previous: Dictionary = lab.view.context.profile_for(0).duplicate(true)
 lab.editor.preview.text = "{invalid"
 lab.editor.apply_and_run()
 check(lab.view.context.profile_for(0) == previous,"invalid preview no apply")
 check(lab.editor.feedback.text.contains("上一份有效 JSON 与验证场保持"),"invalid preview explains preserved state")
 var modal: SettingsPanel = SettingsPanel.new()
 lab.add_child(modal)
 modal.select_category("LLM")
 modal.open_panel()
 await frames()
 var left: float = lab.view.context.elapsed
 await frames(20)
 check(get_tree().paused and lab.view.context.elapsed == left,"LLM settings pauses battle")
 modal.close_panel()
 await frames()
 check(not get_tree().paused and lab.editor.prompt.text == "低生命时撤退","close restores drafts")
 # Placement counts and invalid positions leave initial data unchanged.
 lab.view.rebuild(false,false)
 var count: int = lab.view.layout.size()
 lab.view.add_unit(Vector2(1200,140))
 check(lab.view.layout.size() == count,"invalid placement atomic")
 lab.view.layout.clear()
 for i: int in range(2): lab.view.layout.append(LaboratoryPresets.unit("hexagon",0,400+i*100,200))
 lab.view.rebuild(false,false)
 lab.view.place_kind = "hexagon"
 lab.view.add_unit(Vector2(600,200))
 check(lab.view.layout.size() == 2,"two hex cap")
 lab.view.layout.clear()
 for i: int in range(30): lab.view.layout.append(LaboratoryPresets.unit("triangle",0,350+(i%10)*55,150+(i/10)*70))
 lab.view.rebuild(false,false)
 lab.view.place_kind = "triangle"
 lab.view.add_unit(Vector2(1000,200))
 check(lab.view.layout.size() == 30,"population cap")
 lab.queue_free()
 await frames()
 check(LLMService.requests.is_empty(),"leaving cancels owners")
 print("AI_LAB_FLOW passed=%d failed=%d" % [passed,failed])
 get_tree().quit(0 if failed == 0 else 1)
