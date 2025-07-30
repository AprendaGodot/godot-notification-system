## Manages and displays UI notifications like toasts, banners, and dialogs.
## Accessed globally via `Notifications.show_toast(...)` etc.
extends Node

## Emitted when a dialog managed by this system is dismissed.
## The `result` can be the text of the button pressed, or a custom value from the dialog.
signal dialog_dismissed(result: Variant)

signal toast_actives_changed(actives: Array[Node])
signal toast_queue_changed(queue: Array[Dictionary])

## Enum for defining notification positions on the screen.
enum NotificationPosition {
	TOP_LEFT, TOP_CENTER, TOP_RIGHT,
	CENTER_LEFT, CENTER, CENTER_RIGHT,
	BOTTOM_LEFT, BOTTOM_CENTER, BOTTOM_RIGHT,
	TOP_EDGE, BOTTOM_EDGE, LEFT_EDGE, RIGHT_EDGE
}

#region Default Scene Paths (can be overridden by registered styles)
const DEFAULT_TOAST_SCENE_PATH = "res://addons/godot_notification_system/styles/default_toast.tscn"
const DEFAULT_BANNER_SCENE_PATH = "res://addons/godot_notification_system/styles/default_banner.tscn"
const DEFAULT_DIALOG_SCENE_PATH = "res://addons/godot_notification_system/styles/default_dialog.tscn"
#endregion

#region Configuration Variables (with defaults)
var default_toast_duration: float = 3.0
var default_toast_position: NotificationPosition = NotificationPosition.BOTTOM_RIGHT
var default_banner_duration: float = 5.0
var default_banner_position: NotificationPosition = NotificationPosition.TOP_EDGE
var max_visible_toasts: int = 5
#endregion

#region Internal State
var _toast_styles: Dictionary = {}
var _banner_styles: Dictionary = {}
var _dialog_styles: Dictionary = {}

var _default_toast_scene: PackedScene
var _default_banner_scene: PackedScene
var _default_dialog_scene: PackedScene

var _toast_queue: Array[Dictionary] = [] # Stores ToastConfig dictionaries
var _active_toasts: Array[Node] = [] # Stores active toast instances

var _active_timed_banners: Array[Node] = [] # Stores active timed banner instances
var _active_persistent_banners: Dictionary = {} # {id: StringName : banner_instance: Node}

var _current_dialog: Node = null

# Containers for different positions
var _containers: Dictionary = {} # {NotificationPosition: Control_container}
var _ui_layer: CanvasLayer
#endregion


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Ensure this node processes, especially for timers if not using SceneTreeTimer
	process_mode = Node.PROCESS_MODE_ALWAYS

	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "NotificationCanvasLayer"
	add_child(_ui_layer)

	_load_default_scenes()

	 # --- Load Project Settings ---
	# Ensure that the enum values used as defaults match your NotificationPosition enum
	# For example, if BOTTOM_RIGHT is 7 and TOP_EDGE is 9
	print(default_toast_position)

	default_toast_duration = ProjectSettings.get_setting("notifications/default_toast_duration", 3.0)
	default_toast_position = NotificationPosition.values()[ProjectSettings.get_setting("notifications/default_toast_position", NotificationPosition.BOTTOM_RIGHT)] # 7 is example for BOTTOM_RIGHT
	print(default_toast_position)
	max_visible_toasts = ProjectSettings.get_setting("notifications/max_visible_toasts", 5)
	default_banner_duration = ProjectSettings.get_setting("notifications/default_banner_duration", 5.0)
	default_banner_position = NotificationPosition.values()[ProjectSettings.get_setting("notifications/default_banner_position", NotificationPosition.TOP_EDGE)] # 9 is example for TOP_EDGE

	# Validate loaded enum positions
	if not _is_valid_position(default_toast_position):
		push_warning("GNS Warning: Invalid default_toast_position from project settings. Reverting to BOTTOM_RIGHT.")
		default_toast_position = NotificationPosition.BOTTOM_RIGHT
	if not _is_valid_position(default_banner_position):
		push_warning("GNS Warning: Invalid default_banner_position from project settings. Reverting to TOP_EDGE.")
		default_banner_position = NotificationPosition.TOP_EDGE


