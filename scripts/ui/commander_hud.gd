extends CanvasLayer

const TEXT: Color = Color(0.88,0.94,0.99)
const MUTED: Color = Color(0.61,0.75,0.83)
const ACCENT: Color = Color(0.2,0.8,1.0)
var arena: MainArena
var root: Control
var matrix_open: bool = false
var matrix_backdrop: ColorRect
var end_backdrop: ColorRect
var time_label: Label
var blue_label: Label
var red_label: Label
var blue_health: ProgressBar
var red_health: ProgressBar
var flux_label: Label
var prism_label: Label
var link_label: Label
var feedback_label: Label
var message_label: Label
var prompt_input: LineEdit
var override_button: Button
var cooldown_bar: ProgressBar
var unit_buttons: Array[UnitDeployButton] = []
var skill_buttons: Dictionary = {}
var skill_bars: Dictionary = {}
var budget_bar: ProgressBar
var matrix_prompt: TextEdit
var matrix_preview: TextEdit
var matrix_status: Label
var matrix_apply: Button
var matrix_button: Button
var matrix_return_focus: Control
var restart_button: Button
var start_button: Button
var selected_unit_label: Label
var retreat_slider: HSlider
var retreat_value: Label
var selected_kind: String = "triangle"
var draft_overrides: Dictionary = {}
var draft_profile: Dictionary = {}
var matrix_compiled: bool = false
var loading_matrix: bool = false
var selected_buttons: Dictionary = {}
var result_heading: Label
var result_body: Label
var tick_left: float = 0.0
var message_left: float = 0.0
var return_dialog: ConfirmationDialog
var returning: bool = false
var settings: SettingsPanel
var bottom_layout: HBoxContainer
var status_layout: HBoxContainer
var actions_layout: HFlowContainer
var matrix_frame: PanelContainer
var ui_theme: Theme

func _ready() -> void:
 layer = 10
 build_theme()
 root = Control.new()
 root.name = "CommanderHUD"
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root.mouse_filter = Control.MOUSE_FILTER_IGNORE
 root.theme = ui_theme
 add_child(root)
 build_top()
 build_bottom()
 build_matrix()
 build_result()
 build_return_dialog()
 SignalBus.tactical_profile_updated.connect(_tactic_updated)
 SignalBus.match_ended.connect(_match_ended)
 _tactic_updated(0, TacticalBrain.team_profiles[0], "默认均衡战术")
 GameSettings.settings_changed.connect(settings_updated)
 settings_updated()
 open_matrix()
 update_hud()

func box(fill: Color, stroke: Color, border: int = 1) -> StyleBoxFlat:
 return CommanderTheme.box(fill,stroke,border)

func build_theme() -> void:
 ui_theme = CommanderTheme.create()

func label(value: String, font_size: int = 18, color: Color = TEXT) -> Label:
 var node: Label = Label.new()
 node.text = value
 CommanderTheme.font(node,font_size)
 node.add_theme_color_override("font_color", color)
 return node

func button(value: String, action: Callable) -> Button:
 var node: Button = Button.new()
 node.text = value
 node.custom_minimum_size.y = 44
 node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 node.pressed.connect(action)
 return node

func panel(parent: Node) -> PanelContainer:
 var node: PanelContainer = PanelContainer.new()
 parent.add_child(node)
 return node

func margin(parent: Node, inset: int = 16) -> MarginContainer:
 var node: MarginContainer = MarginContainer.new()
 for side: String in ["left","right","top","bottom"]:
  node.add_theme_constant_override("margin_" + side, inset)
 parent.add_child(node)
 return node

func bar(color: Color, height: float = 6.0) -> ProgressBar:
 var node: ProgressBar = ProgressBar.new()
 node.show_percentage = false
 node.max_value = 2500.0
 node.value = 2500.0
 node.custom_minimum_size = Vector2(0,height)
 var fill: StyleBoxFlat = box(color, Color(0,0,0,0), 0)
 fill.content_margin_top = 0
 fill.content_margin_bottom = 0
 var background: StyleBoxFlat = box(Color(0.055,0.11,0.15), Color(0,0,0,0), 0)
 background.content_margin_top = 0
 background.content_margin_bottom = 0
 node.add_theme_stylebox_override("fill",fill)
 node.add_theme_stylebox_override("background",background)
 return node

