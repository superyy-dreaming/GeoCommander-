class_name TacticLaboratory
extends Control

var editor: LabPromptEditor
var view: LaboratoryView
var columns: HSplitContainer
var battle_column: VBoxContainer
var readings: TabContainer
var summary: Label
var rule_reading: TextEdit
var event_log: TextEdit
var feedback: Label
var map_select: OptionButton
var edit_select: OptionButton
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
var floating: LabFloatingReadout
var placement_panel: LabPlacementPanel
var dialog: LabDialog
var unit_picker: OptionButton
var unit_row: HBoxContainer
var map_caption: Label
var map_menu: MenuButton
var edit_menu: MenuButton
var display_menu: MenuButton
var placement_menu: MenuButton
var units_panel: PanelContainer
static var left_ratio: float = 0.42
var arranging_layout: bool = false
var current_preset: int = 6

func _ready() -> void:
 GameSettings.apply_content_scale()
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
 dialog = LabDialog.new()
 add_child(dialog)
 var margin: MarginContainer = MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for edge: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,16)
 ui.add_child(margin)
 var column: VBoxContainer = VBoxContainer.new()
 margin.add_child(column)
 var header: HBoxContainer = HBoxContainer.new()
 column.add_child(header)
 var title: Label = label("提示词实验室",24)
 title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
 header.add_child(title)
 unit_picker = OptionButton.new()
 unit_picker.fit_to_longest_item = false
 unit_picker.custom_minimum_size = Vector2(180,44)
 for kind: String in UnitCatalog.TYPES: unit_picker.add_item(UnitCatalog.DATA[kind]["zh"])
 unit_picker.item_selected.connect(func(index: int) -> void: select_unit(UnitCatalog.TYPES[index]))
 header.add_child(unit_picker)
 header.add_child(button("返回",request_leave))
 header.add_child(button("设置",open_settings))
 unit_row = HBoxContainer.new()
 column.add_child(unit_row)
 for kind: String in UnitCatalog.TYPES:
  var unit_button: Button = button(UnitCatalog.DATA[kind]["zh"],func() -> void: select_unit(kind))
  unit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  unit_button.toggle_mode = true
  unit_button.button_pressed = kind == LaboratoryStore.selected_kind
  unit_buttons[kind] = unit_button
  unit_row.add_child(unit_button)
 unit_picker.select(UnitCatalog.TYPES.find(LaboratoryStore.selected_kind))
 columns = HSplitContainer.new()
 columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
 columns.add_theme_constant_override("separation",12)
 column.add_child(columns)
 units_panel = PanelContainer.new()
 units_panel.custom_minimum_size.x = 360
 units_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 columns.add_child(units_panel)
 editor = LabPromptEditor.new()
 editor.dialog = dialog
 editor.kind = LaboratoryStore.selected_kind
 units_panel.add_child(editor)
 editor.settings_requested.connect(open_llm_settings)
 battle_column = VBoxContainer.new()
 battle_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 battle_column.custom_minimum_size.x = 420
 columns.add_child(battle_column)
 var status_row: HBoxContainer = HBoxContainer.new()
 battle_column.add_child(status_row)
 map_caption = label("",16)
 map_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
 map_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 status_row.add_child(map_caption)
 start_button = button("开始验证",func() -> void:
  view.rebuild(true,false)
  attach_context())
 status_row.add_child(start_button)
 pause_button = button("暂停",func() -> void: view.context.toggle_pause())
 status_row.add_child(pause_button)
 var options: HFlowContainer = HFlowContainer.new()
 options.add_theme_constant_override("h_separation",6)
 battle_column.add_child(options)
 map_menu = menu("地图",MapCatalog.TITLES,func(index: int) -> void:
  if view.context.state!=LaboratoryArena.State.ARRANGING: return
  confirm_operation("切换地图？","将停止当前验证并检查阵容是否适合新地图。",change_map.bind(index),true))
 options.add_child(map_menu)
 placement_menu = menu("布阵",["布阵属性与预设","清空阵容"],func(index: int) -> void:
  if index==0: placement_panel.open_at(placement_menu_anchor())
  elif view.context.state==LaboratoryArena.State.ARRANGING:
   confirm_operation("清空阵容？","清空实验双方单位，保留当前提示词和 JSON。",clear_layout))
 options.add_child(placement_menu)
 edit_menu = menu("编辑",["布阵","编辑路径","选择掩体"],func(index: int) -> void:
  edit_select.select(index)
  set_edit_mode(index))
 options.add_child(edit_menu)
 var debug_menu: MenuButton = menu("验证",["重置布阵","默认战术对照","前进一帧","运行到下一步骤"],debug_action)
 options.add_child(debug_menu)
 display_menu = menu("显示",["显示／隐藏读数","恢复读数位置"],func(index: int) -> void:
  if index==0: floating.visible = not floating.visible
  else: floating.reset_layout())
 options.add_child(display_menu)
 view = LaboratoryView.new()
 view.path_edit_allowed=func()->bool:return not editor.busy
 view.size_flags_vertical = Control.SIZE_EXPAND_FILL
 battle_column.add_child(view)
 floating = LabFloatingReadout.new()
 view.add_child(floating)
 floating.interaction_started.connect(view.cancel_interaction)
 readings = floating.readings
 summary = label("",16)
 summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 var summary_scroll: ScrollContainer = ScrollContainer.new()
 summary_scroll.name = "结果"
 summary_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 summary_scroll.focus_mode = Control.FOCUS_ALL
 summary_scroll.follow_focus = true
 readings.add_child(summary_scroll)
 summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 summary_scroll.add_child(summary)
 rule_reading = TextEdit.new()
 rule_reading.name = "规则读数"
 rule_reading.editable = false
 rule_reading.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
 CommanderTheme.font(rule_reading,16)
 readings.add_child(rule_reading)
 event_log = TextEdit.new()
 event_log.name = "事件"
 event_log.editable = false
 event_log.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
 CommanderTheme.font(event_log,16)
 readings.add_child(event_log)
 placement_panel = LabPlacementPanel.new()
 ui.add_child(placement_panel)
 team_select = OptionButton.new()
 team_select.add_item("蓝方")
 team_select.add_item("红方")
 placement_panel.field("放置阵营",team_select)
 kind_select = OptionButton.new()
 for kind: String in UnitCatalog.TYPES: kind_select.add_item(UnitCatalog.DATA[kind]["zh"])
 placement_panel.field("放置兵种",kind_select)
 hp_input = spin(1,100,100)
 placement_panel.field("初始生命 %",hp_input)
 angle_input = spin(0,359,0)
 placement_panel.field("朝向 °",angle_input)
 presets = OptionButton.new()
 presets.custom_minimum_size.y = 44
 for title_text: String in LaboratoryPresets.TITLES: presets.add_item(title_text)
 presets.add_item("自定义布阵")
 presets.set_item_disabled(6,true)
 placement_panel.field("快捷预设（将替换当前阵容）",presets)
 var remove: Button = button("删除选中单位",view.delete_selected)
 placement_panel.content.add_child(remove)
 editing_controls.append_array([team_select,kind_select,hp_input,angle_input,presets,remove])
 # Keep the selectors as compatibility state for tests and programmatic callers.
 map_select = OptionButton.new()
 for text: String in MapCatalog.TITLES: map_select.add_item(text)
 map_select.hide()
 ui.add_child(map_select)
 edit_select = OptionButton.new()
 for text: String in ["布阵","编辑路径","选择掩体"]: edit_select.add_item(text)
 edit_select.hide()
 ui.add_child(edit_select)
 feedback = label("左键布阵或选中，滚轮缩放，中键平移。布阵属性与调试操作在战场菜单中。",14)
 feedback.clip_text = true
 feedback.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
 feedback.tooltip_text = feedback.text
 column.add_child(feedback)
 map_select.item_selected.connect(change_map)
 presets.item_selected.connect(func(index: int) -> void:
  placement_panel.hide()
  presets.select(current_preset)
  confirm_operation("载入快捷预设？","将替换当前实验阵容，提示词和 JSON 保留。",load_preset.bind(index)))
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
 editor.plan_editor.step_selected.connect(func(id: String) -> void:
  view.path_step=id
  refresh_path())
 editor.plan_editor.edited.connect(func(_value: Dictionary) -> void: refresh_path())
 editor.draft_changed.connect(refresh_path)
 view.path_edited.connect(func(points: Array, obstacle: String) -> void:
  editor.plan_editor.map_id=view.map_id
  editor.plan_editor.edit_path(view.path_step,points,obstacle)
  refresh_path())
 view.layout_edited.connect(func() -> void:
  current_preset=6
  presets.select(6))
 editor.rerun_requested.connect(func() -> void:
  view.rebuild(true,false)
  attach_context())
 columns.dragged.connect(func(_offset: int) -> void:
  if not arranging_layout: remember_columns.call_deferred())
 if not restore_setup(): load_preset(0)
 attach_context()
 GameSettings.settings_changed.connect(settings_updated)
 get_viewport().size_changed.connect(reflow)
 settings_updated()
 reflow.call_deferred()

