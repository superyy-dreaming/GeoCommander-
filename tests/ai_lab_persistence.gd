extends Node
func _ready() -> void:
 var reading: bool = "--read" in OS.get_cmdline_user_args()
 if reading:
  var ok: bool = LaboratoryStore.records["circle"]["prompt"] == "持久化测试提示词" and LaboratoryStore.records["circle"]["program"].get("version") == 1 and LaboratoryStore.setup.get("seed") == 7401 and LLMService.model == "persist-model" and LLMService.api_key.is_empty() and not TacticalBrain.opening_profile["unit_rules"]["circle"].has("program")
  print("AI_LAB_PERSIST_READ passed=%d failed=%d" % [1 if ok else 0,0 if ok else 1])
  get_tree().quit(0 if ok else 1)
 else:
  LaboratoryStore.set_prompt("circle","持久化测试提示词")
  LaboratoryStore.accept_program("circle",UnitTacticProgram.default_program("circle"),"persist-model")
  LaboratoryStore.setup = {"map_id":"balanced","seed":7401,"units":LaboratoryPresets.create(0)}
  var ok: bool = LaboratoryStore.save()
  ok = LLMService.configure("http://127.0.0.1:18741/v1","only-memory-secret","persist-model")["ok"] and ok
  print("AI_LAB_PERSIST_WRITE passed=%d failed=%d" % [1 if ok else 0,0 if ok else 1])
  get_tree().quit(0 if ok else 1)
