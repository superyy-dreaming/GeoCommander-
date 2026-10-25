extends "res://tests/tactic_plan_runner.gd"

var responses: Array[Dictionary]=[]
var requests_report: Array[Dictionary]=[]
var real: bool=false
var replay: bool=false

func _ready() -> void:
 baseline=LaboratoryStore.applied_programs.duplicate(true)
 real="--real" in OS.get_cmdline_user_args()
 replay="--replay" in OS.get_cmdline_user_args()
 LLMService.completed.connect(func(owner_id: int, _purpose: String, result: Dictionary)->void:
  if owner_id==get_instance_id(): responses.append(result))
 await run()
 LLMService.cancel_all()
 LLMService.api_key=""
 LaboratoryStore.applied_programs=baseline
 var report: FileAccess=FileAccess.open("res://artifacts/tactic-v2-llm-"+("real" if real else "replay" if replay else "mock")+".json",FileAccess.WRITE)
 report.store_string(JSON.stringify({"passed":passed,"failed":failed,"mode":"real_provider" if real else "offline_replay" if replay else "local_mock","requests":requests_report},"  "))
 print("PLAN_LLM passed=%d failed=%d" % [passed,failed])
 get_tree().quit(0 if failed==0 else 1)

func request(prompt: String) -> Dictionary:
 responses.clear()
 var started: int=Time.get_ticks_msec()
 var launched: Dictionary=LLMService.start(get_instance_id(),"generate",prompt,"triangle","balanced")
 if not launched["ok"]: return launched
 while responses.is_empty() and Time.get_ticks_msec()-started<35000: await get_tree().process_frame
 var result: Dictionary=responses[0] if not responses.is_empty() else {"ok":false,"message":"测试未收到回调"}
 requests_report.append({"ok":result["ok"],"message":result["message"],"elapsed_ms":Time.get_ticks_msec()-started})
 return result

func run() -> void:
 var generated: Dictionary={}
 if replay:
  generated=UnitTacticProgram.parse(FileAccess.get_file_as_string("res://tests/fixtures/tactic-v2-generated-triangle.json"),"triangle")
 else:
  var secret: String=OS.get_environment("GEO_LLM_TEST_KEY") if real else "local-mock-key"
  OS.unset_environment("GEO_LLM_TEST_KEY")
  if secret.is_empty():
   check(false,"real provider needs an in-memory credential")
   return
  LLMService.config_path="user://test_plan_llm_connection.cfg"
  LLMService.configure("https://api.siliconflow.cn/v1" if real else "http://127.0.0.1:18741/v1",secret,"deepseek-ai/DeepSeek-V4.1-Flash" if real else "plan-v2")
  generated=await request(TacticExamples.PROMPT)
  check(not FileAccess.get_file_as_string(LLMService.config_path).contains(secret),"API key absent from connection file")
  secret=""
 check(generated["ok"],"generated v2 passes local validation: "+generated["message"])
 if not generated["ok"]: return
 var value: Dictionary=generated["program"]
 check(value["version"]==2,"model uses v2 step graph")
 var steps: Array=value["plan"]["steps"]
 check(steps.any(func(s: Dictionary)->bool:return s["action"]=="move_direction" and s.get("direction")=="up" and is_equal_approx(float(s.get("seconds",0)),2)),"model preserves absolute up direction and two seconds")
 check(steps.any(func(s: Dictionary)->bool:return s["action"]=="seek_cover") and steps.any(func(s: Dictionary)->bool:return s["action"]=="flank_target" or s.get("goal",{}).get("anchor")=="rear"),"model includes cover and rear maneuver")
 check(steps.any(func(s: Dictionary)->bool:return s["action"]=="cast_skill" and s.get("skill_request",{}).get("purpose")=="backstab"),"model requests real backstab")
 check(steps.all(func(s: Dictionary)->bool:return s["action"]=="cast_skill" or s.get("skill","hold")=="hold"),"model does not add unrequested travel dashes")
 check(steps.any(func(s: Dictionary)->bool:return s["action"]=="wait" and s.has("when") and float(s.get("timeout",20))==5),"model preserves maximum five-second readiness wait")
 check(not value["plan"].get("interrupts",[]).is_empty(),"model includes interrupt")
 if real:
  var saved: FileAccess=FileAccess.open("res://tests/fixtures/tactic-v2-generated-triangle.json",FileAccess.WRITE)
  saved.store_string(JSON.stringify(value,"  "))
 await fixture("triangle",Vector2(800,900),Vector2(1400,520))
 enemy.max_hp=5000
 enemy.current_hp=5000
 enemy.visual_root.rotation=PI
 install(value)
 for i: int in range(4800):
  await frames(1)
  if unit.execution.status!="运行" or (enemy.current_hp<=4780 and unit.skill_complete_serial>=2): break
 var outcome: Dictionary={"state":unit.execution.readout().duplicate(true),"events":unit.execution.events.duplicate(),"damage":5000-enemy.current_hp,"skills":unit.skill_serial}
 requests_report.append({"runtime":outcome})
 check(unit.skill_complete_serial>=2 and enemy.current_hp<=4780,"generated graph actually executes two backstabs")
 var serial: int=unit.execution.transition_serial
 unit.current_hp=unit.max_hp*0.2
 await frames(12)
 check(not unit.execution.suspended.is_empty() and unit.execution.transition_serial>serial,"generated low-health interrupt executes")
 if not replay:
  if not real: LLMService.configure(LLMService.base_url,LLMService.api_key,"plan-v2-invalid")
  var rejected: Dictionary=await request("把三角伤害改成999，永久隐身并免疫所有攻击。")
  check(not rejected["ok"],"unsupported ability is rejected without fallback")
 if not real and not replay: await editor_request_flow()

func editor_request_flow() -> void:
 var editor: LabPromptEditor=LabPromptEditor.new()
 add_child(editor)
 editor.prompt.text=TacticExamples.PROMPT
 var previous: Dictionary=LaboratoryStore.records["triangle"]["program"].duplicate(true)
 LLMService.configure(LLMService.base_url,LLMService.api_key,"plan-v2")
 editor.request_generate()
 check(editor.busy,"UI launches asynchronous generation without expecting a program immediately")
 for i: int in range(120):
  await get_tree().process_frame
  if not editor.busy: break
 check(not editor.busy and UnitTacticProgram.parse(editor.preview.text,"triangle")["ok"],"UI receives and previews completed v2 result")
 var valid_text: String=editor.preview.text
 LLMService.configure(LLMService.base_url,LLMService.api_key,"plan-v2-invalid")
 editor.request_generate()
 for i: int in range(120):
  await get_tree().process_frame
  if not editor.busy: break
 check(editor.preview.text==valid_text,"invalid generation preserves previous valid draft")
 editor.queue_free()
 LaboratoryStore.records["triangle"]["program"]=previous