func menu(title: String, items: Array, action: Callable) -> MenuButton:
 var node: MenuButton = MenuButton.new()
 node.text = title
 node.flat = false
 node.focus_mode = Control.FOCUS_ALL
 node.custom_minimum_size.y = 44
 for item: String in items: node.get_popup().add_item(item)
 node.get_popup().id_pressed.connect(action)
 node.about_to_popup.connect(func() -> void: view.cancel_interaction())
 return node

func placement_menu_anchor() -> Control:
 return map_menu.get_parent().get_child(1) as Control

func select_unit(kind: String) -> void:
 editor.select_kind(kind)
 unit_picker.select(UnitCatalog.TYPES.find(kind))
 for id: String in unit_buttons: (unit_buttons[id] as Button).button_pressed = id == kind

func set_edit_mode(index: int) -> void:
 view.cancel_interaction()
 view.edit_mode=index
 if index>0: show_message("先在步骤页选择步骤。左键添加或拖动航点，右键删除；选择掩体时点击墙体。")
 refresh_path()
 refresh()

func clear_layout() -> void:
 view.restore_error=""
 view.layout.clear()
 view.rebuild(false,false)
 attach_context()
 view.persist()

func confirm_operation(title: String, message: String, action: Callable, pause: bool = false) -> void:
 view.cancel_interaction()
 placement_panel.hide()
 dialog.present(title,message,action,pause)

