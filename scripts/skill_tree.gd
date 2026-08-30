class_name EraSkillTree
extends RefCounted

signal tree_changed
signal era_changed(era_name: String)

const RITUAL_ID := "ascension_ritual"
const RITUAL_NAME := "圣火冶炼"
const RITUAL_ERA_PROOFS := ["狂暴猿王", "毒沼巨鳄", "石甲猛犸兽王"]
const RITUAL_CORE_MATERIALS := {
	"flint": 1,
	"animal_bone": 1,
	"rough_hide": 1,
	"vine": 1,
}
const BRANCHES := [
	{
		"id": "gathering",
		"name": "采集 · 石工",
		"skills": [
			{"id": "stone_axe_gathering", "tier": 1, "name": "石斧采集", "effect": "木材产出 +1", "cost": 1, "requires": []},
			{"id": "flint_processing", "tier": 2, "name": "燧石加工", "effect": "解锁燧石、生火", "cost": 1, "requires": ["stone_axe_gathering"]},
			{"id": "vine_weaving", "tier": 3, "name": "藤蔓编织", "effect": "藤蔓转化为绳索", "cost": 2, "requires": ["flint_processing"]},
			{"id": "bone_tools", "tier": 4, "name": "兽骨工具", "effect": "兽骨利用率 +50%", "cost": 4, "requires": ["vine_weaving"]},
		],
	},
	{
		"id": "building",
		"name": "建造 · 庇护",
		"skills": [
			{"id": "grass_shelter", "tier": 1, "name": "草棚", "effect": "体温 +6/时", "cost": 1, "requires": []},
			{"id": "campfire", "tier": 2, "name": "火堆", "effect": "烹饪与取暖", "cost": 1, "requires": ["grass_shelter"]},
			{"id": "wooden_palisade", "tier": 3, "name": "木栅栏", "effect": "城墙 L1，耐久 200", "cost": 2, "requires": ["campfire"]},
			{"id": "watchtower", "tier": 4, "name": "初级哨塔", "effect": "防御塔 L1，攻击 8", "cost": 4, "requires": ["wooden_palisade", "flint_processing"]},
		],
	},
	{
		"id": "combat",
		"name": "战斗 · 狩猎",
		"skills": [
			{"id": "wooden_spear", "tier": 1, "name": "木矛", "effect": "近战 +5", "cost": 1, "requires": []},
			{"id": "throwing_tool", "tier": 2, "name": "投石工具", "effect": "远程 +8", "cost": 1, "requires": ["wooden_spear"]},
			{"id": "stone_knife", "tier": 3, "name": "石刀", "effect": "采集与战斗双用", "cost": 2, "requires": ["throwing_tool"]},
			{"id": "trap_making", "tier": 4, "name": "陷阱制作", "effect": "解锁陷坑，克制钻地", "cost": 4, "requires": ["stone_knife"]},
		],
	},
	{
		"id": "survival",
		"name": "生存 · 命线",
		"skills": [
			{"id": "forage_food", "tier": 1, "name": "采集食物", "effect": "解锁浆果与贝肉", "cost": 1, "requires": []},
			{"id": "clean_water", "tier": 2, "name": "净水", "effect": "清水恢复水分 +40", "cost": 1, "requires": ["forage_food"]},
			{"id": "warm_hide", "tier": 3, "name": "保暖兽皮", "effect": "御寒 +15", "cost": 2, "requires": ["clean_water"]},
			{"id": "stamina_recovery", "tier": 4, "name": "体力恢复", "effect": "静止恢复 +20%", "cost": 4, "requires": ["warm_hide"]},
		],
	},
	{
		"id": "vehicle",
		"name": "载具 · 驯兽",
		"skills": [
			{"id": "taming_basics", "tier": 1, "name": "驯兽入门", "effect": "解锁驯兽技能", "cost": 1, "requires": []},
			{"id": "saddle_making", "tier": 2, "name": "制作鞍具", "effect": "兽皮与藤蔓制作", "cost": 1, "requires": ["taming_basics"]},
			{"id": "tame_boar", "tier": 3, "name": "驯服野猪", "effect": "坐骑移动速度 +20%", "cost": 2, "requires": ["saddle_making"]},
			{"id": "raft_making", "tier": 4, "name": "木筏制作", "effect": "水路载具 +8 格", "cost": 4, "requires": ["tame_boar"]},
		],
	},
]

