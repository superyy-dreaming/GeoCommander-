class_name TacticLaboratory
extends Control

var editor: LabPromptEditor
var view: LaboratoryView
var columns: HBoxContainer
var battle_column: VBoxContainer
var readings: TabContainer
var summary: Label
var rule_reading: TextEdit
var event_log: TextEdit
var feedback: Label
var map_select: OptionButton
var presets: OptionButton
var team_select: OptionButton
var kind_select: OptionButton
var hp_input: SpinBox
var angle_input: SpinBox
var start_button: Button
var pause_button: Button
var editing_controls: Array[Control] = []
var refresh_left: float = 0.0
var events: Array[String] = []
var transitioning: bool = false
var unit_buttons: Dictionary = {}
var ui: Control

func _ready() -> void:
 get_window().content_scale_size = Vector2i.ZERO
 theme = CommanderTheme.create()
 var background: ColorRect = ColorRect.new()
 background.color = Color(0.012,0.025,0.041)
 background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 background.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(background)
 var layer: CanvasLayer = CanvasLayer.new()
 layer.layer = 10
 add_child(layer)
 ui = Control.new()
 ui.theme = CommanderTheme.create()
 ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 layer.add_child(ui)
 var margin: MarginContainer = MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for edge: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,18)
 ui.add_child(margin)
 var column: VBoxContainer = VBoxContainer.new()
 margin.add_child(column)
 var header: HBoxContainer = HBoxContainer.new()
 column.add_child(header)
 var title: Label = label("提示词实验室 · 布阵验证",24)
 title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 header.add_child(title)
 header.add_child(button("返回兵种演练",leave))
 header.add_child(button("设置",open_settings))
 var units: HBoxContainer = HBoxContainer.new()
 column.add_child(units)
 for kind: String in UnitCatalog.TYPES:
  var unit_button: Button = button(UnitCatalog.DATA[kind]["zh"],func() -> void:
   editor.select_kind(kind)
   for id: String in unit_buttons: (unit_buttons[id] as Button).button_pressed = id == kind)
  unit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  unit_button.toggle_mode = true
  unit_button.button_pressed = kind == LaboratoryStore.selected_kind
  unit_buttons[kind] = unit_button
  units.add_child(unit_button)
 columns = HBoxContainer.new()
 columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
 column.add_child(columns)
 var panel: PanelContainer = PanelContainer.new()
 panel.custom_minimum_size.x = 340
 columns.add_child(panel)
 editor = LabPromptEditor.new()
 editor.kind = LaboratoryStore.selected_kind
 panel.add_child(editor)
 battle_column = VBoxContainer.new()
 battle_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 columns.add_child(battle_column)
 var options: HFlowContainer = HFlowContainer.new()
 battle_column.add_child(options)
 map_select = OptionButton.new()
 for title_text: String in MapCatalog.TITLES: map_select.add_item(title_text)
 map_select.custom_minimum_size.y = 44
 options.add_child(map_select)
 presets = OptionButton.new()
 for title_text: String in LaboratoryPresets.TITLES: presets.add_item(title_text)
 presets.add_item("自定义布阵")
 presets.set_item_disabled(6,true)
 presets.custom_minimum_size.y = 44
 options.add_child(presets)
 var clear: Button = button("清空阵容",func() -> void:
  view.layout.clear()
  view.rebuild(false,false)
  view.persist())
 options.add_child(clear)
 editing_controls.append_array([map_select,presets,clear])
 view = LaboratoryView.new()
 view.size_flags_vertical = Control.SIZE_EXPAND_FILL
 battle_column.add_child(view)
 var placement: HFlowContainer = HFlowContainer.new()
 battle_column.add_child(placement)
 team_select = OptionButton.new()
 team_select.add_item("放置蓝方")
 team_select.add_item("放置红方")
 team_select.custom_minimum_size.y = 44
 placement.add_child(team_select)
 kind_select = OptionButton.new()
 for kind: String in UnitCatalog.TYPES: kind_select.add_item(UnitCatalog.DATA[kind]["zh"])
 kind_select.custom_minimum_size.y = 44
 placement.add_child(kind_select)
 placement.add_child(label("生命 %",14))
 hp_input = spin(1,100,100)
 placement.add_child(hp_input)
 placement.add_child(label("朝向 °",14))
 angle_input = spin(0,359,0)
 placement.add_child(angle_input)
 var remove: Button = button("删除选中",view.delete_selected)
 placement.add_child(remove)
 editing_controls.append_array([team_select,kind_select,hp_input,angle_input,remove])
 var actions: HFlowContainer = HFlowContainer.new()
 battle_column.add_child(actions)
 start_button = button("开始验证",func() -> void:
  view.rebuild(true,false)
  attach_context())
 actions.add_child(start_button)
 pause_button = button("暂停",func() -> void: view.context.toggle_pause())
 actions.add_child(pause_button)
 actions.add_child(button("重置布阵",func() -> void:
  view.rebuild(false,false)
  attach_context()))
 actions.add_child(button("默认战术对照",func() -> void:
  view.rebuild(true,true)
  attach_context()))
 readings = TabContainer.new()
 readings.custom_minimum_size.y = 150
 readings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 battle_column.add_child(readings)
 summary = label("",16)
 summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 var summary_scroll: ScrollContainer = ScrollContainer.new()
 summary_scroll.name = "结果"
 summary_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 readings.add_child(summary_scroll)
 summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 summary_scroll.add_child(summary)
 rule_reading = TextEdit.new()
 rule_reading.name = "规则读数"
 rule_reading.editable = false
 rule_reading.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
 CommanderTheme.font(rule_reading,14)
 readings.add_child(rule_reading)
 event_log = TextEdit.new()
 event_log.name = "事件"
 event_log.editable = false
 event_log.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
 CommanderTheme.font(event_log,14)
 readings.add_child(event_log)
 feedback = label("左键放置/选中，拖动后松开应用；滚轮缩放，中键平移。正式冷却，1×速度，种子 7401。",14)
 feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 column.add_child(feedback)
 map_select.item_selected.connect(change_map)
 presets.item_selected.connect(load_preset)
 team_select.item_selected.connect(func(index: int) -> void:
  view.place_team = index
  angle_input.value = 180 if index == 1 else 0)
 kind_select.item_selected.connect(func(index: int) -> void: view.place_kind = UnitCatalog.TYPES[index])
 hp_input.value_changed.connect(func(value: float) -> void: view.edit_selected(value/100,angle_input.value))
 angle_input.value_changed.connect(func(value: float) -> void: view.edit_selected(hp_input.value/100,value))
 view.selected.connect(func(unit: BaseGeoUnit) -> void:
  hp_input.set_value_no_signal(unit.current_hp/unit.max_hp*100)
  angle_input.set_value_no_signal(fposmod(rad_to_deg(unit.visual_root.rotation),360)))
 view.message.connect(show_message)
 view.changed.connect(refresh)
 view.layout_edited.connect(func() -> void: presets.select(6))
 editor.rerun_requested.connect(func() -> void:
  view.rebuild(true,false)
  attach_context())
 if not restore_setup(): load_preset(0)
 attach_context()
 GameSettings.settings_changed.connect(settings_updated)
 get_viewport().size_changed.connect(reflow)
 settings_updated()

