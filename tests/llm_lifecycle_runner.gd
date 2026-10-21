extends Node

var passed: int = 0
var failed: int = 0
var received: bool = false
var gap_ms: int = 0
var previous_ms: int = 0
var category: String = ""

func _process(_delta: float) -> void:
 var now: int = Time.get_ticks_msec()
 if previous_ms > 0: gap_ms = maxi(gap_ms,now-previous_ms)
 previous_ms = now

func check(ok: bool, title: String) -> void:
 if ok: passed += 1
 else: failed += 1
 print(("PASS " if ok else "FAIL ")+title)

func _ready() -> void:
 LLMService.config_path = "user://test_llm_lifecycle.cfg"
 LLMService.configure("http://127.0.0.1:18741/v1","","stalled")
 LLMService.completed.connect(func(_request_owner: int, _purpose: String, response: Dictionary) -> void:
  received = true
  category = response.get("category",""))
 for i: int in range(3): await get_tree().process_frame
 LLMService.request_timeout = 0.1
 var started: int = Time.get_ticks_msec()
 LLMService.start(get_instance_id(),"test")
 while not received and Time.get_ticks_msec()-started < 4000: await get_tree().process_frame
 await get_tree().process_frame
 var elapsed: int = Time.get_ticks_msec()-started
 check(received,"timeout completes once")
 check(elapsed >=70 and elapsed <500,"timeout follows wall time without blocking worker")
 check(gap_ms < 150,"timeout preserves main loop responsiveness")
 gap_ms = 0
 received = false
 LLMService.request_timeout = 5
 LLMService.start(get_instance_id(),"test")
 await get_tree().create_timer(0.05).timeout
 started = Time.get_ticks_msec()
 LLMService.cancel_owner(get_instance_id())
 var cancel_ms: int = Time.get_ticks_msec()-started
 await get_tree().process_frame
 await get_tree().process_frame
 check(cancel_ms <100,"explicit cancel returns promptly")
 check(gap_ms <150,"cancel preserves main loop responsiveness")
 await get_tree().create_timer(1.5).timeout
 check(not received and LLMService.requests.is_empty(),"cancelled request never completes")
 var report: Dictionary = {"passed":passed,"failed":failed,"timeout_elapsed_ms":elapsed,"cancel_ms":cancel_ms,"max_cancel_frame_gap_ms":gap_ms,"timeout_category":category}
 var file: FileAccess = FileAccess.open("res://artifacts/llm-lifecycle-report.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "))
 print("LLM_LIFECYCLE "+JSON.stringify(report))
 get_tree().quit(0 if failed ==0 else 1)
