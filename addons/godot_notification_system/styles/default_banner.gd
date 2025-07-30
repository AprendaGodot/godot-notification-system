extends PanelContainer

@onready var message_label: Label = $MarginContainer/HBoxContainer/MessageLabel

@onready var icon_rect: TextureRect = $MarginContainer/HBoxContainer/IconRect

@onready var close_button: Button = $MarginContainer/HBoxContainer/CloseButton


## Called by the Notifications system to populate this banner.
## `config` Dictionary can contain "title", "message", "icon", "persistent_id", "custom_data".
func setup(config: Dictionary) -> void:
	# Banners typically just have a message, title might be less common here or integrated.
	var message: String = config.get("message", "Banner Notification")
	var icon: Texture2D = config.get("icon", null)
	var persistent_id: StringName = config.get("persistent_id", &"")

	message_label.text = message

	if icon:
		icon_rect.texture = icon
		icon_rect.visible = true
	else:
		icon_rect.visible = false

	if persistent_id != &"" and config.get("show_close_button", false): # Example
		close_button.visible = true
		close_button.pressed.connect(func(): Notifications.dismiss_banner(persistent_id)) # If GNS is global
	else:
		close_button.visible = false