func build_top() -> void:
 var top: PanelContainer = panel(root)
 top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
 top.offset_left = 24
 top.offset_right = -24
 top.offset_top = 20
 var row: HBoxContainer = HBoxContainer.new()
 row.add_theme_constant_override("separation",32)
 top.add_child(row)
 var blue: VBoxContainer = VBoxContainer.new()
 blue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 row.add_child(blue)
 blue_label = label("BLUE CORE   2500 / 2500",22,ProceduralGeo.BLUE)
 blue.add_child(blue_label)
 blue_health = bar(ProceduralGeo.BLUE)
 blue.add_child(blue_health)
 var blue_sub: HBoxContainer = HBoxContainer.new()
 blue.add_child(blue_sub)
 var title: Label = label("GEOCOMMANDER",18,TEXT)
 title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 blue_sub.add_child(title)
 blue_sub.add_child(label("蓝方指挥席",16,MUTED))
 var center: VBoxContainer = VBoxContainer.new()
 center.custom_minimum_size.x = 300
 row.add_child(center)
 time_label = label("10:00",32)
 time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 center.add_child(time_label)
 prism_label = label("NORTH  中立    SOUTH  中立",16,MUTED)
 prism_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 center.add_child(prism_label)
 var red: VBoxContainer = VBoxContainer.new()
 red.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 row.add_child(red)
 red_label = label("RED CORE   2500 / 2500",22,ProceduralGeo.RED)
 red_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
 red.add_child(red_label)
 red_health = bar(ProceduralGeo.RED)
 red.add_child(red_health)
 flux_label = label("FLUX  180   +12/s",20,ACCENT)
 flux_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
 red.add_child(flux_label)
 var actions: HFlowContainer = HFlowContainer.new()
 actions_layout = actions
 actions.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
 actions.offset_left = -800
 actions.offset_right = -24
 actions.offset_top = 136
 root.add_child(actions)
 start_button = button("开始对局",arena.start_match)
 actions.add_child(start_button)
 matrix_button = button("战术矩阵 [Tab]",toggle_matrix)
 actions.add_child(matrix_button)
 actions.add_child(button("返回主菜单",request_menu_exit))
 actions.add_child(button("设置",open_settings))

