class_name KeybindSettingsModal
extends CanvasLayer

var backdrop: ColorRect
var frame: PanelContainer
var capture_action: String = ""
var capture_label: Button
var previous_focus: Control
var status_label: Label
var retry_button: Button
var key_buttons: Dictionary = {}

func open_modal() -> void:
 layer = 45
 process_mode = Node.PROCESS_MODE_ALWAYS
 add_to_group("gameplay_input_blocker")
 previous_focus = get_viewport().gui_get_focus_owner()
 backdrop = ColorRect.new()
 backdrop.color = Color(0.003,0.008,0.016,0.88)
 backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
 add_child(backdrop)
 var center: CenterContainer = CenterContainer.new()
 center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 backdrop.add_child(center)
 frame = PanelContainer.new()
 frame.custom_minimum_size = Vector2(720,620)
 center.add_child(frame)
 var padding: MarginContainer = MarginContainer.new()
 for side: String in ["left","right","top","bottom"]: padding.add_theme_constant_override("margin_"+side,20)
 frame.add_child(padding)
 var column: VBoxContainer = VBoxContainer.new()
 padding.add_child(column)
 var heading: HBoxContainer = HBoxContainer.new()
 column.add_child(heading)
 var title: Label = Label.new()
 title.text = "按键设置"
 CommanderTheme.font(title,26)
 title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 heading.add_child(title)
 var close: Button = Button.new()
 close.text = "关闭 [Esc]"
 close.custom_minimum_size.y = 44
 close.pressed.connect(close_modal)
 heading.add_child(close)
 var scroll: ScrollContainer = ScrollContainer.new()
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 scroll.mouse_force_pass_scroll_events = false
 column.add_child(scroll)
 var list: VBoxContainer = VBoxContainer.new()
 list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 list.add_theme_constant_override("separation",6)
 scroll.add_child(list)
 var groups: Array[Dictionary] = [
  {"title":"兵种技能","actions":["skill_triangle","skill_square","skill_circle","skill_diamond","skill_hexagon"]},
  {"title":"小队与部署","actions":["squad_hold_orbit","squad_return_ai","spawn_triangle","spawn_square","spawn_circle","spawn_diamond","spawn_hexagon"]},
  {"title":"指挥技能","actions":["cmd_emp","cmd_overclock","cmd_swap"]},
  {"title":"AI 参谋","actions":["copilot_opt_1","copilot_opt_2","copilot_opt_3","copilot_toggle_auto"]},
  {"title":"界面","actions":["toggle_tactical_drawer"]}
 ]
 for group: Dictionary in groups:
  var group_label: Label = Label.new()
  group_label.text = group["title"]
  CommanderTheme.font(group_label,17)
  group_label.add_theme_color_override("font_color",ProceduralGeo.GOLD)
  list.add_child(group_label)
  for action: String in group["actions"]:
   var row: HBoxContainer = HBoxContainer.new()
   row.custom_minimum_size.y = 46
   list.add_child(row)
   var action_label: Label = Label.new()
   action_label.text = action_title(action)
   CommanderTheme.font(action_label,15)
   action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
   row.add_child(action_label)
   var key_button: Button = Button.new()
   key_button.text = KeybindManager.get_key_label(action)
   key_button.custom_minimum_size = Vector2(150,44)
   key_button.pressed.connect(func() -> void: begin_capture(action,key_button))
   row.add_child(key_button)
   key_buttons[action] = key_button
 var footer: HBoxContainer = HBoxContainer.new()
 column.add_child(footer)
 status_label = Label.new()
 status_label.name = "Status"
 status_label.text = "点击按键后按下新键。冲突按键会自动交换。"
 CommanderTheme.font(status_label,14)
 status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 footer.add_child(status_label)
 retry_button = Button.new()
 retry_button.text = "重试保存"
 retry_button.custom_minimum_size.y = 44
 retry_button.visible = not KeybindManager.persistence_error.is_empty()
 retry_button.pressed.connect(func() -> void:
  KeybindManager.retry_save()
  update_status("按键已保存" if KeybindManager.persistence_error.is_empty() else KeybindManager.persistence_error))
 footer.add_child(retry_button)
 var reset: Button = Button.new()
 reset.text = "恢复默认"
 reset.custom_minimum_size.y = 44
 reset.pressed.connect(func() -> void:
  var result: Dictionary = KeybindManager.reset_to_defaults()
  update_key_labels()
  update_status("已恢复默认按键并保存" if bool(result.get("saved",false)) else str(result.get("message","恢复默认已生效，但未保存")))
 )
 footer.add_child(reset)
 if not SignalBus.keybinds_updated.is_connected(_on_keybinds_updated):
  SignalBus.keybinds_updated.connect(_on_keybinds_updated)
 close.grab_focus()

