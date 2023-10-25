extends Control

@onready var var_name_node = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/VarName
@onready var var_type_node = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/VarType
@onready var var_value_node = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/VarValue

@onready var var_list = $MarginContainer/HBoxContainer/VBoxContainer/VarList

@onready var error_label = $MarginContainer/HBoxContainer/VBoxContainer2/ErrorLabel

var variable_list: Array[Variable] = []
var USING_SIGNED: bool = true

func _ready():
	hide_error()
	
	print(
		compute_operation(VAR_TYPE.WORD, Token.new(TOKEN_TYPE.OPERATOR, "-"), VAR_TYPE.BYTE).asm
	)

func hide_error():
	error_label.text = "Error: "
	error_label.visible = false

func show_error(error: String):
	printerr(error)
	error_label.text = "Error: " + error 
	error_label.visible = true

func _on_add_var_pressed():
	var vname: String = var_name_node.text
	vname.replace(" ", "")
	var_name_node.text = ""
	var vtype: VAR_TYPE = var_type_node.get_selected_id()
	var vvalue: int = int(var_value_node.value)
	if (vname.replace(" ", "") == ""):
		return
	var variable: Variable = Variable.new(
		vname.to_lower(),
		vtype,
		vvalue
	)
	
	
	var i = 0
	for v in variable_list:
		if (v.var_name == variable.var_name):
			update_variable(i, variable)
			return
		i += 1
			
	add_variable_to_list(variable)

func add_variable_to_list(variable: Variable):
	variable_list.append(variable)
	var_list.add_item(variable.var_name + " " + type_to_string(variable.type) + " " + str(variable.value), null, true)

func update_variable(index: int, variable: Variable):
	variable_list[index] = variable
	var_list.set_item_text(index, variable.var_name + " " + type_to_string(variable.type) + " " + str(variable.value))

func _on_rmv_var_pressed():
	var arr: PackedInt32Array = var_list.get_selected_items()
	if (arr.size() == 0): return
	variable_list.remove_at(arr[0])
	var_list.remove_item(arr[0])
	# idk if the array can have more than 1 value
	# but if it can i should reverse the array
	# and eliminate all of me.. (TODO ig)
		

# UTILS

class Variable:
	var var_name: String
	var type: VAR_TYPE
	var value: int
	
	func _init(p_name: String, p_type: VAR_TYPE, p_value: int):
		var_name = p_name
		type = p_type
		value = p_value

enum VAR_TYPE {
	BYTE,
	WORD,
	DOUBLEWORD,
	QUARDWORD
}

func type_to_string(type: VAR_TYPE) -> String:
	if (type == VAR_TYPE.BYTE):
		return "byte"
	if (type == VAR_TYPE.WORD):
		return "word"
	if (type == VAR_TYPE.DOUBLEWORD):
		return "dword"
	if (type == VAR_TYPE.QUARDWORD):
		return "qword"
	return "NaT" # Not a Type :skull:

"""
	PARSER
"""

var prs_operators: Array[String] = ["+", "-", "*", "/"]
var prs_digits: Array[String] = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
var prs_wrappers: Array[String] = ["(", ")"]

func parse(input: String):
	var inp = input.replace(" ", "")
	var token_list: Array[Token] = tokenize(inp)
	if (token_list.size() == 0): return
	for token in token_list:
		if (token.type == TOKEN_TYPE.NUMBER):
			token.value_size = get_size_from_value(int(token.value), USING_SIGNED)
			token.signed = USING_SIGNED
		if (token.type == TOKEN_TYPE.VARIABLE):
			var variable: Variable = null
			for v in variable_list:
				if (v.var_name == token.value):
					variable = v 
					break 
			if (variable == null):
				show_error("Undifined variable " + token.value)
				return
			token.value_size = variable.type
			token.signed = USING_SIGNED
			# TODO: CHECK IF VARIABLE VALUE OVERFLOWS
			
	print(token_list)

"""
func compute_token_slice(slice: Array[Token]) -> String:
	var result: String = ""
	var ok_w: bool = true
	var ok_h: bool = true
	var ok_l: bool = true
	while true:
		
		for i in range(0, slice.size()):
			if (slice[i].type == TOKEN_TYPE.WRAPPER):
				var j := slice.find(slice[i].pointer)
				var new_slice = slice.slice(i + 1, j - 1)
				var r = compute_token_slice(new_slice)
				result += r
		
		if (ok_w == true):
			break
	
	return result
"""