func _load_default_scenes() -> void:
	_default_toast_scene = load(DEFAULT_TOAST_SCENE_PATH)
	if not _default_toast_scene:
		push_error("GNS Error: Default toast scene not found at '%s'." % DEFAULT_TOAST_SCENE_PATH)

	_default_banner_scene = load(DEFAULT_BANNER_SCENE_PATH)
	if not _default_banner_scene:
		push_error("GNS Error: Default banner scene not found at '%s'." % DEFAULT_BANNER_SCENE_PATH)

	_default_dialog_scene = load(DEFAULT_DIALOG_SCENE_PATH)
	if not _default_dialog_scene:
		push_error("GNS Error: Default dialog scene not found at '%s'." % DEFAULT_DIALOG_SCENE_PATH)


# --- Configuration API ---

## Sets the default duration for toasts if not specified when shown.
func set_default_toast_duration(duration: float) -> void:
	if duration <= 0:
		push_warning("GNS Warning: Default toast duration must be positive.")
		return
	default_toast_duration = duration


func get_default_toast_duration() -> float:
	return default_toast_duration

## Sets the default screen position for toasts.
func set_default_toast_position(position: NotificationPosition) -> void:
	if not _containers.has(position):
		push_warning("GNS Warning: Invalid toast position '%s'." % NotificationPosition.keys()[position])
		return
	default_toast_position = position


func get_default_toast_position() -> NotificationPosition:
	return default_toast_position


func get_active_toasts() -> Array[Node]:
	return _active_toasts


## Sets the default screen position for banners.
func set_default_banner_position(position: NotificationPosition) -> void:
	if not _containers.has(position):
		push_warning("GNS Warning: Invalid banner position '%s'." % NotificationPosition.keys()[position])
		return
	default_banner_position = position

## Sets the maximum number of toasts that can be visible simultaneously.
## Older toasts will be queued.
func set_max_visible_toasts(count: int) -> void:
	if count <= 0:
		push_warning("GNS Warning: Max visible toasts must be positive.")
		return
	max_visible_toasts = count


func get_max_visible_toasts() -> int:
	return max_visible_toasts


## Registers a custom PackedScene for a specific toast style.
func register_toast_style(style_name: StringName, scene: PackedScene) -> void:
	if not scene:
		push_error("GNS Error: Cannot register null scene for toast style '%s'." % style_name)
		return
	_toast_styles[style_name] = scene

## Registers a custom PackedScene for a specific banner style.
func register_banner_style(style_name: StringName, scene: PackedScene) -> void:
	if not scene:
		push_error("GNS Error: Cannot register null scene for banner style '%s'." % style_name)
		return
	_banner_styles[style_name] = scene

## Registers a custom PackedScene for a specific dialog style.
func register_dialog_style(style_name: StringName, scene: PackedScene) -> void:
	if not scene:
		push_error("GNS Error: Cannot register null scene for dialog style '%s'." % style_name)
		return
	_dialog_styles[style_name] = scene



#region DIALOGS
## Shows a simple dialog with a title, message, and OK button by default.
## Returns a signal that emits the text of the button pressed when the dialog is dismissed.
func show_dialog_simple(title: String, message: String, buttons: Array[String] = ["OK"]) -> Signal:
	var config := {
		"title": title,
		"message": message,
		"buttons": buttons
	}
	return show_dialog(config)


