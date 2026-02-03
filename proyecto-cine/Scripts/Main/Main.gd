extends Node3D

@onready var DaySetupUIScript = preload("res://Scripts/UI/DaySetupUI.gd")

func _enter_tree() -> void:
	# IMPORTANT: esto corre antes del _ready de los hijos
	RunState.reset_run()

func _ready() -> void:
	# Deja SOLO 1 DaySetupUI (evita duplicados “debajo”)
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