func debug_action(index: int) -> void:
 match index:
  0: confirm_operation("重置布阵？","停止验证并恢复相同初始阵容与种子。",func() -> void:
   view.rebuild(false,false)
   attach_context(),true)
  1: confirm_operation("运行默认战术对照？","停止当前验证，以相同阵容与种子运行默认战术。",func() -> void:
   view.rebuild(true,true)
   attach_context(),true)
  2:
   if view.context.state!=LaboratoryArena.State.PAUSED: show_message("先暂停验证，再逐帧前进")
   else: view.context.step_frame()
  3:
   if view.context.state!=LaboratoryArena.State.PAUSED or not is_instance_valid(view.selected_unit) or view.selected_unit.execution==null: show_message("暂停后选中一个运行 v2 方案的单位")
   else: view.context.step_transition(view.selected_unit)

func request_leave() -> void:
 if view.context.state in [LaboratoryArena.State.RUNNING,LaboratoryArena.State.PAUSED]:
  confirm_operation("返回兵种演练？","将放弃当前验证，已保存的提示词和初始布阵保留。",leave,true)
 else: leave()

func remember_columns() -> void:
 if columns.size.x>12: left_ratio=clampf(units_panel.size.x/(columns.size.x-12),0.32,0.58)
 reflow()

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
 if setup.get("map_id") not in MapCatalog.IDS or not setup.get("units") is Array or not UnitTacticProgram.numeric(setup.get("seed")):
  return invalid_setup("布阵头信息无效")
 view.map_id = setup["map_id"]
 view.layout.clear()
 for index: int in range(setup["units"].size()):
  var entry: Variant = setup["units"][index]
  var error: String=LaboratoryArena.spec_error(entry)
  if not error.is_empty():
   return invalid_setup("第%d个单位：%s" % [index+1,error])
  view.layout.append(entry.duplicate(true))
 presets.select(6)
 view.seed_value = int(setup["seed"])
 map_select.select(MapCatalog.IDS.find(view.map_id))
 view.rebuild(false,false)
 var error: String=view.context.validate_layout()
 if not error.is_empty(): show_message("原布阵已保留，待修复："+error+"。可拖动或删除冲突单位，修复前禁止运行。")
 return true

