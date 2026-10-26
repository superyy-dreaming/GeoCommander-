class_name SettingsPanel
extends CanvasLayer

signal closed
var root: Control
var content: VBoxContainer
var feedback: Label
var retry: Button
var close_button: Button
var controls: Dictionary = {}
var tabs: Dictionary = {}
var display_dialog: ConfirmationDialog
var reset_dialog: ConfirmationDialog
var opened: bool = false
var previous_pause: bool = false
var previous_focus: Control
var display_pending: bool = false
var previous_display: Dictionary = {}
var display_left: float = 0.0
var category: String = "显示"
var guide_label: Label

func _ready() -> void:
 layer = 30
 process_mode = Node.PROCESS_MODE_ALWAYS
 add_to_group("gameplay_input_blocker")
 root = ColorRect.new()
 (root as ColorRect).color = Color(0.003,0.009,0.018,0.94)
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root.mouse_filter = Control.MOUSE_FILTER_STOP
 add_child(root)
 var margin: MarginContainer = MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for edge: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,32)
 root.add_child(margin)
 var panel: PanelContainer = PanelContainer.new()
 margin.add_child(panel)
 var column: VBoxContainer = VBoxContainer.new()
 panel.add_child(column)
 var header: HBoxContainer = HBoxContainer.new()
 column.add_child(header)
 var heading: Label = make_label("设置",30)
 heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 header.add_child(heading)
 close_button = make_button("关闭 [Esc]",close_panel)
 header.add_child(close_button)
 var tab_row: HBoxContainer = HBoxContainer.new()
 column.add_child(tab_row)
 for title: String in ["显示","界面","LLM","操作与关于"]:
  var tab: Button = make_button(title,func() -> void: select_category(title))
  tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  tab.toggle_mode = true
  tabs[title] = tab
  tab_row.add_child(tab)
 var scroll: ScrollContainer = ScrollContainer.new()
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 scroll.follow_focus = true
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 column.add_child(scroll)
 content = VBoxContainer.new()
 content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 content.add_theme_constant_override("separation",18)
 scroll.add_child(content)
 feedback = make_label("",16)
 feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 column.add_child(feedback)
 var footer: HBoxContainer = HBoxContainer.new()
 column.add_child(footer)
 footer.add_child(make_button("恢复默认",func() -> void: reset_dialog.popup_centered(Vector2i(600,220))))
 retry = make_button("重试保存",GameSettings.save_settings)
 footer.add_child(retry)
 var note: Label = make_label("普通设置立即生效。对局中打开此面板会暂停战场。",16)
 note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 footer.add_child(note)
 display_dialog = BoundedConfirmation.new()
 display_dialog.title = "保留显示设置？"
 display_dialog.ok_button_text = "保留设置"
 display_dialog.cancel_button_text = "恢复原设置"
 display_dialog.confirmed.connect(confirm_display)
 display_dialog.canceled.connect(revert_display)
 root.add_child(display_dialog)
 reset_dialog = BoundedConfirmation.new()
 reset_dialog.title = "恢复默认设置？"
 reset_dialog.dialog_text = "将恢复所有界面、显示和镜头设置。\n当前战局、默认开局指令、实验与 LLM 连接配置会保留。"
 reset_dialog.ok_button_text = "恢复默认"
 reset_dialog.cancel_button_text = "取消"
 reset_dialog.confirmed.connect(restore_defaults)
 root.add_child(reset_dialog)
 GameSettings.settings_changed.connect(settings_updated)
 GameSettings.persistence_changed.connect(update_status)
 if not SignalBus.keybinds_updated.is_connected(_keybinds_updated):
  SignalBus.keybinds_updated.connect(_keybinds_updated)
 CommanderTheme.refresh(root)
 select_category(category)
 root.hide()