## Shows a dialog using a configuration Dictionary.
## The config dictionary can specify "title", "message", "buttons" (Array[String]),
## "icon" (Texture2D), "style_name" (StringName).
## Returns a signal that emits the result when the dialog is dismissed.
func show_dialog(config: Dictionary) -> Signal:
	var completion_signal := Signal()

	if _current_dialog and is_instance_valid(_current_dialog):
		push_warning("GNS Warning: Another dialog is already active. New dialog request ignored.")
		# Emit immediately with an error or specific value if desired
		# completion_signal.emit("ERROR_DIALOG_ACTIVE") # Or some other indicator
		# For await to work, it must emit something.
		# Or simply don't emit, and await will hang until manually completed or timeout.
		# A better approach for robust await is to always emit.
		get_tree().create_timer(0.001, false, true, true).timeout.connect(
			func():
				if not completion_signal.is_null(): completion_signal.emit(null) # Or an error string
		, CONNECT_ONE_SHOT) # Emit null or error after a frame.
		return completion_signal

	var style_name = config.get("style_name", &"")
	var scene_to_load: PackedScene = _dialog_styles.get(style_name, _default_dialog_scene)

	if not scene_to_load:
		push_error("GNS Error: No scene found for dialog style '%s' and no default dialog scene loaded." % style_name)
		get_tree().create_timer(0.001, false, true, true).timeout.connect(
			func():
				if not completion_signal.is_null(): completion_signal.emit(null)
		, CONNECT_ONE_SHOT)
		return completion_signal

	_current_dialog = scene_to_load.instantiate()
	if not _current_dialog:
		push_error("GNS Error: Failed to instantiate dialog scene for style '%s'." % style_name)
		get_tree().create_timer(0.001, false, true, true).timeout.connect(
			func():
				if not completion_signal.is_null(): completion_signal.emit(null)
		, CONNECT_ONE_SHOT)
		return completion_signal

	# Dialogs are typically added directly to the UI layer or as child of this node
	# and then made visible. They handle their own positioning (usually centered).
	_ui_layer.add_child(_current_dialog)

	if _current_dialog.has_method("setup"):
		_current_dialog.setup(config)
	else:
		push_warning("GNS Warning: Dialog scene for style '%s' does not have a 'setup(config: Dictionary)' method." % style_name)


	# Connect the local completion_signal to be emitted by our internal handler
	# Ensure this connection is ONE_SHOT so it cleans itself up.
	# We use an intermediate function that is connected to _current_dialog's signal.
	# That intermediate function will then emit the completion_signal.

	# The dialog scene itself should emit a signal like "dialog_closed(result_data)"
	# or specific button signals. We connect to that.
	if _current_dialog.has_signal("gns_dialog_result_internal"): # Expect custom dialog to emit this
		_current_dialog.gns_dialog_result_internal.connect(
			func(result: Variant): _on_internal_dialog_dismissed_and_emit(result, completion_signal)
			, CONNECT_ONE_SHOT
		)
	else:
		 # Fallback: if it's a Godot dialog, connect to its built-in signals
		if _current_dialog is ConfirmationDialog:
			_current_dialog.confirmed.connect(
				 func(): _on_internal_dialog_dismissed_and_emit(_current_dialog.ok_button_text, completion_signal)
				, CONNECT_ONE_SHOT
			)
			# Godot ConfirmationDialog doesn't have a direct "cancelled" signal that gives button text.
			# Custom dialogs are better for this.
		elif _current_dialog is AcceptDialog:
			_current_dialog.confirmed.connect(
				func(): _on_internal_dialog_dismissed_and_emit(_current_dialog.ok_button_text, completion_signal)
				, CONNECT_ONE_SHOT
			)
		push_warning("GNS Warning: Dialog scene for style '%s' does not emit 'gns_dialog_result_internal(result)' signal. Simple 'confirmed' might be used." % style_name)


	if _current_dialog.has_method("popup_centered"):
		_current_dialog.popup_centered()
	elif _current_dialog.has_method("show"):
		_current_dialog.show()
	else:
		_current_dialog.visible = true # Fallback

	# Return a signal that this Notifications manager will emit
	dialog_dismissed.connect(completion_signal.emit, CONNECT_ONE_SHOT) # Forward global to local
	return completion_signal


func _on_internal_dialog_dismissed_and_emit(result: Variant, signal_to_emit: Signal) -> void:
	if _current_dialog and is_instance_valid(_current_dialog):
		_current_dialog.queue_free()
	_current_dialog = null

	# Emit the specific signal instance that was returned by show_dialog()
	if not signal_to_emit.is_null(): # Check if signal object still exists (it should)
		signal_to_emit.emit(result)

	# Also emit the global signal for other listeners if needed
	dialog_dismissed.emit(result) # This is the global one
#endregion


