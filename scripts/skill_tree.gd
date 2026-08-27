class_name EraSkillTree
extends RefCounted

signal tree_changed
signal era_changed(era_name: String)

const RITUAL_ID := "ascension_ritual"
const SKILLS := [
	{"id": "survival", "name": "生存本能"},
	{"id": "gathering", "name": "采集技艺"},
	{"id": "building", "name": "建造基础"},
	{"id": "hunting", "name": "狩猎训练"},
	{"id": "defense", "name": "守城准备"},
	{"id": RITUAL_ID, "name": "升维仪式", "ritual": true},
]

var skill_points := 5
var current_era := "原始时代"
var unlocked: Dictionary = {}


func can_unlock(skill_id: String) -> bool:
	var index := _skill_index(skill_id)
	if index < 0 or unlocked.has(skill_id):
		return false
	if skill_id == RITUAL_ID:
		return _all_normal_skills_unlocked()
	return skill_points > 0 and (index == 0 or unlocked.has(String(SKILLS[index - 1]["id"])))


func unlock_skill(skill_id: String) -> bool:
	if not can_unlock(skill_id):
		return false
	unlocked[skill_id] = true
	if skill_id == RITUAL_ID:
		current_era = "青铜时代"
		era_changed.emit(current_era)
	else:
		skill_points -= 1
	tree_changed.emit()
	return true


func is_unlocked(skill_id: String) -> bool:
	return unlocked.has(skill_id)


func is_ritual_ready() -> bool:
	return can_unlock(RITUAL_ID)


func _all_normal_skills_unlocked() -> bool:
	for index: int in range(SKILLS.size() - 1):
		if not unlocked.has(String(SKILLS[index]["id"])):
			return false
	return true


func _skill_index(skill_id: String) -> int:
	for index: int in range(SKILLS.size()):
		if String(SKILLS[index]["id"]) == skill_id:
			return index
	return -1