func label(value: String, font_size: int) -> Label:
 var node: Label = Label.new()
 node.text = value
 CommanderTheme.font(node,font_size)
 return node

func button(value: String, action: Callable) -> Button:
 var node: Button = Button.new()
 node.text = value
 node.custom_minimum_size.y = 44
 node.pressed.connect(action)
 return node

func spin(minimum: float, maximum: float, value: float) -> SpinBox:
 var node: SpinBox = SpinBox.new()
 node.min_value = minimum
 node.max_value = maximum
 node.value = value
 node.custom_minimum_size = Vector2(88,44)
 return node

func restore_setup() -> bool:
 var setup: Dictionary = LaboratoryStore.setup
 if setup.is_empty(): return false
 if setup.get("map_id") not in MapCatalog.IDS or not setup.get("units") is Array or not UnitTacticProgram.numeric(setup.get("seed")): return false
 view.map_id = setup["map_id"]
 view.layout.clear()
 view.rebuild(false,false)
 var counts: Array[int] = [0,0]
 var hexes: Array[int] = [0,0]
 for entry: Variant in setup["units"]:
  if not entry is Dictionary or entry.get("kind") not in UnitCatalog.TYPES or entry.get("team") not in [0,1]: return invalid_setup()
  for key: String in ["x","y","hp","angle"]:
   if not UnitTacticProgram.numeric(entry.get(key)): return invalid_setup()
  if float(entry["hp"]) < 0.01 or float(entry["hp"]) > 1 or float(entry["angle"]) < 0 or float(entry["angle"]) > 359: return invalid_setup()
  var team: int = int(entry["team"])
  counts[team] += 1
  if entry["kind"] == "hexagon": hexes[team] += 1
  if counts[team] > 30 or hexes[team] > 2: return invalid_setup()
  if not view.context.valid_point(entry["kind"],Vector2(entry["x"],entry["y"]),-1,view.layout).is_empty(): return invalid_setup()
  view.layout.append({"kind":entry["kind"],"team":int(entry["team"]),"x":float(entry["x"]),"y":float(entry["y"]),"hp":float(entry["hp"]),"angle":float(entry["angle"])})
 presets.select(6)
 view.seed_value = int(setup["seed"])
 map_select.select(MapCatalog.IDS.find(view.map_id))
 view.rebuild(false,false)
 return true