#region TOASTS
## Shows a toast notification with a message.
## `icon`: Optional Texture2D for the toast.
func show_toast(title: String, message: String = "", icon: Texture2D = null) -> void:
	var config := {
		"message": message,
		"title": title,
		"icon": icon,
	}

	show_toast_adv(config)


## Shows a toast notification using an advanced configuration Dictionary.
## Config can include: "message", "title", "icon", "duration", "style_name", "position" (NotificationPosition),
## "custom_data" (Variant).
func show_toast_adv(config: Dictionary) -> void:
	if not config.has("message") and not config.has("title"):
		push_warning("GNS Warning: Toast must have at least a message or a title.")
		return

	if _active_toasts.size() >= max_visible_toasts:
		_toast_queue.push_back(config)
		toast_queue_changed.emit(_toast_queue)
	else:
		_display_toast(config)


func _display_toast(config: Dictionary) -> void:
	var style_name = config.get("style_name", &"")
	var scene_to_load: PackedScene = _toast_styles.get(style_name, _default_toast_scene)

	if not scene_to_load:
		push_error("GNS Error: No scene found for toast style '%s' and no default toast scene loaded." % style_name)
		return

	var toast_instance: Node = scene_to_load.instantiate()
	if not toast_instance:
		push_error("GNS Error: Failed to instantiate toast scene for style '%s'." % style_name)
		return

	var position = config.get("position", default_toast_position)
	config.set("position", position) # Maybe consider that config is immutable?

	var container: Control = _get_or_create_container(position)
	if not container:
		push_warning("GNS Warning: No container found for toast position '%s'. Using default." % NotificationPosition.keys()[position])
		container = _get_or_create_container(default_toast_position)

	container.add_child(toast_instance)

	_update_container_position(container, position)

	_active_toasts.push_back(toast_instance)
	toast_actives_changed.emit(_active_toasts)

	var duration = config.get("duration", default_toast_duration)
	config.set("duration", duration)

	if duration <= 0: duration = default_toast_duration

	var timer = get_tree().create_timer(duration, true, false, true) # process_always = true, process_in_physics = false, ignore_time_scale = true
	timer.timeout.connect(_on_toast_timer_timeout.bind(toast_instance), CONNECT_ONE_SHOT)
	toast_instance.set_meta("gns_timer", timer) # Store timer for potential early dismissal


	if toast_instance.has_method("setup"):
		toast_instance.setup(config)
	else:
		push_warning("GNS Warning: Toast scene for style '%s' does not have 'setup(config: Dictionary)' method." % style_name)


func _on_toast_timer_timeout(toast_instance: Node) -> void:
	if is_instance_valid(toast_instance):
		_active_toasts.erase(toast_instance)
		toast_instance.queue_free()
		toast_actives_changed.emit(_active_toasts)
	_process_toast_queue()


func _process_toast_queue() -> void:
	while not _toast_queue.is_empty() and _active_toasts.size() < max_visible_toasts:
		var config = _toast_queue.pop_front()
		_display_toast(config)
		toast_queue_changed.emit(_toast_queue)
#endregion


#region BANNERS
## Shows a banner notification.
## `duration`: Time in seconds. 3 for default (could be infinite if `persistent_id` is set).
## `persistent_id`: If provided, banner can be updated or dismissed by this ID.
## An empty `persistent_id` means a timed, non-persistent banner.
func show_banner(message: String, duration: float = 3, icon: Texture2D = null, persistent_id: StringName = &"") -> void:
	var config := {
		"message": message,
		"duration": duration,
		"icon": icon,
		"persistent_id": persistent_id,
		"position": default_banner_position # Default, can be overridden in adv
	}
	show_banner_adv(config)


