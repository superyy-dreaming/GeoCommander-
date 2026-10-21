class_name LabPromptEditor
extends VBoxContainer

signal rerun_requested
signal opening_applied
var kind: String = "triangle"
var prompt: TextEdit
var preview: TextEdit
var feedback: Label
var source: Label
var generate: Button
var cancel_button: Button
var apply_button: Button
var opening_button: Button
var busy: bool = false
var candidate_model: String = ""

var tabs: TabContainer

func _ready() -> void:
 size_flags_horizontal = Control.SIZE_EXPAND_FILL
 size_flags_vertical = Control.SIZE_EXPAND_FILL
 var heading: HBoxContainer = HBoxContainer.new()
 add_child(heading)
 var title: Label = label("提示词",22)
 title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 heading.add_child(title)
 cancel_button = button("取消生成",cancel)
 heading.add_child(cancel_button)
 tabs = TabContainer.new()
 tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
 tabs.custom_minimum_size.y = 180
 add_child(tabs)
 var prompt_page: VBoxContainer = VBoxContainer.new()
 prompt_page.name = "提示词"
 var prompt_scroll: ScrollContainer = ScrollContainer.new()
 prompt_scroll.name = "提示词"
 prompt_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 prompt_scroll.follow_focus = true
 tabs.add_child(prompt_scroll)
 prompt_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 prompt_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
 prompt_scroll.add_child(prompt_page)
 var explanation: Label = label("描述当前兵种在什么条件下如何行动。最多 4096 字符。",16)
 explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 prompt_page.add_child(explanation)
 prompt = TextEdit.new()
 prompt.size_flags_vertical = Control.SIZE_EXPAND_FILL
 prompt.custom_minimum_size.y = 80
 prompt.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
 prompt.placeholder_text = "例如：生命低于30%时主动撤退；否则优先攻击敌方菱形。"
 prompt_page.add_child(prompt)
 prompt.text_changed.connect(func() -> void:
  feedback.text = "草稿 %d / 4096 字符，切换兵种时保存。" % prompt.text.length())
 var buttons: HFlowContainer = HFlowContainer.new()
 prompt_page.add_child(buttons)
 buttons.add_child(button("保存草稿",save_draft))
 generate = button("AI 生成 JSON",request_generate)
 buttons.add_child(generate)
 buttons.add_child(button("LLM 设置",open_settings))
 var json_page: VBoxContainer = VBoxContainer.new()
 json_page.name = "JSON"
 var json_scroll: ScrollContainer = ScrollContainer.new()
 json_scroll.name = "JSON"
 json_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 json_scroll.follow_focus = true
 tabs.add_child(json_scroll)
 json_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 json_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
 json_scroll.add_child(json_page)
 source = label("",14)
 source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 json_page.add_child(source)
 preview = TextEdit.new()
 preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
 preview.custom_minimum_size.y = 80
 preview.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
 CommanderTheme.font(preview,14)
 json_page.add_child(preview)
 json_page.add_child(button("校验 JSON",validate_preview))
 var actions: VBoxContainer = VBoxContainer.new()
 add_child(actions)
 apply_button = button("应用当前兵种并重跑",apply_and_run)
 actions.add_child(apply_button)
 opening_button = button("应用当前兵种为开局",apply_opening)
 actions.add_child(opening_button)
 feedback = label("",14)
 feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 var feedback_scroll: ScrollContainer = ScrollContainer.new()
 feedback_scroll.custom_minimum_size.y = 72
 feedback_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 feedback_scroll.follow_focus = true
 feedback_scroll.focus_mode = Control.FOCUS_ALL
 feedback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 feedback_scroll.add_child(feedback)
 add_child(feedback_scroll)
 var retry: Button = button("重试保存实验",func() -> void:
  LaboratoryStore.save()
  feedback.text = LaboratoryStore.status)
 retry.visible = LaboratoryStore.dirty
 LaboratoryStore.persistence_changed.connect(func() -> void: retry.visible = LaboratoryStore.dirty)
 add_child(retry)
 LLMService.completed.connect(on_result)
 LLMService.configuration_changed.connect(func() -> void:
  if busy:
   busy = false
   update_buttons()
   feedback.text = "配置已改变，生成已取消。请显式重试。")
 select_kind(kind,false)

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
 preview.text = "" if program.is_empty() else JSON.stringify(program,"  ")
 candidate_model = LaboratoryStore.records[kind]["source_model"]
 source.text = "来源模型："+(candidate_model if not candidate_model.is_empty() else "尚未生成")
 feedback.text = "尚未生成。点击“LLM 设置”配置连接，再点击“AI 生成 JSON”。" if program.is_empty() else "已恢复有效 JSON。开局需点击“应用当前兵种为开局”。"
 if not LaboratoryStore.status.is_empty(): feedback.text += "\n"+LaboratoryStore.status
 update_buttons()

