extends "res://tests/ai_lab_visual.gd"

var passed: int = 0
var failed: int = 0
var metrics: Array[Dictionary] = []
var baseline_action_height: float = 0.0

func check(ok: bool, title: String) -> void:
 if ok: passed+=1
 else:
  failed+=1
  push_error("LAB_LAYOUT_FAIL "+title)

func visible_rect(node: Control) -> Rect2:
 var rect: Rect2=node.get_global_rect().intersection(get_viewport().get_visible_rect())
 var parent: Node=node.get_parent()
 while parent!=null:
  if parent is Control and (parent as Control).clip_contents: rect=rect.intersection((parent as Control).get_global_rect())
  parent=parent.get_parent()
 return rect

func full_visible(node: Control) -> bool:
 return node.is_visible_in_tree() and visible_rect(node).grow(1).encloses(node.get_global_rect())

func click(point: Vector2) -> void:
 for down: bool in [true,false]:
  var event: InputEventMouseButton=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_LEFT
  event.position=point
  event.global_position=point
  event.pressed=down
  get_viewport().push_input(event,true)
 await settle()

func drag(from: Vector2,to: Vector2) -> void:
 var event: InputEventMouseButton=InputEventMouseButton.new()
 event.position=from
 event.global_position=from
 event.button_index=MOUSE_BUTTON_LEFT
 event.pressed=true
 get_viewport().push_input(event,true)
 var motion: InputEventMouseMotion=InputEventMouseMotion.new()
 motion.position=to
 motion.global_position=to
 motion.relative=to-from
 get_viewport().push_input(motion,true)
 event=InputEventMouseButton.new()
 event.position=to
 event.global_position=to
 event.button_index=MOUSE_BUTTON_LEFT
 event.pressed=false
 get_viewport().push_input(event,true)
 await settle()

func key(code: Key) -> void:
 var event: InputEventKey=InputEventKey.new()
 event.keycode=code
 event.pressed=true
 get_viewport().push_input(event,true)

func assert_layout(tag: String) -> void:
 var ed: LabPromptEditor=lab.editor
 var ratio: float=ed.info_area.size.y/(ed.split.size.y-12)
 metrics.append({"tag":tag,"left":str(lab.units_panel.get_global_rect()),"split_height":ed.split.size.y,"feedback_height":ed.info_area.size.y,"feedback_ratio":ratio,"frame":str(lab.floating.get_global_rect()),"battlefield":str(lab.view.get_global_rect())})
 var expected: float=maxf(0.4,ed.feedback_panel.get_combined_minimum_size().y/(ed.split.size.y-12))
 check(absf(ratio-expected)<0.055 and ratio<=0.605,tag+" feedback uses 40%, preserving readable minimum within 60%")
 check(ed.feedback_panel.scroll.size.y>=ed.feedback.get_theme_font("font").get_height(ed.feedback.get_theme_font_size("font_size"))*1.9,tag+" feedback shows at least two text lines")
 for control: Control in [ed.generate,ed.validate_button,ed.apply_button,ed.opening_button,ed.feedback_panel,lab.start_button,lab.pause_button]:
  check(full_visible(control),tag+" visible "+control.get_class()+" "+str(control.get_global_rect()))
 check(not ed.action_rows.get_global_rect().intersects(ed.info_area.get_global_rect()),tag+" fixed actions do not obscure feedback")
 check(ed.prompt.size.y>=44,tag+" editable text area remains usable")
 check(lab.view.get_global_rect().encloses(lab.floating.get_global_rect()),tag+" readout contained in battlefield")
 check(full_visible(lab.floating.collapse) and full_visible(lab.floating.close_button),tag+" readout title actions visible")
 check(not ed.generate.get_global_rect().intersects(ed.validate_button.get_global_rect()),tag+" generation actions do not overlap")