func invalid_setup(reason: String) -> bool:
 LaboratoryStore.backup_invalid()
 view.restore_error="保存的布阵待修复："+reason
 view.layout.clear()
 view.rebuild(false,false)
 show_message(view.restore_error+"。原文件和方案保留，禁止运行。请明确清空或载入预设后重新布阵。")
 return true

func load_preset(index: int) -> void:
 view.restore_error=""
 current_preset = index
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
 current_preset = index
 presets.select(index)
 show_message("已载入 "+LaboratoryPresets.TITLES[index]+("；%d 个位置与本地图冲突，未放置" % rejected if rejected > 0 else "，可自由调整"))

func change_map(index: int) -> void:
 map_select.select(index)
 var old: String = view.map_id
 if editor.busy: editor.cancel()
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

func refresh_path() -> void:
 if not is_instance_valid(view) or not is_instance_valid(editor): return
 editor.map_id=view.map_id
 editor.plan_editor.map_id=view.map_id
 var program: Dictionary = editor.plan_editor.program
 view.path_points=[]
 view.path_obstacle=""
 if int(program.get("version",1))!=2:
  view.path_step=""
  return
 var steps: Array = program["plan"]["steps"]
 if not steps.any(func(s: Dictionary) -> bool: return s["id"]==view.path_step):
  view.path_step=steps[clampi(editor.plan_editor.selected,0,steps.size()-1)]["id"]
 for step: Dictionary in steps:
  if step["id"]==view.path_step:
   view.path_points=step.get("path",[]).duplicate(true)
   view.path_obstacle=step.get("obstacle","")
 editor.update_buttons()

func attach_context() -> void:
 refresh_path()
 view.context.tactic_event.connect(func(_unit: BaseGeoUnit, text: String) -> void: view.context.event_added.emit(text))
 events.clear()
 if is_instance_valid(event_log): ReadoutText.update(event_log,"尚无事件。开始验证后会记录真实技能启动、阵亡与占点。")
 view.context.event_added.connect(func(text: String) -> void:
  events.append(text)
  if events.size() > 80: events.pop_front()
  ReadoutText.update(event_log,"\n".join(events)))
 refresh()

func show_message(text: String) -> void:
 feedback.text = text
 feedback.tooltip_text = text
 # Detailed battlefield errors share the protected, scrollable feedback area.
 if is_instance_valid(editor.feedback): editor.feedback.text = text

