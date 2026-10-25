class_name LabPromptEditor
extends VBoxContainer

signal rerun_requested
signal opening_applied
signal draft_changed
signal settings_requested
var kind: String = "triangle"
var prompt: TextEdit
var preview: TextEdit
var feedback: Label
var source: Label
var global_prompt: TextEdit
var global_count: Label
var global_status: Label
var info_area: PanelContainer
var intent_label: Label
var generate: Button
var cancel_button: Button
var apply_button: Button
var opening_button: Button
var busy: bool = false
var candidate_model: String = ""

var plan_editor: TacticPlanEditor
var syncing: bool = false
var map_id: String = "balanced"
var tabs: TabContainer
var split: VSplitContainer
var feedback_panel: LabFeedbackPanel
var page_select: OptionButton
var page_bar: TabBar
var more: MenuButton
var dialog: LabDialog
var validate_button: Button
var action_rows: VBoxContainer
static var feedback_ratio: float = 0.4
var fitting: bool = false

func _ready() -> void:
 size_flags_horizontal = Control.SIZE_EXPAND_FILL
 size_flags_vertical = Control.SIZE_EXPAND_FILL
 add_theme_constant_override("separation",8)
 var heading: HBoxContainer = HBoxContainer.new()
 add_child(heading)
 page_select = OptionButton.new()
 page_select.fit_to_longest_item = false
 for title: String in ["兵种提示词","JSON","步骤","整体提示词"]: page_select.add_item(title)
 page_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 page_select.custom_minimum_size.y = 44
 heading.add_child(page_select)
 page_bar = TabBar.new()
 page_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 for title: String in ["兵种提示词","JSON","步骤","整体提示词"]: page_bar.add_tab(title)
 heading.add_child(page_bar)
 page_bar.tab_changed.connect(func(index: int) -> void: tabs.current_tab=index)
 page_select.item_selected.connect(func(index: int) -> void: tabs.current_tab=index)
 more = MenuButton.new()
 more.text = "更多"
 more.flat = false
 more.focus_mode = Control.FOCUS_ALL
 more.custom_minimum_size.y = 44
 heading.add_child(more)
 for title: String in ["保存草稿","LLM 设置","本兵种编排示例","重试保存实验","恢复当前兵种默认"]: more.get_popup().add_item(title)
 more.get_popup().id_pressed.connect(more_action)
 split = VSplitContainer.new()
 split.size_flags_vertical = Control.SIZE_EXPAND_FILL
 split.add_theme_constant_override("separation",12)
 add_child(split)
 tabs = TabContainer.new()
 tabs.tabs_visible = false
 tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
 split.add_child(tabs)
 tabs.tab_changed.connect(func(index: int) -> void:
  page_select.select(index)
  page_bar.current_tab=index
  _resize_info_area.call_deferred())
 var prompt_page: VBoxContainer = VBoxContainer.new()
 prompt_page.name = "兵种提示词"
 tabs.add_child(prompt_page)
 var explanation: Label = label("当前兵种的行动要求，最多 4096 字符。",14)
 explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 prompt_page.add_child(explanation)
 prompt = TextEdit.new()
 prompt.size_flags_vertical = Control.SIZE_EXPAND_FILL
 prompt.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
 prompt.placeholder_text = "例如：生命低于30%时撤退，否则优先攻击敌方菱形。"
 prompt_page.add_child(prompt)
 prompt.text_changed.connect(func() -> void:
  feedback.text = "草稿 %d / 4096 字符，切换兵种时保存。" % prompt.text.length())
 preview = TextEdit.new()
 preview.name = "JSON"
 preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
 preview.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
 CommanderTheme.font(preview,16)
 tabs.add_child(preview)
 plan_editor = TacticPlanEditor.new()
 plan_editor.name = "步骤"
 tabs.add_child(plan_editor)
 var shared_scroll: ScrollContainer = ScrollContainer.new()
 shared_scroll.name = "整体提示词"
 shared_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 shared_scroll.follow_focus = true
 tabs.add_child(shared_scroll)
 var shared: VBoxContainer = VBoxContainer.new()
 shared.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 shared.size_flags_vertical = Control.SIZE_EXPAND_FILL
 shared_scroll.add_child(shared)
 var shared_help: Label = label("共享约束用于每个兵种的生成，不会自动覆盖已有 JSON。",14)
 shared_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 shared.add_child(shared_help)
 global_prompt = TextEdit.new()
 global_prompt.custom_minimum_size.y = 80
 global_prompt.size_flags_vertical = Control.SIZE_EXPAND_FILL
 global_prompt.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
 global_prompt.placeholder_text = "例如：所有单位优先保持阵型，避免穿越晶簇。"
 global_prompt.text = LaboratoryStore.global_prompt
 global_prompt.text_changed.connect(_global_prompt_changed)
 shared.add_child(global_prompt)
 var shared_actions: HBoxContainer = HBoxContainer.new()
 shared.add_child(shared_actions)
 var global_more: MenuButton = MenuButton.new()
 global_more.text = "整体提示词操作"
 global_more.flat = false
 global_more.focus_mode = Control.FOCUS_ALL
 global_more.custom_minimum_size.y = 44
 for title: String in ["保存整体提示词","清空","恢复上次内容"]: global_more.get_popup().add_item(title)
 global_more.get_popup().id_pressed.connect(func(index: int) -> void:
  if busy: return
  match index:
   0: save_global_prompt()
   1: dialog.present("清空整体提示词？","仅清空共享提示词，已有兵种 JSON 保留。",clear_global_prompt)
   2: restore_global_prompt()
 )
 shared_actions.add_child(global_more)
 global_count = label("0 / 4096",14)
 shared_actions.add_child(global_count)
 global_status = label("",14)
 global_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 shared.add_child(global_status)
 feedback_panel = LabFeedbackPanel.new()
 feedback_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
 info_area = feedback_panel
 split.add_child(feedback_panel)
 feedback = feedback_panel.feedback
 source = feedback_panel.source
 intent_label = feedback_panel.intent
 if not is_instance_valid(dialog):
  dialog = LabDialog.new()
  add_child(dialog)
 feedback_panel.expand_requested.connect(func() -> void: dialog.present("反馈与验证",feedback_panel.full_text()))
 action_rows = VBoxContainer.new()
 action_rows.add_theme_constant_override("separation",6)
 add_child(action_rows)
 var first: HBoxContainer = HBoxContainer.new()
 action_rows.add_child(first)
 var generation_slot: Control = Control.new()
 generation_slot.custom_minimum_size.y = 44
 generation_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 first.add_child(generation_slot)
 generate = button("AI 生成",request_generate)
 generate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 generation_slot.add_child(generate)
 cancel_button = button("取消生成",cancel)
 cancel_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 generation_slot.add_child(cancel_button)
 validate_button = button("校验 JSON",validate_preview)
 validate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 first.add_child(validate_button)
 var second: HBoxContainer = HBoxContainer.new()
 action_rows.add_child(second)
 apply_button = button("应用并重跑",apply_and_run)
 opening_button = button("应用开局",apply_opening)
 for item: Button in [apply_button,opening_button]:
  item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  second.add_child(item)
 plan_editor.edited.connect(func(value: Dictionary) -> void:
  syncing = true
  preview.text = JSON.stringify(value,"  ")
  LaboratoryStore.records[kind]["draft_json"] = preview.text
  syncing = false
  update_buttons())
 preview.text_changed.connect(func() -> void:
  if syncing: return
  LaboratoryStore.records[kind]["draft_json"] = preview.text
  var checked: Dictionary = UnitTacticProgram.parse(preview.text,kind)
  plan_editor.set_program(checked["program"] if checked["ok"] else {})
  update_buttons())
 preview.text_changed.connect(func() -> void: draft_changed.emit())
 split.dragged.connect(func(_offset: int) -> void:
  if not fitting: remember_split.call_deferred())
 resized.connect(_resize_info_area)
 split.resized.connect(_resize_info_area)
 LLMService.completed.connect(on_result)
 LLMService.configuration_changed.connect(func() -> void:
  if busy:
   busy = false
   update_buttons()
   feedback.text = "配置已改变，生成已取消。请显式重试。")
 _global_prompt_changed()
 select_kind(kind,false)
 _resize_info_area.call_deferred()

