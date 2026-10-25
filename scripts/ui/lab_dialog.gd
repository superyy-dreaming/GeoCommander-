class_name LabDialog
extends CanvasLayer

## One protected, scrollable layer for lab confirmations and expanded feedback.
var root: ColorRect
var panel: PanelContainer
var heading: Label
var body: TextEdit
var accept_button: Button
var cancel_button: Button
var opened: bool = false
var callback: Callable
var previous_focus: Control
var previous_pause: bool = false
var pauses: bool = false

func _ready() -> void:
 layer = 25
 process_mode = Node.PROCESS_MODE_ALWAYS
 root = ColorRect.new()
 root.color = Color(0.003,0.009,0.018,0.9)
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root.mouse_filter = Control.MOUSE_FILTER_STOP
 add_child(root)
 panel = PanelContainer.new()
 root.add_child(panel)
 var column: VBoxContainer = VBoxContainer.new()
 panel.add_child(column)
 heading = Label.new()
 heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 CommanderTheme.font(heading,22)
 column.add_child(heading)
 body = TextEdit.new()
 body.editable = false
 body.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
 body.size_flags_vertical = Control.SIZE_EXPAND_FILL
 CommanderTheme.font(body,18)
 column.add_child(body)
 var actions: HBoxContainer = HBoxContainer.new()
 column.add_child(actions)
 cancel_button = Button.new()
 cancel_button.text = "取消"
 cancel_button.custom_minimum_size.y = 44
 cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 cancel_button.pressed.connect(finish.bind(false))
 actions.add_child(cancel_button)
 accept_button = Button.new()
 accept_button.custom_minimum_size.y = 44
 accept_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 accept_button.pressed.connect(finish.bind(true))
 actions.add_child(accept_button)
 get_viewport().size_changed.connect(fit)
 GameSettings.settings_changed.connect(fit)
 root.hide()

func present(title: String, text: String, action: Callable = Callable(), pause: bool = false) -> void:
 if opened: return
 callback = action
 previous_focus = get_viewport().gui_get_focus_owner()
 previous_pause = get_tree().paused
 pauses = pause
 opened = true
 heading.text = title
 body.text = text
 cancel_button.visible = action.is_valid()
 accept_button.text = "确认" if action.is_valid() else "关闭"
 root.show()
 if pauses: get_tree().paused = true
 fit()
 cancel_button.grab_focus() if action.is_valid() else accept_button.grab_focus()

func fit() -> void:
 if not is_inside_tree() or not is_instance_valid(panel): return
 CommanderTheme.refresh(root)
 var available: Vector2 = get_viewport().get_visible_rect().size
 panel.size = Vector2(minf(900,available.x-48),minf(620,available.y-48))
 panel.position = (available-panel.size)*0.5

func finish(accepted: bool) -> void:
 if not opened: return
 opened = false
 root.hide()
 if pauses: get_tree().paused = previous_pause
 if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree(): previous_focus.grab_focus()
 var action: Callable = callback
 callback = Callable()
 if accepted and action.is_valid(): action.call()

func _input(event: InputEvent) -> void:
 if not opened or not event is InputEventKey or not event.is_pressed(): return
 var key: InputEventKey = event as InputEventKey
 if key.keycode == KEY_ESCAPE:
  finish(false)
  get_viewport().set_input_as_handled()
 elif key.keycode == KEY_TAB:
  var targets: Array[Control] = [body,accept_button]
  if cancel_button.visible: targets.insert(1,cancel_button)
  var index: int = targets.find(get_viewport().gui_get_focus_owner())
  targets[posmod(index+(-1 if key.shift_pressed else 1),targets.size())].grab_focus()
  get_viewport().set_input_as_handled()

func _exit_tree() -> void:
 if opened and pauses: get_tree().paused = previous_pause