func build_bottom() -> void:
 var bottom: HBoxContainer = HBoxContainer.new()
 bottom_layout = bottom
 root.add_child(bottom)
 bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 bottom.offset_left = 24
 bottom.offset_right = -24
 bottom.offset_top = -232
 bottom.offset_bottom = -24
 bottom.add_theme_constant_override("separation",16)
 var deployment: PanelContainer = panel(bottom)
 var deploy_column: VBoxContainer = VBoxContainer.new()
 deployment.add_child(deploy_column)
 var deploy_header: HBoxContainer = HBoxContainer.new()
 deploy_column.add_child(deploy_header)
 var deploy_title: Label = label("部署编队",18)
 deploy_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 deploy_header.add_child(deploy_title)
 var count_label: Label = label("UNITS  9 / 30",16,MUTED)
 count_label.name = "Population"
 deploy_header.add_child(count_label)
 var cards: HBoxContainer = HBoxContainer.new()
 cards.add_theme_constant_override("separation",8)
 deploy_column.add_child(cards)
 for index: int in range(5):
  var card: UnitDeployButton = UnitDeployButton.new()
  card.kind = UnitCatalog.TYPES[index]
  card.hotkey = index + 1
  card.pressed.connect(func() -> void: arena.deploy(card.kind))
  cards.add_child(card)
  unit_buttons.append(card)
 var terminal: PanelContainer = panel(bottom)
 terminal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 var column: VBoxContainer = VBoxContainer.new()
 terminal.add_child(column)
 var header: HBoxContainer = HBoxContainer.new()
 column.add_child(header)
 header.add_child(label("关键词终端 · 提交替换整队",18))
 link_label = label("HEX-LINK ONLINE ×1.4",16,ProceduralGeo.GOLD)
 link_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 link_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
 header.add_child(link_label)
 var input_row: HBoxContainer = HBoxContainer.new()
 column.add_child(input_row)
 prompt_input = LineEdit.new()
 prompt_input.placeholder_text = "输入战术指令，如：三角形绕后切菱形"
 prompt_input.max_length = 256
 prompt_input.custom_minimum_size.y = 46
 prompt_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 prompt_input.text_submitted.connect(func(text: String) -> void: arena.submit_tactic(text))
 input_row.add_child(prompt_input)
 override_button = button("OVERRIDE",func() -> void: arena.submit_tactic(prompt_input.text))
 override_button.tooltip_text = "应用新战术。每次重新编译整套规则，基础冷却 30 秒。"
 input_row.add_child(override_button)
 var chips: HBoxContainer = HBoxContainer.new()
 chips.add_theme_constant_override("separation",8)
 column.add_child(chips)
 for prompt: String in ["侧翼切后排","棱镜折射","保护六边形","全军突击"]:
  var chip: Button = button(prompt,func() -> void:
   prompt_input.text = prompt
   arena.submit_tactic(prompt))
  chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  CommanderTheme.font(chip,16)
  chips.add_child(chip)
 feedback_label = label("ACTIVE RULE: 均衡战术",16,MUTED)
 feedback_label.clip_text = true
 column.add_child(feedback_label)
 cooldown_bar = bar(ACCENT,4)
 cooldown_bar.max_value = 30.0
 cooldown_bar.value = 30.0
 column.add_child(cooldown_bar)
 var skills_panel: PanelContainer = panel(bottom)
 skills_panel.custom_minimum_size.x = 270
 var skill_column: VBoxContainer = VBoxContainer.new()
 skills_panel.add_child(skill_column)
 skill_column.add_child(label("全局指挥",18))
 for skill: String in ["EMP_STRIKE","OVERCLOCK","TOPOLOGY_SWAP"]:
  var skill_button: Button = button("",func() -> void: SignalBus.commander_skill_requested.emit(skill))
  skill_button.custom_minimum_size.y = 45
  CommanderTheme.font(skill_button,16)
  skill_column.add_child(skill_button)
  skill_buttons[skill] = skill_button
  var skill_bar: ProgressBar = bar(ACCENT,3)
  skill_button.add_child(skill_bar)
  skill_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
  skill_bar.offset_left = 4
  skill_bar.offset_right = -4
  skill_bar.offset_top = -3
  skill_bar.offset_bottom = -1
  skill_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
  skill_bar.max_value = float(UnitCatalog.SKILLS[skill]["cd"])
  skill_bars[skill] = skill_bar
 var status: HBoxContainer = HBoxContainer.new()
 status_layout = status
 root.add_child(status)
 status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 status.offset_left = 30
 status.offset_right = -30
 status.offset_top = -274
 status.offset_bottom = -240
 message_label = label("数字 1-5 部署  |  WASD 移动  |  滚轮缩放  |  Z/X/C 指挥技能",17,MUTED)
 message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 message_label.clip_text = true
 status.add_child(message_label)
 status.add_child(label("右键 / Esc 取消瞄准",16,MUTED))

func backdrop() -> ColorRect:
 var node: ColorRect = ColorRect.new()
 node.color = Color(0.003,0.008,0.016,0.82)
 node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 node.mouse_filter = Control.MOUSE_FILTER_STOP
 root.add_child(node)
 return node

