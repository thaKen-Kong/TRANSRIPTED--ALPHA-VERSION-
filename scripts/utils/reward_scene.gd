extends CanvasLayer
class_name RewardScene

# =========================
# DATA FROM GAME_LEVEL
# =========================
var deliveries_done: int
var deliveries_required: int
var time_left: float
var reward_per_delivery: int

# =========================
# UI
# =========================
@onready var deliveries_label: Label = $Control/DELIVERIES
@onready var atp_label: Label = $Control/DELIVERIES2
@onready var total_label: Label = $Control/DELIVERIES3
@onready var finish_button: Button = $Control/FINISH

# =========================
func _ready() -> void:
	_calculate_rewards()
	finish_button.pressed.connect(_on_finish_pressed)

# =========================
func _calculate_rewards() -> void:
	var delivery_reward := deliveries_done * reward_per_delivery
	var time_bonus := int(max(time_left, 0))
	var total := delivery_reward + time_bonus

	deliveries_label.text = \
		"DELIVERIES : %d / %d" % [deliveries_done, deliveries_required]

	atp_label.text = "ATP LEFT : %d" % time_bonus
	total_label.text = "TOTAL : %d" % total

# =========================
func _on_finish_pressed() -> void:
	queue_free()
