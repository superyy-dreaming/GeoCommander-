extends Node

signal settings_changed
signal persistence_changed

const DEFAULTS: Dictionary = {"font_scale":1.0,"window_mode":0,"resolution":Vector2i(1440,810),"glow":1.0,"reduced_motion":false,"camera_speed":1.0}
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280,720),Vector2i(1440,810),Vector2i(1440,900),Vector2i(1920,1080)]
var values: Dictionary = DEFAULTS.duplicate()
var storage_path: String = "user://settings.cfg"
var status: String = ""
var dirty: bool = false
var test_mode: bool = false
var environments: Array[WeakRef] = []

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 test_mode = DisplayServer.get_name() == "headless" or "--geo-test" in OS.get_cmdline_user_args()
 if test_mode:
  storage_path = "user://test-settings.cfg"
 else:
  load_settings()
  apply_display()

func valid_value(key: String, value: Variant) -> bool:
 match key:
  "font_scale": return (value is float or value is int) and float(value) in [1.0,1.15,1.3]
  "window_mode": return value is int and value in [0,1]
  "resolution": return value is Vector2i and value in RESOLUTIONS
  "glow": return (value is float or value is int) and is_finite(float(value)) and float(value) >= 0 and float(value) <= 1.5
  "reduced_motion": return value is bool
  "camera_speed": return (value is float or value is int) and is_finite(float(value)) and float(value) >= 0.5 and float(value) <= 2
 return false

func load_settings() -> void:
 values = DEFAULTS.duplicate()
 status = ""
 var file: ConfigFile = ConfigFile.new()
 var error: Error = file.load(storage_path)
 if error == ERR_FILE_NOT_FOUND: return
 if error != OK or file.get_value("meta","version",0) != 1:
  var backup: Error = backup_invalid()
  status = "设置文件无法读取，已恢复默认。"+backup_status(backup)
  return
 var repaired: bool = false
 for key: String in DEFAULTS:
  var value: Variant = file.get_value("settings",key,DEFAULTS[key])
  if valid_value(key,value): values[key] = value
  else: repaired = true
 if repaired:
  var backup: Error = backup_invalid()
  status = "部分设置无效，已恢复对应默认值。"+backup_status(backup)

func backup_invalid() -> Error:
 return DirAccess.copy_absolute(ProjectSettings.globalize_path(storage_path),ProjectSettings.globalize_path(storage_path)+".invalid-"+str(Time.get_unix_time_from_system()))

func backup_status(error: Error) -> String:
 return "原文件已保留。" if error == OK else "原文件备份失败："+error_string(error)

func save_settings() -> bool:
 var file: ConfigFile = ConfigFile.new()
 file.set_value("meta","version",1)
 for key: String in values: file.set_value("settings",key,values[key])
 var error: Error = file.save(storage_path+".tmp")
 if error == OK: error = DirAccess.rename_absolute(ProjectSettings.globalize_path(storage_path+".tmp"),ProjectSettings.globalize_path(storage_path))
 dirty = error != OK
 status = "本次运行已生效，未保存："+error_string(error) if dirty else "设置已保存到本机"
 persistence_changed.emit()
 return not dirty

func set_value(key: String, value: Variant, persist: bool = true) -> bool:
 if not valid_value(key,value): return false
 values[key] = value
 refresh_environments()
 settings_changed.emit()
 if persist: return save_settings()
 return true

func font_px(base: int) -> int:
 return roundi(base * float(values["font_scale"]))

func resolution_fits(dimensions: Vector2i) -> bool:
 if DisplayServer.get_name() == "headless": return true
 var usable: Rect2i = DisplayServer.screen_get_usable_rect()
 return dimensions.x <= usable.size.x and dimensions.y <= usable.size.y-40

func apply_display() -> void:
 if DisplayServer.get_name() == "headless": return
 var window: Window = get_window()
 if int(values["window_mode"]) == 1:
  window.mode = Window.MODE_FULLSCREEN
 else:
  window.mode = Window.MODE_WINDOWED
  window.borderless = false
  var dimensions: Vector2i = values["resolution"]
  if not resolution_fits(dimensions):
   dimensions = Vector2i(1280,720)
   for option: Vector2i in RESOLUTIONS:
    if resolution_fits(option): dimensions = option
   values["resolution"] = dimensions
   status = "窗口尺寸已适配当前显示器。"
  window.size = dimensions
  var usable: Rect2i = DisplayServer.screen_get_usable_rect()
  window.position = usable.position+(usable.size-window.size)/2

func track_environment(world: WorldEnvironment) -> void:
 environments.append(weakref(world))
 refresh_environments()

func refresh_environments() -> void:
 var live: Array[WeakRef] = []
 for reference: WeakRef in environments:
  var world: WorldEnvironment = reference.get_ref() as WorldEnvironment
  if not is_instance_valid(world): continue
  live.append(reference)
  world.environment.glow_enabled = float(values["glow"]) > 0
  world.environment.glow_intensity = 0.9 * float(values["glow"])
 environments = live
