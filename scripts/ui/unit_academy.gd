class_name UnitAcademy
extends Control

var stage: UnitShowcaseStage
var ui: Control
var selected_kind: String = "triangle"
var cards: Dictionary = {}
var roster: BoxContainer
var roster_panel: PanelContainer
var body: HBoxContainer
var dossier_panel: PanelContainer
var dossier_title: Label
var dossier_role: Label
var dossier_cost: Label
var normal_text: Label
var skill_text: Label
var prompt_text: Label
var feedback: Label
var stage_status: Label
var link_status: Label
var stats: Dictionary = {}
var stat_values: Dictionary = {}
var attack_button: Button
var skill_button: Button
var reset_button: Button
var launch_button: Button
var auto_button: CheckButton
var fade: ColorRect
var transitioning: bool = false
var narrow: bool = false
var stat_tween: Tween
var background: ShaderMaterial
var settings: SettingsPanel

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_PAUSABLE
 get_window().content_scale_size = Vector2i.ZERO
 var world: Node2D = Node2D.new()
 add_child(world)
 background = CombatContext.create_environment(world,Rect2(0,0,3200,2150))
 var layer: CanvasLayer = CanvasLayer.new()
 layer.layer = 10
 add_child(layer)
 ui = Control.new()
 ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 ui.theme = CommanderTheme.create()
 layer.add_child(ui)
 var padding: MarginContainer = MarginContainer.new()
 padding.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side: String in ["left","right","top","bottom"]: padding.add_theme_constant_override("margin_"+side,24)
 ui.add_child(padding)
 var column: VBoxContainer = VBoxContainer.new()
 column.add_theme_constant_override("separation",12)
 padding.add_child(column)
 var header: HBoxContainer = HBoxContainer.new()
 header.add_theme_constant_override("separation",24)
 column.add_child(header)
 var title_column: VBoxContainer = VBoxContainer.new()
 title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 header.add_child(title_column)
 title_column.add_child(text_label("兵种演练",26,CommanderTheme.TEXT))
 launch_button = action_button("选择地图",launch_battle)
 launch_button.custom_minimum_size = Vector2(170,56)
 header.add_child(launch_button)
 header.add_child(action_button("返回首页",return_home))
 header.add_child(action_button("设置",open_settings))
 var academy_tabs: HBoxContainer = HBoxContainer.new()
 column.add_child(academy_tabs)
 var current_tab: Button = action_button("档案与演示",func() -> void: pass)
 current_tab.disabled = true
 academy_tabs.add_child(current_tab)
 academy_tabs.add_child(action_button("提示词 · 布阵验证",open_laboratory))
 roster_panel = PanelContainer.new()
 column.add_child(roster_panel)
 roster = BoxContainer.new()
 roster_panel.add_child(roster)
 for kind: String in UnitCatalog.TYPES:
  var card: UnitRosterCard = UnitRosterCard.new()
  card.kind = kind
  card.text = String(UnitCatalog.DATA[kind]["zh"])+"\n"+String(UnitCatalog.DATA[kind]["name"])
  card.alignment = HORIZONTAL_ALIGNMENT_LEFT
  card.add_theme_stylebox_override("normal",CommanderTheme.box(Color(0.025,0.06,0.09),Color(0.13,0.29,0.38)))
  card.pressed.connect(func() -> void: select_unit(kind))
  roster.add_child(card)
  cards[kind] = card
 body = HBoxContainer.new()
 body.size_flags_vertical = Control.SIZE_EXPAND_FILL
 body.add_theme_constant_override("separation",16)
 column.add_child(body)
 dossier_panel = PanelContainer.new()
 body.add_child(dossier_panel)
 build_dossier()
 var stage_panel: PanelContainer = PanelContainer.new()
 stage_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 body.add_child(stage_panel)
 var stage_column: VBoxContainer = VBoxContainer.new()
 stage_panel.add_child(stage_column)
 stage_column.add_child(text_label("兵种实机演武场",24,CommanderTheme.TEXT))
 stage = UnitShowcaseStage.new()
 stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
 stage_column.add_child(stage)
 stage_status = text_label("",15,CommanderTheme.MUTED)
 stage_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 stage_status.custom_minimum_size.y = 0
 stage_column.add_child(stage_status)
 link_status = text_label("演示冷却已加速，正式冷却见左侧档案",14,ProceduralGeo.GOLD)
 stage_column.add_child(link_status)
 var controls: GridContainer = GridContainer.new()
 controls.columns = 2
 stage_column.add_child(controls)
 auto_button = CheckButton.new()
 auto_button.text = "自动循环演示：ON"
 auto_button.button_pressed = true
 auto_button.custom_minimum_size.y = 44
 auto_button.toggled.connect(func(value: bool) -> void:
  stage.set_auto_loop(value)
  auto_button.text = "自动循环演示："+("ON" if value else "OFF"))
 controls.add_child(auto_button)
 attack_button = action_button("立即演示普攻",stage.demonstrate_attack)
 controls.add_child(attack_button)
 skill_button = action_button("立即演示技能",stage.demonstrate_skill)
 controls.add_child(skill_button)
 reset_button = action_button("重置靶场假人",stage.reset_scenario)
 controls.add_child(reset_button)
 stage.state_changed.connect(update_stage_controls)
 fade = ColorRect.new()
 fade.color = Color(0.005,0.012,0.02,0)
 fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
 ui.add_child(fade)
 get_viewport().size_changed.connect(reflow)
 reflow()
 select_unit(selected_kind)
 GameSettings.settings_changed.connect(settings_updated)
 settings_updated()
 launch_button.grab_focus()

