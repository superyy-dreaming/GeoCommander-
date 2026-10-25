class_name LabFeedbackPanel
extends PanelContainer

signal expand_requested
var feedback: Label
var source: Label
var intent: Label
var scroll: ScrollContainer
var details: VBoxContainer

func _ready() -> void:
 var column: VBoxContainer = VBoxContainer.new()
 column.add_theme_constant_override("separation",4)
 add_child(column)
 var header: HBoxContainer = HBoxContainer.new()
 column.add_child(header)
 var title: Label = Label.new()
 title.text = "反馈与验证"
 title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 CommanderTheme.font(title,16)
 header.add_child(title)
 var expand: Button = Button.new()
 expand.text = "展开"
 expand.tooltip_text = "在独立窗口中阅读完整反馈"
 expand.custom_minimum_size.y = 44
 CommanderTheme.font(expand,14)
 expand.pressed.connect(func() -> void: expand_requested.emit())
 header.add_child(expand)
 scroll = ScrollContainer.new()
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 scroll.follow_focus = true
 scroll.focus_mode = Control.FOCUS_ALL
 column.add_child(scroll)
 details = VBoxContainer.new()
 details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.add_child(details)
 # Put the current result before metadata so failure/recovery is visible first.
 feedback = make_label("",18)
 source = make_label("",14)
 intent = make_label("本地识别：尚未分析",14)
 for item: Label in [feedback,source,intent]: details.add_child(item)
 for item: Label in [source,intent]: item.add_theme_color_override("font_color",CommanderTheme.MUTED)
 GameSettings.settings_changed.connect(update_minimum.call_deferred)
 update_minimum.call_deferred()

func update_minimum() -> void:
 if not is_inside_tree(): return
 var line_height: float = CommanderTheme.create().default_font.get_height(GameSettings.font_px(18))
 var header_height: float = (get_child(0).get_child(0) as Control).get_combined_minimum_size().y
 custom_minimum_size.y = header_height+line_height*2+26

func make_label(value: String, base: int) -> Label:
 var item: Label = Label.new()
 item.text = value
 item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 CommanderTheme.font(item,base)
 return item

func full_text() -> String:
 return feedback.text+"\n\n"+source.text+"\n\n"+intent.text