func invalid_setup() -> bool:
 var backed: bool = LaboratoryStore.backup_invalid()
 show_message("保存的布阵包含无效数据，本次载入标准阵容。"+("原文件已备份。" if backed else "原文件保留，备份失败。实验本次运行已生效，未保存，请重试保存实验。"))
 view.layout.clear()
 return false

func load_preset(index: int) -> void:
 presets.select(index)
 view.layout.clear()
 view.rebuild(false,false)
 var rejected: int = 0
 for spec: Dictionary in LaboratoryPresets.create(index):
  if view.context.valid_point(spec["kind"],Vector2(spec["x"],spec["y"]),-1,view.layout).is_empty(): view.layout.append(spec)
  else: rejected += 1
 view.rebuild(false,false)
 attach_context()
 view.persist()
 presets.select(index)
 show_message("已载入 "+LaboratoryPresets.TITLES[index]+("；%d 个位置与本地图冲突，未放置" % rejected if rejected > 0 else "，可自由调整"))

func change_map(index: int) -> void:
 map_select.select(index)
 var old: String = view.map_id
 view.map_id = MapCatalog.IDS[index]
 view.rebuild(false,false)
 for spec: Dictionary in view.layout:
  var i: int = view.layout.find(spec)
  var error: String = view.context.valid_point(spec["kind"],Vector2(spec["x"],spec["y"]),i,view.layout)
  if not error.is_empty():
   view.map_id = old
   map_select.select(MapCatalog.IDS.find(old))
   view.rebuild(false,false)
   attach_context()
   show_message("新地图落点无效："+error+"。请清空后切换地图。")
   return
 attach_context()
 view.persist()

func attach_context() -> void:
 events.clear()
 if is_instance_valid(event_log): ReadoutText.update(event_log,"尚无事件。开始验证后会记录真实技能启动、阵亡与占点。")
 view.context.event_added.connect(func(text: String) -> void:
  events.append(text)
  if events.size() > 80: events.pop_front()
  ReadoutText.update(event_log,"\n".join(events)))
 refresh()