func more_action(index: int) -> void:
 match index:
  0: save_draft()
  1: open_settings()
  2:
   if busy: return
   plan_editor.change(TacticExamples.for_unit(kind))
   tabs.current_tab = 2
  3:
   LaboratoryStore.save()
   feedback.text = LaboratoryStore.status
  4:
   if busy: return
   dialog.present("恢复当前兵种默认？","清除该兵种的实验与运行内开局方案，其他兵种保留。取消可保留原文。",reset_kind)

func remember_split() -> void:
 if split.size.y>0:
  feedback_ratio = clampf(info_area.size.y/maxf(1,split.size.y-12),0.3,0.6)
 _resize_info_area()

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

func select_kind(next: String, save_previous: bool = true) -> void:
 if save_previous: save_draft()
 LLMService.cancel_owner(get_instance_id())
 busy = false
 kind = next
 LaboratoryStore.selected_kind = kind
 prompt.text = LaboratoryStore.records[kind]["prompt"]
 var program: Dictionary = LaboratoryStore.records[kind]["program"]
 syncing = true
 var draft: String = str(LaboratoryStore.records[kind].get("draft_json",""))
 preview.text = draft if not draft.is_empty() else "" if program.is_empty() else JSON.stringify(program,"  ")
 syncing = false
 plan_editor.kind = kind
 plan_editor.history.clear()
 plan_editor.future.clear()
 var checked: Dictionary = UnitTacticProgram.parse(preview.text,kind)
 plan_editor.set_program(checked["program"] if checked["ok"] else {})
 candidate_model = LaboratoryStore.records[kind]["source_model"]
 source.text = "来源模型："+(candidate_model if not candidate_model.is_empty() else "尚未生成")
 feedback.text = "尚未生成。请配置LLM后生成，或使用本兵种示例。" if program.is_empty() else "已恢复JSON草稿。校验后再应用。"
 if not str(LaboratoryStore.records[kind].get("repair_error","")).is_empty(): feedback.text="待修复，原方案已保留："+LaboratoryStore.records[kind]["repair_error"]
 if not LaboratoryStore.status.is_empty(): feedback.text += "\n"+LaboratoryStore.status
 update_buttons()
 draft_changed.emit()