func save_draft() -> void:
 if not is_instance_valid(prompt): return
 if prompt.text.length() > 4096:
  feedback.text = "提示词超过 4096 字符，未保存。请缩短后重试。"
  return
 LaboratoryStore.set_prompt(kind,prompt.text)
 feedback.text = LaboratoryStore.status

func request_generate() -> void:
 if busy: return
 if prompt.text.length() > 4096 or prompt.text.strip_edges().is_empty():
  feedback.text = "提示词需为 1 至 4096 字符"
  return
 save_draft()
 var result: Dictionary = LLMService.start(get_instance_id(),"generate",prompt.text,kind)
 feedback.text = result["message"] if result["ok"] else String(result["message"])+"。请打开“LLM 设置”检查连接后重试。"
 busy = result["ok"]
 update_buttons()

func cancel() -> void:
 LLMService.cancel_owner(get_instance_id())
 busy = false
 feedback.text = "已取消生成，上一份有效 JSON 保留；可点击 AI 生成重试。"
 update_buttons()

func on_result(request_owner: int, purpose: String, result: Dictionary) -> void:
 if request_owner != get_instance_id() or purpose != "generate": return
 busy = false
 update_buttons()
 feedback.text = result["message"]
 if not result["ok"]:
  feedback.text += "。上一份有效 JSON 与验证场保持。请调整提示词或检查“LLM 设置”，再点击“AI 生成 JSON”。"
  return
 candidate_model = result["source_model"]
 preview.text = JSON.stringify(result["program"],"  ")
 tabs.current_tab = 1
 LaboratoryStore.accept_program(kind,result["program"],candidate_model)
 update_buttons()
 source.text = "来源模型："+candidate_model
 feedback.text = "AI JSON 校验通过。请检查后应用并重跑。\n"+LaboratoryStore.status

func validate_preview() -> Dictionary:
 var result: Dictionary = UnitTacticProgram.parse(preview.text,kind)
 feedback.text = result["message"] if result["ok"] else String(result["message"])+"。上一份有效 JSON 与验证场保持。在 JSON 页修正后点击“校验 JSON”，或重新生成。"
 return result

func apply_and_run() -> void:
 var result: Dictionary = validate_preview()
 if not result["ok"]: return
 LaboratoryStore.accept_program(kind,result["program"],candidate_model)
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
 apply_button.disabled = busy or preview.text.strip_edges().is_empty()
 opening_button.disabled = busy or preview.text.strip_edges().is_empty()
 prompt.editable = not busy
 preview.editable = not busy

func open_settings() -> void:
 var panel: SettingsPanel = SettingsPanel.new()
 add_child(panel)
 panel.category = "LLM"
 # Category is selected explicitly because add_child invokes _ready immediately.
 panel.select_category("LLM")
 panel.open_panel()

func _exit_tree() -> void:
 LLMService.cancel_owner(get_instance_id())
 if is_instance_valid(prompt) and prompt.text.length() <= 4096: LaboratoryStore.set_prompt(kind,prompt.text)