func refresh() -> void:
 if not is_instance_valid(summary) or not is_instance_valid(view.context): return
 var context: LaboratoryArena = view.context
 var editing: bool = context.state == LaboratoryArena.State.ARRANGING
 for control: Control in editing_controls:
  if control is BaseButton: (control as BaseButton).disabled = not editing
  elif control is SpinBox: (control as SpinBox).editable = editing
  control.tooltip_text = "先在验证菜单中重置布阵，再修改阵容" if not editing else ""
 placement_panel.status.text = "修改选中单位，或设置下次放置的属性。" if editing else "验证期间不可修改阵容。请先在验证菜单中重置布阵。"
 map_caption.text = MapCatalog.TITLES[MapCatalog.IDS.find(view.map_id)]+" · "+["布阵","运行","暂停","结束"][context.state]
 map_caption.tooltip_text = map_caption.text
 for index: int in range(MapCatalog.IDS.size()):
  map_menu.get_popup().set_item_disabled(index,not editing)
  map_menu.get_popup().set_item_tooltip(index,"先重置布阵，再切换地图" if not editing else "")
  map_menu.get_popup().set_item_as_radio_checkable(index,true)
  map_menu.get_popup().set_item_checked(index,MapCatalog.IDS[index]==view.map_id)
 placement_menu.get_popup().set_item_disabled(1,not editing)
 placement_menu.get_popup().set_item_tooltip(1,"先重置布阵，再清空阵容" if not editing else "")
 for index: int in range(3):
  edit_menu.get_popup().set_item_disabled(index,not editing or editor.busy)
  edit_menu.get_popup().set_item_tooltip(index,"生成中请先取消" if editor.busy else "先重置布阵，再编辑" if not editing else "")
  edit_menu.get_popup().set_item_as_radio_checkable(index,true)
  edit_menu.get_popup().set_item_checked(index,index==view.edit_mode)
 edit_menu.text = ["编辑：布阵","编辑：路径","编辑：掩体"][view.edit_mode]
 var start_error: String=context.validate_layout()
 if start_error.is_empty(): start_error=TacticPlan.profile_error(context.profile_for(0),view.map_id)
 start_button.disabled = not editing or not start_error.is_empty()
 start_button.tooltip_text = "请先重置布阵" if not editing else start_error
 pause_button.disabled = context.state not in [LaboratoryArena.State.RUNNING,LaboratoryArena.State.PAUSED]
 pause_button.tooltip_text = "开始验证后可暂停" if pause_button.disabled else ""
 pause_button.text = "继续" if context.state == LaboratoryArena.State.PAUSED else "暂停"
 summary.text = "%s\n%.1f / 120s，%s，种子 %d\n" % [context.result_text,context.elapsed,"默认对照" if context.comparison else "实验规则",view.seed_value]
 for team: int in range(2):
  var data: Dictionary = context.totals[team]
  summary.text += "%s 存活 %d，伤害 %.0f，治疗 %.0f，主技能 %d，扫描 %d，本地 Flux +%d\n" % ["蓝方" if team == 0 else "红方",context.units_for(team).size(),data["damage"],data["healing"],data["skills"],data["scans"],context.terrain.local_flux[team]]
 var unit: BaseGeoUnit = view.selected_unit
 var reading: String = "点击战场单位查看当前命中的规则、有效动作与阻塞原因。"
 if is_instance_valid(unit) and not unit.dead:
  reading = "%s %s\n命中：%s\n受阻：%s\n有效动作：\n%s\n事实：\n%s" % ["蓝方" if unit.team==0 else "红方",UnitCatalog.DATA[unit.unit_type]["zh"],unit.matched_rule,unit.action_blocked if not unit.action_blocked.is_empty() else "无",JSON.stringify(unit.rule,"  "),JSON.stringify(unit.last_facts,"  ")]

 if is_instance_valid(unit) and unit.execution!=null:
  reading = "编排执行：\n"+JSON.stringify(unit.execution.readout(),"  ")+"\n技能状态："+("施放中" if unit.skill_active else "空闲")+"\n"+reading
 ReadoutText.update(rule_reading,reading)

func _process(delta: float) -> void:
 refresh_left -= delta
 if refresh_left <= 0:
  refresh_left = 0.2
  refresh()

func reflow() -> void:
 if not is_instance_valid(floating): return
 arranging_layout = true
 unit_row.visible = size.x>=1600 and float(GameSettings.values["font_scale"])<=1.3
 unit_picker.visible = not unit_row.visible
 columns.split_offset = roundi((columns.size.x-12)*(left_ratio-0.5))
 arranging_layout = false
 editor._resize_info_area.call_deferred()
 floating.fit.call_deferred()

func settings_updated() -> void:
 CommanderTheme.refresh(ui)
 reflow.call_deferred()

func open_llm_settings() -> void:
 open_settings("LLM")

func open_settings(category: String = "显示") -> void:
 if dialog.opened: return
 for child: Node in get_children():
  if child is SettingsPanel: return
 view.cancel_interaction()
 placement_panel.hide()
 var panel: SettingsPanel = SettingsPanel.new()
 panel.category=category
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