## Shows a banner using an advanced configuration Dictionary.
## Config can include: "message", "title", "icon", "duration", "style_name", "persistent_id",
## "position" (NotificationPosition), "custom_data" (Variant).
func show_banner_adv(config: Dictionary) -> void:
	if not config.has("message") and not config.has("title"):
		push_warning("GNS Warning: Banner must have at least a message or a title.")
		return

	var persistent_id: StringName = config.get("persistent_id", &"")

	# If persistent ID exists, update existing banner
	if persistent_id != &"" and _active_persistent_banners.has(persistent_id):
		var existing_banner: Node = _active_persistent_banners[persistent_id]
		if is_instance_valid(existing_banner):
			if existing_banner.has_method("setup"):
				existing_banner.setup(config) # Re-setup with new config
			else:
				push_warning("GNS Warning: Persistent banner (ID: %s) scene doesn't have 'setup' method for update." % persistent_id)

			# Reset timer if duration is provided
			var duration = config.get("duration", 3)
			if duration > 0:
				if existing_banner.has_meta('gns_timer'):
					var old_timer: SceneTreeTimer = existing_banner.get_meta("gns_timer", null)
					if old_timer and is_instance_valid(old_timer): old_timer.time_left = 0 # Effectively stop it

				var new_timer = get_tree().create_timer(duration, false, true, true)
				new_timer.timeout.connect(_on_banner_timer_timeout.bind(existing_banner, persistent_id), CONNECT_ONE_SHOT)
				existing_banner.set_meta("gns_timer", new_timer)
			return # Updated existing banner

	# Create new banner
	var style_name = config.get("style_name", &"")
	var scene_to_load: PackedScene = _banner_styles.get(style_name, _default_banner_scene)

	if not scene_to_load:
		push_error("GNS Error: No scene for banner style '%s' and no default banner scene." % style_name)
		return

	var banner_instance: Node = scene_to_load.instantiate()
	if not banner_instance:
		push_error("GNS Error: Failed to instantiate banner scene for style '%s'." % style_name)
		return

	var position = config.get("position", default_banner_position)
	var container: Control = _get_or_create_container(position)
	if not container:
		push_warning("GNS Warning: No container for banner position '%s'. Using default." % NotificationPosition.keys()[position])
		container = _get_or_create_container(default_banner_position)

	container.add_child(banner_instance)

	if banner_instance.has_method("setup"):
		banner_instance.setup(config)
	else:
		push_warning("GNS Warning: Banner scene for style '%s' lacks 'setup(config: Dictionary)'." % style_name)

	var duration = config.get("duration", 3)
	var is_persistent_without_timer = (persistent_id != &"" and duration <= 0)

	if persistent_id != &"":
		_active_persistent_banners[persistent_id] = banner_instance
	elif duration > 0: # Timed, non-persistent
		_active_timed_banners.push_back(banner_instance)
	# else: if no persistent_id and no duration, it's effectively a one-frame banner or an error.
	# We'll assume if duration is -1 and no ID, it's persistent until cleared manually.
	# For truly timed, duration must be > 0.

	if duration > 0: # Only start timer if duration is positive
		var timer = get_tree().create_timer(duration, false, true, true)
		timer.timeout.connect(_on_banner_timer_timeout.bind(banner_instance, persistent_id), CONNECT_ONE_SHOT)
		banner_instance.set_meta("gns_timer", timer)


func _on_banner_timer_timeout(banner_instance: Node, persistent_id: StringName) -> void:
	if is_instance_valid(banner_instance):
		if persistent_id != &"" and _active_persistent_banners.has(persistent_id):
			if _active_persistent_banners[persistent_id] == banner_instance: # Ensure it's the same one
				_active_persistent_banners.erase(persistent_id)
		_active_timed_banners.erase(banner_instance) # erase works even if not present
		banner_instance.queue_free()


## Dismisses a persistent banner by its ID.
func dismiss_banner(id: StringName) -> void:
	if _active_persistent_banners.has(id):
		var banner_instance: Node = _active_persistent_banners.get(id)
		if is_instance_valid(banner_instance):
			if banner_instance.has_meta("gns_timer"):
				var timer: SceneTreeTimer = banner_instance.get_meta("gns_timer", null)
				if timer and is_instance_valid(timer):
					timer.time_left = 0 # Stop timer if any
			banner_instance.queue_free()
		_active_persistent_banners.erase(id)
	else:
		push_warning("GNS Warning: No persistent banner found with ID '%s' to dismiss." % id)
#endregion


