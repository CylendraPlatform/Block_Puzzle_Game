class_name ClassicScore
extends RefCounted
## Classic scoring counter (M1.3 plan §6.1, decision D2). Owned by the game screen and kept
## separate from PuzzleState: the engine's move_number rewinds on Undo, the score does not.

var moves := 0

## Call only for an action the session accepted; rejected actions never count.
func on_commit() -> void:
	moves += 1

## Undo never refunds a scoring move.
func on_undo() -> void:
	pass

## Restart starts the count again, like the legacy reload.
func on_restart() -> void:
	moves = 0

## Stars for a win with this score, using the unchanged Classic formula.
func stars(par: int) -> int:
	return Catalog.star_rating(moves, par)
