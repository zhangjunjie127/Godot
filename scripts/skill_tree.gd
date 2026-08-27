class_name EraSkillTree
extends RefCounted

signal tree_changed
signal era_changed(era_name: String)

const RITUAL_ID := "ascension_ritual"
const BRANCHES := [
	{
		"id": "survival",
		"name": "生存类",
		"skills": [
			{"id": "survival_instinct", "name": "生存本能", "requires": []},
			{"id": "herbal_knowledge", "name": "草药辨识", "requires": ["survival_instinct"]},
			{"id": "endurance_training", "name": "耐力训练", "requires": ["herbal_knowledge"]},
			{"id": "wilderness_mastery", "name": "荒野大师", "requires": ["endurance_training"]},
		],
	},
	{
		"id": "technology",
		"name": "科技类",
		"skills": [
			{"id": "stone_tools", "name": "石器打磨", "requires": []},
			{"id": "rope_craft", "name": "绳结工艺", "requires": ["stone_tools"]},
			{"id": "primitive_building", "name": "原始建造", "requires": ["rope_craft"]},
			{"id": "bronze_smelting", "name": "青铜冶炼", "requires": ["primitive_building"]},
		],
	},
	{
		"id": "learning",
		"name": "学习类",
		"skills": [
			{"id": "observation", "name": "观察模仿", "requires": []},
			{"id": "language_symbols", "name": "语言符号", "requires": ["observation"]},
			{"id": "knowledge_legacy", "name": "知识传承", "requires": ["language_symbols"]},
			{"id": "civilization_awareness", "name": "文明启蒙", "requires": ["knowledge_legacy"]},
		],
	},
]

var skill_points := 12
var current_era := "原始时代"
var unlocked: Dictionary = {}


func can_unlock(skill_id: String) -> bool:
	if unlocked.has(skill_id):
		return false
	if skill_id == RITUAL_ID:
		return _all_skills_unlocked()
	var skill := _find_skill(skill_id)
	if skill.is_empty() or skill_points <= 0:
		return false
	for requirement: String in skill.get("requires", []):
		if not unlocked.has(requirement):
			return false
	return true


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


func get_total_skill_count() -> int:
	var total := 0
	for branch: Dictionary in BRANCHES:
		total += (branch["skills"] as Array).size()
	return total


func _all_skills_unlocked() -> bool:
	for branch: Dictionary in BRANCHES:
		for skill: Dictionary in branch["skills"]:
			if not unlocked.has(String(skill["id"])):
				return false
	return true


func _find_skill(skill_id: String) -> Dictionary:
	for branch: Dictionary in BRANCHES:
		for skill: Dictionary in branch["skills"]:
			if String(skill["id"]) == skill_id:
				return skill
	return {}