func show_message(text: String) -> void:
 feedback.text = text

func refresh() -> void:
 if not is_instance_valid(summary) or not is_instance_valid(view.context): return
 var context: LaboratoryArena = view.context
 var editing: bool = context.state == LaboratoryArena.State.ARRANGING
 for control: Control in editing_controls:
  if control is BaseButton: (control as BaseButton).disabled = not editing
  elif control is SpinBox: (control as SpinBox).editable = editing
 start_button.disabled = not editing
 pause_button.disabled = context.state not in [LaboratoryArena.State.RUNNING,LaboratoryArena.State.PAUSED]
 pause_button.text = "继续" if context.state == LaboratoryArena.State.PAUSED else "暂停"
 summary.text = "%s\n%.1f / 120s，%s，种子 %d\n" % [context.result_text,context.elapsed,"默认对照" if context.comparison else "实验规则",view.seed_value]
 for team: int in range(2):
  var data: Dictionary = context.totals[team]
  summary.text += "%s 存活 %d，伤害 %.0f，治疗 %.0f，技能 %d\n" % ["蓝方" if team == 0 else "红方",context.units_for(team).size(),data["damage"],data["healing"],data["skills"]]
 var unit: BaseGeoUnit = view.selected_unit
 var reading: String = "点击战场单位查看当前命中的规则、有效动作与阻塞原因。"
 if is_instance_valid(unit) and not unit.dead:
  reading = "%s\n命中：%s\n受阻：%s\n有效动作：\n%s\n事实：\n%s" % [UnitCatalog.DATA[unit.unit_type]["zh"],unit.matched_rule,unit.action_blocked if not unit.action_blocked.is_empty() else "无",JSON.stringify(unit.rule,"  "),JSON.stringify(unit.last_facts,"  ")]

 ReadoutText.update(rule_reading,reading)

func _process(delta: float) -> void:
 refresh_left -= delta
 if refresh_left <= 0:
  refresh_left = 0.2
  refresh()

func reflow() -> void:
 if not is_instance_valid(readings): return
 var wide: bool = size.x >= 1700
 if readings.get_parent() != (columns if wide else battle_column): readings.reparent(columns if wide else battle_column)
 readings.custom_minimum_size = Vector2(330*float(GameSettings.values["font_scale"]),150) if wide else Vector2(0,150)
 readings.size_flags_horizontal = Control.SIZE_FILL if wide else Control.SIZE_EXPAND_FILL
 readings.size_flags_vertical = Control.SIZE_EXPAND_FILL if wide else Control.SIZE_FILL

func settings_updated() -> void:
 CommanderTheme.refresh(ui)
 reflow()

func open_settings() -> void:
 for child: Node in get_children():
  if child is SettingsPanel: return
 var panel: SettingsPanel = SettingsPanel.new()
 add_child(panel)
 panel.open_panel()

func leave() -> void:
 if transitioning: return
 transitioning = true
 editor.save_draft()
 LLMService.cancel_owner(editor.get_instance_id())
 var was_active: bool = view.context.active
 view.context.active = false
 var fade: ColorRect = ColorRect.new()
 fade.color = Color(0.005,0.012,0.02,0)
 fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 fade.mouse_filter = Control.MOUSE_FILTER_STOP
 ui.add_child(fade)
 var tween: Tween = create_tween()
 tween.tween_property(fade,"color:a",1.0,0.0 if bool(GameSettings.values["reduced_motion"]) else 0.18)
 await tween.finished
 var error: Error = get_tree().change_scene_to_file("res://scenes/unit_academy.tscn")
 if error != OK:
  transitioning = false
  view.context.active = was_active
  fade.queue_free()
  show_message("返回失败："+error_string(error))

func _exit_tree() -> void:
 if is_instance_valid(view.context): view.context.shutdown()
 get_window().content_scale_size = Vector2i(1920,1080)