func action_title(action: String) -> String:
 var names: Dictionary = {"skill_triangle":"三角形技能","skill_square":"方形技能","skill_circle":"圆形技能","skill_diamond":"菱形技能","skill_hexagon":"六边形技能","squad_hold_orbit":"小队驻守环绕","squad_return_ai":"归还 AI 托管","spawn_triangle":"部署三角形","spawn_square":"部署方形","spawn_circle":"部署圆形","spawn_diamond":"部署菱形","spawn_hexagon":"部署六边形","cmd_emp":"EMP","cmd_overclock":"超频区","cmd_swap":"拓扑转移","copilot_opt_1":"参谋方案一","copilot_opt_2":"参谋方案二","copilot_opt_3":"参谋方案三","copilot_toggle_auto":"参谋自动代理","toggle_tactical_drawer":"战术矩阵"}
 return str(names.get(action,action))

func begin_capture(action: String, button: Button) -> void:
 capture_action = action
 capture_label = button
 button.text = "请按下新按键..."
 update_status("正在设置："+action_title(action)+"，Esc 取消")
 button.grab_focus()

func _input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.is_pressed() or event.is_echo(): return
 var key_event: InputEventKey = event as InputEventKey
 if key_event.keycode == KEY_ESCAPE:
  if not capture_action.is_empty():
   if is_instance_valid(capture_label): capture_label.text = KeybindManager.get_key_label(capture_action)
   capture_action = ""
   update_status("已取消按键捕获")
  else:
   close_modal()
  get_viewport().set_input_as_handled()
  return
 if capture_action.is_empty(): return
 var code: Key = key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode
 var result: Dictionary = KeybindManager.rebind_action(capture_action,code)
 if bool(result.get("ok",false)):
  var changed_action: String = capture_action
  update_key_labels()
  var swapped: String = str(result.get("swapped",""))
  var message: String = action_title(changed_action)+" 已绑定到 "+KeybindManager.get_key_label(changed_action)
  if not swapped.is_empty(): message += "；与"+action_title(swapped)+"交换"
  if not bool(result.get("saved",false)): message += "。本次运行生效，未保存，可重试"
  update_status(message)
  capture_action = ""
  get_viewport().set_input_as_handled()
 else:
  if is_instance_valid(capture_label): capture_label.text = KeybindManager.get_key_label(capture_action)
  update_status(str(result.get("message","按键无效")))
  capture_action = ""
  get_viewport().set_input_as_handled()

func _on_keybinds_updated(_bindings: Dictionary) -> void:
 update_key_labels()

func update_key_labels() -> void:
 for action: String in key_buttons:
  if is_instance_valid(key_buttons[action]):
   (key_buttons[action] as Button).text = KeybindManager.get_key_label(action)

func update_status(message: String) -> void:
 if not is_instance_valid(status_label): return
 status_label.text = message
 retry_button.visible = not KeybindManager.persistence_error.is_empty()

func _exit_tree() -> void:
 if is_instance_valid(SignalBus) and SignalBus.keybinds_updated.is_connected(_on_keybinds_updated):
  SignalBus.keybinds_updated.disconnect(_on_keybinds_updated)

func close_modal() -> void:
 if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree(): previous_focus.grab_focus()
 queue_free()
