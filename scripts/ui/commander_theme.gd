class_name CommanderTheme
extends RefCounted

const TEXT: Color = Color(0.88,0.94,0.99)
const MUTED: Color = Color(0.61,0.75,0.83)
const ACCENT: Color = Color(0.2,0.8,1.0)
static var shared_theme: Theme

static func box(fill: Color, stroke: Color, border: int = 1) -> StyleBoxFlat:
 var style: StyleBoxFlat = StyleBoxFlat.new()
 style.bg_color = fill
 style.border_color = stroke
 style.set_border_width_all(border)
 style.set_corner_radius_all(4)
 style.content_margin_left = 14
 style.content_margin_right = 14
 style.content_margin_top = 10
 style.content_margin_bottom = 10
 return style

static func create() -> Theme:
 if is_instance_valid(shared_theme):
  shared_theme.default_font_size = GameSettings.font_px(18)
  shared_theme.set_font_size("font_size","TooltipLabel",GameSettings.font_px(16))
  return shared_theme
 var ui_theme: Theme = Theme.new()
 var font: SystemFont = SystemFont.new()
 font.font_names = PackedStringArray(["PingFang SC", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
 # SystemFont uses the first matching family, not a fallback chain. Some macOS
 # PingFang collections resolve to the HK face, which lacks simplified glyphs.
 var simplified: SystemFont = SystemFont.new()
 simplified.font_names = PackedStringArray(["Hiragino Sans GB", "Microsoft YaHei", "Noto Sans CJK SC", "Heiti SC", "sans-serif"])
 font.fallbacks = [simplified]
 ui_theme.default_font = font
 ui_theme.default_font_size = GameSettings.font_px(18)
 ui_theme.set_color("font_color", "Label", TEXT)
 ui_theme.set_color("font_color", "Button", TEXT)
 ui_theme.set_color("font_disabled_color", "Button", MUTED)
 ui_theme.set_stylebox("panel", "PanelContainer", box(Color(0.022,0.043,0.067,0.96), Color(0.13,0.29,0.38)))
 ui_theme.set_stylebox("normal", "Button", box(Color(0.04,0.09,0.13), Color(0.15,0.33,0.43)))
 ui_theme.set_stylebox("hover", "Button", box(Color(0.055,0.16,0.21), ACCENT))
 ui_theme.set_stylebox("pressed", "Button", box(Color(0.06,0.22,0.28), ACCENT, 2))
 ui_theme.set_stylebox("disabled", "Button", box(Color(0.028,0.055,0.075), Color(0.11,0.22,0.29)))
 var focus: StyleBoxFlat = box(Color(0,0,0,0), Color(0.72,0.92,1.0), 2)
 ui_theme.set_stylebox("focus", "Button", focus)
 for kind: String in ["LineEdit", "TextEdit"]:
  ui_theme.set_stylebox("normal", kind, box(Color(0.012,0.025,0.041), Color(0.16,0.34,0.44)))
  ui_theme.set_stylebox("focus", kind, focus)
  ui_theme.set_color("font_color", kind, TEXT)
  ui_theme.set_color("font_placeholder_color", kind, MUTED)
  ui_theme.set_color("caret_color", kind, ACCENT)
  ui_theme.set_color("selection_color", kind, Color(0.08,0.32,0.45))
 ui_theme.set_stylebox("background", "ProgressBar", box(Color(0.045,0.09,0.13), Color(0,0,0,0), 0))
 ui_theme.set_stylebox("fill", "ProgressBar", box(Color(0.12,0.66,0.84), Color(0,0,0,0), 0))
 ui_theme.set_font_size("font_size", "TooltipLabel",GameSettings.font_px(16))
 ui_theme.set_stylebox("panel", "TooltipPanel",box(Color(0.022,0.043,0.067),Color(0.25,0.5,0.6)))
 ui_theme.set_constant("separation", "HBoxContainer", 12)
 ui_theme.set_constant("separation", "VBoxContainer", 10)

 shared_theme = ui_theme
 return ui_theme

static func font(control: Control, base: int) -> void:
 control.set_meta("base_font_size",base)
 control.add_theme_font_size_override("font_size",GameSettings.font_px(base))

static func refresh(root: Control) -> void:
 root.theme = create()
 refresh_fonts(root)

static func refresh_fonts(node: Node) -> void:
 if node is Window: (node as Window).theme = create()
 if node is Control:
  var control: Control = node as Control
  if control.has_meta("base_font_size"):
   control.add_theme_font_size_override("font_size",GameSettings.font_px(int(control.get_meta("base_font_size"))))
  control.queue_redraw()
 for child: Node in node.get_children(): refresh_fonts(child)
