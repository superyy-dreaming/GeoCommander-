extends Node

var lab: TacticLaboratory
var passed: int = 0
var failed: int = 0

func check(ok: bool, title: String) -> void:
 if ok: passed += 1
 else:
  failed += 1
  push_error("LAB_MENU_FAIL "+title)

func frames() -> void:
 for i: int in range(6): await get_tree().process_frame

func click(control: Control) -> void:
 var motion: InputEventMouseMotion = InputEventMouseMotion.new()
 motion.position = control.get_global_rect().get_center()
 motion.global_position = motion.position
 Input.parse_input_event(motion)
 await get_tree().process_frame
 for down: bool in [true,false]:
  var event: InputEventMouseButton = InputEventMouseButton.new()
  event.position = control.get_global_rect().get_center()
  event.global_position = event.position
  event.button_index = MOUSE_BUTTON_LEFT
  event.pressed = down
  Input.parse_input_event(event)
  await get_tree().process_frame
 await frames()

func key(_viewport: Viewport, code: Key) -> void:
 # PopupMenu handles keys before Viewport.push_input(), in Window's input
 # dispatch. Route through Input so embedded popup selection is exercised.
 for down: bool in [true,false]:
  var event: InputEventKey = InputEventKey.new()
  event.keycode = code
  event.pressed = down
  Input.parse_input_event(event)
  await get_tree().process_frame
 await frames()

func choose(menu: MenuButton, index: int) -> void:
 await click(menu)
 check(menu.get_popup().visible,"menu opens: "+menu.text)
 await select_popup(menu.get_popup(),index)

func select_popup(popup: PopupMenu, index: int) -> void:
 # Navigate through Window's actual keyboard dispatch. Setting focus directly
 # can be overwritten by the first native mouse motion after a popup opens.
 for attempt: int in range(popup.item_count+1):
  if popup.get_focused_item()==index: break
  await key(popup,KEY_DOWN)
 check(popup.get_focused_item()==index,"popup keyboard selection "+str(index))
 await key(popup,KEY_ENTER)

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 GameSettings.values = GameSettings.DEFAULTS.duplicate()
 GameSettings.set_value("font_scale",1.8,false)
 DisplayServer.window_set_size(Vector2i(1280,720))
 LaboratoryStore.setup.clear()
 lab = (load("res://scenes/tactic_laboratory.tscn") as PackedScene).instantiate() as TacticLaboratory
 add_child(lab)
 DisplayServer.window_move_to_foreground()
 get_window().grab_focus()
 await get_tree().create_timer(0.5,true).timeout
 await frames()
 var context: int = lab.view.context.get_instance_id()
 var initial: Array[Dictionary] = lab.view.layout.duplicate(true)
 lab.editor.preview.text = "{invalid draft retained}"
 lab.editor.prompt.text = "菜单切换保留提示词"
 for index: int in [3,2,1,0]:
  await click(lab.editor.page_select)
  await select_popup(lab.editor.page_select.get_popup(),index)
  check(lab.editor.tabs.current_tab==index,"editor page reachable "+str(index))
 check(lab.editor.preview.text=="{invalid draft retained}" and lab.editor.prompt.text=="菜单切换保留提示词","page navigation preserves invalid JSON and prompt drafts")
 await choose(lab.map_menu,0)
 check(lab.dialog.opened,"map change requires confirmation")
 await key(get_viewport(),KEY_ESCAPE)
 check(lab.view.context.get_instance_id()==context and lab.view.layout==initial,"cancel map change preserves combat context and formation")
 await choose(lab.placement_menu,0)
 check(lab.placement_panel.visible,"placement properties open from menu")
 await key(lab.placement_panel,KEY_ESCAPE)
 check(not lab.placement_panel.visible,"Esc closes placement popup first")
 await choose(lab.edit_menu,2)
 check(lab.view.edit_mode==2,"cover selection mode reachable")
 await choose(lab.edit_menu,0)
 check(lab.view.edit_mode==0,"formation mode restored")
 var debug_menu: MenuButton = lab.edit_menu.get_parent().get_child(3) as MenuButton
 await choose(debug_menu,0)
 check(lab.dialog.opened,"reset validation uses shared confirmation")
 await key(get_viewport(),KEY_ESCAPE)
 check(lab.view.context.get_instance_id()==context,"cancel reset does not rebuild combat")
 await choose(lab.display_menu,0)
 check(not lab.floating.visible,"display menu hides readout")
 await choose(lab.display_menu,0)
 check(lab.floating.visible,"display menu restores readout")
 await choose(lab.display_menu,1)
 check(not lab.floating.collapsed,"reset readout restores expanded frame")
 lab.readings.current_tab = 2
 await frames()
 var zoom: float = lab.view.zoom_factor
 var wheel: InputEventMouseButton = InputEventMouseButton.new()
 wheel.position = lab.event_log.get_global_rect().get_center()
 wheel.global_position = wheel.position
 wheel.button_index = MOUSE_BUTTON_WHEEL_UP
 wheel.pressed = true
 Input.parse_input_event(wheel)
 wheel = wheel.duplicate() as InputEventMouseButton
 wheel.pressed = false
 Input.parse_input_event(wheel)
 await frames()
 check(lab.view.zoom_factor==zoom,"readout scrolling never zooms battlefield")
 await choose(lab.editor.more,4)
 check(lab.dialog.opened,"restore default requires confirmation")
 await key(get_viewport(),KEY_ESCAPE)
 check(lab.editor.preview.text=="{invalid draft retained}","cancel default preserves raw invalid JSON")
 lab.editor.more.grab_focus()
 await key(get_viewport(),KEY_SPACE)
 check(lab.editor.more.get_popup().visible,"More menu opens using keyboard focus and Space")
 await key(lab.editor.more.get_popup(),KEY_ESCAPE)
 check(not lab.editor.more.get_popup().visible and not lab.dialog.opened,"Esc closes menu without modifying draft")
 lab.open_settings()
 lab.open_settings()
 await frames()
 var panels: int = 0
 for child: Node in lab.get_children():
  if child is SettingsPanel: panels += 1
 check(panels==1,"settings entry prevents duplicate panels")
 await key(get_viewport(),KEY_ESCAPE)
 check(not get_tree().paused and lab.view.context.get_instance_id()==context,"settings closes without changing context or pause state")
 print("LAB_MENU_NATIVE passed=%d failed=%d" % [passed,failed])
 get_tree().quit(0 if failed==0 else 1)
