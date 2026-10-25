class_name LabFloatingReadout
extends PanelContainer

signal interaction_started
static var remembered_position: Vector2 = Vector2(-1,-1)
static var remembered_size: Vector2 = Vector2.ZERO
static var remembered_collapsed: bool = false
var readings: TabContainer
var selector: OptionButton
var header: HBoxContainer
var collapse: Button
var close_button: Button
var resize_handle: Button
var title: Label
var column: VBoxContainer
var collapsed: bool = false
var moving: bool = false
var resizing: bool = false
var last_mouse: Vector2
var fitting: bool = false

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_STOP
 # Scroll events otherwise bubble through STOP controls by default, reaching
 # the battlefield's zoom handler behind the readout.
 mouse_force_pass_scroll_events = false
 column = VBoxContainer.new()
 column.add_theme_constant_override("separation",4)
 add_child(column)
 header = HBoxContainer.new()
 header.mouse_filter = Control.MOUSE_FILTER_STOP
 header.gui_input.connect(drag_input)
 header.mouse_default_cursor_shape = Control.CURSOR_MOVE
 header.add_theme_constant_override("separation",4)
 column.add_child(header)
 title = Label.new()
 title.text = "读数"
 CommanderTheme.font(title,14)
 title.mouse_filter = Control.MOUSE_FILTER_STOP
 title.gui_input.connect(drag_input)
 title.mouse_default_cursor_shape = Control.CURSOR_MOVE
 title.tooltip_text = "拖动标题移动读数框"
 header.add_child(title)
 selector = OptionButton.new()
 selector.fit_to_longest_item = false
 selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 CommanderTheme.font(selector,14)
 for text: String in ["结果","规则读数","事件"]: selector.add_item(text)
 selector.custom_minimum_size.y = 44
 selector.item_selected.connect(func(index: int) -> void: readings.current_tab = index)
 header.add_child(selector)
 collapse = action("收起",toggle_collapsed)
 header.add_child(collapse)
 close_button = action("关闭",hide)
 header.add_child(close_button)
 readings = TabContainer.new()
 readings.size_flags_vertical = Control.SIZE_EXPAND_FILL
 readings.tab_changed.connect(func(index: int) -> void: selector.select(index))
 column.add_child(readings)
 # Keep the resize target outside the text, including its scrollbar.
 resize_handle = action("调整",func() -> void: pass)
 resize_handle.tooltip_text = "拖动以调整读数框尺寸"
 resize_handle.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
 resize_handle.gui_input.connect(resize_input)
 resize_handle.size_flags_horizontal = Control.SIZE_SHRINK_END
 column.add_child(resize_handle)
 collapsed = remembered_collapsed
 get_parent().resized.connect(fit)
 GameSettings.settings_changed.connect(func() -> void: fit.call_deferred())
 fit.call_deferred()

func action(text: String, handler: Callable) -> Button:
 var node: Button = Button.new()
 node.text = text
 node.custom_minimum_size.y = 44
 CommanderTheme.font(node,14)
 node.pressed.connect(handler)
 node.button_down.connect(func() -> void: interaction_started.emit())
 return node

func toggle_collapsed() -> void:
 collapsed = not collapsed
 remembered_collapsed = collapsed
 fit()

func reset_layout() -> void:
 remembered_position = Vector2(-1,-1)
 remembered_size = Vector2.ZERO
 collapsed = false
 remembered_collapsed = false
 show()
 fit()

func fit() -> void:
 if fitting or not is_inside_tree() or not is_instance_valid(readings): return
 fitting = true
 CommanderTheme.refresh(self)
 var available: Vector2 = (get_parent() as Control).size
 if available.x<1 or available.y<1:
  fitting = false
  return
 readings.visible = not collapsed
 resize_handle.visible = not collapsed
 collapse.text = "展开" if collapsed else "收起"
 readings.tabs_visible = false
 # A single header selector keeps all readout pages reachable in narrow frames.
 selector.visible = not collapsed
 selector.custom_minimum_size.x = 64 if not collapsed else 0
 var minimum: Vector2 = header.get_combined_minimum_size()+Vector2(28,20)
 if not collapsed: minimum.y += resize_handle.get_combined_minimum_size().y+64
 var maximum: Vector2 = (available*Vector2(0.6,0.65)).min(available-Vector2(16,16))
 var desired: Vector2 = remembered_size if remembered_size!=Vector2.ZERO else available*Vector2(0.4,0.35)
 if collapsed: desired.y = minimum.y
 size = desired.clamp(minimum.min(maximum),maximum)
 position = remembered_position*available if remembered_position.x>=0 else Vector2(available.x-size.x-8,8)
 position = position.clamp(Vector2.ZERO,(available-size).max(Vector2.ZERO))
 fitting = false

func drag_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and (event as InputEventMouseButton).button_index==MOUSE_BUTTON_LEFT:
  moving = event.is_pressed()
  last_mouse = (event as InputEventMouseButton).global_position
  interaction_started.emit()
  accept_event()
 elif event is InputEventMouseMotion and moving:
  var now: Vector2 = (event as InputEventMouseMotion).global_position
  remembered_position = (position+now-last_mouse)/(get_parent() as Control).size
  last_mouse = now
  fit()
  remembered_position = position/(get_parent() as Control).size
  accept_event()

func resize_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and (event as InputEventMouseButton).button_index==MOUSE_BUTTON_LEFT:
  resizing = event.is_pressed()
  last_mouse = (event as InputEventMouseButton).global_position
  interaction_started.emit()
  accept_event()
 elif event is InputEventMouseMotion and resizing:
  var now: Vector2 = (event as InputEventMouseMotion).global_position
  remembered_size = size+now-last_mouse
  last_mouse = now
  fit()
  remembered_size = size
  accept_event()