# OPERATION UTILS
func ascend_mem(mem_size: VAR_TYPE) -> String:
	var res: String = ""
	if (mem_size == VAR_TYPE.BYTE):
		if (USING_SIGNED):
			res += "pop AX\n"
			res += "cbw\n"
			res += "push AX\n"
		else:
			res += "pop AX\n"
			res += "mov AH, 0h\n"
			res += "push AX\n"
	if (mem_size == VAR_TYPE.WORD):
		if (USING_SIGNED):
			res += "pop AX\n"
			res += "cwd\n"
			res += "push DX\n"
			res += "push AX\n"
		else:
			res += "mov EAX, 0h\n"
			res += "pop AX\n"
			res += "push EAX\n"
	if (mem_size == VAR_TYPE.DOUBLEWORD):
		if (USING_SIGNED):
			res += "pop EAX\n"
			res += "cdq\n"
			res += "push EDX\n"
			res += "push EAX\n"
		else:
			res += "mov EAX, 0h\n"
			res += "push EAX"
	return res

func push_var_to_stack(value: String, memsize: VAR_TYPE) -> String:
	var res: String = ""
	if (memsize == VAR_TYPE.BYTE):
		res += "mov AL, BYTE [" + value + "]\n"
		res += "push AX\n"
	if (memsize == VAR_TYPE.WORD):
		res += "mov AX, WORD [" + value + "]\n"
		res += "push AX\n"
	if (memsize == VAR_TYPE.DOUBLEWORD):
		res += "mov EAX, DWORD [" + value + "]\n"
		res += "push EAX\n"
	if (memsize == VAR_TYPE.QUARDWORD):
		res += "mov EAX, DWORD [" + value + " + 4]\n"
		res += "push EAX\n"
		res += "mov EAX, DWORD [" + value + " + 0]\n"
		res += "push EAX\n"
	return res

func swap_in_stack(a: VAR_TYPE, b: VAR_TYPE) -> String:
	# A SHOULD BE LOWER THAN B IN STACK
	var res: String = ""
	if (b == VAR_TYPE.BYTE):
		res += "pop AX\n"
	if (b == VAR_TYPE.WORD):
		res += "pop AX\n"
	if (b == VAR_TYPE.DOUBLEWORD):
		res += "pop EAX\n"
	if (b == VAR_TYPE.QUARDWORD):
		res += "pop EAX\n"
		res += "pop EDX\n"
	
	if (a == VAR_TYPE.BYTE):
		res += "pop BX\n"
	if (a == VAR_TYPE.WORD):
		res += "pop BX\n"
	if (a == VAR_TYPE.DOUBLEWORD):
		res += "pop EBX\n"
	if (a == VAR_TYPE.QUARDWORD):
		res += "pop EBX\n"
		res += "pop ECX\n"
	
	if (b == VAR_TYPE.BYTE):
		res += "push AX\n"
	if (b == VAR_TYPE.WORD):
		res += "push AX\n"
	if (b == VAR_TYPE.DOUBLEWORD):
		res += "push EAX\n"
	if (b == VAR_TYPE.QUARDWORD):
		res += "push EDX\n"
		res += "push EAX\n"
	
	if (a == VAR_TYPE.BYTE):
		res += "push BX\n"
	if (a == VAR_TYPE.WORD):
		res += "push BX\n"
	if (a == VAR_TYPE.DOUBLEWORD):
		res += "push EBX\n"
	if (a == VAR_TYPE.QUARDWORD):
		res += "push ECX\n"
		res += "push EBX\n"
		
	return res

func compute_operation(a: VAR_TYPE, operand: Token, b: VAR_TYPE) -> OperationResul:
	# IN STACK A SHOULD BE LOWER THAN B
	var asm: String = ""
	if (operand.value == "+"):
		return compute_addition(a, b)
	if (operand.value == "-"):
		return compute_substraction(a, b)
	
	show_error("Something went terribly wrong in the compute operation function")
	return OperationResul.new(VAR_TYPE.WORD, "")

func compute_addition(a: VAR_TYPE, b: VAR_TYPE):
	var asm: String = ""
	while (b < a):
		asm += ascend_mem(b)
		b += 1
	asm += swap_in_stack(a, b)
	# NOW B I LOWER THAN A
	while (a < b):
		asm += ascend_mem(a)
		a += 1
		
	if (a != b):
		show_error("Something went terribly wrong in the compute addition function (+)")
		return OperationResul.new(VAR_TYPE.WORD, "")
		
	if (a == VAR_TYPE.BYTE):
		asm += "pop AX\n"
		asm += "pop DX\n"
		if (USING_SIGNED):
			asm += "cbw\n"
		else:
			asm += "mov AH, 0h\n"
		asm += "add AL, DL\n"
		asm += "adc AH, 0h\n"
		asm += "push AX\n"
		return OperationResul.new(VAR_TYPE.WORD, asm)
		
	if (a == VAR_TYPE.WORD):
		asm += "pop AX\n"
		asm += "pop BX\n"
		asm += "add AX, BX\n"
		if (USING_SIGNED):
			asm += "cwd\n"
		else:
			asm += "mov DX, 0h\n"
		asm += "adc DX, 0h\n"
		asm += "push DX\n"
		asm += "push AX\n"
		return OperationResul.new(VAR_TYPE.DOUBLEWORD, asm)
		
	if (a == VAR_TYPE.DOUBLEWORD):
		# WE DONT REALLY CARE ABOUT OVERFLOW ANY MORE
		asm += "pop EAX\n"
		asm += "pop EDX\n"
		asm += "add EAX, EDX\n"
		asm += "push EAX\n"
		return OperationResul.new(VAR_TYPE.DOUBLEWORD, asm)
	
	if (a == VAR_TYPE.QUARDWORD):
		asm += "pop EAX\n"
		asm += "pop EDX\n"
		asm += "pop EBX\n"
		asm += "pop ECX\n"
		asm += "add EAX, EBX\n"
		asm += "adc EDX, ECX\n"
		asm += "push EDX\n"
		asm += "push EAX\n"
		return OperationResul.new(VAR_TYPE.QUARDWORD, asm)
	
	show_error("Something went terribly wrong in the compute addition function (+)")
	return OperationResul.new(VAR_TYPE.WORD, "")

