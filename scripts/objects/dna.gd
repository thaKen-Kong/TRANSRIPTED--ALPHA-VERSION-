extends StaticBody2D
class_name DNA

signal minigame_completed(phase_name: String)

enum PHASES {
	PRE_INITIATION,
	INITIATION,
	ELONGATION,
	PARING,
	TERMINATION
}

var current_phase := PHASES.PRE_INITIATION

var dna_sequence_template : String = ""
var deliveries_required : int
var deliveries_done : int = 0

@export var mRNA_scene: PackedScene
@export var rna_polymerase_scene: PackedScene
@export var rna_spawn_position: Vector2 = Vector2(0, -64)
@export var elongation_speed: float = 0.15

@export var promoter_region_minigame: PackedScene
@export var rna_polymerase_minigame: PackedScene
@export var pre_termination_minigame: PackedScene 
@export var termination_minigame_scene: PackedScene

@onready var interaction_area: InteractionArea = $InteractionArea
@onready var drop_place: DropPlace = $PROMOTER_REGION
@onready var path_follow: PathFollow2D = $Path2D/PathFollow2D
@onready var termination_visual : Sprite2D = $TerminationSite
@onready var mRNA_Spawn : Marker2D = $mRNA_SPAWN_POINT
@onready var dna_template_strand : Label = $"PhaseLabel/Control/TEMPLATE/DNA TEMPLATE STRAND"
@onready var delivered_label : Label = $PhaseLabel/Control/TaskBar/DELIVERED
@onready var timer_label : Label = $PhaseLabel/Control/TaskBar/TIME_LEFT
@onready var rnap_spawn : Marker2D = $RNAP_SPAWNPOINT

var active_rnap: Node2D
var elongating := false
var spawned_nodes: Array[Node] = []

# ------------------------
func _ready():
	self.position = Vector2(0, -2000)
	delivered_label.text = "DELIVERED: " + str(deliveries_done) + "/" + str(deliveries_required)

	termination_visual.hide()
	if drop_place:
		drop_place.object_placed.connect(_on_drop_place_object_placed)
		drop_place.hide()

	# Make sure interaction area always exists and is initially active
	if interaction_area:
		interaction_area.interact = Callable(self, "_start_pre_initiation")
		interaction_area.set_process_input(true)

	_setup_phase(current_phase)

# ------------------------
func _process(delta: float):
	if current_phase != PHASES.ELONGATION or not elongating or not active_rnap:
		return

	path_follow.progress_ratio = clamp(path_follow.progress_ratio + elongation_speed * delta, 0.0, 1.0)
	active_rnap.global_position = path_follow.global_position
	_update_progress_bar()

	if path_follow.progress_ratio >= 1.0:
		_finish_elongation()

# ------------------------
func _setup_phase(phase: PHASES):
	match phase:
		PHASES.PRE_INITIATION:
			if interaction_area:
				interaction_area.set_process_input(true)
				interaction_area.interact = Callable(self, "_start_pre_initiation")
		PHASES.ELONGATION:
			_start_elongation()
		PHASES.PARING:
			_spawn_mRNA()

# ------------------------
func _start_pre_initiation():
	if interaction_area:
		interaction_area.set_process_input(false)  # Disable during minigame
	if promoter_region_minigame:
		var minigame_instance = promoter_region_minigame.instantiate()
		add_child(minigame_instance)
		spawned_nodes.append(minigame_instance)
		minigame_instance.minigame_finished.connect(_on_promoter_minigame_finished)

# ------------------------
func _on_promoter_minigame_finished(dna_sequence: String, promoter_index: int):
	current_phase = PHASES.INITIATION
	dna_template_strand.text = dna_sequence_template

	if rna_polymerase_scene:
		active_rnap = rna_polymerase_scene.instantiate()
		add_child(active_rnap)
		spawned_nodes.append(active_rnap)
		active_rnap.global_position = global_position + rna_spawn_position

	if drop_place:
		drop_place.show()

	# Re-enable interaction area after setup
	if interaction_area:
		interaction_area.set_process_input(true)

	_setup_phase(current_phase)