func centered_panel(parent: Control, width: float, height: float) -> PanelContainer:
 var center: CenterContainer = CenterContainer.new()
 center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 parent.add_child(center)
 var frame: PanelContainer = panel(center)
 frame.custom_minimum_size = Vector2(width,height)
 frame.add_theme_stylebox_override("panel",box(Color(0.022,0.045,0.07,0.99),Color(0.2,0.6,0.76),1))
 return frame

func build_matrix() -> void:
 matrix_backdrop = backdrop()
 var frame: PanelContainer = centered_panel(matrix_backdrop,1500,800)
 matrix_frame = frame
 var outer: VBoxContainer = VBoxContainer.new()
 var padding: MarginContainer = margin(frame,16)
 padding.add_child(outer)
 var heading: HBoxContainer = HBoxContainer.new()
 outer.add_child(heading)
 var title: Label = label("战术矩阵",30)
 title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 heading.add_child(title)
 heading.add_child(button("关闭 [Esc]",close_matrix))
 outer.add_child(label("部署几何编队，以战术指令改变自动战斗。占领棱镜增加资源，摧毁红方核心获胜。",18,MUTED))
 var body: HBoxContainer = HBoxContainer.new()
 body.size_flags_vertical = Control.SIZE_EXPAND_FILL
 body.add_theme_constant_override("separation",24)
 var body_scroll: ScrollContainer = ScrollContainer.new()
 body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 body_scroll.follow_focus = true
 outer.add_child(body_scroll)
 body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 body_scroll.add_child(body)
 var roster: VBoxContainer = VBoxContainer.new()
 roster.custom_minimum_size.x = 195
 body.add_child(roster)
 roster.add_child(label("兵种与行为",20))
 var descriptions: Dictionary = {"triangle":"冲刺穿刺 / 背刺暴击", "square":"前线承伤 / 反射护盾", "circle":"聚集拉拽 / 范围坍缩", "diamond":"远程风筝 / 两次折射", "hexagon":"群体治疗 / 指挥加速"}
 for kind: String in UnitCatalog.TYPES:
  var choice: Button = button(String(UnitCatalog.DATA[kind]["zh"]),func() -> void: select_unit(kind))
  choice.toggle_mode = true
  choice.button_pressed = kind == selected_kind
  roster.add_child(choice)
  selected_buttons[kind] = choice
  roster.add_child(label(String(descriptions[kind]),15,MUTED))
 var editor: VBoxContainer = VBoxContainer.new()
 editor.custom_minimum_size.x = 420
 editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 body.add_child(editor)
 editor.add_child(label("自然语言战术",20))
 matrix_prompt = TextEdit.new()
 matrix_prompt.text = "均衡战术"
 matrix_prompt.placeholder_text = "如：正方形保护六边形，菱形折射激光，三角形绕后切后排"
 matrix_prompt.custom_minimum_size = Vector2(0,135)
 matrix_prompt.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
 matrix_prompt.text_changed.connect(func() -> void:
  if not loading_matrix: matrix_compiled = false
  refresh_preview())
 editor.add_child(matrix_prompt)
 budget_bar = bar(ACCENT,4)
 budget_bar.max_value = 256
 editor.add_child(budget_bar)
 var presets: GridContainer = GridContainer.new()
 presets.columns = 2
 editor.add_child(presets)
 for prompt: String in ["侧翼切后排","棱镜折射","保护六边形","全军突击"]:
  var preset: Button = button(prompt,func() -> void:
   matrix_compiled = false
   matrix_prompt.text = prompt
   draft_overrides.clear()
   refresh_preview())
  preset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  presets.add_child(preset)
 selected_unit_label = label("锐角突击：撤退生命阈值",18)
 editor.add_child(selected_unit_label)
 var slider_row: HBoxContainer = HBoxContainer.new()
 editor.add_child(slider_row)
 retreat_slider = HSlider.new()
 retreat_slider.min_value = 0.0
 retreat_slider.max_value = 0.9
 retreat_slider.step = 0.05
 retreat_slider.custom_minimum_size = Vector2(320,44)
 retreat_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 slider_row.add_child(retreat_slider)
 retreat_value = label("20%",18,ProceduralGeo.GOLD)
 retreat_value.custom_minimum_size.x = 60
 slider_row.add_child(retreat_value)
 retreat_slider.value_changed.connect(func(value: float) -> void:
  draft_overrides[selected_kind] = value
  refresh_preview())
 matrix_status = label("",16,MUTED)
 matrix_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 editor.add_child(matrix_status)
 var help: Label = label("指令每次替换整套规则。冷却由存活六边形加速。\n指挥官全部阵亡会锁定终端，重新部署即可恢复。\n战中打开矩阵不会暂停战场。",16,MUTED)
 help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 editor.add_child(help)
 var preview_column: VBoxContainer = VBoxContainer.new()
 preview_column.custom_minimum_size.x = 360
 body.add_child(preview_column)
 preview_column.add_child(label("编译预览 / JSON",20))
 matrix_preview = TextEdit.new()
 matrix_preview.editable = false
 matrix_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
 matrix_preview.custom_minimum_size = Vector2(360,330)
 CommanderTheme.font(matrix_preview,15)
 var mono: SystemFont = SystemFont.new()
 mono.font_names = PackedStringArray(["Menlo","monospace"])
 matrix_preview.add_theme_font_override("font",mono)
 preview_column.add_child(matrix_preview)
 var footer: HBoxContainer = HBoxContainer.new()
 outer.add_child(footer)
 var footer_text: Label = label("初始 180 Flux  /  每秒 +12  /  每队 30 单位  /  对局 10 分钟",16,MUTED)
 footer_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 footer.add_child(footer_text)
 matrix_apply = button("应用战术并开始",apply_matrix)
 matrix_apply.custom_minimum_size.x = 260
 footer.add_child(matrix_apply)
 refresh_preview()

