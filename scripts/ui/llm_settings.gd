class_name LLMSettings
extends VBoxContainer

var url: LineEdit
var key: LineEdit
var model_id: LineEdit
var models: OptionButton
var feedback: Label
var fetch_button: Button
var test_button: Button
var cancel_button: Button
var busy: bool = false
var save_feedback: Label
var save_retry: Button

func _ready() -> void:
 size_flags_horizontal = Control.SIZE_EXPAND_FILL
 add_child(label("LLM 连接",24))
 var note: Label = label("使用 OpenAI 兼容接口。Key 仅保留本次运行，不写入磁盘；提示词仅在点击 AI 生成时发送给此地址。",16)
 note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 add_child(note)
 url = field("Base URL",LLMService.base_url)
 key = field("API Key（仅本次运行）",LLMService.api_key)
 key.secret = true
 key.placeholder_text = "可留空用于本地无鉴权服务"
 model_id = field("模型 ID（可手填）",LLMService.model)
 models = OptionButton.new()
 models.custom_minimum_size.y = 44
 models.add_item("尚未获取模型，可直接手填")
 models.item_selected.connect(func(index: int) -> void:
  if index == 0: return
  model_id.text = models.get_item_text(index)
  config_changed())
 add_child(models)
 var actions: HFlowContainer = HFlowContainer.new()
 add_child(actions)
 fetch_button = button("获取模型",func() -> void: send("models"))
 actions.add_child(fetch_button)
 test_button = button("测试连接",func() -> void: send("test"))
 actions.add_child(test_button)
 cancel_button = button("取消请求",cancel)
 actions.add_child(cancel_button)
 save_retry = button("重试保存连接配置",func() -> void:
  LLMService.save_connection()
  feedback.text = LLMService.status
  update_persistence())
 actions.add_child(save_retry)
 save_feedback = label("连接配置本次运行已生效，未保存。点击“重试保存连接配置”。Key 仅存内存。",16)
 save_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 add_child(save_feedback)
 feedback = label(LLMService.status,16)
 feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 add_child(feedback)
 LLMService.completed.connect(on_result)
 LLMService.persistence_changed.connect(update_persistence)
 update_busy(false)
 update_persistence()

func label(value: String, font_size: int = 18) -> Label:
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

func field(title: String, value: String) -> LineEdit:
 add_child(label(title))
 var input: LineEdit = LineEdit.new()
 input.text = value
 input.custom_minimum_size.y = 44
 input.text_changed.connect(func(_text: String) -> void: config_changed())
 add_child(input)
 return input

func config_changed() -> void:
 if not is_instance_valid(model_id): return
 var result: Dictionary = LLMService.configure(url.text,key.text,model_id.text)
 if is_instance_valid(feedback): feedback.text = result["message"]
 update_busy(false)

func send(purpose: String) -> void:
 var configured: Dictionary = LLMService.configure(url.text,key.text,model_id.text)
 if not configured["ok"]:
  feedback.text = configured["message"]
  return
 url.text = LLMService.base_url
 var result: Dictionary = LLMService.start(get_instance_id(),purpose)
 feedback.text = result["message"]
 update_busy(result["ok"])

func update_busy(value: bool) -> void:
 busy = value
 if not is_instance_valid(fetch_button): return
 fetch_button.disabled = busy
 test_button.disabled = busy
 cancel_button.disabled = not busy

func cancel() -> void:
 LLMService.cancel_owner(get_instance_id())
 feedback.text = "已取消，可再次点击获取或测试"
 update_busy(false)

func on_result(request_owner: int, purpose: String, result: Dictionary) -> void:
 if request_owner != get_instance_id(): return
 update_busy(false)
 feedback.text = result["message"]
 if purpose == "models" and result["ok"]:
  models.clear()
  models.add_item("选择模型，或手填 ID")
  for id: String in result["models"]: models.add_item(id)
  var selected: int = result["models"].find(model_id.text)
  if selected >= 0: models.select(selected+1)

func update_persistence() -> void:
 if is_instance_valid(save_feedback): save_feedback.visible = LLMService.dirty
 if is_instance_valid(save_retry): save_retry.visible = LLMService.dirty

func _exit_tree() -> void:
 LLMService.cancel_owner(get_instance_id())