func open_panel() -> void:
 if opened: return
 previous_pause = get_tree().paused
 previous_focus = get_viewport().gui_get_focus_owner()
 opened = true
 root.show()
 get_tree().paused = true
 close_button.grab_focus()
 update_status()

func close_panel() -> void:
 if display_pending: revert_display()
 if not opened: return
 opened = false
 get_tree().paused = previous_pause
 if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree(): previous_focus.grab_focus()
 closed.emit()
 queue_free()

func _exit_tree() -> void:
 if opened: get_tree().paused = previous_pause
 if is_instance_valid(SignalBus) and SignalBus.keybinds_updated.is_connected(_keybinds_updated):
  SignalBus.keybinds_updated.disconnect(_keybinds_updated)

func make_label(text: String, base: int = 18) -> Label:
 var label: Label = Label.new()
 label.text = text
 CommanderTheme.font(label,base)
 return label

func make_button(text: String, action: Callable) -> Button:
 var button: Button = Button.new()
 button.text = text
 button.custom_minimum_size.y = 44
 button.pressed.connect(action)
 return button

func row(title: String, detail: String) -> VBoxContainer:
 var section: VBoxContainer = VBoxContainer.new()
 content.add_child(section)
 section.add_child(make_label(title,20))
 if not detail.is_empty():
  var explanation: Label = make_label(detail,16)
  explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  explanation.add_theme_color_override("font_color",CommanderTheme.MUTED)
  section.add_child(explanation)
 return section

func select_category(title: String) -> void:
 category = title
 guide_label = null
 for key: String in tabs: (tabs[key] as Button).button_pressed = key == title
 for child: Node in content.get_children():
  content.remove_child(child)
  child.queue_free()
 controls.clear()
 if title == "显示":
  var mode: OptionButton = OptionButton.new()
  mode.add_item("窗口")
  mode.add_item("全屏")
  mode.selected = int(GameSettings.values["window_mode"])
  mode.item_selected.connect(func(index: int) -> void: preview_display(index,GameSettings.values["resolution"]))
  mode.custom_minimum_size.y = 44
  row("窗口模式","全屏使用当前显示器尺寸，并保持进入前窗口画面的比例与排版。").add_child(mode)
  controls["window_mode"] = mode
  var resolution: OptionButton = OptionButton.new()
  for dimensions: Vector2i in GameSettings.RESOLUTIONS:
   resolution.add_item("%d × %d" % [dimensions.x,dimensions.y])
   var index: int = resolution.item_count-1
   resolution.set_item_disabled(index,not GameSettings.resolution_fits(dimensions))
   if not GameSettings.resolution_fits(dimensions): resolution.get_popup().set_item_tooltip(index,"当前显示器可用空间不足")
  resolution.selected = GameSettings.RESOLUTIONS.find(GameSettings.values["resolution"])
  resolution.disabled = int(GameSettings.values["window_mode"]) == 1
  resolution.custom_minimum_size.y = 44
  resolution.item_selected.connect(func(index: int) -> void: preview_display(0,GameSettings.RESOLUTIONS[index]))
  row("窗口分辨率","决定窗口打开与恢复时的尺寸。进入全屏后以当时的实际窗口画面等比放大，宽高比不同时居中留边。").add_child(resolution)
  controls["resolution"] = resolution
  add_slider("glow","发光强度","仅调整几何与战斗特效，正文不受影响。0% 关闭发光。",0,1.5)
 elif title == "界面":
  var fonts: OptionButton = OptionButton.new()
  for text: String in ["标准 · 100%","较大 · 115%","大 · 130%","特大 · 150%","超大 · 180%"]: fonts.add_item(text)
  var font_values: Array[float] = [1.0,1.15,1.3,1.5,1.8]
  fonts.selected = font_values.find(float(GameSettings.values["font_scale"]))
  fonts.custom_minimum_size.y = 44
  fonts.item_selected.connect(func(index: int) -> void: GameSettings.set_value("font_scale",font_values[index]))
  row("全局字号","应用于菜单、档案、演武读数、战场 HUD、战术矩阵及提示。").add_child(fonts)
  controls["font_scale"] = fonts
  var motion: CheckButton = CheckButton.new()
  motion.text = "启用低动效"
  motion.button_pressed = bool(GameSettings.values["reduced_motion"])
  motion.custom_minimum_size.y = 44
  motion.toggled.connect(func(value: bool) -> void: GameSettings.set_value("reduced_motion",value))
  row("低动效","关闭网格扫描与拖尾，减少碎片，取消界面淡出。").add_child(motion)
 elif title == "LLM":
  content.add_child(LLMSettings.new())
 else:
  add_slider("camera_speed","镜头移动速度","屏幕边缘平移、滚轮缩放和中键拖动的速度。",0.5,2)
  guide_label = make_label(operations_guide_text(),16)
  guide_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  row("操作说明","").add_child(guide_label)
  row("自定义按键","冲突按键会自动交换，文本输入时不会触发战斗快捷键。").add_child(make_button("打开按键设置",open_keybinds))
  var version: Label = make_label("GeoCommander\n离线单人几何战术游戏。多人功能开发中。\nGodot "+Engine.get_version_info()["string"]+" · Forward+ · Metal · 2D HDR",16)
  version.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  row("关于游戏","").add_child(version)
 CommanderTheme.refresh(root)
 update_status()