func compute_substraction(a: VAR_TYPE, b: VAR_TYPE):
	var asm: String = ""
	while (b < a):
		asm += ascend_mem(b)
		b += 1
	asm += swap_in_stack(a, b)
	# NOW B I LOWER THAN A
	while (a < b):
		asm += ascend_mem(a)
		a += 1
		
	if (a != b):
		show_error("Something went terribly wrong in the compute substraction function (-)")
		return OperationResul.new(VAR_TYPE.WORD, "")
		
	if (a == VAR_TYPE.BYTE):
		asm += "pop AX\n"
		asm += "pop DX\n"
		if (USING_SIGNED):
			asm += "cbw\n"
		else:
			asm += "mov AH, 0h\n"
		asm += "sub AL, DL\n"
		asm += "sbb AH, 0h\n"
		asm += "push AX\n"
		return OperationResul.new(VAR_TYPE.WORD, asm)
		
	if (a == VAR_TYPE.WORD):
		asm += "pop AX\n"
		asm += "pop BX\n"
		asm += "sub AX, BX\n"
		asm += "push AX\n"
		return OperationResul.new(VAR_TYPE.WORD, asm)
		
	if (a == VAR_TYPE.DOUBLEWORD):
		asm += "pop EAX\n"
		asm += "pop EDX\n"
		asm += "sub EAX, EDX\n"
		asm += "push EAX\n"
		return OperationResul.new(VAR_TYPE.DOUBLEWORD, asm)
	
	if (a == VAR_TYPE.QUARDWORD):
		asm += "pop EAX\n"
		asm += "pop EDX\n"
		asm += "pop EBX\n"
		asm += "pop ECX\n"
		asm += "sub EAX, EBX\n"
		asm += "sbb EDX, ECX\n"
		asm += "push EDX\n"
		asm += "push EAX\n"
		return OperationResul.new(VAR_TYPE.QUARDWORD, asm)
	
	show_error("Something went terribly wrong in the compute substraction function (-)")
	return OperationResul.new(VAR_TYPE.WORD, "")

class OperationResul:
	var size_on_stack: VAR_TYPE
	var asm: String
	func _init(p_size_on_stack: VAR_TYPE, p_asm: String):
		size_on_stack = p_size_on_stack
		asm = p_asm
		

