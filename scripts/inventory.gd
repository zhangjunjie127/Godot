class_name InventoryData
extends RefCounted

signal inventory_changed

const SLOT_COUNT := 20

var slots: Array[Dictionary] = []


func _init() -> void:
	for _index: int in range(SLOT_COUNT):
		slots.append({})
	add_item("stone_axe", "石斧", 1, 1)


func add_item(item_id: String, display_name: String, amount: int = 1, max_stack: int = 99) -> int:
	var remaining := maxi(amount, 0)
	for slot: Dictionary in slots:
		if remaining == 0:
			break
		if slot.get("id", "") != item_id or int(slot.get("count", 0)) >= int(slot.get("max_stack", max_stack)):
			continue
		var moved := mini(remaining, int(slot.get("max_stack", max_stack)) - int(slot.get("count", 0)))
		slot["count"] = int(slot.get("count", 0)) + moved
		remaining -= moved

	for index: int in range(slots.size()):
		if remaining == 0:
			break
		if not slots[index].is_empty():
			continue
		var moved := mini(remaining, maxi(max_stack, 1))
		slots[index] = {
			"id": item_id,
			"name": display_name,
			"count": moved,
			"max_stack": maxi(max_stack, 1),
		}
		remaining -= moved

	var added := maxi(amount, 0) - remaining
	if added > 0:
		inventory_changed.emit()
	return added


func remove_item(item_id: String, amount: int = 1) -> int:
	var remaining := mini(maxi(amount, 0), get_item_count(item_id))
	var removed := remaining
	for index: int in range(slots.size() - 1, -1, -1):
		if remaining == 0:
			break
		if slots[index].get("id", "") != item_id:
			continue
		var moved := mini(remaining, int(slots[index].get("count", 0)))
		slots[index]["count"] = int(slots[index].get("count", 0)) - moved
		remaining -= moved
		if int(slots[index].get("count", 0)) == 0:
			slots[index] = {}
	if removed > 0:
		inventory_changed.emit()
	return removed


func get_item_count(item_id: String) -> int:
	var total := 0
	for slot: Dictionary in slots:
		if slot.get("id", "") == item_id:
			total += int(slot.get("count", 0))
	return total