func operations_guide_text() -> String:
 var deploy: Array[String] = []
 for kind: String in UnitCatalog.TYPES:
  deploy.append(KeybindManager.get_key_label("spawn_"+kind)+" "+str(UnitCatalog.DATA[kind]["zh"]))
 return "部署："+" / ".join(deploy)+"\n兵种技能："+KeybindManager.get_key_label("skill_triangle")+" / "+KeybindManager.get_key_label("skill_square")+" / "+KeybindManager.get_key_label("skill_circle")+" / "+KeybindManager.get_key_label("skill_diamond")+" / "+KeybindManager.get_key_label("skill_hexagon")+"\n全局技能："+KeybindManager.get_key_label("cmd_emp")+" / "+KeybindManager.get_key_label("cmd_overclock")+" / "+KeybindManager.get_key_label("cmd_swap")+"\n小队驻守 / 归还 AI："+KeybindManager.get_key_label("squad_hold_orbit")+" / "+KeybindManager.get_key_label("squad_return_ai")+"\n参谋方案："+KeybindManager.get_key_label("copilot_opt_1")+" / "+KeybindManager.get_key_label("copilot_opt_2")+" / "+KeybindManager.get_key_label("copilot_opt_3")+"，自动代理："+KeybindManager.get_key_label("copilot_toggle_auto")+"\n战术矩阵："+KeybindManager.get_key_label("toggle_tactical_drawer")+"\n屏幕边缘或中键移动镜头，滚轮以光标为中心缩放。左键选择/框选；右键移动或集火；Shift + 右键绘制小队航线。右键 / Esc 取消瞄准。\n输入文字期间屏蔽战斗快捷键。占领南北能源点增加 Flux，摧毁敌方核心获胜；对局最长十分钟。"

func _keybinds_updated(_bindings: Dictionary) -> void:
 if is_instance_valid(guide_label): guide_label.text = operations_guide_text()

func open_keybinds() -> void:
 var modal: Node = load("res://scripts/ui/keybind_settings_modal.gd").new()
 add_child(modal)
 modal.call("open_modal")

func add_slider(key: String, title: String, detail: String, minimum: float, maximum: float) -> void:
 var section: VBoxContainer = row(title,detail)
 var value_label: Label = make_label("%d%%" % roundi(float(GameSettings.values[key])*100),20)
 section.add_child(value_label)
 var slider: HSlider = HSlider.new()
 slider.min_value = minimum
 slider.max_value = maximum
 slider.step = 0.1
 slider.value = float(GameSettings.values[key])
 slider.custom_minimum_size.y = 44
 slider.value_changed.connect(func(value: float) -> void:
  value_label.text = "%d%%" % roundi(value*100)
  GameSettings.set_value(key,value))
 section.add_child(slider)
 controls[key] = slider