#region CLEARING
## Clears all currently visible (and queued) toasts.
func clear_toasts() -> void:
	for toast_instance in _active_toasts:
		if is_instance_valid(toast_instance):
			if toast_instance.has_meta("gns_timer"):
				var timer: SceneTreeTimer = toast_instance.get_meta("gns_timer", null)
				if timer and is_instance_valid(timer): timer.time_left = 0 # Stop timer
			toast_instance.queue_free()
	_active_toasts.clear()
	toast_actives_changed.emit(_active_toasts)
	_toast_queue.clear()
	toast_queue_changed.emit(_toast_queue)

## Clears all banners.
## `include_persistent`: If true, also clears banners shown with a `persistent_id`.
func clear_banners(include_persistent: bool = false) -> void:
	for banner_instance in _active_timed_banners:
		if is_instance_valid(banner_instance):
			if banner_instance.has_meta("gns_timer"):
				var timer: SceneTreeTimer = banner_instance.get_meta("gns_timer", null)
				if timer and is_instance_valid(timer): timer.time_left = 0
			banner_instance.queue_free()
	_active_timed_banners.clear()

	if include_persistent:
		for id in _active_persistent_banners.keys():
			var banner_instance: Node = _active_persistent_banners[id]
			if is_instance_valid(banner_instance):
				if banner_instance.has_meta('gns_timer'):
					var timer: SceneTreeTimer = banner_instance.get_meta("gns_timer", null)
					if timer and is_instance_valid(timer): timer.time_left = 0
				banner_instance.queue_free()
		_active_persistent_banners.clear()


## Clears all notifications.
func clear_all(include_persistent_banners: bool = false) -> void:
	clear_toasts()
	clear_banners(include_persistent_banners)
	if _current_dialog and is_instance_valid(_current_dialog):
		_current_dialog.queue_free()
		_current_dialog = null
#endregion


#region Dynamic Container Management
# --- Helper for validating enum from settings ---
func _is_valid_position(pos_value: int) -> bool:
	return pos_value >= 0 and pos_value < NotificationPosition.size()


