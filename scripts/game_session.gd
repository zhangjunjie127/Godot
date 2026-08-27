extends Node

const GENDER_MALE := "male"
const GENDER_FEMALE := "female"

var selected_gender := GENDER_MALE


func select_gender(value: String) -> void:
	selected_gender = GENDER_FEMALE if value == GENDER_FEMALE else GENDER_MALE