func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 GameSettings.values=GameSettings.DEFAULTS.duplicate()
 LaboratoryStore.setup.clear()
 LaboratoryStore.selected_kind="triangle"
 LaboratoryStore.records["triangle"]["program"]=TacticExamples.for_unit("triangle")
 LaboratoryStore.records["triangle"]["draft_json"]=""
 LabPromptEditor.feedback_ratio=0.4
 TacticLaboratory.left_ratio=0.42
 LabFloatingReadout.remembered_size=Vector2.ZERO
 LabFloatingReadout.remembered_position=Vector2(-1,-1)
 lab=(load("res://scenes/tactic_laboratory.tscn") as PackedScene).instantiate() as TacticLaboratory
 add_child(lab)
 await settle()
 lab.editor.prompt.text="向上移动2秒，寻找墙后掩体，等待冲刺就绪后绕到敌方菱形背后。"
 var context_id: int=lab.view.context.get_instance_id()
 var draft: String=lab.editor.preview.text
 for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080)]:
  DisplayServer.window_set_size(dimensions)
  for factor: float in [1.0,1.3,1.8]:
   GameSettings.set_value("font_scale",factor,false)
   lab.editor.tabs.current_tab=0
   await settle()
   var tag: String="%dx%d-%d" % [dimensions.x,dimensions.y,roundi(factor*100)]
   assert_layout(tag)
   if tag=="1280x720-100": baseline_action_height=lab.editor.generate.get_parent().size.y
   await capture("layout-"+tag,lab.ui)
 check(lab.view.context.get_instance_id()==context_id and lab.editor.preview.text==draft,"resize/font updates preserve context and JSON")
 DisplayServer.window_set_size(Vector2i(1280,720))
 for factor: float in [1.0,1.15,1.3,1.5,1.8,1.5,1.3,1.15,1.0]:
  GameSettings.set_value("font_scale",factor,false)
  await settle()
  check(full_visible(lab.editor.apply_button),"font roundtrip "+str(factor))
 check(absf(lab.editor.generate.get_parent().size.y-baseline_action_height)<=1,"180 to 100 restores original action height")
 var split_y: float=lab.editor.tabs.get_global_rect().end.y+6
 await drag(Vector2(lab.editor.split.get_global_rect().get_center().x,split_y),Vector2(lab.editor.split.get_global_rect().get_center().x,split_y-55))
 var adjusted: float=lab.editor.info_area.size.y/(lab.editor.split.size.y-12)
 check(adjusted>0.45 and adjusted<=0.605,"native vertical split drag expands feedback within limits")
 var column_x: float=lab.units_panel.get_global_rect().end.x+6
 var old_width: float=lab.units_panel.size.x
 await drag(Vector2(column_x,lab.columns.get_global_rect().get_center().y),Vector2(column_x+45,lab.columns.get_global_rect().get_center().y))
 check(lab.units_panel.size.x>old_width+20,"native horizontal split drag changes editor width")
 LabPromptEditor.feedback_ratio=0.4
 TacticLaboratory.left_ratio=0.42
 lab.reflow()
 GameSettings.set_value("font_scale",1.8,false)
 await settle()
 for index: int in [1,2,3]:
  lab.editor.tabs.current_tab=index
  await settle()
  check(full_visible(lab.editor.tabs),"page "+str(index)+" visible")
  await capture("layout-page-%d-180" % index,lab.ui)
 lab.editor.tabs.current_tab=1
 lab.editor.preview.text="{\"version\":2,\"damage\":999}"
 lab.editor.validate_preview()
 lab.editor.feedback.text+="\n"+"无法校验。请保留草稿，检查字段后重新生成。\n".repeat(14)
 await settle()
 check(lab.editor.feedback_panel.scroll.get_v_scroll_bar().max_value>lab.editor.feedback_panel.scroll.size.y,"long feedback scrolls independently")
 await capture("layout-error-180",lab.ui)
 lab.dialog.present("反馈与验证",lab.editor.feedback_panel.full_text())
 await settle()
 var count: int=lab.view.layout.size()
 await click(lab.view.get_global_rect().get_center())
 check(lab.view.layout.size()==count,"modal blocks battlefield placement")
 check(full_visible(lab.dialog.accept_button) and full_visible(lab.dialog.body),"expanded feedback fixed close and body visible")
 await capture("layout-expanded-180",lab.dialog.root)
 key(KEY_ESCAPE)
 await settle()
 check(not lab.dialog.opened,"Esc dismisses top confirmation")
 check(get_viewport().gui_get_focus_owner()!=lab.dialog.body,"dialog restores previous focus")
 var initial: Array[Dictionary]=lab.view.layout.duplicate(true)
 lab.confirm_operation("清空阵容？","测试取消",lab.clear_layout)
 await settle()
 await click(lab.dialog.cancel_button.get_global_rect().get_center())
 check(lab.view.layout==initial,"cancel destructive operation preserves layout")
 lab.view.dragging=true
 lab.map_menu.about_to_popup.emit()
 check(not lab.view.dragging,"opening menu cancels unit drag")
 lab.placement_panel.open_at(lab.placement_menu_anchor())
 await settle()
 check(lab.placement_panel.size.x<=get_viewport().get_visible_rect().size.x and lab.placement_panel.size.y<=get_viewport().get_visible_rect().size.y,"placement popup bounded")
 check(lab.placement_panel.scroll.size.y<lab.placement_panel.content.size.y and lab.placement_panel.close_button.get_global_rect().end.y<=lab.placement_panel.size.y,"placement body scrolls while close stays visible")
 await capture("layout-placement-180",lab.ui)
 lab.placement_panel.hide()
 lab.floating.reset_layout()
 await settle()
 var pos: Vector2=lab.floating.position
 await drag(lab.floating.title.get_global_rect().get_center(),lab.floating.title.get_global_rect().get_center()+Vector2(-70,60))
 check(lab.floating.position.distance_to(pos)>10 and lab.view.layout.size()==count,"readout drag moves frame without placement")
 var rect: Rect2=lab.floating.get_global_rect()
 await drag(lab.floating.resize_handle.get_global_rect().get_center(),lab.floating.resize_handle.get_global_rect().get_center()+Vector2(50,50))
 check(lab.floating.size.distance_to(rect.size)>5,"readout resizing changes size")
 await click(lab.floating.collapse.get_global_rect().get_center())
 check(lab.floating.collapsed and not lab.readings.visible,"readout collapse")
 await click(lab.floating.collapse.get_global_rect().get_center())
 check(not lab.floating.collapsed,"readout expand")
 check(lab.floating.size.x<=lab.view.size.x*0.6+1 and lab.floating.size.y<=lab.view.size.y*0.65+1,"readout respects maximum relative size")
 await click(lab.floating.close_button.get_global_rect().get_center())
 check(not lab.floating.visible,"readout close")
 lab.floating.reset_layout()
 var path_before: String=lab.editor.preview.text
 lab.editor.more_action(4)
 await settle()
 key(KEY_TAB)
 await settle()
 check(lab.dialog.root.is_ancestor_of(get_viewport().gui_get_focus_owner()),"modal keyboard focus remains inside confirmation")
 key(KEY_ESCAPE)
 await settle()
 check(lab.editor.preview.text==path_before,"cancel restore default keeps JSON draft")
 lab.open_settings()
 await settle()
 var settings: SettingsPanel
 for child: Node in lab.get_children():
  if child is SettingsPanel: settings=child as SettingsPanel
 check(is_instance_valid(settings) and settings.opened,"unified settings opened")
 settings.reset_dialog.popup_centered(Vector2i(600,220))
 await settle()
 check(settings.reset_dialog.size.x<=get_viewport().get_visible_rect().size.x-24,"settings confirmation bounded")
 await capture("layout-settings-confirm-180",settings.root)
 settings.reset_dialog.hide()
 settings.close_panel()
 await settle()
 var storage_path: String=LaboratoryStore.path
 LaboratoryStore.path="user://missing-layout-test-dir/file.json"
 lab.editor.save_draft()
 check(lab.editor.feedback.text.contains("未保存"),"save failure explicitly retains unsaved runtime draft")
 LaboratoryStore.path=storage_path
 lab.editor.more_action(3)
 check(not LaboratoryStore.dirty,"save retry succeeds")
 # Actual local HTTP request with the same fixed actions, no live credentials.
 LLMService.configure("http://127.0.0.1:18741/v1","local-test-key","good")
 lab.editor.tabs.current_tab=0
 lab.editor.prompt.text="生命低于30%时撤退"
 var generation_position: Rect2=lab.editor.generate.get_global_rect()
 lab.editor.request_generate()
 check(not lab.editor.generate.visible and lab.editor.cancel_button.visible and lab.editor.cancel_button.get_global_rect()==generation_position,"cancel reuses fixed generate position")
 await settle()
 check(full_visible(lab.editor.cancel_button) if lab.editor.busy else lab.editor.preview.text.contains("low_hp"),"mock generation or completed candidate visible")
 for i: int in range(250):
  if not lab.editor.busy: break
  await get_tree().process_frame
 check(not lab.editor.busy and lab.editor.preview.text.contains("low_hp"),"mock HTTP candidate validated")
 lab.editor.apply_and_run()
 await settle()
 check(lab.view.context.state==LaboratoryArena.State.RUNNING,"fixed apply action starts validation")
 check(lab.team_select.disabled and lab.placement_panel.status.text.contains("不可修改"),"running placement is disabled with explanation")
 var file: FileAccess=FileAccess.open("res://artifacts/lab-layout-report.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"passed":passed,"failed":failed,"captures":captures,"overflow":overflow,"metrics":metrics,"screen_scale":DisplayServer.screen_get_scale(),"screen_size":str(DisplayServer.screen_get_size())},"  "))
 print("LAB_LAYOUT_NATIVE passed=%d failed=%d overflow=%d captures=%d" % [passed,failed,overflow.size(),captures.size()])
 get_tree().quit(0 if failed==0 and overflow.is_empty() else 1)
