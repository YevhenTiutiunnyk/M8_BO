class_name MatchState
extends RefCounted

## Pure scoring / half / winner logic for a 2-player match.
## Two halves; first to GOALS_TO_WIN_HALF goals wins a half.
## Overall winner = more halves won, tiebreak by total goals.
## Player numbers are 1 and 2; arrays are indexed [p1, p2].

const GOALS_TO_WIN_HALF := 3
const TOTAL_HALVES := 2
const BLOWS_PER_HALF := 2

var current_half: int = 1
var half_goals: Array[int] = [0, 0]
var halves_won: Array[int] = [0, 0]
var total_goals: Array[int] = [0, 0]
var blows_left: Array[int] = [BLOWS_PER_HALF, BLOWS_PER_HALF]
var finished: bool = false
var winner: int = 0  # 0 = none/draw, else player number

func reset() -> void:
	current_half = 1
	half_goals = [0, 0]
	halves_won = [0, 0]
	total_goals = [0, 0]
	blows_left = [BLOWS_PER_HALF, BLOWS_PER_HALF]
	finished = false
	winner = 0

func is_cruijff_half() -> bool:
	return current_half == 2

## Record a goal. Returns what happened:
##   {"goal": player, "half_over": bool, "match_over": bool, "half_winner": int}
func score_goal(player: int) -> Dictionary:
	var result := {"goal": player, "half_over": false, "match_over": false, "half_winner": 0}
	if finished:
		return result
	var i := player - 1
	half_goals[i] += 1
	total_goals[i] += 1
	if half_goals[i] >= GOALS_TO_WIN_HALF:
		halves_won[i] += 1
		result["half_over"] = true
		result["half_winner"] = player
		if current_half >= TOTAL_HALVES:
			_finish_match()
			result["match_over"] = true
		else:
			_start_next_half()
	return result

func _start_next_half() -> void:
	current_half += 1
	half_goals = [0, 0]
	blows_left = [BLOWS_PER_HALF, BLOWS_PER_HALF]

func _finish_match() -> void:
	finished = true
	if halves_won[0] > halves_won[1]:
		winner = 1
	elif halves_won[1] > halves_won[0]:
		winner = 2
	elif total_goals[0] > total_goals[1]:
		winner = 1
	elif total_goals[1] > total_goals[0]:
		winner = 2
	else:
		winner = 0  # genuine draw

## Consume one Cruijff Turn for the player. Returns true if a use was available
## (only in the second half).
func try_blow(player: int) -> bool:
	if not is_cruijff_half():
		return false
	var i := player - 1
	if blows_left[i] <= 0:
		return false
	blows_left[i] -= 1
	return true
