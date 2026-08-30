extends SceneTree

const EXPECTED_BRANCHES := [
	["采集 · 石工", "石斧采集", "燧石加工", "藤蔓编织", "兽骨工具"],
	["建造 · 庇护", "草棚", "火堆", "木栅栏", "初级哨塔"],
	["战斗 · 狩猎", "木矛", "投石工具", "石刀", "陷阱制作"],
	["生存 · 命线", "采集食物", "净水", "保暖兽皮", "体力恢复"],
	["载具 · 驯兽", "驯兽入门", "制作鞍具", "驯服野猪", "木筏制作"],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var skill_tree = (load("res://scripts/skill_tree.gd") as Script).new()
	if skill_tree.BRANCHES.size() != 5 or skill_tree.get_total_skill_count() != 20:
		_fail("Primitive Era skill tree is not five branches with twenty nodes")
		return

	var total_cost := 0
	for branch_index: int in range(EXPECTED_BRANCHES.size()):
		var branch: Dictionary = skill_tree.BRANCHES[branch_index]
		var expected: Array = EXPECTED_BRANCHES[branch_index]
		if String(branch["name"]) != String(expected[0]) or (branch["skills"] as Array).size() != 4:
			_fail("Primitive Era branch layout does not match the design document")
			return
		for skill_index: int in range(4):
			var skill: Dictionary = branch["skills"][skill_index]
			if String(skill["name"]) != String(expected[skill_index + 1]):
				_fail("Primitive Era skill name mismatch")
				return
			total_cost += int(skill["cost"])
	if total_cost != 40:
		_fail("Primitive Era skill costs do not total 40 SP")
		return

	skill_tree.add_skill_points(40)
	for branch: Dictionary in skill_tree.BRANCHES:
		for skill: Dictionary in branch["skills"]:
			if not skill_tree.unlock_skill(String(skill["id"])):
				_fail("Could not unlock primitive skill: " + String(skill["id"]))
				return
	if skill_tree.is_ritual_ready():
		_fail("Ascension ignored the era proof and personally gathered core materials")
		return

	for material_id: String in skill_tree.RITUAL_CORE_MATERIALS:
		skill_tree.add_personal_material(material_id, int(skill_tree.RITUAL_CORE_MATERIALS[material_id]))
	skill_tree.add_era_proof("狂暴猿王")
	if not skill_tree.is_ritual_ready() or not skill_tree.unlock_skill(skill_tree.RITUAL_ID):
		_fail("Complete Primitive Era requirements did not activate Holy Fire Smelting")
		return
	if skill_tree.current_era != "青铜时代":
		_fail("Holy Fire Smelting did not advance to the Bronze Era")
		return

	print("PRIMITIVE_SKILL_TREE_OK")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