# I HAVE NO IDEA HOW AN ACTUAL TOKENIZER WORKS
# THIS IS JUST ME GUESSING... TODO: LEARN HOW
# A TOKENIZER WORKS.. :P
func tokenize(input: String) -> Array[Token]:
	# RETURNING AN EMPTY ARRAY MEANS THERES BEEN AN
	# ERROR IN PARSING
	# TODO: this could look better if i make a custom wrapper class
	# to wrapp around the array and give aditional data
	# (for example, error codes / 200 OK)
	var token_list: Array[Token] = []
	
	var i := 0
	var start := 0
	var current_token_type: TOKEN_TYPE = TOKEN_TYPE.NULL
	
	while (i < input.length()):
		var val = input[i]
		
		if (val == " " || prs_operators.has(val) || prs_wrappers.has(val)):
			if (current_token_type == TOKEN_TYPE.NUMBER):
				var number_token := Token.new(TOKEN_TYPE.NUMBER, input.substr(start, i - start))
				token_list.push_back(number_token)
				start = i 
				current_token_type = TOKEN_TYPE.NULL
			elif (current_token_type == TOKEN_TYPE.VARIABLE):
				var var_token := Token.new(TOKEN_TYPE.VARIABLE, input.substr(start, i - start))
				token_list.push_back(var_token)
				start = i
				current_token_type = TOKEN_TYPE.NULL
				
		if (val == " "):
			current_token_type = TOKEN_TYPE.NULL
			start = i + 1
			i += 1
			continue
		
		var type: TOKEN_TYPE
		if (prs_digits.has(val)): # DIGIT
			if (current_token_type == TOKEN_TYPE.VARIABLE):
				type = TOKEN_TYPE.VARIABLE
				current_token_type = type
				i += 1
				continue
			else:
				type = TOKEN_TYPE.NUMBER
				current_token_type = type
				i += 1
				continue
		
		elif (prs_operators.has(val)): # OPERATOR
			if (current_token_type == TOKEN_TYPE.OPERATOR): # ERROR, INVALID
				show_error("LAST_TYPE=TYPE = OPERATOR " + str(i) + " " + val)
				return []
			type = TOKEN_TYPE.OPERATOR
			var opr_token := Token.new(TOKEN_TYPE.OPERATOR, val)
			token_list.push_back(opr_token)
			current_token_type = TOKEN_TYPE.NULL
			start = i + 1
			i += 1
			continue
			
		elif (prs_wrappers.has(val)): # WRAPPER
			if (current_token_type == TOKEN_TYPE.WRAPPER): # ERROR, INVALID
				show_error("LAST_TYPE=TYPE = WRAPPER " + str(i) + " " + val)
				return []
			type = TOKEN_TYPE.WRAPPER
			var wrp_token := Token.new(TOKEN_TYPE.WRAPPER, val)
			if (val == ")"):
				var ok: bool = false
				for j in range(token_list.size() - 1, -1, -1):
					if (
						token_list[j].type == TOKEN_TYPE.WRAPPER && 
						token_list[j].value == "(" && 
						token_list[j].pointer == null
					):
						ok = true
						token_list[j].pointer = wrp_token
						wrp_token.pointer = token_list[j]
						break
				if (!ok): # ERROR, COULD NOT FIND MATCHING WRAPPER
					for j in range(token_list.size() - 1, -1, -1):
						prints(j, token_list[j], token_list.size())
					show_error("COULD NOT FIND MATCHING WRAPPER " + str(i) + " " + val)
					return [] 
			token_list.push_back(wrp_token)
			current_token_type = TOKEN_TYPE.NULL
			start = i + 1
			i += 1
			continue
			
				
			
		else: # VARIABLE
			type = TOKEN_TYPE.VARIABLE
			current_token_type = type
			i += 1
			continue
	
	if (current_token_type == TOKEN_TYPE.NUMBER):
		var number_token := Token.new(TOKEN_TYPE.NUMBER, input.substr(start, i - start))
		token_list.push_back(number_token)
		start = i 
		current_token_type = TOKEN_TYPE.NULL
	elif (current_token_type == TOKEN_TYPE.VARIABLE):
		var var_token := Token.new(TOKEN_TYPE.VARIABLE, input.substr(start, i - start))
		token_list.push_back(var_token)
		start = i
		current_token_type = TOKEN_TYPE.NULL
	
	return token_list

func get_size_from_value(value: int, is_signed: bool) -> VAR_TYPE:
	if (!is_signed): #UNSIGNED
		# if (value < 0): # THIS IS NA ERROR, LETS HOPE IT NEVER HAPPENES..
		if (value <= 255):
			return VAR_TYPE.BYTE
		if (value <= 65535):
			return VAR_TYPE.WORD
		if (value <= 4294967295):
			return VAR_TYPE.DOUBLEWORD
		return VAR_TYPE.QUARDWORD
	else: # SIGNED
		if (value >= -128 && value <= 127):
			return VAR_TYPE.BYTE
		if (value >= -32768 && value <= 32767):
			return VAR_TYPE.WORD
		if (value >= -2147483648 && value <= 2147483647):
			return VAR_TYPE.DOUBLEWORD
		return VAR_TYPE.QUARDWORD
	return VAR_TYPE.QUARDWORD

class Token:
	var type: TOKEN_TYPE
	var value: String
	var pointer: Token = null # FOR WRAPPERS
	var value_size: VAR_TYPE # FOR VAR AND NUMBERS
	var signed: bool # FOR VAR AND NUMBERS
	var not_found: bool # USED FOR VARIABLES
	
	func _init(p_type: TOKEN_TYPE, p_value: String):
		type = p_type
		value = p_value
	
	func _to_string():
		if (type == TOKEN_TYPE.WRAPPER):
			return "Token(WRAPPER " + value + ") -> " + ("NULL" if pointer == null else pointer.value)
		else:
			return "Token(" + str(type) + " " + value + ")"

enum TOKEN_TYPE {
	NULL,
	OPERATOR,
	WRAPPER, # PARANTESIS
	VARIABLE,
	NUMBER
}

func _on_expression_text_changed(new_text):
	hide_error()
	parse(new_text)
