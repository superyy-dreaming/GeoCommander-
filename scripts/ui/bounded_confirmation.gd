class_name BoundedConfirmation
extends ConfirmationDialog

## Native dialog buttons and focus, with a bounded, independently scrollable body.
var message: TextEdit

func _ready() -> void:
 get_label().hide()
 message = TextEdit.new()
 message.editable = false
 message.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
 message.size_flags_vertical = Control.SIZE_EXPAND_FILL
 CommanderTheme.font(message,18)
 add_child(message)
 about_to_popup.connect(fit.call_deferred)
 GameSettings.settings_changed.connect(fit.call_deferred)
 get_parent().get_viewport().size_changed.connect(fit.call_deferred)
 fit()

func fit() -> void:
 if not is_inside_tree(): return
 CommanderTheme.refresh_fonts(self)
 var available: Vector2i = get_parent().get_viewport().get_visible_rect().size
 size = Vector2i(mini(760,available.x-64),mini(380,available.y-80))
 position = (available-size)/2

func _process(_delta: float) -> void:
 if is_instance_valid(message) and message.text!=dialog_text: message.text=dialog_text
