extends Node3D

@onready var DaySetupUIScript = preload("res://Scripts/UI/DaySetupUI.gd")

func _enter_tree() -> void:
	# IMPORTANT: esto corre antes del _ready de los hijos.
	# Si venimos de cargar un save, NO reseteamos el estado preservado.
	if not RunState._coming_from_save:
		RunState.reset_run()

func _ready() -> void:
	var from_save := RunState._coming_from_save
	RunState._coming_from_save = false   # consumir el flag (one-shot)

	# Resetear managers solo en partida nueva (no al cargar guardado)
	if not from_save:
		StabilityManager.reset()
		FameManager.reset()
		EndingManager.reset()
		NPCRegistry.build_run_pool()   # sorteo de NPCs para esta run

	# ── PauseUI (vive toda la sesión, por encima de todo) ─────
	var pause_ui := PauseUI.new()
	pause_ui.name = "PauseUI"
	add_child(pause_ui)
	if pause_ui.has_signal("exit_to_menu_requested"):
		pause_ui.exit_to_menu_requested.connect(_on_exit_to_menu)

	# ── Deja SOLO 1 DaySetupUI (evita duplicados "debajo") ───
	var uis := get_tree().get_nodes_in_group("day_setup_ui")
	if uis.size() > 0:
		# quedarnos con la primera y borrar el resto
		for i in range(1, uis.size()):
			(uis[i] as Node).queue_free()
		# asegurarnos de nombre fijo
		(uis[0] as Node).name = "DaySetupUI"
		return

	# Si no existe ninguna, crearla
	var ui := DaySetupUIScript.new()
	ui.name = "DaySetupUI"
	add_child(ui)

func _on_exit_to_menu() -> void:
	SaveManager.save_slot(1)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
