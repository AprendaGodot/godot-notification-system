@tool
extends EditorPlugin

const SINGLETON_NAME = "Notifications"
const SINGLETON_SCRIPT_PATH = "res://addons/godot_notification_system/notifications.gd"

# --- Project Settings Definitions ---
const SETTINGS_PREFIX = "notifications/"
const TOAST_PREFIX = "toast/"
const BANNER_PREFIX = "banner/"
const SETTING_TOAST_DURATION = SETTINGS_PREFIX + TOAST_PREFIX + "default_toast_duration"
const SETTING_TOAST_POSITION = SETTINGS_PREFIX + TOAST_PREFIX + "default_toast_position"
const SETTING_MAX_TOASTS = SETTINGS_PREFIX + TOAST_PREFIX + "max_visible_toasts"
const SETTING_BANNER_DURATION = SETTINGS_PREFIX + BANNER_PREFIX + "default_banner_duration"
const SETTING_BANNER_POSITION = SETTINGS_PREFIX + BANNER_PREFIX + "default_banner_position"


# Helper to generate enum hint string for NotificationPosition
func _get_notification_position_enum_string() -> String:
	var enum_names: Array[String] = []
	# Assuming Notifications.NotificationPosition is accessible here
	# If not, duplicate the enum definition or find a way to access it.
	# For simplicity, let's hardcode it based on your enum in notifications.gd
	# This should ideally come directly from the Notifications.NotificationPosition enum
	var position_enum_dict = {
		"TOP_LEFT": 0, "TOP_CENTER": 1, "TOP_RIGHT": 2,
		"CENTER_LEFT": 3, "CENTER": 4, "CENTER_RIGHT": 5,
		"BOTTOM_LEFT": 6, "BOTTOM_CENTER": 7, "BOTTOM_RIGHT": 8,
		"TOP_EDGE": 9, "BOTTOM_EDGE": 10, "LEFT_EDGE": 11, "RIGHT_EDGE": 12
	} # This needs to match your enum order/values in notifications.gd

	# Sort by value to ensure order for hint string
	var sorted_keys_by_value = []
	var temp_array = []
	for key in position_enum_dict:
		temp_array.push_back({"name": key, "value": position_enum_dict[key]})
	temp_array.sort_custom(func(a,b): return a.value < b.value)
	for item in temp_array:
		enum_names.push_back(item.name)

	return ",".join(enum_names)


func _setup_project_settings() -> void:
	var position_enum_hint_string = _get_notification_position_enum_string()

	var properties_to_add = [
		{
			"name": SETTING_TOAST_DURATION, "type": TYPE_FLOAT, "default": 3.0,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.1,60,0.1,or_greater"
		},
		{
			"name": SETTING_TOAST_POSITION, "type": TYPE_INT, "default": 8, # Assuming BOTTOM_RIGHT is 8
			"hint": PROPERTY_HINT_ENUM, "hint_string": position_enum_hint_string
		},
		{
			"name": SETTING_MAX_TOASTS, "type": TYPE_INT, "default": 5,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "1,20,1,or_greater"
		},
		{
			"name": SETTING_BANNER_DURATION, "type": TYPE_FLOAT, "default": 5.0,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "-1,300,0.1,or_greater" # -1 for persistent
		},
		{
			"name": SETTING_BANNER_POSITION, "type": TYPE_INT, "default": 9, # Assuming TOP_EDGE is 9
			"hint": PROPERTY_HINT_ENUM, "hint_string": position_enum_hint_string
		},
	]

	for prop_info in properties_to_add:
		if not ProjectSettings.has_setting(prop_info.name):
			ProjectSettings.set_setting(prop_info.name, prop_info.default)
			print("Godot Notification System: Added project setting '%s' with default value %s." % [prop_info.name, str(prop_info.default)])

		var property_dict = {
			"name": prop_info.name,
			"type": prop_info.type,
		}
		if prop_info.has("hint"):
			property_dict["hint"] = prop_info.hint
		if prop_info.has("hint_string"):
			property_dict["hint_string"] = prop_info.hint_string

		ProjectSettings.add_property_info(property_dict)
		ProjectSettings.set_initial_value(prop_info.name, prop_info.default) # Ensures it appears if not saved
		ProjectSettings.set_as_basic(prop_info.name, true) # Make it visible in basic settings view


func _remove_project_settings() -> void:
	# --- Remove Project Settings ---
	# Note: ProjectSettings.clear() does not remove the property from the project.godot file if it was saved.
	# It only removes it from memory for the current session if it wasn't saved.
	# To truly remove, users might need to edit project.godot or we just leave them.
	# For now, we'll just unregister the property_info so it doesn't show in the editor.
	# Actual values might persist if changed by user.
	var settings_to_clear = [
		SETTING_TOAST_DURATION,
		SETTING_TOAST_POSITION,
		SETTING_MAX_TOASTS,
		SETTING_BANNER_DURATION,
		SETTING_BANNER_POSITION,
	]
	for setting_name in settings_to_clear:
		if ProjectSettings.has_setting(setting_name):
			# This doesn't actually remove the property from being listed in editor,
			# ProjectSettings lacks a 'remove_property_info'.
			# We just ensure it's not present in the next _enable_plugin run's "has_setting" checks.
			# The best we can do is set it to its default and let the user remove from project.godot if desired.
			# Or, document that uninstalling requires manual cleanup of these settings from project.godot.
			pass # No direct way to remove property_info after added for the session.
	print("Godot Notification System: Plugin disabled. Project settings related to GNS might need manual cleanup from project.godot if you wish to fully remove them.")


func _setup_autoload() -> void:
	# Add the Notifications script as an autoload singleton.
	# The 'false' argument means it's not enabled by default in new projects,
	# but for an active plugin, we typically want it enabled.
	# We check if it exists first to avoid errors if manually added.
	if not ProjectSettings.has_setting("autoload/" + SINGLETON_NAME):
		add_autoload_singleton(SINGLETON_NAME, SINGLETON_SCRIPT_PATH)
		print("Godot Notification System: '%s' autoload registered." % SINGLETON_NAME)

	else:
		# If it exists but path is different, update it.
		var existing_path = ProjectSettings.get_setting("autoload/" + SINGLETON_NAME).replace("*", "")

		if existing_path != SINGLETON_SCRIPT_PATH:
			ProjectSettings.set_setting("autoload/" + SINGLETON_NAME, "*" + SINGLETON_SCRIPT_PATH)
			print("Godot Notification System: '%s' autoload path updated." % SINGLETON_NAME)

		# Ensure it's enabled if it already exists
		var current_setting = ProjectSettings.get_setting("autoload/" + SINGLETON_NAME)

		if not current_setting.begins_with("*"):
			ProjectSettings.set_setting("autoload/" + SINGLETON_NAME, "*" + current_setting)
			print("Godot Notification System: '%s' autoload re-enabled." % SINGLETON_NAME)


func _remove_autoload() -> void:
	# Remove the Notifications autoload singleton.
	if ProjectSettings.has_setting("autoload/" + SINGLETON_NAME):
		remove_autoload_singleton(SINGLETON_NAME)
		print("Godot Notification System: '%s' autoload unregistered." % SINGLETON_NAME)


func _enable_plugin():
	_setup_autoload()
	_setup_project_settings()


func _disable_plugin():
	_remove_autoload()
	_remove_project_settings()