func select_unit(kind: String) -> void:
 selected_kind = kind
 for key: String in selected_buttons:
  (selected_buttons[key] as Button).button_pressed = key == kind
 refresh_preview()

func refresh_preview() -> void:
 if not is_instance_valid(matrix_preview):
  return
 budget_bar.value = matrix_prompt.text.length()
 var result: Dictionary = {"ok":true,"profile":draft_profile.duplicate(true)} if matrix_compiled else TacticalBrain.parse_prompt(matrix_prompt.text)
 var valid: bool = bool(result["ok"]) and matrix_prompt.text.length() <= 256
 if valid:
  var profile: Dictionary = result["profile"]
  for kind: String in draft_overrides:
   profile["unit_rules"][kind]["retreat_hp"] = draft_overrides[kind]
   if profile["unit_rules"][kind].has("program"): profile["unit_rules"][kind]["program"]["base"]["retreat_hp"] = draft_overrides[kind]
  matrix_preview.text = TacticalBrain.json_preview(profile)
  var value: float = profile["unit_rules"][selected_kind]["retreat_hp"]
  retreat_slider.set_value_no_signal(value)
  retreat_value.text = str(roundi(value * 100.0)) + "%"
  matrix_status.text = "本地编译就绪  /  字符预算 " + str(matrix_prompt.text.length()) + "/256\n草稿尚未应用。提交后才会改变战场。"
  if matrix_compiled: matrix_status.text = "当前已编译战术，包含已应用的 AI 条件规则。直接开始会原样保留。\n编辑关键词指令将替换整队战术。"
  matrix_status.add_theme_color_override("font_color",MUTED)
 else:
  matrix_preview.text = "{}"
  matrix_status.text = "最多输入 256 个字符" if matrix_prompt.text.length() > 256 else String(result["message"])
  matrix_status.add_theme_color_override("font_color",Color(1.0,0.5,0.55))
 selected_unit_label.text = String(UnitCatalog.DATA[selected_kind]["zh"]) + "：撤退生命阈值"