func _resize_info_area() -> void:
 if not is_instance_valid(split) or split.size.y<=0: return
 fitting = true
 var available: float = split.size.y-12
 # Both children expand equally. An absolute offset avoids accumulating deferred
 # layout deltas while a window or font change triggers several container sorts.
 split.split_offset = roundi(available*(0.5-feedback_ratio))
 fitting = false
 # Use the compact page picker only when the actual tab labels cannot fit.
 var required: float = 0.0
 for index: int in range(page_bar.tab_count):
  required += page_bar.get_theme_font("font").get_string_size(page_bar.get_tab_title(index),HORIZONTAL_ALIGNMENT_LEFT,-1,page_bar.get_theme_font_size("font_size")).x+32
 page_bar.visible = required<size.x-more.get_combined_minimum_size().x-24
 page_select.visible = not page_bar.visible
 if is_instance_valid(generate):
  generate.get_parent().custom_minimum_size.y = maxf(generate.get_combined_minimum_size().y,cancel_button.get_combined_minimum_size().y)

func _global_prompt_changed() -> void:
 if not is_instance_valid(global_prompt): return
 if global_prompt.text.length() > LaboratoryStore.MAX_GLOBAL_PROMPT:
  var caret: int = global_prompt.caret_column
  global_prompt.text = global_prompt.text.left(LaboratoryStore.MAX_GLOBAL_PROMPT)
  global_prompt.caret_column = mini(caret,global_prompt.text.length())
 global_count.text = "%d / %d" % [global_prompt.text.length(),LaboratoryStore.MAX_GLOBAL_PROMPT]
 global_status.text = "未保存的整体提示词草稿" if global_prompt.text != LaboratoryStore.global_prompt else "整体提示词已保存"

func save_global_prompt() -> void:
 if not is_instance_valid(global_prompt): return
 var ok: bool = LaboratoryStore.set_global_prompt(global_prompt.text)
 global_status.text = LaboratoryStore.status if not ok else "整体提示词已保存，本次生成将使用共享约束"

func clear_global_prompt() -> void:
 if busy: return
 global_prompt.text = ""
 save_global_prompt()

func restore_global_prompt() -> void:
 if busy: return
 LaboratoryStore.restore_previous_global_prompt()
 global_prompt.text = LaboratoryStore.global_prompt
 global_status.text = "已恢复上次整体提示词"

func save_draft() -> void:
 if not is_instance_valid(prompt): return
 if prompt.text.length() > 4096:
  feedback.text = "提示词超过 4096 字符，未保存。请缩短后重试。"
  return
 LaboratoryStore.records[kind]["draft_json"] = preview.text
 LaboratoryStore.set_prompt(kind,prompt.text)
 feedback.text = LaboratoryStore.status

func request_generate() -> void:
 if busy: return
 if prompt.text.length() > 4096 or prompt.text.strip_edges().is_empty():
  feedback.text = "提示词需为 1 至 4096 字符"
  return
 save_draft()
 var local_intent: Dictionary = TacticPlan.normalize_prompt(prompt.text)
 intent_label.text = "本地识别："+str(local_intent["summary"])
 if not local_intent["unsupported"].is_empty():
  feedback.text = "提示词包含无法表达的要求："+", ".join(local_intent["unsupported"])+"。模型仍需返回具体 error。"
 var result: Dictionary = LLMService.start(get_instance_id(),"generate",prompt.text,kind,map_id,LaboratoryStore.global_prompt)
 if result["ok"]: feedback.text += ("\n" if not feedback.text.is_empty() else "")+String(result["message"])
 else: feedback.text = String(result["message"])+"。请打开“LLM 设置”检查连接后重试。"
 busy = result["ok"]
 update_buttons()

func cancel() -> void:
 LLMService.cancel_owner(get_instance_id())
 busy = false
 feedback.text = "已取消生成，上一份有效 JSON 保留；可点击 AI 生成重试。"
 update_buttons()