var skill_points := 12
var current_era := "原始时代"
var unlocked: Dictionary = {}
var era_proofs: Dictionary = {}
var personal_materials: Dictionary = {}


func can_unlock(skill_id: String) -> bool:
	if unlocked.has(skill_id):
		return false
	if skill_id == RITUAL_ID:
		return current_era == "原始时代" and _all_skills_unlocked() and has_era_proof() and has_ritual_materials()
	var skill := _find_skill(skill_id)
	if skill.is_empty() or skill_points < int(skill.get("cost", 1)):
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
		skill_points -= int(_find_skill(skill_id).get("cost", 1))
	tree_changed.emit()
	return true


func add_skill_points(amount: int) -> void:
	if amount <= 0:
		return
	skill_points += amount
	tree_changed.emit()


func add_era_proof(proof_name: String) -> bool:
	if proof_name not in RITUAL_ERA_PROOFS:
		return false
	era_proofs[proof_name] = true
	tree_changed.emit()
	return true


func add_personal_material(material_id: String, amount: int = 1) -> bool:
	if not RITUAL_CORE_MATERIALS.has(material_id) or amount <= 0:
		return false
	personal_materials[material_id] = int(personal_materials.get(material_id, 0)) + amount
	tree_changed.emit()
	return true


func is_unlocked(skill_id: String) -> bool:
	return unlocked.has(skill_id)


func is_ritual_ready() -> bool:
	return can_unlock(RITUAL_ID)


func has_era_proof() -> bool:
	for proof_name: String in RITUAL_ERA_PROOFS:
		if era_proofs.has(proof_name):
			return true
	return false


func has_ritual_materials() -> bool:
	for material_id: String in RITUAL_CORE_MATERIALS:
		if int(personal_materials.get(material_id, 0)) < int(RITUAL_CORE_MATERIALS[material_id]):
			return false
	return true


func get_ritual_material_count() -> int:
	var ready := 0
	for material_id: String in RITUAL_CORE_MATERIALS:
		if int(personal_materials.get(material_id, 0)) >= int(RITUAL_CORE_MATERIALS[material_id]):
			ready += 1
	return ready


func get_ritual_missing_requirements() -> Array[String]:
	var missing: Array[String] = []
	if not _all_skills_unlocked():
		missing.append("技能节点 %d/%d" % [get_unlocked_skill_count(), get_total_skill_count()])
	if not has_era_proof():
		missing.append("时代之证")
	if not has_ritual_materials():
		missing.append("本人采集核心材料 %d/%d" % [get_ritual_material_count(), RITUAL_CORE_MATERIALS.size()])
	return missing


func get_unlocked_skill_count() -> int:
	var total := 0
	for branch: Dictionary in BRANCHES:
		for skill: Dictionary in branch["skills"]:
			if unlocked.has(String(skill["id"])):
				total += 1
	return total


func get_total_skill_count() -> int:
	var total := 0
	for branch: Dictionary in BRANCHES:
		total += (branch["skills"] as Array).size()
	return total


func get_total_skill_cost() -> int:
	var total := 0
	for branch: Dictionary in BRANCHES:
		for skill: Dictionary in branch["skills"]:
			total += int(skill.get("cost", 1))
	return total


func _all_skills_unlocked() -> bool:
	return get_unlocked_skill_count() == get_total_skill_count()


func _find_skill(skill_id: String) -> Dictionary:
	for branch: Dictionary in BRANCHES:
		for skill: Dictionary in branch["skills"]:
			if String(skill["id"]) == skill_id:
				return skill
	return {}
