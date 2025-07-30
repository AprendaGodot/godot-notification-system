extends MarginContainer

const ICON = preload('res://icon.svg')

@onready var top_left: Button = $VBoxContainer/CenterContainer/GridContainer/TopLeft
@onready var top_center: Button = $VBoxContainer/CenterContainer/GridContainer/TopCenter
@onready var top_right: Button = $VBoxContainer/CenterContainer/GridContainer/TopRight
@onready var center_left: Button = $VBoxContainer/CenterContainer/GridContainer/CenterLeft
@onready var center: Button = $VBoxContainer/CenterContainer/GridContainer/Center
@onready var center_right: Button = $VBoxContainer/CenterContainer/GridContainer/CenterRight
@onready var bottom_left: Button = $VBoxContainer/CenterContainer/GridContainer/BottomLeft
@onready var bottom_center: Button = $VBoxContainer/CenterContainer/GridContainer/BottomCenter
@onready var bottom_right: Button = $VBoxContainer/CenterContainer/GridContainer/BottomRight

@onready var default_toast: Button = $VBoxContainer/HBoxContainer/DefaultToast
@onready var clear_all: Button = $VBoxContainer/HBoxContainer/ClearAll
@onready var show_icon: CheckButton = $VBoxContainer/HBoxContainer/ShowIcon

@onready var back: Button = $VBoxContainer/Back

@onready var toast_queue_label: Label = $VBoxContainer2/ToastQueue
@onready var toast_actives_label: Label = $VBoxContainer2/ToastActives


var _count: int = 0
var _show_icon: bool = false


func _ready() -> void:
	# connections of the signals explicitly declared
	top_left.button_down.connect(_on_button_down_top_left)
	top_center.button_down.connect(_on_button_down_top_center)
	top_right.button_down.connect(_on_button_down_top_right)
	center_left.button_down.connect(_on_button_down_center_left)
	center.button_down.connect(_on_button_down_center)
	center_right.button_down.connect(_on_button_down_center_right)
	bottom_left.button_down.connect(_on_button_down_bottom_left)
	bottom_center.button_down.connect(_on_button_down_bottom_center)
	bottom_right.button_down.connect(_on_button_down_bottom_right)

	default_toast.button_down.connect(_on_button_down_default_toast)
	clear_all.button_down.connect(Notifications.clear_all)

	Notifications.toast_queue_changed.connect(_on_toast_queue_changed)
	Notifications.toast_actives_changed.connect(_on_toast_actives_changed)

	toast_queue_label.text = "Toast queue: 0"
	toast_actives_label.text = "Toast actives: 0/%d" % Notifications.get_max_visible_toasts()


func _on_toast_queue_changed(_toast_queue: Array[Dictionary]) -> void:
	toast_queue_label.text = "Toast queue: %d" % _toast_queue.size()


func _on_toast_actives_changed(active_toasts: Array[Node]) -> void:
	toast_actives_label.text = "Toast actives: %d/%d" % [active_toasts.size(), Notifications.get_max_visible_toasts()]


func _on_show_icon_toggled(toggled_on: bool) -> void:
	_show_icon = toggled_on

func _on_button_down_top_left() -> void:
	_count += 1
	Notifications.show_toast_adv({
		"title": "TOP_LEFT %d" % _count,
		"message": "on_button_down_top_left",
		"position": Notifications.NotificationPosition.TOP_LEFT,
		"icon": ICON if _show_icon else null,
	})


func _on_button_down_top_center() -> void:
	_count += 1
	Notifications.show_toast_adv({
		"title": "TOP_CENTER %d" % _count,
		"message": "on_button_down_top_center",
		"position": Notifications.NotificationPosition.TOP_CENTER,
		"icon": ICON if _show_icon else null,
	})


func _on_button_down_top_right() -> void:
	_count += 1
	Notifications.show_toast_adv({
		"title": "TOP_RIGHT %d" % _count,
		"message": "on_button_down_top_right",
		"position": Notifications.NotificationPosition.TOP_RIGHT,
		"icon": ICON if _show_icon else null,
	})


func _on_button_down_center_left() -> void:
	_count += 1
	Notifications.show_toast_adv({
		"title": "CENTER_LEFT %d" % _count,
		"message": "on_button_down_center_left",
		"position": Notifications.NotificationPosition.CENTER_LEFT,
		"icon": ICON if _show_icon else null,
	})


func _on_button_down_center() -> void:
	_count += 1
	Notifications.show_toast_adv({
		"title": "CENTER %d" % _count,
		"message": "on_button_down_center",
		"position": Notifications.NotificationPosition.CENTER,
		"icon": ICON if _show_icon else null,
	})


func _on_button_down_center_right() -> void:
	_count += 1
	Notifications.show_toast_adv({
		"title": "CENTER_RIGHT %d" % _count,
		"message": "on_button_down_center_right",
		"position": Notifications.NotificationPosition.CENTER_RIGHT,
		"icon": ICON if _show_icon else null,
	})


func _on_button_down_bottom_left() -> void:
	_count += 1
	Notifications.show_toast_adv({
		"title": "BOTTOM_LEFT %d" % _count,
		"message": "on_button_down_bottom_left",
		"position": Notifications.NotificationPosition.BOTTOM_LEFT,
		"icon": ICON if _show_icon else null,
	})


func _on_button_down_bottom_center() -> void:
	_count += 1
	Notifications.show_toast_adv({
		"title": "BOTTOM_CENTER %d" % _count,
		"message": "on_button_down_bottom_center",
		"position": Notifications.NotificationPosition.BOTTOM_CENTER,
		"icon": ICON if _show_icon else null,
	})


func _on_button_down_bottom_right() -> void:
	_count += 1
	Notifications.show_toast_adv({
		"title": "BOTTOM_RIGHT %d" % _count,
		"message": "on_button_down_bottom_right",
		"position": Notifications.NotificationPosition.BOTTOM_RIGHT,
		"icon": ICON if _show_icon else null,
	})


func _on_button_down_default_toast() -> void:
	_count += 1
	Notifications.show_toast("Default TOAST %d" % _count, "This is a defaul toast.", ICON if _show_icon else null,
	)

#func _on_button_down_top_left():
#	Notifications.show_toast("This is a notification with the [TOP_LEFT] position", "Top Left", 1)
