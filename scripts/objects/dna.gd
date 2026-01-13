extends StaticBody2D
class_name DNA

# =========================
# SIGNALS
# =========================
signal minigame_completed(phase_name: String)

# =========================
# PHASES
# =========================
enum PHASES {
	PRE_INITIATION,
	INITIATION,
	ELONGATION,
	PARING,
	TERMINATION
}

var current_phase: PHASES = PHASES.PRE_INITIATION

# =========================
# STATE FLAGS
# =========================
var pre_initiation_used := false
var elongating := false

# =========================
# DATA
# =========================
var dna_sequence_template := ""
var deliveries_done := 0
@export var deliveries_required := 1

# =========================
# SCENES
# =========================
@export var mRNA_scene: PackedScene
@export var rna_polymerase_scene: PackedScene
@export var promoter_region_minigame: PackedScene
@export var rna_polymerase_minigame: PackedScene
@export var pre_termination_minigame: PackedScene
@export var termination_minigame_scene: PackedScene

# =========================
# CONFIG
# =========================
@export var elongation_speed := 0.15
@export var rna_spawn_position := Vector2(0, -64)

# =========================
# NODES
# =========================
@onready var interaction_area: InteractionArea = $InteractionArea
@onready var drop_place: DropPlace = $PROMOTER_REGION
@onready var path_follow: PathFollow2D = $Path2D/PathFollow2D
@onready var termination_visual: Sprite2D = $TerminationSite
@onready var mRNA_spawn: Marker2D = $mRNA_SPAWN_POINT
@onready var rnap_spawn: Marker2D = $RNAP_SPAWNPOINT

@onready var dna_label: Label = $"PhaseLabel/Control/TEMPLATE/DNA TEMPLATE STRAND"
@onready var delivered_label: Label = $PhaseLabel/Control/TaskBar/DELIVERED

# =========================
# RUNTIME
# =========================
var active_rnap: Node2D
var spawned_nodes: Array[Node] = []

# =========================
# READY
# =========================
func _ready() -> void:
	self.position = Vector2(0, -2000)

	delivered_label.text = "DELIVERED: %d/%d" % [deliveries_done, deliveries_required]
	termination_visual.hide()
	drop_place.hide()

	if interaction_area:
		interaction_area.interact = Callable(self, "_on_interact")

	if drop_place:
		drop_place.object_placed.connect(_on_drop_place_object_placed)

	_enter_phase(PHASES.PRE_INITIATION)

# =========================
# PROCESS
# =========================
func _process(delta: float) -> void:
	if current_phase != PHASES.ELONGATION or not elongating or not active_rnap:
		return

	path_follow.progress_ratio = min(
		path_follow.progress_ratio + elongation_speed * delta,
		1.0
	)

	active_rnap.global_position = path_follow.global_position
	_update_progress_bar()

	if path_follow.progress_ratio >= 1.0:
		_finish_elongation()

# =========================
# INTERACTION ENTRY POINT
# =========================
func _on_interact() -> void:
	match current_phase:
		PHASES.PRE_INITIATION:
			_try_start_pre_initiation()

# =========================
# PRE-INITIATION
# =========================
func _try_start_pre_initiation() -> void:
	if pre_initiation_used:
		return

	pre_initiation_used = true

	var mini := promoter_region_minigame.instantiate()
	add_child(mini)
	spawned_nodes.append(mini)
	mini.minigame_finished.connect(_on_promoter_minigame_finished)

func _on_promoter_minigame_finished(dna_sequence: String, _index: int) -> void:
	dna_sequence_template = dna_sequence
	dna_label.text = dna_sequence_template
	_enter_phase(PHASES.INITIATION)

# =========================
# INITIATION
# =========================
func _on_drop_place_object_placed(obj: GrabbableObject) -> void:
	if current_phase != PHASES.INITIATION:
		return

	active_rnap = obj
	obj.can_be_grabbed = false
	obj.is_held = false
	obj.global_position = drop_place.global_position

	_enter_phase(PHASES.ELONGATION)

# =========================
# ELONGATION
# =========================
func _start_elongation() -> void:
	if not active_rnap:
		return

	path_follow.progress_ratio = 0.0
	active_rnap.global_position = path_follow.global_position
	_fade_in_progress_bar()
	elongating = true

func _finish_elongation() -> void:
	elongating = false
	_fade_out_progress_bar()
	_enter_phase(PHASES.TERMINATION)

# =========================
# TERMINATION
# =========================
func _on_termination_complete(_success: bool) -> void:
	_enter_phase(PHASES.PARING)

# =========================
# PARING
# =========================
func _spawn_mRNA() -> void:
	var mrna := mRNA_scene.instantiate()
	add_child(mrna)
	spawned_nodes.append(mrna)
	mrna.global_position = mRNA_spawn.global_position
	mrna.dna_sequence = dna_sequence_template

# =========================
# PHASE CONTROLLER
# =========================
func _enter_phase(phase: PHASES) -> void:
	current_phase = phase

	match phase:
		PHASES.PRE_INITIATION:
			pre_initiation_used = false

		PHASES.INITIATION:
			_spawn_rnap()
			drop_place.show()

		PHASES.ELONGATION:
			drop_place.hide()
			termination_visual.show()
			_start_elongation()

		PHASES.TERMINATION:
			var term := termination_minigame_scene.instantiate()
			add_child(term)
			spawned_nodes.append(term)
			term.termination_complete.connect(_on_termination_complete)

		PHASES.PARING:
			_spawn_mRNA()

# =========================
# HELPERS
# =========================
func _spawn_rnap() -> void:
	active_rnap = rna_polymerase_scene.instantiate()
	add_child(active_rnap)
	spawned_nodes.append(active_rnap)
	active_rnap.global_position = rnap_spawn.global_position

func _update_progress_bar() -> void:
	var bar := active_rnap.get_node_or_null("ProgressBar")
	if bar:
		bar.value = path_follow.progress_ratio * 100.0

func _fade_in_progress_bar() -> void:
	var bar := active_rnap.get_node_or_null("ProgressBar")
	if not bar:
		return
	bar.visible = true
	bar.modulate.a = 0.0
	get_tree().create_tween().tween_property(bar, "modulate:a", 1.0, 0.4)

func _fade_out_progress_bar() -> void:
	var bar := active_rnap.get_node_or_null("ProgressBar")
	if not bar:
		return
	var tween := get_tree().create_tween()
	tween.tween_property(bar, "modulate:a", 0.0, 0.3)
	tween.finished.connect(func(): bar.visible = false)

# =========================
# RESET
# =========================
func restart_transcription() -> void:
	for node in spawned_nodes:
		if is_instance_valid(node):
			node.queue_free()

	spawned_nodes.clear()
	active_rnap = null
	elongating = false
	path_follow.progress_ratio = 0.0
	drop_place.hide()
	termination_visual.hide()

	_enter_phase(PHASES.PRE_INITIATION)