# ------------------------
func _on_drop_place_object_placed(obj: GrabbableObject):
	if current_phase != PHASES.INITIATION:
		return

	active_rnap = obj
	spawned_nodes.append(obj)
	obj.can_be_grabbed = false
	obj.is_held = false
	obj.holder = null
	obj.global_position = drop_place.global_position

	# Disable interaction area while minigame is active
	if interaction_area:
		interaction_area.set_process_input(false)

	if rna_polymerase_minigame:
		var mini = rna_polymerase_minigame.instantiate()
		add_child(mini)
		spawned_nodes.append(mini)

# ------------------------
func _on_phase_completed(phase_name: String):
	emit_signal("minigame_completed", phase_name)

	match phase_name:
		"PRE_INITIATION":
			current_phase = PHASES.INITIATION
			if rna_polymerase_scene:
				active_rnap = rna_polymerase_scene.instantiate()
				add_child(active_rnap)
				spawned_nodes.append(active_rnap)
				active_rnap.global_position = rnap_spawn.global_position
			if drop_place:
				drop_place.show()

		"INITIATION":
			if drop_place:
				drop_place.hide()
			current_phase = PHASES.ELONGATION
			termination_visual.show()

		"ELONGATION":
			elongating = false
			if pre_termination_minigame:
				var pre = pre_termination_minigame.instantiate()
				add_child(pre)
				spawned_nodes.append(pre)
			if termination_minigame_scene:
				var term_instance = termination_minigame_scene.instantiate()
				add_child(term_instance)
				spawned_nodes.append(term_instance)
				term_instance.termination_complete.connect(_on_termination_minigame_complete)

	_setup_phase(current_phase)

# ------------------------
func _on_termination_minigame_complete(success: bool):
	current_phase = PHASES.PARING
	termination_visual.show()
	print("Termination completed, now in PARING phase")
	_setup_phase(current_phase)

# ------------------------
func _start_elongation():
	if not active_rnap:
		return
	path_follow.progress_ratio = 0.0
	active_rnap.global_position = path_follow.global_position
	_fade_in_progress_bar()
	elongating = true

# ------------------------
func _update_progress_bar():
	var bar := active_rnap.get_node_or_null("ProgressBar")
	if bar:
		bar.value = path_follow.progress_ratio * 100.0

# ------------------------
func _finish_elongation():
	elongating = false
	_fade_out_progress_bar()
	_on_phase_completed("ELONGATION")

# ------------------------
func _fade_in_progress_bar():
	var bar := active_rnap.get_node_or_null("ProgressBar")
	if not bar:
		return
	bar.value = 0
	bar.visible = true
	bar.modulate.a = 0
	var tween := get_tree().create_tween()
	tween.tween_property(bar, "modulate:a", 1.0, 0.4)

# ------------------------
func _fade_out_progress_bar():
	var bar := active_rnap.get_node_or_null("ProgressBar")
	if not bar:
		return
	var tween := get_tree().create_tween()
	tween.tween_property(bar, "modulate:a", 0.0, 0.3)
	tween.finished.connect(func(): bar.visible = false)

# ------------------------
func _spawn_mRNA():
	if not mRNA_scene:
		push_error("No mRNA_scene assigned!")
		return
	var mRNA_instance = mRNA_scene.instantiate()
	add_child(mRNA_instance)
	spawned_nodes.append(mRNA_instance)
	mRNA_instance.global_position = mRNA_Spawn.global_position
	mRNA_instance.dna_sequence = dna_sequence_template
	print("mRNA spawned at:", mRNA_instance.global_position)

# ------------------------
# Restart transcription and clean up all spawned nodes
func restart_transcription():
	print("Restarting DNA transcription...")

	# Remove all spawned nodes except interaction area
	for node in spawned_nodes:
		if is_instance_valid(node):
			node.queue_free()
	spawned_nodes.clear()

	# Reset active RNA polymerase
	active_rnap = null
	elongating = false
	if path_follow:
		path_follow.progress_ratio = 0.0

	# Hide visuals
	if termination_visual:
		termination_visual.hide()
	if drop_place:
		drop_place.hide()

	# Reset phase
	current_phase = PHASES.PRE_INITIATION
	_setup_phase(current_phase)

	# Enable interaction area for next delivery
	if interaction_area:
		interaction_area.set_process_input(true)

# ------------------------
func _spawn_self():
	var tween = get_tree().create_tween()
	tween.tween_property(self, "position", Vector2(0, -774), 0.4).set_ease(Tween.EASE_OUT)
	await tween.finished
	get_tree().get_first_node_in_group("player").camera.start_shake(12,0.5)