func apply_matrix() -> void:
 if matrix_prompt.text.length() > 256:
  arena.notify("战术指令最多 256 个字符",true)
  return
 var result: Dictionary = arena.submit_tactic(matrix_prompt.text,draft_overrides,draft_profile if matrix_compiled else {})
 if bool(result["ok"]):
  if arena.phase == MainArena.Phase.PREPARING:
   arena.start_match()
  close_matrix()
 else:
  matrix_status.text = String(result["message"])

func open_matrix() -> void:
 if arena.phase == MainArena.Phase.ENDED or matrix_open:
  return
 matrix_return_focus = get_viewport().gui_get_focus_owner()
 draft_overrides.clear()
 loading_matrix = true
 matrix_prompt.text = TacticalBrain.last_prompts[0]
 loading_matrix = false
 draft_profile = TacticalBrain.team_profiles[0].duplicate(true)
 matrix_compiled = true
 var parsed: Dictionary = TacticalBrain.parse_prompt(matrix_prompt.text)
 if bool(parsed["ok"]):
  for kind: String in UnitCatalog.TYPES:
   var current_value: float = TacticalBrain.team_profiles[0]["unit_rules"][kind]["retreat_hp"]
   if current_value != float(parsed["profile"]["unit_rules"][kind]["retreat_hp"]):
    draft_overrides[kind] = current_value
 matrix_open = true
 matrix_backdrop.show()
 arena.selected_skill = ""
 refresh_preview()
 matrix_prompt.grab_focus()

func close_matrix() -> void:
 if not matrix_open:
  return
 matrix_open = false
 matrix_backdrop.hide()
 if is_instance_valid(matrix_return_focus) and matrix_return_focus.is_visible_in_tree():
  matrix_return_focus.grab_focus()
 else:
  matrix_button.grab_focus()
 matrix_return_focus = null

func toggle_matrix() -> void:
 if matrix_open:
  close_matrix()
 else:
  open_matrix()

func build_result() -> void:
 end_backdrop = backdrop()
 var frame: PanelContainer = centered_panel(end_backdrop,690,380)
 var column: VBoxContainer = VBoxContainer.new()
 var padding: MarginContainer = margin(frame,28)
 padding.add_child(column)
 result_heading = label("矩阵胜利",38,ACCENT)
 result_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 column.add_child(result_heading)
 result_body = label("",20)
 result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 result_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
 column.add_child(result_body)
 restart_button = button("重新开局",arena.restart)
 column.add_child(restart_button)
 column.add_child(button("返回主菜单",return_to_menu))
 end_backdrop.hide()

func build_return_dialog() -> void:
 return_dialog = ConfirmationDialog.new()
 return_dialog.title = "放弃当前对局？"
 return_dialog.dialog_text = "返回主菜单后，当前战局不会保存。默认开局指令会保留。"
 return_dialog.ok_button_text = "返回主菜单"
 return_dialog.cancel_button_text = "继续对局"
 return_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
 root.add_child(return_dialog)
 return_dialog.confirmed.connect(return_to_menu)
 return_dialog.canceled.connect(func() -> void: get_tree().paused = false)

func request_menu_exit() -> void:
 if returning or is_instance_valid(settings): return
 if arena.phase == MainArena.Phase.PLAYING:
  arena.selected_skill = ""
  return_dialog.popup_centered(Vector2i(520,180))
  get_tree().paused = true
 else:
  return_to_menu()

func return_to_menu() -> void:
 if returning: return
 returning = true
 arena.selected_skill = ""
 get_tree().paused = true
 var fade: ColorRect = ColorRect.new()
 fade.color = Color(0.005,0.012,0.02,0)
 fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 fade.mouse_filter = Control.MOUSE_FILTER_STOP
 root.add_child(fade)
 var transition: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
 transition.tween_property(fade,"color:a",1.0,0.0 if arena.reduced_motion else 0.18)
 await transition.finished
 get_tree().paused = false
 MatchSession.menu_page = "home"
 var error: Error = get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
 if error != OK:
  fade.queue_free()
  returning = false
  show_message("主菜单载入失败："+error_string(error)+"。请重试。",true)

