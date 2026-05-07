extends Node

# Autoloaded global game state. Holds the player's harvested Element wallet,
# the current phase, and cycle count. Scenes pull from here and listen to
# signals; this autoload never reaches into scene structure (avoids dangling
# references when scenes free).

signal phase_changed(new_phase: int)
signal wallet_changed
signal cycle_completed(cycles_so_far: int)

var phase: int = Phase.Type.EXPLORE
var cycles_completed: int = 0
var wallet: Dictionary = {} # Element.Type -> int


# §6: difficulty_multiplier = floor(cycles_completed / 3) + 1
func difficulty_multiplier() -> int:
	return cycles_completed / 3 + 1


func add_to_wallet(kind: int, amount: int) -> void:
	wallet[kind] = wallet.get(kind, 0) + amount
	wallet_changed.emit()


func advance_phase() -> void:
	phase = (phase + 1) % 4
	if phase == Phase.Type.EXPLORE:
		cycles_completed += 1
		cycle_completed.emit(cycles_completed)
	phase_changed.emit(phase)
