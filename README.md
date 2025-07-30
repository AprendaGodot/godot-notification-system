# Godot Notification System (GNS)

<p align="center">
  <a href="https://godotengine.org/download/windows/">
	  <img alt="Static Badge" src="https://img.shields.io/badge/Godot-4.1.1-blue">
  </a>
  <a href="LICENSE">
	<img alt="GitHub License" src="https://img.shields.io/github/license/AprendaGodot/godot-notification-system">
  </a>
</p>

A flexible and developer-friendly UI notification system for the Godot Engine. Display toasts, banners, and dialogs with ease using a clean API and customizable scenes.

## Motivation & Philosophy

In many games, providing feedback to the player without disrupting gameplay is crucial. Existing UI solutions often require significant boilerplate or tightly couple notification logic with specific UI implementations.

GNS aims to provide a **robust, centralized system** for managing UI notifications, inspired by modern UI frameworks and guided by Godot's core principles:

*   **Developer Experience:** A simple, high-level API via an Autoload Singleton makes triggering notifications trivial.
*   **UI Agnostic Core:** The plugin manages the *lifecycle* and *placement*, you define the *look* via scenes.
*   **Composition over Inheritance:** Customize notifications using standard Godot scenes. No complex class hierarchies to learn.
*   **Beautiful Defaults:** Clean, functional default notification styles are included, working immediately after installation.
*   **Open Code & AI-Ready:** Full GDScript source and scene files provided for transparency, easy customization, and potential AI analysis/generation.

## Features

*   **Toast Notifications:** Display non-modal, timed messages (ideal for item pickups, quick updates, achievements). Automatic queuing and screen position management.
*   **Banner Notifications:** Show edge-aligned messages (top/bottom) that can be timed or persistent (ideal for announcements, critical alerts).
*   **Modal Dialogs:** Present interruptive dialogs for confirmations, critical errors, or important choices.
*   **Configuration:** Set defaults for duration, screen position, and styles via Project Settings or code.
*   **Simple API:** Trigger notifications with single function calls from anywhere in your code via the `Notifications` Autoload.
*   **Easy Customization:** Replace default notification appearances by simply providing your own `PackedScene`. Register multiple styles (e.g., "default", "warning", "achievement").
*   **Queue Management:** Handles multiple simultaneous toast notifications gracefully.

## Planned Features (Roadmap)
*   [ ] Asynchronous Dialog Handling (`await Notifications.show_dialog(...)`).
*   [ ] Project settings for default values.
*   [ ] More Default Styles & Examples.
*   [ ] Advanced Animation Hooks (Control animation via Callables/Signals).
*   [ ] Integration with Godot's Theme system for easier styling of defaults.
*   [ ] Support for RichTextLabel in default templates.

## Installation

1.  **Download:** Get the latest release from the [Releases](link-to-releases) page or the Godot Asset Library (link-to-assetlib).
2.  **Extract:** Unzip the archive.
3.  **Copy:** Copy the `addons/godot_notification_system` folder into your Godot project's root directory.
4.  **Enable:** Go to `Project -> Project Settings -> Plugins` and enable the "Godot Notification System" plugin. This will automatically register the `Notifications` Autoload Singleton.

## Usage

After enabling the plugin, you can access the notification system globally via the `Notifications` singleton.

**Showing a simple Toast:**

```gdscript
func _on_item_pickup():
	Notifications.show_toast("Health Potion Acquired!", "Your health is restored slightly.")
```

**Showing a Toast with advanced Options:**

Config can include: 
- title: String
- message: String
- icon: Texture2D
- duration: float
- position: NotificationPosition,
- custom_data: Variant
```gdscript
	Notifications.show_toast_adv({
		"title": "New item acquired !",
		"message": "Sword",
		"position": Notifications.NotificationPosition.CENTER_RIGHT,
		"icon": SWORD_ICON,
		"duration": 5.0,
	})
```

```gdscript
	Notifications.show_toast("Health Potion Acquired", "Your health is restored slightly.")
```

**Showing a Persistent Banner:**

```gdscript
func _on_server_maintenance_start():
	Notifications.show_banner("Server maintenance starting in 5 minutes.", -1.0, null, &"server_maint_warning") # duration -1.0 with ID makes it persistent
```

**Dismissing the Banner:**

```gdscript
func _on_server_maintenance_end():
	Notifications.dismiss_banner(&"server_maint_warning")
```

**Showing a Confirmation Dialog:**

```gdscript
func _on_quit_button_pressed():
	var signal = Notifications.show_dialog_simple("Confirm Quit", "Are you sure you want to exit?", ["Yes", "No"])
	var result = await signal
	if result == "Yes":
		get_tree().quit()
```