func _match_ended(winner: int, reason: String) -> void:
 close_matrix()
 result_heading.text = "矩阵胜利" if winner == 0 else ("核心失守" if winner == 1 else "势均力敌")
 result_heading.add_theme_color_override("font_color",ProceduralGeo.BLUE if winner == 0 else (ProceduralGeo.RED if winner == 1 else ProceduralGeo.GOLD))
 result_body.text = reason + "\n\n蓝方核心  " + str(roundi(arena.bases[0].current_hp)) + " / 2500\n红方核心  " + str(roundi(arena.bases[1].current_hp)) + " / 2500\n对局时长  " + str(int(arena.elapsed)) + " 秒"
 end_backdrop.show()
 restart_button.grab_focus()

func _tactic_updated(team: int, profile: Dictionary, _prompt: String) -> void:
 if team != 0:
  return
 var rules: Dictionary = profile["unit_rules"]
 feedback_label.text = "ACTIVE RULE  " + String(rules["triangle"]["movement"]) + "  |  " + String(rules["square"]["skill_cond"]) + "  |  " + String(rules["diamond"]["movement"])
 feedback_label.tooltip_text = TacticalBrain.json_preview(profile)

func show_message(message: String, error: bool = false) -> void:
 message_label.text = message
 message_label.add_theme_color_override("font_color",Color(1.0,0.5,0.55) if error else Color(0.6,0.92,1.0))
 message_left = 5.0

func _process(delta: float) -> void:
 tick_left -= delta
 message_left -= delta
 if tick_left <= 0.0:
  tick_left = 0.1
  update_hud()
 if message_left <= 0.0 and arena.selected_skill.is_empty():
  message_label.text = "数字 1-5 部署  |  WASD 移动  |  滚轮缩放  |  Z/X/C 指挥技能"
  message_label.add_theme_color_override("font_color",MUTED)

func update_hud() -> void:
 var seconds: int = ceili(arena.match_left)
 time_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
 if arena.phase == MainArena.Phase.PREPARING:
  time_label.text = "准备阶段"
 blue_label.text = "BLUE CORE   %d / 2500" % roundi(arena.bases[0].current_hp)
 red_label.text = "RED CORE   %d / 2500" % roundi(arena.bases[1].current_hp)
 blue_health.value = arena.bases[0].current_hp
 red_health.value = arena.bases[1].current_hp
 flux_label.text = "FLUX  %d   +%d/s" % [floori(arena.flux[0]),int(arena.income(0))]
 prism_label.text = "NORTH " + ownership(arena.prisms[0].capture_owner) + "    SOUTH " + ownership(arena.prisms[1].capture_owner)
 var population: Label = root.find_child("Population",true,false) as Label
 population.text = "UNITS  %d / 30" % arena.units_for(0).size()
 start_button.visible = arena.phase == MainArena.Phase.PREPARING
 link_label.text = "链路中断，请部署六边形" if arena.communication_jammed else "HEX-LINK ONLINE ×%.1f" % arena.commander_recharge()
 link_label.add_theme_color_override("font_color",ProceduralGeo.RED if arena.communication_jammed else ProceduralGeo.GOLD)
 override_button.disabled = arena.phase == MainArena.Phase.ENDED or (arena.phase == MainArena.Phase.PLAYING and (arena.communication_jammed or arena.override_left > 0.0))
 override_button.text = "%ds" % ceili(arena.override_left / arena.commander_recharge()) if arena.override_left > 0 else "OVERRIDE"
 cooldown_bar.value = 30.0 - arena.override_left
 for card: UnitDeployButton in unit_buttons:
  var reason: String = arena.deployment_reason(card.kind)
  card.disabled = not reason.is_empty()
  card.tooltip_text = reason if not reason.is_empty() else String(UnitCatalog.DATA[card.kind]["zh"]) + "：花费 " + str(UnitCatalog.DATA[card.kind]["cost"]) + " Flux"
  card.queue_redraw()
 for skill: String in skill_buttons:
  var skill_button: Button = skill_buttons[skill]
  var data: Dictionary = UnitCatalog.SKILLS[skill]
  var left: float = arena.skill_cooldowns[skill]
  (skill_bars[skill] as ProgressBar).value = float(data["cd"]) - left
  skill_button.text = "%s [%s]  %s" % [data["name"],data["key"],("%ds" % ceili(left / arena.commander_recharge())) if left > 0 else ("%d F" % int(data["cost"]))]
  var reason: String = arena.skill_reason(skill)
  skill_button.disabled = not reason.is_empty()
  skill_button.tooltip_text = reason if not reason.is_empty() else String(data["zh"]) + "：点击后选择战场位置"
  skill_button.modulate = Color(0.55,0.95,1.0) if arena.selected_skill == skill else Color.WHITE
 matrix_apply.text = "应用战术并开始" if arena.phase == MainArena.Phase.PREPARING else ("共享冷却 %ds" % ceili(arena.override_left / arena.commander_recharge()) if arena.override_left > 0 else "应用战术")
 matrix_apply.disabled = arena.phase == MainArena.Phase.ENDED or (arena.phase == MainArena.Phase.PLAYING and (arena.communication_jammed or arena.override_left > 0.0))

