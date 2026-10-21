extends Node

signal completed(request_owner: int, purpose: String, result: Dictionary)
signal configuration_changed
signal persistence_changed

var base_url: String = "https://api.openai.com/v1"
var api_key: String = ""
var model: String = ""
var generation: int = 0
var requests: Dictionary = {}
var status: String = "尚未测试连接"
var dirty: bool = false
var config_path: String = "user://llm_connection.cfg"
var request_timeout: float = 30.0

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 if DisplayServer.get_name() == "headless" or "--geo-test" in OS.get_cmdline_user_args(): config_path = "user://test_llm_connection.cfg"
 var config: ConfigFile = ConfigFile.new()
 if config.load(config_path) == OK and config.get_value("connection","version",0) == 1:
  var url: String = str(config.get_value("connection","base_url",base_url))
  var normalized: Dictionary = normalize_url(url)
  if normalized["ok"]: base_url = normalized["url"]
  model = str(config.get_value("connection","model","" )).left(200)

func normalize_url(value: String) -> Dictionary:
 var url: String = value.strip_edges().trim_suffix("/")
 if not (url.begins_with("https://") or url.begins_with("http://")): return {"ok":false,"message":"地址须以 https:// 或 http:// 开头"}
 if "?" in url or "#" in url or "@" in url or "\n" in url or "\r" in url or " " in url: return {"ok":false,"message":"地址不可包含凭据、查询参数、空格或片段"}
 if url.ends_with("/chat/completions"): url = url.trim_suffix("/chat/completions")
 if url.ends_with("/models"): url = url.trim_suffix("/models")
 if url.get_slice("://",1).is_empty(): return {"ok":false,"message":"请填写服务主机地址"}
 return {"ok":true,"url":url}

func configure(url: String, key: String, selected_model: String) -> Dictionary:
 var normalized: Dictionary = normalize_url(url)
 if not normalized["ok"]:
  cancel_all()
  generation += 1
  status = "连接地址无效，之前测试已失效"
  configuration_changed.emit()
  return normalized
 if "\n" in key or "\r" in key: return {"ok":false,"message":"Key 不可包含换行"}
 var changed: bool = base_url != normalized["url"] or api_key != key or model != selected_model.strip_edges()
 if changed:
  cancel_all()
  generation += 1
  base_url = normalized["url"]
  api_key = key
  model = selected_model.strip_edges().left(200)
  status = "连接配置已改变，请重新测试"
  save_connection()
  configuration_changed.emit()
 return {"ok":true,"message":status}

func save_connection() -> bool:
 var recovering: bool = dirty
 var config: ConfigFile = ConfigFile.new()
 config.set_value("connection","version",1)
 config.set_value("connection","base_url",base_url)
 config.set_value("connection","model",model)
 var error: Error = config.save(config_path)
 dirty = error != OK
 if dirty: status = "连接配置本次运行已生效，未保存。请重试保存连接配置。"
 elif recovering: status = "连接配置已保存，请重新测试"
 persistence_changed.emit()
 return not dirty

func cancel_owner(request_owner: int) -> void:
 if not requests.has(request_owner): return
 var request: HTTPRequest = requests[request_owner]["node"]
 requests.erase(request_owner)
 request.cancel_request()
 request.queue_free()

func cancel_all() -> void:
 for request_owner: int in requests.keys(): cancel_owner(request_owner)

func provider_profile() -> String:
 # Exact endpoint/model capability, verified against SiliconFlow docs and the
 # real service. Never send provider-only parameters to an arbitrary endpoint.
 if base_url == "https://api.siliconflow.cn/v1" and model == "deepseek-ai/DeepSeek-V4.1-Flash": return "siliconflow_json"
 return "compatible"

func request_payload(purpose: String, prompt: String = "", kind: String = "triangle") -> Dictionary:
 var messages: Array = [{"role":"user","content":"Reply with OK."}]
 if purpose == "generate": messages = [{"role":"system","content":UnitTacticProgram.system_prompt(kind)},{"role":"user","content":prompt}]
 var payload: Dictionary = {"model":model,"messages":messages,"stream":false}
 if provider_profile() == "siliconflow_json":
  payload["enable_thinking"] = false
  if purpose == "generate": payload["response_format"] = {"type":"json_object"}
 return payload