func _get_or_create_container(position: NotificationPosition) -> Control:
	if not _containers.has(position):
		# Create the top-level container for this specific position
		var base_container = Control.new()
		base_container.name = "PositionalContainer_" + NotificationPosition.keys()[position]
		base_container.mouse_filter = Control.MOUSE_FILTER_IGNORE # Let clicks pass through base
		base_container.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		_ui_layer.add_child(base_container)


		var margin_container = MarginContainer.new()
		margin_container.name = "Margin"
		margin_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Default margins, can be customized per position if needed
		margin_container.add_theme_constant_override("margin_left", 10)
		margin_container.add_theme_constant_override("margin_top", 10)
		margin_container.add_theme_constant_override("margin_right", 10)
		margin_container.add_theme_constant_override("margin_bottom", 10)


		base_container.add_child(margin_container)


		# Actual layout container (VBox for stacking is common)
		var layout_container = VBoxContainer.new() # Or HBoxContainer for edge cases
		layout_container.name = "Layout"
		layout_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layout_container.add_theme_constant_override("separation", 8) # Spacing between notifications

		margin_container.add_child(layout_container)

		_containers[position] = layout_container # Store the actual layout container

		# Configure anchors and growth for the base_container
		# This determines where the whole block for this position sits.
		# Individual notifications within the layout_container will then stack.
		match position:
			NotificationPosition.TOP_LEFT:
				margin_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
				layout_container.alignment = BoxContainer.ALIGNMENT_BEGIN
			NotificationPosition.TOP_CENTER:
				margin_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
				layout_container.alignment = BoxContainer.ALIGNMENT_CENTER
			NotificationPosition.TOP_RIGHT:
				margin_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
				layout_container.alignment = BoxContainer.ALIGNMENT_END
			NotificationPosition.CENTER_LEFT:
				margin_container.set_anchors_preset(Control.PRESET_CENTER_LEFT)
				layout_container.alignment = BoxContainer.ALIGNMENT_BEGIN # VBox default
			NotificationPosition.CENTER:
				margin_container.set_anchors_preset(Control.PRESET_CENTER)
				layout_container.alignment = BoxContainer.ALIGNMENT_CENTER
			NotificationPosition.CENTER_RIGHT:
				margin_container.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
				layout_container.alignment = BoxContainer.ALIGNMENT_END
			NotificationPosition.BOTTOM_LEFT:
				margin_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
				layout_container.alignment = BoxContainer.ALIGNMENT_BEGIN
			NotificationPosition.BOTTOM_CENTER:
				margin_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
				layout_container.alignment = BoxContainer.ALIGNMENT_CENTER
			NotificationPosition.BOTTOM_RIGHT:
				margin_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
				layout_container.alignment = BoxContainer.ALIGNMENT_END
			NotificationPosition.TOP_EDGE:
				margin_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
				layout_container.alignment = BoxContainer.ALIGNMENT_CENTER # Center items in wide banner
			NotificationPosition.BOTTOM_EDGE:
				margin_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
				layout_container.alignment = BoxContainer.ALIGNMENT_CENTER
			NotificationPosition.LEFT_EDGE: # Would typically use HBox and different anchor
				margin_container.set_anchors_preset(Control.PRESET_CENTER_LEFT) # Example, adjust
				# layout_container might be HBoxContainer here if items go side-by-side
				layout_container.alignment = BoxContainer.ALIGNMENT_CENTER
			NotificationPosition.RIGHT_EDGE: # Would typically use HBox
				margin_container.set_anchors_preset(Control.PRESET_CENTER_RIGHT) # Example, adjust
				layout_container.alignment = BoxContainer.ALIGNMENT_CENTER

		# Make the base_container only as big as its content by default for corners
		# For edges, it should expand.
		if position in [NotificationPosition.TOP_EDGE, NotificationPosition.BOTTOM_EDGE,
						NotificationPosition.LEFT_EDGE, NotificationPosition.RIGHT_EDGE]:
			base_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
			base_container.grow_vertical = Control.GROW_DIRECTION_BOTH
			if position in [NotificationPosition.LEFT_EDGE, NotificationPosition.RIGHT_EDGE]:
				layout_container = HBoxContainer.new() # Override for side-by-side
				margin_container.get_child(0).queue_free() # remove old VBox
				margin_container.add_child(layout_container)
				_containers[position] = layout_container
		#else: # For corners and center, don't grow, let content define size
			#base_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN  # GROW_DIRECTION_DISABLED
			#base_container.grow_vertical = Control.GROW_DIRECTION_BEGIN # GROW_DIRECTION_DISABLED
			#base_container.size = Vector2.ZERO # Shrink to content

	return _containers[position]

func _update_container_position(container: Control, position: NotificationPosition) -> void:
	container.get_parent().set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 0)
	match position:
		NotificationPosition.TOP_LEFT:
			container.get_parent().set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE, 0)
		NotificationPosition.TOP_CENTER:
			container.get_parent().set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_KEEP_SIZE, 0)
		NotificationPosition.TOP_RIGHT:
			container.get_parent().set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 0)
		NotificationPosition.CENTER_LEFT:
			container.get_parent().set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_KEEP_SIZE, 0)
		NotificationPosition.CENTER:
			container.get_parent().set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE, 0)
		NotificationPosition.CENTER_RIGHT:
			container.get_parent().set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 0)
		NotificationPosition.BOTTOM_LEFT:
			container.get_parent().set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_KEEP_SIZE, 0)
		NotificationPosition.BOTTOM_CENTER:
			container.get_parent().set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_KEEP_SIZE, 0)
		NotificationPosition.BOTTOM_RIGHT:
			container.get_parent().set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 0)
		NotificationPosition.TOP_EDGE:
			container.get_parent().set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_KEEP_SIZE, 0)
		NotificationPosition.BOTTOM_EDGE:
			container.get_parent().set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_KEEP_SIZE, 0)
		NotificationPosition.LEFT_EDGE: # Would typically use HBox and different anchor
			container.get_parent().set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_KEEP_SIZE, 0)
		NotificationPosition.RIGHT_EDGE: # Would typically use HBox
			container.get_parent().set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 0)
#endregion