func ownership(team: int) -> String:
 return "蓝方" if team == 0 else ("红方" if team == 1 else "中立")

func collect_focusable(node: Node, controls: Array[Control]) -> void:
 if node is Control:
  var control: Control = node as Control
  if not control.is_visible_in_tree():
   return
  if control.focus_mode == Control.FOCUS_ALL and not (control is BaseButton and (control as BaseButton).disabled):
   controls.append(control)
 for child: Node in node.get_children():
  collect_focusable(child,controls)

func cycle_modal_focus(modal: Control, backwards: bool) -> void:
 var controls: Array[Control] = []
 collect_focusable(modal,controls)
 if controls.is_empty():
  return
 var index: int = controls.find(get_viewport().gui_get_focus_owner())
 var next: int = posmod(index + (-1 if backwards else 1),controls.size()) if index >= 0 else (controls.size()-1 if backwards else 0)
 controls[next].grab_focus()

func _input(event: InputEvent) -> void:
 if is_instance_valid(settings) or (is_instance_valid(return_dialog) and return_dialog.visible): return
 if not event is InputEventKey or not event.is_pressed() or event.is_echo():
  return
 var key_event: InputEventKey = event as InputEventKey
 var key: int = key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
 var focus: Control = get_viewport().gui_get_focus_owner()
 if key == KEY_ESCAPE:
  if focus is LineEdit or focus is TextEdit:
   focus.release_focus()
  if matrix_open:
   close_matrix()
  arena.selected_skill = ""
  get_viewport().set_input_as_handled()
 elif key == KEY_TAB:
  if end_backdrop.visible:
   cycle_modal_focus(end_backdrop,key_event.shift_pressed)
  elif matrix_open:
   cycle_modal_focus(matrix_backdrop,key_event.shift_pressed)
  elif not key_event.shift_pressed and not (focus is LineEdit or focus is TextEdit):
   open_matrix()
  else:
   return
  get_viewport().set_input_as_handled()

func open_settings() -> void:
 if returning or is_instance_valid(settings) or return_dialog.visible: return
 arena.selected_skill = ""
 settings = SettingsPanel.new()
 add_child(settings)
 settings.open_panel()

func settings_updated() -> void:
 CommanderTheme.refresh(root)
 var factor: float = float(GameSettings.values["font_scale"])
 bottom_layout.offset_top = -232-(factor-1)*150
 status_layout.offset_top = bottom_layout.offset_top-42
 status_layout.offset_bottom = bottom_layout.offset_top-8
 for card: UnitDeployButton in unit_buttons: card.update_metrics()
 if is_instance_valid(matrix_frame):
  matrix_frame.custom_minimum_size = Vector2(1500+200*(factor-1),800+100*(factor-1))