func settings_updated() -> void:
 CommanderTheme.refresh(root)
 if controls.has("window_mode"):
  (controls["window_mode"] as OptionButton).select(int(GameSettings.values["window_mode"]))
 if controls.has("resolution"):
  (controls["resolution"] as OptionButton).disabled = int(GameSettings.values["window_mode"]) == 1
 update_status()

func update_status() -> void:
 if not is_instance_valid(feedback): return
 feedback.text = GameSettings.status if not GameSettings.status.is_empty() else "设置自动保存到本机。"
 feedback.add_theme_color_override("font_color",Color(1,0.65,0.5) if GameSettings.dirty else CommanderTheme.MUTED)
 retry.visible = GameSettings.dirty

func preview_display(mode: int, dimensions: Vector2i) -> void:
 if display_pending: return
 previous_display = {"window_mode":GameSettings.values["window_mode"],"resolution":GameSettings.values["resolution"]}
 if previous_display["window_mode"] == mode and previous_display["resolution"] == dimensions: return
 display_pending = true
 display_left = 15
 GameSettings.values["window_mode"] = mode
 GameSettings.values["resolution"] = dimensions
 GameSettings.apply_display()
 # Headless behavior tests exercise the confirmation state machine without a
 # native window. Opening a Window there produces invalid popup coordinates.
 if DisplayServer.get_name() != "headless":
  display_dialog.popup_centered(Vector2i(650,240))

func confirm_display() -> void:
 if not display_pending: return
 display_pending = false
 GameSettings.save_settings()
 select_category(category)

func revert_display() -> void:
 if not display_pending: return
 display_pending = false
 GameSettings.values.merge(previous_display,true)
 GameSettings.apply_display()
 display_dialog.hide()
 select_category(category)
 feedback.text = "已恢复原显示设置。"

func restore_defaults() -> void:
 var old_mode: int = int(GameSettings.values["window_mode"])
 var old_resolution: Vector2i = GameSettings.values["resolution"]
 for key: String in GameSettings.DEFAULTS:
  if key not in ["window_mode","resolution"]: GameSettings.set_value(key,GameSettings.DEFAULTS[key],false)
 GameSettings.save_settings()
 select_category(category)
 if old_mode != 0 or old_resolution != Vector2i(1440,810): preview_display(0,Vector2i(1440,810))

func _process(delta: float) -> void:
 if display_pending:
  display_left -= delta
  display_dialog.dialog_text = "新显示设置已应用。\n%d 秒内确认，否则自动恢复原设置。" % ceili(display_left)
  if display_left <= 0: revert_display()

func _input(event: InputEvent) -> void:
 if not opened or display_dialog.visible or reset_dialog.visible: return
 if event is InputEventKey and event.is_pressed():
  var key: InputEventKey = event as InputEventKey
  if key.keycode == KEY_ESCAPE:
   close_panel()
   get_viewport().set_input_as_handled()
  elif key.keycode == KEY_TAB:
   var focusables: Array[Control] = []
   collect_focus(root,focusables)
   var current: int = focusables.find(get_viewport().gui_get_focus_owner())
   if not focusables.is_empty(): focusables[posmod(current+(-1 if key.shift_pressed else 1),focusables.size())].grab_focus()
   get_viewport().set_input_as_handled()

func collect_focus(node: Node, found: Array[Control]) -> void:
 if node is Control and (node as Control).is_visible_in_tree() and (node as Control).focus_mode == Control.FOCUS_ALL:
  if not (node is BaseButton and (node as BaseButton).disabled): found.append(node as Control)
 for child: Node in node.get_children(): collect_focus(child,found)