func text_label(value: String, font_size: int = 18, tint: Color = CommanderTheme.TEXT) -> Label:
 var node: Label = Label.new()
 node.text = value
 CommanderTheme.font(node,font_size)
 node.add_theme_color_override("font_color",tint)
 return node

func action_button(value: String, action: Callable) -> Button:
 var node: Button = Button.new()
 node.text = value
 node.custom_minimum_size.y = 44
 node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
 node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 node.pressed.connect(action)
 return node

func paragraph(parent: Node, heading: String) -> Label:
 parent.add_child(text_label(heading,16,ProceduralGeo.GOLD))
 var node: Label = text_label("")
 node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 parent.add_child(node)
 return node

func build_dossier() -> void:
 var scroll: ScrollContainer = ScrollContainer.new()
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 scroll.follow_focus = true
 dossier_panel.add_child(scroll)
 var column: VBoxContainer = VBoxContainer.new()
 column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 column.add_theme_constant_override("separation",12)
 scroll.add_child(column)
 dossier_title = text_label("",30)
 column.add_child(dossier_title)
 dossier_role = text_label("",18,ProceduralGeo.GOLD)
 column.add_child(dossier_role)
 dossier_cost = text_label("",16,CommanderTheme.MUTED)
 column.add_child(dossier_cost)
 for key: String in ["hp","speed","range","synergy"]:
  var row: HBoxContainer = HBoxContainer.new()
  column.add_child(row)
  var names: Dictionary = {"hp":"结构强度 / HP","speed":"机动速度 / MOBILITY","range":"攻击射程 / RANGE","synergy":"协同需求 / 设计评级"}
  var caption: Label = text_label(names[key],15)
  caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  row.add_child(caption)
  var value: Label = text_label("",15,CommanderTheme.MUTED)
  row.add_child(value)
  stat_values[key] = value
  var meter: ProgressBar = ProgressBar.new()
  meter.show_percentage = false
  meter.custom_minimum_size.y = 6
  meter.max_value = 460.0 if key == "hp" else (270.0 if key == "speed" else (400.0 if key == "range" else 5.0))
  column.add_child(meter)
  stats[key] = meter
 normal_text = paragraph(column,"普攻机制")
 skill_text = paragraph(column,"核心技能")
 prompt_text = paragraph(column,"AI 提示词推荐写法")
 prompt_text.add_theme_color_override("font_color",Color(0.55,0.87,1.0))
 column.add_child(action_button("应用为默认开局指令",save_opening))
 feedback = text_label("本次运行内保存，战前仍可修改",15,CommanderTheme.MUTED)
 feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 column.add_child(feedback)

