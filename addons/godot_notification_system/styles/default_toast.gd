extends PanelContainer

@onready var title_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/TitleLabel
@onready var message_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/MessageLabel
@onready var icon_rect: TextureRect = $MarginContainer/HBoxContainer/IconRect
@onready var progress_bar: ProgressBar = $ProgressBar

var _is_timed: bool = true

## Called by the Notifications system to populate this toast.
## `config` Dictionary can contain "title", "message", "icon", "custom_data".
func setup(config: Dictionary) -> void:
	var title: String = config.get("title", "")
	var message: String = config.get("message", "Notification") # Fallback message
	var icon: Texture2D = config.get("icon", null)
	var duration: float = config.get("duration", -1)

	if title.is_empty():
		title_label.visible = false
	else:
		title_label.text = title
		title_label.visible = true

	message_label.text = message

	if icon:
		icon_rect.texture = icon
		icon_rect.visible = true
	else:
		icon_rect.visible = false

	if duration < 0:
		progress_bar.visible = false
	else:
		progress_bar.visible = true
		progress_bar.value = 0
		progress_bar.max_value = duration
		_is_timed = true


func _process(delta: float) -> void:
	if _is_timed and has_meta('gns_timer'):
		var timer: SceneTreeTimer = get_meta("gns_timer", null)
		if timer and is_instance_valid(timer):
			progress_bar.value = timer.time_left


	# Example: Access custom_data
	# var custom_info = config.get("custom_data", null)
	# if custom_info:
	#     print("Toast custom data: ", custom_info)
