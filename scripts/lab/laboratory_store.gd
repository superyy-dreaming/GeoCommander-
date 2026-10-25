extends Node

signal persistence_changed
var records: Dictionary = {}
var selected_kind: String = "triangle"
var applied_programs: Dictionary = {}
var setup: Dictionary = {}
var path: String = "user://tactic_laboratory_v2.json"
var dirty: bool = false
var status: String = ""
var invalid_backed_up: bool = false
var backup_pending: bool = false
var migration_source: String = ""
const FILE_VERSION: int = 4
var migration_backup: String = ""
var write_blocked: bool = false
const MAX_GLOBAL_PROMPT: int = 4096
var global_prompt: String = ""
var global_prompt_previous: String = ""

func _ready() -> void:
 if DisplayServer.get_name() == "headless" or "--geo-test" in OS.get_cmdline_user_args(): path = "user://test_tactic_laboratory_v2.json"
 load_records()

func load_records() -> void:
 records.clear()
 applied_programs.clear()
 setup.clear()
 migration_source=""
 migration_backup=""
 invalid_backed_up=false
 backup_pending=false
 write_blocked=false
 global_prompt=""
 global_prompt_previous=""
 for kind: String in UnitCatalog.TYPES:
  records[kind] = {"prompt":UnitDossier.DATA[kind]["prompt"],"program":{},"source_model":"","draft_json":"","repair_error":""}
 var old_path: String = path.replace("_v2.json","_v1.json")
 if not FileAccess.file_exists(path) and FileAccess.file_exists(old_path):
  migration_source = old_path
 if not FileAccess.file_exists(path) and migration_source.is_empty(): return
 var source_file: FileAccess = FileAccess.open(migration_source if not migration_source.is_empty() else path,FileAccess.READ)
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
 var document := JSON.new()
 var parsed_error: Error = document.parse(text)
 var data: Variant = document.data if parsed_error == OK else null
 if not data is Dictionary or not UnitTacticProgram.numeric(data.get("version")) or (float(data["version"]) < 1 or float(data["version"]) > FILE_VERSION) or not data.get("records") is Dictionary:
  var backed: bool = backup_invalid()
  status = "实验文件无效，"+("已备份原文件" if backed else "原文件保留，备份失败")+"；本次使用空实验"
  return
 var raw_space: Variant=data.get("map_space_version",1)
 if not UnitTacticProgram.numeric(raw_space) or float(raw_space)!=floorf(float(raw_space)) or float(raw_space)<1 or float(raw_space)>MapCatalog.SPACE_VERSION:
  status="实验地图空间版本无效或来自更新版本，原文件保留，未进行迁移。"
  write_blocked=true
  return
 var source_space: int = int(raw_space)
 var migrated_space: bool = source_space < MapCatalog.SPACE_VERSION
 var needs_migration: bool=int(data["version"])<FILE_VERSION or migrated_space
 if needs_migration:
  var original: String=migration_source if not migration_source.is_empty() else path
  migration_backup=original+".pre-map-v3-"+str(Time.get_unix_time_from_system())
  if DirAccess.copy_absolute(original,migration_backup)!=OK:
   migration_backup="PENDING:"+original
 for kind: String in UnitCatalog.TYPES:
  var record: Variant = data["records"].get(kind)
  if not record is Dictionary: continue
  if record.get("draft_json") is String:
   var draft: String=record["draft_json"].left(262144)
   var parser := JSON.new()
   var parsed: Variant=parser.data if parser.parse(draft)==OK else null
   if migrated_space and parsed is Dictionary:
    draft=JSON.stringify(MapCatalog.migrate_program_coordinates(parsed,source_space),"  ")
   records[kind]["draft_json"]=draft
  if record.get("prompt") is String: records[kind]["prompt"] = record["prompt"].left(4096)
  var raw_program: Variant = record.get("repair_original",record.get("program"))
  if migrated_space and raw_program is Dictionary:
   raw_program = MapCatalog.migrate_program_coordinates(raw_program,source_space)
  records[kind]["source_model"]=str(record.get("source_model","")).left(200)
  var checked: Dictionary = UnitTacticProgram.validate(raw_program,kind)
  if checked["ok"]: records[kind]["program"]=checked["program"]
  elif raw_program!=null and (not raw_program is Dictionary or not raw_program.is_empty()):
   records[kind]["repair_error"]=kind+"："+checked["message"]
   records[kind]["repair_original"]=raw_program
   if str(records[kind]["draft_json"]).is_empty(): records[kind]["draft_json"]=JSON.stringify(raw_program,"  ")
  var raw_applied: Variant=record.get("applied_repair_original",record.get("applied_program"))
  if migrated_space and raw_applied is Dictionary: raw_applied=MapCatalog.migrate_program_coordinates(raw_applied,source_space)
  if raw_applied!=null and (not raw_applied is Dictionary or not raw_applied.is_empty()):
   var applied: Dictionary=UnitTacticProgram.validate(raw_applied,kind)
   if applied["ok"]: applied_programs[kind]=applied["program"]
   else:
    records[kind]["applied_repair_original"]=raw_applied
    records[kind]["repair_error"]=kind+"开局："+applied["message"]
 if data.get("setup") is Dictionary: setup = data["setup"].duplicate(true)
 if migrated_space and setup.get("units") is Array:
  for raw_unit: Variant in setup["units"]:
   if raw_unit is Dictionary and UnitTacticProgram.numeric(raw_unit.get("x")) and UnitTacticProgram.numeric(raw_unit.get("y")):
    var migrated_position := MapCatalog.migrate_point(Vector2(float(raw_unit["x"]),float(raw_unit["y"])),source_space)
    raw_unit["x"] = migrated_position.x
    raw_unit["y"] = migrated_position.y
 if data.get("global_prompt") is String:
  global_prompt = str(data["global_prompt"]).left(MAX_GLOBAL_PROMPT)
  global_prompt_previous = global_prompt
 if needs_migration:
  dirty=true
  status="已迁移到2400×1350空间版本3。旧文件已备份。"
  save()
 var repairs: Array[String]=[]
 for kind: String in UnitCatalog.TYPES:
  if not str(records[kind]["repair_error"]).is_empty(): repairs.append(records[kind]["repair_error"])
 if not repairs.is_empty():
  status="方案已保留，以下内容待修复，不能应用或开战：\n"+"\n".join(repairs)
 persistence_changed.emit()

