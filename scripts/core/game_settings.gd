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
var display_initialized: bool = false
var observed_window_mode: int = Window.MODE_WINDOWED
var requested_window_mode: int = -1
var fullscreen_canvas_size: Vector2i = Vector2i.ZERO
var last_windowed_layout_size: Vector2i = Vector2i.ZERO
var windowed_size_candidate: Vector2i = Vector2i.ZERO
var windowed_size_stable_frames: int = 0
var native_fullscreen_pending: bool = false

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 observed_window_mode = get_window().mode
 last_windowed_layout_size = current_layout_size()
 windowed_size_candidate = last_windowed_layout_size
 get_window().size_changed.connect(window_geometry_changed)
 test_mode = DisplayServer.get_name() == "headless" or "--geo-test" in OS.get_cmdline_user_args()
 if test_mode:
  storage_path = "user://test-settings.cfg"
 else:
  load_settings()
  apply_display()

func valid_value(key: String, value: Variant) -> bool:
 match key:
  "font_scale": return (value is float or value is int) and float(value) in [1.0,1.15,1.3,1.5,1.8]
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

func is_fullscreen_mode(mode: int) -> bool:
 return mode == Window.MODE_FULLSCREEN or mode == Window.MODE_EXCLUSIVE_FULLSCREEN

func current_layout_size() -> Vector2i:
 var visible: Vector2 = get_viewport().get_visible_rect().size
 return Vector2i(maxi(1,roundi(visible.x)),maxi(1,roundi(visible.y)))

func remember_stable_window_size() -> void:
 var window: Window = get_window()
 if native_fullscreen_pending or is_fullscreen_mode(window.mode) or window.content_scale_size != Vector2i.ZERO: return
 var current: Vector2i = current_layout_size()
 if current != windowed_size_candidate:
  windowed_size_candidate = current
  windowed_size_stable_frames = 0
  return
 windowed_size_stable_frames += 1
 if windowed_size_stable_frames >= 3: last_windowed_layout_size = current

func window_geometry_changed() -> void:
 sync_native_fullscreen_transition(get_window().mode)

func sync_native_fullscreen_transition(mode: int) -> void:
 if OS.get_name() != "macOS" or not display_initialized: return
 if is_fullscreen_mode(mode) or is_fullscreen_mode(observed_window_mode): return
 var window: Window = get_window()
 # AppKit sends the screen-sized resize before didEnterFullScreen updates
 # Window.mode. A decorated window/maximize has a smaller content rectangle.
 # Treat this geometry as provisional, never as a new windowed layout. No
 # timer can decide ownership of this resize: mode confirmation commits it,
 # while restored window geometry cancels it.
 var screen_sized: bool = window.size == DisplayServer.screen_get_size(window.current_screen)
 if screen_sized and not native_fullscreen_pending:
  native_fullscreen_pending = true
  fullscreen_canvas_size = last_windowed_layout_size
  apply_content_scale()
 elif not screen_sized and native_fullscreen_pending:
  native_fullscreen_pending = false
  apply_content_scale()

func apply_content_scale() -> void:
 var window: Window = get_window()
 window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
 var fullscreen: bool = native_fullscreen_pending or int(values["window_mode"]) == 1 or is_fullscreen_mode(window.mode)
 if fullscreen and fullscreen_canvas_size == Vector2i.ZERO:
  fullscreen_canvas_size = Vector2i(values["resolution"])
 # Fullscreen uses the actual pre-fullscreen layout as its logical canvas.
 # This also covers the macOS native fullscreen control, which bypasses the
 # in-game display setting entirely.
 window.content_scale_size = fullscreen_canvas_size if fullscreen else Vector2i.ZERO

func apply_display() -> void:
 var window: Window = get_window()
 if DisplayServer.get_name() == "headless":
  display_initialized = true
  return
 native_fullscreen_pending = false
 var target_fullscreen: bool = int(values["window_mode"]) == 1
 if target_fullscreen:
  if display_initialized and not is_fullscreen_mode(window.mode):
   fullscreen_canvas_size = current_layout_size()
  elif fullscreen_canvas_size == Vector2i.ZERO:
   fullscreen_canvas_size = Vector2i(values["resolution"])
 apply_content_scale()
 if target_fullscreen:
  requested_window_mode = Window.MODE_FULLSCREEN
  window.mode = Window.MODE_FULLSCREEN
 else:
  requested_window_mode = Window.MODE_WINDOWED
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
 display_initialized = true

func _process(_delta: float) -> void:
 var window: Window = get_window()
 var mode: int = window.mode
 var was_fullscreen: bool = is_fullscreen_mode(observed_window_mode)
 var fullscreen: bool = is_fullscreen_mode(mode)
 sync_native_fullscreen_transition(mode)
 if fullscreen != was_fullscreen:
  var requested: bool = requested_window_mode >= 0 and is_fullscreen_mode(requested_window_mode) == fullscreen
  if fullscreen:
   if not requested and last_windowed_layout_size.x > 0 and last_windowed_layout_size.y > 0:
    fullscreen_canvas_size = last_windowed_layout_size
   values["window_mode"] = 1
  else:
   values["window_mode"] = 0
  native_fullscreen_pending = false
  apply_content_scale()
  requested_window_mode = -1
  settings_changed.emit()
 observed_window_mode = mode
 if requested_window_mode == mode: requested_window_mode = -1
 if not fullscreen: remember_stable_window_size()

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
