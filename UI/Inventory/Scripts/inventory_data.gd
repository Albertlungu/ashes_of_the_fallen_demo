extends Resource
class_name InventoryData

@export var slot_datas: Array[SlotData]

func add_item(slot_data_to_add: SlotData) -> bool:
	# Find first empty slot
	for i in range(slot_datas.size()):
		if slot_datas[i] == null:
			slot_datas[i] = slot_data_to_add
			return true
		
		# Check if stackable and same item
		if slot_datas[i].item_data == slot_data_to_add.item_data:
			if slot_datas[i].item_data.stackable:
				slot_datas[i].quantity += slot_data_to_add.quantity
				return true
	
	return false  # Inventory full

func has_item(item_name: String) -> bool:
	for slot_data in slot_datas:
		if slot_data and slot_data.item_data:
			if slot_data.item_data.name == item_name:
				return true
	return false

func remove_item(item_name: String) -> bool:
	for i in range(slot_datas.size()):
		if slot_datas[i] and slot_datas[i].item_data:
			if slot_datas[i].item_data.name == item_name:
				slot_datas[i] = null
				return true
	return false