func select_unit(kind: String) -> void:
 selected_kind = kind
 for key: String in cards: (cards[key] as Button).button_pressed = key == kind
 var data: Dictionary = UnitCatalog.DATA[kind]
 var dossier: Dictionary = UnitDossier.DATA[kind]
 dossier_title.text = String(data["zh"])
 dossier_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 dossier_cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 dossier_role.text = dossier["role"]
 dossier_cost.text = "COST: %d FLUX   |   技能冷却: %.1fs" % [int(data["cost"]),float(data["skill_cd"])]
 normal_text.text = dossier["attack"]
 skill_text.text = dossier["skill"]
 prompt_text.text = "「"+String(dossier["prompt"])+"」"
 if is_instance_valid(stat_tween): stat_tween.kill()
 stat_tween = create_tween().set_parallel(true)
 for key: String in stats:
  var value: float = float(dossier["synergy"] if key == "synergy" else data[key])
  (stat_values[key] as Label).text = ("%d / 5" % int(value)) if key == "synergy" else ("%d" % int(value))
  stat_tween.tween_property(stats[key],"value",value,0.0 if bool(GameSettings.values["reduced_motion"]) else 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
 stage.select_unit(kind)
 feedback.text = "已保存开局："+TacticalBrain.opening_prompt
 update_stage_controls()

func save_opening() -> void:
 var prompt: String = UnitDossier.DATA[selected_kind]["prompt"]
 var result: Dictionary = TacticalBrain.save_opening_prompt(prompt)
 feedback.text = "已保存开局："+prompt if bool(result["ok"]) else String(result["message"])
 feedback.add_theme_color_override("font_color",CommanderTheme.ACCENT if bool(result["ok"]) else ProceduralGeo.RED)

func reflow() -> void:
 var width: float = get_viewport().get_visible_rect().size.x
 var next_narrow: bool = width < 1600.0
 if next_narrow != narrow or roster.get_parent() != (roster_panel if next_narrow else body):
  roster.reparent(roster_panel if next_narrow else body)
  if not next_narrow: body.move_child(roster,0)
 narrow = next_narrow
 roster.vertical = not narrow
 roster_panel.visible = narrow
 roster.custom_minimum_size = Vector2(0,0) if narrow else Vector2(380.0 if width >= 1900 else 300.0,0)
 dossier_panel.custom_minimum_size.x = (width-80.0)*0.44 if narrow else (620.0 if width >= 1900 else 480.0)
 for key: String in cards:
  var card: UnitRosterCard = cards[key]
  card.compact = narrow
  card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  card.custom_minimum_size.y = maxf(64,64*float(GameSettings.values["font_scale"])) if narrow else 112.0
  var style: StyleBoxFlat = CommanderTheme.box(Color(0.025,0.06,0.09),Color(0.13,0.29,0.38))
  style.content_margin_left = 53.0 if narrow else 88.0
  card.add_theme_stylebox_override("normal",style)
  var hover: StyleBoxFlat = style.duplicate() as StyleBoxFlat
  hover.bg_color = Color(0.055,0.16,0.21)
  hover.border_color = CommanderTheme.ACCENT
  card.add_theme_stylebox_override("hover",hover)
  var pressed: StyleBoxFlat = hover.duplicate() as StyleBoxFlat
  pressed.bg_color = Color(0.06,0.22,0.28)
  pressed.set_border_width_all(2)
  card.add_theme_stylebox_override("pressed",pressed)
  card.text = String(UnitCatalog.DATA[key]["zh"])+( "" if narrow else "\n"+String(UnitCatalog.DATA[key]["name"])+"\n"+String(UnitDossier.DATA[key]["role"]))
  CommanderTheme.font(card,14 if narrow else 18)
 stage.custom_minimum_size.y = (180.0 if get_viewport().get_visible_rect().size.y < 800 else 220.0) if narrow else 350.0
 stage.fit_stage()

func update_stage_controls() -> void:
 if not is_instance_valid(attack_button): return
 attack_button.disabled = stage.busy or selected_kind == "hexagon"
 attack_button.tooltip_text = "支援兵种，无直接普攻" if selected_kind == "hexagon" else ("当前动作结束后可操作" if stage.busy else "调用真实普攻")
 skill_button.disabled = stage.busy
 stage_status.text = stage.status

func set_reduced_motion(enabled: bool) -> void:
 GameSettings.set_value("reduced_motion",enabled)
 background.set_shader_parameter("reduced_motion",enabled)
 stage.set_reduced_motion(enabled)
 for key: String in cards: (cards[key] as UnitRosterCard).reduced_motion = enabled

func _process(_delta: float) -> void:
 if is_instance_valid(link_status) and selected_kind == "hexagon":
  link_status.text = "演示终端剩余 %.1fs  |  恢复速度 +40%%，×1.4" % stage.terminal_left
 elif is_instance_valid(link_status):
  link_status.text = "演示冷却已加速，正式冷却见左侧档案"

func settings_updated() -> void:
 CommanderTheme.refresh(ui)
 var enabled: bool = bool(GameSettings.values["reduced_motion"])
 background.set_shader_parameter("reduced_motion",enabled)
 stage.set_reduced_motion(enabled)
 for key: String in cards: (cards[key] as UnitRosterCard).reduced_motion = enabled
 reflow()

func open_settings() -> void:
 if is_instance_valid(settings) or transitioning: return
 settings = SettingsPanel.new()
 add_child(settings)
 settings.open_panel()

func launch_battle() -> void:
 MatchSession.menu_page = "single"
 leave_academy()

func return_home() -> void:
 MatchSession.menu_page = "home"
 leave_academy()

func leave_academy() -> void:
 if transitioning: return
 transitioning = true
 fade.mouse_filter = Control.MOUSE_FILTER_STOP
 var tween: Tween = create_tween()
 tween.tween_property(fade,"color:a",1.0,0.0 if bool(GameSettings.values["reduced_motion"]) else 0.18)
 await tween.finished
 var error: Error = get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
 if error != OK:
  feedback.text = "页面载入失败："+error_string(error)+"。请重试。"
  fade.color.a = 0
  fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
  transitioning = false

func _exit_tree() -> void:
 if is_instance_valid(stage): stage.shutdown()
 get_window().content_scale_size = Vector2i(1920,1080)

func open_laboratory() -> void:
 if transitioning: return
 transitioning = true
 fade.mouse_filter = Control.MOUSE_FILTER_STOP
 LaboratoryStore.selected_kind = selected_kind
 var tween: Tween = create_tween()
 tween.tween_property(fade,"color:a",1.0,0.0 if bool(GameSettings.values["reduced_motion"]) else 0.18)
 await tween.finished
 var error: Error = get_tree().change_scene_to_file("res://scenes/tactic_laboratory.tscn")
 if error != OK:
  feedback.text = "实验室载入失败："+error_string(error)
  transitioning = false
  fade.color.a = 0
  fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