func on_result(request_owner: int, purpose: String, result: Dictionary) -> void:
 if request_owner != get_instance_id() or purpose != "generate": return
 if result["ok"]:
  var map_error: String = TacticPlan.map_validation(result["program"],map_id)
  if not map_error.is_empty(): result = {"ok":false,"message":map_error}
 busy = false
 update_buttons()
 feedback.text = result["message"]
 if result.has("intent_summary") and result["intent_summary"] is Dictionary:
  intent_label.text = "本地识别："+str(result["intent_summary"].get("summary",""))
 if not result["ok"]:
  feedback.text += "。上一份有效 JSON 与验证场保持。请调整提示词或检查“LLM 设置”，再点击“AI 生成 JSON”。"
  return
 candidate_model = result["source_model"]
 preview.text = JSON.stringify(result["program"],"  ")
 tabs.current_tab = 1
 LaboratoryStore.accept_program(kind,result["program"],candidate_model)
 plan_editor.set_program(result["program"])
 update_buttons()
 source.text = "来源模型："+candidate_model
 feedback.text = "AI JSON 校验通过。请检查后应用并重跑。\n"+LaboratoryStore.status

func validate_preview() -> Dictionary:
 var result: Dictionary = UnitTacticProgram.parse(preview.text,kind)
 if result["ok"]:
  var map_error: String = TacticPlan.map_validation(result["program"],map_id)
  if not map_error.is_empty(): result = {"ok":false,"message":map_error}
 feedback.text = result["message"] if result["ok"] else String(result["message"])+"。上一份有效 JSON 与验证场保持。在 JSON 页修正后点击“校验 JSON”，或重新生成。"
 return result

func apply_and_run() -> void:
 var result: Dictionary = validate_preview()
 if not result["ok"]: return
 LaboratoryStore.accept_program(kind,result["program"],candidate_model)
 LaboratoryStore.records[kind].erase("applied_repair_original")
 LaboratoryStore.applied_programs[kind] = result["program"].duplicate(true)
 LaboratoryStore.save()
 feedback.text = "当前兵种已应用到验证场。"+LaboratoryStore.status
 rerun_requested.emit()

func apply_opening() -> void:
 var result: Dictionary = validate_preview()
 if not result["ok"]: return
 result = TacticalBrain.save_opening_program(result["program"])
 feedback.text = result["message"]
 opening_applied.emit()

func update_buttons() -> void:
 generate.disabled = busy
 cancel_button.disabled = not busy
 cancel_button.visible = busy
 generate.visible = not busy
 validate_button.disabled = busy
 global_prompt.editable = not busy
 more.get_popup().set_item_disabled(2,busy)
 more.get_popup().set_item_disabled(4,busy)
 var checked: Dictionary = UnitTacticProgram.parse(preview.text,kind)
 var valid: bool = checked["ok"]
 if valid: valid = TacticPlan.map_validation(checked["program"],map_id).is_empty()
 apply_button.disabled = busy or not valid
 opening_button.disabled = busy or not valid
 apply_button.tooltip_text = "校验通过后应用，错误保留草稿" if not valid else "只应用当前兵种"
 plan_editor.mouse_filter = Control.MOUSE_FILTER_IGNORE if busy else Control.MOUSE_FILTER_PASS
 for control: Node in plan_editor.find_children("*","BaseButton",true,false): (control as BaseButton).disabled = busy
 for control: Node in plan_editor.find_children("*","LineEdit",true,false): (control as LineEdit).editable = not busy
 for control: Node in plan_editor.find_children("*","TextEdit",true,false): (control as TextEdit).editable = not busy
 prompt.editable = not busy
 preview.editable = not busy

func open_settings() -> void:
 settings_requested.emit()

func _exit_tree() -> void:
 LLMService.cancel_owner(get_instance_id())
 if is_instance_valid(prompt) and prompt.text.length() <= 4096:
  LaboratoryStore.records[kind]["draft_json"] = preview.text
  LaboratoryStore.set_prompt(kind,prompt.text)

func reset_kind() -> void:
 if busy: return
 LaboratoryStore.records[kind]["program"] = {}
 LaboratoryStore.records[kind]["draft_json"] = ""
 LaboratoryStore.applied_programs.erase(kind)
 LaboratoryStore.records[kind].erase("applied_repair_original")
 LaboratoryStore.records[kind].erase("repair_original")
 LaboratoryStore.records[kind]["repair_error"]=""
 var defaults: Dictionary = TacticalBrain.get_default_profile()["unit_rules"][kind].duplicate(true)
 TacticalBrain.opening_profile["unit_rules"][kind] = defaults
 preview.text = ""
 plan_editor.set_program({})
 LaboratoryStore.save()
 feedback.text = "已清除当前兵种实验与开局方案，其他兵种保留。"+LaboratoryStore.status
