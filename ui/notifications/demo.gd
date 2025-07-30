extends Control

var toast_count: int = 0

func _on_item_pickup():
	print('click')
	toast_count += 1
	print("Health Potion Acquired! %d" % [toast_count])
	Notifications.show_toast("Health Potion Acquired%d" % [toast_count], "Your health is restored slightly.")


func _on_server_maintenance_start():
	Notifications.show_banner("Server maintenance starting in 5 minutes.", -1.0, null, &"server_maint_warning") # duration -1.0 with ID makes it persistent

func _on_server_maintenance_end():
	Notifications.dismiss_banner(&"server_maint_warning")


func _on_quit_button_pressed():
	var result = await Notifications.show_dialog_simple("Confirm Quit", "Are you sure you want to exit?", ["Yes", "No"])
	if result == "Yes":
		get_tree().quit()