func save() -> bool:
 if write_blocked:
  dirty=true
  status="本次运行已生效，未保存。实验空间版本不受支持，原文件保持不变。"
  persistence_changed.emit()
  return false
 if migration_backup.begins_with("PENDING:"):
  var original: String=migration_backup.trim_prefix("PENDING:")
  var destination: String=original+".pre-map-v3-"+str(Time.get_unix_time_from_system())
  if DirAccess.copy_absolute(original,destination)!=OK:
   dirty=true
   status="本次运行已生效，未保存。迁移原文件备份失败，原文件保持不变，请重试。"
   persistence_changed.emit()
   return false
  migration_backup=destination
 for kind: String in UnitCatalog.TYPES:
  if str(records[kind].get("draft_json","")).length()>262144:
   dirty=true
   status="本次运行已生效，未保存。JSON草稿最多262144字符，请缩短后重试。"
   persistence_changed.emit()
   return false
 if not migration_source.is_empty():
  var backup: String = migration_source+".pre-v2"
  if not FileAccess.file_exists(backup) and DirAccess.copy_absolute(migration_source,backup) != OK:
   dirty = true
   status = "本次运行已生效，未保存。旧实验备份失败，请重试。"
   persistence_changed.emit()
   return false
 if backup_pending and not backup_invalid():
  dirty = true
  status = "本次运行已生效，未保存。无效原文件备份失败，请修复写入权限后重试。"
  persistence_changed.emit()
  return false
 # Reconstruct the whitelist; credentials and arbitrary service state never enter this file.
 var clean: Dictionary = {}
 for kind: String in UnitCatalog.TYPES:
  clean[kind] = {"prompt":records[kind]["prompt"],"program":records[kind]["program"],"source_model":records[kind]["source_model"],"applied_program":applied_programs.get(kind,{}),"draft_json":records[kind].get("draft_json","")}
  for key: String in ["repair_original","applied_repair_original"]:
   if records[kind].has(key): clean[kind][key]=records[kind][key]
 var payload: String=JSON.stringify({"version":FILE_VERSION,"map_space_version":MapCatalog.SPACE_VERSION,"global_prompt":global_prompt.left(MAX_GLOBAL_PROMPT),"records":clean,"setup":setup},"  ")
 if payload.to_utf8_buffer().size()>4*1024*1024:
  dirty=true
  status="本次运行已生效，未保存。实验超过4MiB，请缩短草稿后重试。"
  persistence_changed.emit()
  return false
 var file: FileAccess = FileAccess.open(path+".tmp",FileAccess.WRITE)
 if file == null:
  dirty = true
 else:
  file.store_string(payload)
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

func set_global_prompt(value: String, persist: bool = true) -> bool:
 var next: String = value.left(MAX_GLOBAL_PROMPT)
 if next == global_prompt:
  return true
 global_prompt_previous = global_prompt
 global_prompt = next
 dirty = true
 if persist:
  return save()
 persistence_changed.emit()
 return true

func restore_previous_global_prompt() -> void:
 var current: String = global_prompt
 global_prompt = global_prompt_previous.left(MAX_GLOBAL_PROMPT)
 global_prompt_previous = current
 dirty = true
 persistence_changed.emit()

func accept_program(kind: String, program: Dictionary, source_model: String) -> Dictionary:
 var result: Dictionary = UnitTacticProgram.validate(program,kind)
 if not result["ok"]: return result
 records[kind]["repair_error"]=""
 records[kind].erase("repair_original")
 records[kind]["program"] = result["program"]
 records[kind]["source_model"] = source_model
 save()
 return result

func blue_profile() -> Dictionary:
 var profile: Dictionary = TacticalBrain.get_default_profile()
 for kind: String in UnitCatalog.TYPES:
  if applied_programs.has(kind):
   var checked: Dictionary=UnitTacticProgram.validate(applied_programs[kind],kind)
   if checked["ok"]: profile=UnitTacticProgram.apply_to_profile(profile,checked["program"])
   else: profile["unit_rules"][kind]["repair_error"]=checked["message"]
  if records[kind].has("applied_repair_original"): profile["unit_rules"][kind]["repair_error"]=records[kind]["repair_error"]
 return profile

func backup_invalid() -> bool:
 var original: String = migration_source if not migration_source.is_empty() else path
 if invalid_backed_up or not FileAccess.file_exists(original): return true
 var error: Error = DirAccess.copy_absolute(original,original+".invalid-"+str(Time.get_unix_time_from_system()))
 invalid_backed_up = error == OK
 backup_pending = error != OK
 return invalid_backed_up
