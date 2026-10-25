extends "res://tests/ai_lab_native_flow.gd"
var lab: TacticLaboratory

func map_click(point: Vector2, right: bool=false, release_at: Vector2=Vector2.INF) -> void:
 for pressed: bool in [true,false]:
  var world: Vector2=release_at if not pressed and release_at.is_finite() else point
  var screen: Vector2=lab.view.global_position+(world-lab.view.camera.position)*lab.view.camera.zoom+lab.view.size*0.5
  var event: InputEventMouseButton=InputEventMouseButton.new()
  event.position=screen
  event.global_position=screen
  event.button_index=MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT
  event.pressed=pressed
  get_viewport().push_input(event,true)
 await frames()

func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 GameSettings.values=GameSettings.DEFAULTS.duplicate()
 LaboratoryStore.setup.clear()
 LaboratoryStore.applied_programs.clear()
 LaboratoryStore.records["triangle"]["program"]=TacticExamples.for_unit("triangle")
 LaboratoryStore.records["triangle"]["draft_json"]=""
 LaboratoryStore.selected_kind="triangle"
 lab=(load("res://scenes/tactic_laboratory.tscn") as PackedScene).instantiate() as TacticLaboratory
 add_child(lab)
 DisplayServer.window_set_size(Vector2i(1280,720))
 GameSettings.set_value("font_scale",1.3,false)
 lab.editor.tabs.current_tab=2
 await frames()
 var count: int=lab.view.layout.size()
 lab.view.edit_mode=1
 lab.edit_select.select(1)
 lab.refresh_path()
 await map_click(Vector2(700,260))
 check(lab.view.layout.size()==count and lab.view.path_points.size()==1,"path click adds waypoint without placing unit")
 await map_click(Vector2(1200,260))
 check(lab.view.path_points.size()==2,"second native waypoint")
 await map_click(Vector2(700,260),false,Vector2(750,260))
 check(absf(float(lab.view.path_points[0][0])-750)<2,"native waypoint drag changes coordinate")
 await map_click(Vector2(1200,260),true)
 check(lab.view.path_points.size()==1,"native right-click deletes waypoint")
 lab.editor.plan_editor.undo()
 check(lab.view.path_points.size()==2,"path undo updates viewport")
 lab.editor.plan_editor.redo()
 check(lab.view.path_points.size()==1,"path redo updates viewport")
 lab.view.grab_focus()
 send_key(KEY_DELETE)
 await frames()
 check(lab.view.layout.size()==count,"path editing blocks unit deletion shortcut")
 lab.view.edit_mode=2
 lab.edit_select.select(2)
 await map_click(lab.view.context.navigation.walls[0].global_position)
 check(not lab.view.path_obstacle.is_empty() and lab.editor.plan_editor.program["plan"]["map_id"]=="balanced","native wall selection binds stable obstacle")
 var before: Dictionary=lab.editor.plan_editor.program.duplicate(true)
 lab.editor.busy=true
 lab.editor.update_buttons()
 await map_click(lab.view.context.navigation.walls[1].global_position)
 check(lab.editor.plan_editor.program==before and not (lab.editor.plan_editor.fields["id"] as LineEdit).editable,"generation locks plan fields and map editing")
 lab.editor.busy=false
 lab.editor.update_buttons()
 lab.editor.plan_editor.change(TacticExamples.for_unit("triangle"))
 lab.view.edit_mode=0
 lab.edit_select.select(0)
 lab.editor.apply_and_run()
 await frames()
 var unit: BaseGeoUnit=lab.view.context.units_for(0).filter(func(u: BaseGeoUnit)->bool:return u.execution!=null)[0]
 lab.view.selected_unit=unit
 lab.view.context.toggle_pause()
 var elapsed: float=lab.view.context.elapsed
 var clock: float=unit.execution.state["time"]
 lab.view.context.step_frame()
 await frames(5)
 check(absf(lab.view.context.elapsed-elapsed-1.0/60)<0.001 and absf(float(unit.execution.state["time"])-clock-1.0/60)<0.001,"native single frame advances exactly one physics tick")
 lab.view.context.step_transition(unit)
 for i: int in range(400):
  await frames(1)
  if lab.view.context.state==LaboratoryArena.State.PAUSED: break
 check(lab.view.context.state==LaboratoryArena.State.PAUSED and unit.execution.current=="cover","native run-to-next-step pauses on transition")
 lab.view.rebuild(false,false)
 lab.attach_context()
 lab.editor.prompt.grab_focus()
 send_key(KEY_DELETE)
 await frames()
 check(lab.view.layout.size()==count,"text editing key does not delete battle units")
 var profile: Dictionary=TacticalBrain.opening_profile.duplicate(true)
 lab.editor.apply_opening()
 check(TacticalBrain.opening_profile["unit_rules"]["triangle"].has("program") and TacticalBrain.opening_profile["unit_rules"]["diamond"]==profile["unit_rules"]["diamond"],"opening applies only the selected unit kind")
 TacticalBrain.opening_profile=profile
 lab.queue_free()
 await frames()
 check(LLMService.requests.is_empty(),"native lab exit cleans request ownership")
 var file: FileAccess=FileAccess.open("res://artifacts/tactic-v2-native.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"passed":passed,"failed":failed,"renderer":"Metal Forward+","font_scale":1.3,"window":"1280x720"},"  "))
 print("PLAN_NATIVE passed=%d failed=%d" % [passed,failed])
 get_tree().quit(0 if failed==0 else 1)
