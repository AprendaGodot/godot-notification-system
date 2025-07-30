extends Window # Or AcceptDialog, ConfirmationDialog, or PanelContainer if you manage windowing

## Emitted by this dialog scene when a button is pressed or it's dismissed.
## The Notifications singleton will connect to this.
signal gns_dialog_result_internal(result: Variant)
@onready var title_label: Label = $VBoxContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var message_label: Label = $VBoxContainer/MarginContainer/VBoxContainer/MessageLabel
@onready var button_container: HBoxContainer = $VBoxContainer/MarginContainer/VBoxContainer/ButtonContainer

## Called by the Notifications system to populate this dialog.
## `config` Dictionary can contain "title", "message", "icon", "buttons" (Array[String]).
func setup(config: Dictionary) -> void:
	title = config.get("title", "Dialog") # Window title
	title_label.text = title # Label title

	message_label.text = config.get("message", "")

	#var icon: Texture2D = config.get("icon", null) # Add TextureRect if needed

	# Clear old buttons
	for child in button_container.get_children():
		child.queue_free()

	var buttons: Array[String] = config.get("buttons", ["OK"])
	if buttons.is_empty(): # Ensure at least one way to close
		buttons.append("Close")

	for btn_text in buttons:
		var button = Button.new()
		button.text = btn_text
		button_container.add_child(button)
		button.pressed.connect(_on_button_pressed.bind(btn_text))

	# For built-in dialogs like AcceptDialog, you might need to override their buttons
	# or connect to their 'confirmed', 'canceled' signals.
	# This example assumes a custom Window node.
	close_requested.connect(_on_close_requested)


func _on_button_pressed(button_text: String) -> void:
	gns_dialog_result_internal.emit(button_text)
	# queue_free() # The Notifications manager will queue_free this dialog instance.

func _on_close_requested() -> void:
	# Default action if closed via window manager "X" button
	# You might want to emit a specific result or the text of a default "cancel" button.
	var buttons: Array[String] = []
	if button_container.get_child_count() > 0: # Get button text from first button if available
		var first_button : Button = button_container.get_child(0) if button_container.get_child_count() > 0 else null
		if first_button: buttons.append(first_button.text)

	gns_dialog_result_internal.emit(buttons[0] if not buttons.is_empty() else "closed") # Or specific "cancel" value
	# queue_free()

# If using AcceptDialog or ConfirmationDialog as base, override _ok() or connect to confirmed.
# For ConfirmationDialog, also handle get_cancel_button().pressed.

# Example for making it work with Godot's built-in popup logic if extending Window
# func _notification(what):
# 	if what == NOTIFICATION_VISIBILITY_CHANGED:
# 		if not visible:
# 			# If hidden by means other than our buttons (e.g. Esc)
# 			if not is_queued_for_deletion(): # Check if already being handled
#				_on_close_requested()
# 		pass
