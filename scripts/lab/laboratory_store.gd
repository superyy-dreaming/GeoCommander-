extends Node

signal persistence_changed
var records: Dictionary = {}
var selected_kind: String = "triangle"
var applied_programs: Dictionary = {}
var setup: Dictionary = {}
var path: String = "user://tactic_laboratory_v1.json"
var dirty: bool = false
var status: String = ""
var invalid_backed_up: bool = false
var backup_pending: bool = false

func _ready() -> void:
 if DisplayServer.get_name() == "headless" or "--geo-test" in OS.get_cmdline_user_args(): path = "user://test_tactic_laboratory_v1.json"
 for kind: String in UnitCatalog.TYPES:
  records[kind] = {"prompt":UnitDossier.DATA[kind]["prompt"],"program":{},"source_model":""}
 if not FileAccess.file_exists(path): return
 var source_file: FileAccess = FileAccess.open(path,FileAccess.READ)
 if source_file == null:
  status = "无法读取实验文件，请检查本机权限"
  return
 if source_file.get_length() > 4*1024*1024:
  source_file.close()
  var backed: bool = backup_invalid()
  status = "实验文件超出4MiB，"+("已备份" if backed else "原文件保留，备份失败")+"；本次使用空实验"
  return
 var text: String = source_file.get_as_text()
 source_file.close()
 var data: Variant = JSON.parse_string(text)
 if not data is Dictionary or data.get("version") != 1 or not data.get("records") is Dictionary:
  var backed: bool = backup_invalid()
  status = "实验文件无效，"+("已备份原文件" if backed else "原文件保留，备份失败")+"；本次使用空实验"
  return
 for kind: String in UnitCatalog.TYPES:
  var record: Variant = data["records"].get(kind)
  if not record is Dictionary: continue
  if record.get("prompt") is String: records[kind]["prompt"] = record["prompt"].left(4096)
  var checked: Dictionary = UnitTacticProgram.validate(record.get("program"),kind)
  if checked["ok"]:
   records[kind]["program"] = checked["program"]
   records[kind]["source_model"] = str(record.get("source_model","")).left(200)
  var applied: Dictionary = UnitTacticProgram.validate(record.get("applied_program"),kind)
  if applied["ok"]: applied_programs[kind] = applied["program"]
  if not checked["ok"] and record.get("program",{}) != {}:
   var backed: bool = backup_invalid()
   status = "部分实验 JSON 无效，"+("已备份原文件" if backed else "原文件保留，备份失败")+"；请重新生成"
 if data.get("setup") is Dictionary: setup = data["setup"].duplicate(true)

func save() -> bool:
 if backup_pending and not backup_invalid():
  dirty = true
  status = "本次运行已生效，未保存。无效原文件备份失败，请修复写入权限后重试。"
  persistence_changed.emit()
  return false
 # Reconstruct the whitelist; credentials and arbitrary service state never enter this file.
 var clean: Dictionary = {}
 for kind: String in UnitCatalog.TYPES:
  clean[kind] = {"prompt":records[kind]["prompt"],"program":records[kind]["program"],"source_model":records[kind]["source_model"],"applied_program":applied_programs.get(kind,{})}
 var file: FileAccess = FileAccess.open(path+".tmp",FileAccess.WRITE)
 if file == null:
  dirty = true
 else:
  file.store_string(JSON.stringify({"version":1,"records":clean,"setup":setup},"  "))
  file.flush()
  dirty = file.get_error() != OK
  file.close()
  if not dirty: dirty = DirAccess.rename_absolute(path+".tmp",path) != OK
 status = "本次运行已生效，未保存。请重试。" if dirty else "实验已保存到本机"
 persistence_changed.emit()
 return not dirty

func set_prompt(kind: String, prompt: String) -> void:
 records[kind]["prompt"] = prompt.left(4096)
 save()

func accept_program(kind: String, program: Dictionary, source_model: String) -> Dictionary:
 var result: Dictionary = UnitTacticProgram.validate(program,kind)
 if not result["ok"]: return result
 records[kind]["program"] = result["program"]
 records[kind]["source_model"] = source_model
 save()
 return result

func blue_profile() -> Dictionary:
 var profile: Dictionary = TacticalBrain.get_default_profile()
 for kind: String in UnitCatalog.TYPES:
  if applied_programs.has(kind): profile = UnitTacticProgram.apply_to_profile(profile,applied_programs[kind])
 return profile

func backup_invalid() -> bool:
 if invalid_backed_up or not FileAccess.file_exists(path): return true
 var error: Error = DirAccess.copy_absolute(path,path+".invalid-"+str(Time.get_unix_time_from_system()))
 invalid_backed_up = error == OK
 backup_pending = error != OK
 return invalid_backed_up
