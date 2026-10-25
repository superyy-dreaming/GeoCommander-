class_name LabPlacementPanel
extends PopupPanel

var content: VBoxContainer
var scroll: ScrollContainer
var status: Label
var close_button: Button
var previous_focus: Control
var column: VBoxContainer

func _ready() -> void:
 theme = CommanderTheme.create()
 # PopupPanel otherwise grows to a transient wrapped-label minimum before
 # its first layout. The bounded viewport owns sizing; only the body scrolls.
 wrap_controls = false
 column = VBoxContainer.new()
 add_child(column)
 size_changed.connect(fit_contents)
 column.minimum_size_changed.connect(fit_contents.call_deferred)
 var header: HBoxContainer = HBoxContainer.new()
 column.add_child(header)
 var title: Label = Label.new()
 title.text = "布阵属性"
 title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 CommanderTheme.font(title,20)
 header.add_child(title)
 close_button = Button.new()
 close_button.text = "关闭"
 close_button.custom_minimum_size.y = 44
 close_button.pressed.connect(hide)
 header.add_child(close_button)
 status = Label.new()
 status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 CommanderTheme.font(status,14)
 column.add_child(status)
 scroll = ScrollContainer.new()
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 scroll.follow_focus = true
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 column.add_child(scroll)
 content = VBoxContainer.new()
 content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.add_child(content)
 popup_hide.connect(func() -> void:
  if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree(): previous_focus.grab_focus())

func field(title: String, control: Control) -> void:
 var label: Label = Label.new()
 label.text = title
 label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 CommanderTheme.font(label,16)
 content.add_child(label)
 content.add_child(control)

func open_at(anchor: Control) -> void:
 previous_focus = anchor.get_viewport().gui_get_focus_owner()
 CommanderTheme.refresh_fonts(self)
 var available: Vector2i = anchor.get_viewport_rect().size
 size = Vector2i(mini(520,available.x-48),mini(580,available.y-80))
 var desired: Vector2i = Vector2i(anchor.get_global_rect().position+Vector2(0,anchor.size.y+4))
 position = desired.clamp(Vector2i(12,12),(available-size-Vector2i(12,12)).max(Vector2i(12,12)))
 popup(Rect2i(position,size))
 fit_contents.call_deferred()
 close_button.grab_focus()

func fit_contents() -> void:
 if not is_instance_valid(column): return
 # Wrapped text can shrink after PopupPanel's first child layout. Reapply the
 # allocated body rect when that minimum changes, rather than retaining its
 # temporary, oversized height.
 var panel_style: StyleBox = get_theme_stylebox("panel")
 column.position = panel_style.get_offset()
 column.size = Vector2(size)-panel_style.get_minimum_size()