func start(request_owner: int, purpose: String, prompt: String = "", kind: String = "triangle") -> Dictionary:
 cancel_owner(request_owner)
 if purpose not in ["models","test","generate"]: return {"ok":false,"message":"未知请求类型"}
 if purpose != "models" and model.is_empty(): return {"ok":false,"message":"请选择或手填模型 ID"}
 if purpose == "generate" and (prompt.strip_edges().is_empty() or prompt.length() > UnitTacticProgram.MAX_PROMPT): return {"ok":false,"message":"提示词需为 1 至 4096 字符"}
 if purpose == "generate" and kind not in UnitCatalog.TYPES: return {"ok":false,"message":"无效兵种"}
 var request: HTTPRequest = HTTPRequest.new()
 # HTTPRequest remains asynchronous in its default nonblocking mode. Threaded
 # mode joins a blocking socket worker during cancellation and can stall the UI.
 request.use_threads = false
 request.timeout = request_timeout
 request.body_size_limit = 1024*1024
 request.max_redirects = 0
 add_child(request)
 var stamp: int = generation
 requests[request_owner] = {"node":request,"generation":stamp,"purpose":purpose,"started_ms":Time.get_ticks_msec(),"profile":provider_profile()}
 request.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
  finish(request_owner,request,stamp,purpose,kind,result,response_code,body))
 var headers: PackedStringArray = ["Content-Type: application/json"]
 if not api_key.is_empty(): headers.append("Authorization: Bearer "+api_key)
 var path: String = "/models" if purpose == "models" else "/chat/completions"
 var payload: String = ""
 if purpose != "models":
  payload = JSON.stringify(request_payload(purpose,prompt,kind))
 var error: Error = request.request(base_url+path,headers,HTTPClient.METHOD_GET if purpose == "models" else HTTPClient.METHOD_POST,payload)
 if error != OK:
  cancel_owner(request_owner)
  return {"ok":false,"message":"请求未发起："+error_string(error)}
 return {"ok":true,"message":"请求进行中，可取消"+("。SiliconFlow 非思考 JSON 模式" if provider_profile() == "siliconflow_json" and purpose == "generate" else "")}

func finish(request_owner: int, request: HTTPRequest, stamp: int, purpose: String, kind: String, result: int, code: int, body: PackedByteArray) -> void:
 if not requests.has(request_owner) or requests[request_owner]["node"] != request or stamp != generation: return
 var elapsed_ms: int = Time.get_ticks_msec()-int(requests[request_owner]["started_ms"])
 var profile: String = requests[request_owner]["profile"]
 requests.erase(request_owner)
 request.queue_free()
 var response: Dictionary = decode(purpose,kind,result,code,body)
 response["elapsed_ms"] = elapsed_ms
 response["request_profile"] = profile
 if purpose == "test": status = response["message"]
 completed.emit(request_owner,purpose,response)

func decode(purpose: String, kind: String, result: int, code: int, body: PackedByteArray) -> Dictionary:
 if result == HTTPRequest.RESULT_TIMEOUT: return {"ok":false,"category":"timeout","message":"请求超时，未收到完整响应。可显式重试，上一份有效配置保留"}
 if result != HTTPRequest.RESULT_SUCCESS: return {"ok":false,"category":"network","message":"网络、TLS、超时或响应大小检查失败（%d），可显式重试" % result}
 if code in [401,403]: return {"ok":false,"category":"authentication","message":"鉴权失败，请检查 API Key 与权限"}
 if code == 404: return {"ok":false,"category":"model","message":"模型或接口路径不可用，请检查模型 ID 和 Base URL"}
 if code < 200 or code >= 300: return {"ok":false,"category":"http","message":"服务返回 HTTP %d；未自动重试或跟随重定向" % code}
 var parser: JSON = JSON.new()
 if parser.parse(body.get_string_from_utf8()) != OK or not parser.data is Dictionary: return {"ok":false,"category":"format","message":"响应格式错误：需要 JSON 对象"}
 var data: Dictionary = parser.data
 if purpose == "models":
  if not data.get("data") is Array: return {"ok":false,"category":"format","message":"模型列表格式错误，仍可手填模型 ID 并测试生成"}
  var models: Array[String] = []
  for entry: Variant in data["data"]:
   if entry is Dictionary and entry.get("id") is String and entry["id"].length() <= 200: models.append(entry["id"])
  return {"ok":true,"models":models,"message":"已获取 %d 个模型，也可手填 ID" % models.size()}
 var choices: Variant = data.get("choices")
 if not choices is Array or choices.is_empty() or not choices[0] is Dictionary or not choices[0].get("message") is Dictionary or not choices[0]["message"].get("content") is String or choices[0]["message"]["content"].strip_edges().is_empty():
  return {"ok":false,"category":"format","message":"响应缺少 choices[0].message.content 文本"}
 if purpose == "test": return {"ok":true,"category":"success","message":"连接通过：鉴权、模型、网络、响应格式均正常"}
 var checked: Dictionary = UnitTacticProgram.parse(choices[0]["message"]["content"],kind)
 checked["finish_reason"] = str(choices[0].get("finish_reason","unknown"))
 checked["category"] = "success" if checked["ok"] else "validation"
 checked["source_model"] = model
 return checked
