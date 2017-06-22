local _MOD = require("src/constants")
local _util = require("src/util")
local _core = require("src/core")
local _logistics = require("src/logistics")
local _circuitry = require("src/circuitry")
local _gui = require("src/gui/core")
local mod_prefix = _MOD.DEFINES.prefix
local globalCall = _util.globalCall

local function click_turret(id, gui, turret) --Switch turret list
	local gui_element = gui.center[mod_prefix.."gui"][mod_prefix.."logistics-flow"][mod_prefix.."navigation-flow"]
	local gui_data, current_turret = _gui.get_data(id)
	if turret == current_turret then --Already selected
		return
	end
	gui_element[mod_prefix.."turret-table"][mod_prefix..current_turret.."-turret-button"].style = mod_prefix.."gray" --Change the old turret's icon to gray
	gui_element[mod_prefix.."turret-table"][mod_prefix..turret.."-turret-button"].style = mod_prefix.."orange" --Change the new turret's icon to orange
	gui_element[mod_prefix.."control-flow"][mod_prefix.."index-label"].caption = gui_data.index[turret].."/"..#gui_data.logicTurrets[turret]
	gui_data.turret = turret
	_gui.show_control_panel(id, gui)
	_gui.show_request(id, gui)
end

local function click_nav(id, gui, nav) --Move forward or backward through a turret list
	local gui_element = gui.center[mod_prefix.."gui"][mod_prefix.."logistics-flow"][mod_prefix.."navigation-flow"][mod_prefix.."control-flow"][mod_prefix.."index-label"]
	local gui_data, turret, oldIndex = _gui.get_data(id)
	local zIndex = #gui_data.logicTurrets[turret]
	if zIndex <= 1 then --Array only has one turret
		return
	end
	local index = gui_data.index
	if nav == "prev" then
		index[turret] = oldIndex - 1 --Move backward through list
		if index[turret] < 1 then
			index[turret] = zIndex --Set to end of list
		end
	elseif nav == "next" then
		index[turret] = oldIndex + 1 --Move forward through list
		if index[turret] > zIndex then
			index[turret] = 1 --Set to beginning of list
		end
	end
	gui_element.caption = index[turret].."/"..zIndex --Update text
	_gui.show_request(id, gui)
end

local function click_paste(id, gui, pasteMode) --Paste the contents of the clipboard according to the button pressed
	local clipboard = globalCall("Clipboard")[id]
	if clipboard == nil then --Clipboard is empty
		gui.player.print({"MMT.message.paste-nil"}) --Display a message
		return
	end
	local gui_data, current_turret, current_index, cache = _gui.get_data(id)
	local category, ammo, count = clipboard.category, clipboard.ammo, clipboard.count --Clipboard contents
	local is_compatible = function() return false end --Which turrets are compatible depends on the button pressed and the contents of the clipboard
	if pasteMode == "match" then --Only available if the selected turret's ammo category matches the copied turret's
		if ammo == _MOD.DEFINES.blank_in_gui then
			is_compatible = function(turret)
				if turret == current_turret then return true end --Currently selected turret type
			end
		else
			is_compatible = function(turret)
				if turret == current_turret and _logistics.get_ammo_category(turret) == category then return true end --Currently selected turret type and matching ammo type
			end
		end
	elseif pasteMode == "all" then --Always available
		if ammo == _MOD.DEFINES.blank_in_gui then
			is_compatible = function() return true end --All turrets
		else
			is_compatible = function(turret)
				if _logistics.get_ammo_category(turret) == category then return true end --All turrets with matching ammo type
			end
		end
	end
	local paste_data =
	{
		rCount = 0,
		oCount = 0,
		rUnit = nil,
		oUnit = nil
	}
	for turret, logicTurrets in pairs(gui_data.logicTurrets) do
		if is_compatible(turret) then
			for i = 1, #logicTurrets do
				if gui_data.cache[turret][i] == nil then
					gui_data.cache[turret][i] = {}
				end
				local logicTurret = logicTurrets[i]
				local circuitry = cache.circuitry or _circuitry.get_circuitry(logicTurret)
				if circuitry.mode == _MOD.DEFINES.circuit_mode.set_requests then --Request slot is overridden by a circuit network
					if paste_data.oUnit == nil then
						paste_data.oUnit = _gui.get_label(logicTurret, id)
					end
					paste_data.oCount = paste_data.oCount + 1
				else
					gui_data.cache[turret][i].request = {name = ammo, count = count} --Add to cache
					if turret == current_turret and i == current_index then --Update the currently displayed turret if necessary
						_gui.show_request(id, gui)
					end
					if paste_data.rUnit == nil then
						paste_data.rUnit = _gui.get_label(logicTurret, id)
					end
					paste_data.rCount = paste_data.rCount + 1
				end
			end
		end
	end
	gui.player.print(_gui.compose_message(paste_data, clipboard)) --Display a message based on the result
end

local function click_paste_behavior(id, gui) --Paste the control behavior settings stored in the clipboard
	local clipboard = globalCall("Clipboard")[id]
	if clipboard == nil or clipboard.circuitry == nil then --Clipboard is empty
		gui.player.print({"MMT.message.paste-nil"}) --Display a message
		return
	end
	local gui_data, current_turret, current_index = _gui.get_data(id)
	local circuitry = clipboard.circuitry --Clipboard contents
	local circuit_panel = (gui.center[mod_prefix.."gui"][mod_prefix.."circuitry-frame"] ~= nil)
	local paste_data =
	{
		bCount = 0,
		bUnit = nil
	}
	for turret, logicTurrets in pairs(gui_data.logicTurrets) do
		if turret == current_turret then
			for i = 1, #logicTurrets do
				if gui_data.cache[turret][i] == nil then
					gui_data.cache[turret][i] = {}
				end
				gui_data.cache[turret][i].circuitry = {mode = circuitry.mode, wires = {red = circuitry.wires.red, green = circuitry.wires.green}} --Add to cache
				if circuit_panel and turret == current_turret and i == current_index then --Update the currently displayed turret if necessary
					_gui.show_circuit_panel(id, gui)
				end
				if paste_data.bUnit == nil then
					local logicTurret = logicTurrets[i]
					paste_data.bUnit = _gui.get_label(logicTurret, id)
				end
				paste_data.bCount = paste_data.bCount + 1
			end
		end
	end
	gui.player.print(_gui.compose_message(paste_data, clipboard)) --Display a message based on the result
end

local function click_circuitry(id, gui) --Show or hide the circuit network panel
	local gui_element = gui.center[mod_prefix.."gui"]
	if gui_element[mod_prefix.."circuitry-frame"] ~= nil then
		gui_element[mod_prefix.."circuitry-frame"].destroy()
		return
	end
	local gui_data, turret, index, cache = _gui.get_data(id)
	local logicTurret = gui_data.logicTurrets[turret][index]
	local circuitry = cache.circuitry or _circuitry.get_circuitry(logicTurret)
	local circuit_frame = gui_element.add{type = "frame", name = mod_prefix.."circuitry-frame", direction = "vertical", style = "inner_frame_in_outer_frame_style", caption = {"gui-control-behavior.circuit-connection"}}
		circuit_frame.style.font = "default-bold"
		circuit_frame.style.minimal_width = 161
		circuit_frame.add{type = "label", name = mod_prefix.."network-label", caption = _gui.get_network(logicTurret)}
			circuit_frame[mod_prefix.."network-label"].style.font = "default-small-semibold"
		local mode_flow = circuit_frame.add{type = "flow", name = mod_prefix.."mode-flow", direction = "vertical", style = "slot_table_spacing_flow_style"}
			mode_flow.add{type = "label", name = mod_prefix.."mode-label", style = "description_label_style", caption = {"gui-control-behavior.mode-of-operation"}}
			local mode_table = mode_flow.add{type = "table", name = mod_prefix.."mode-table", style = "slot_table_style", colspan = 2}
				mode_table.style.horizontal_spacing = 4
				mode_table.style.vertical_spacing = 3
				mode_table.add{type = "sprite-button", name = mod_prefix.._MOD.DEFINES.circuit_mode.off.."-button", style = mod_prefix.."radio"}
				mode_table.add{type = "label", name = mod_prefix.._MOD.DEFINES.circuit_mode.off.."-label", caption = {"gui-control-behavior-modes.none"}}
					mode_table[mod_prefix.._MOD.DEFINES.circuit_mode.off.."-label"].style.font = "default-small-semibold"
				mode_table.add{type = "sprite-button", name = mod_prefix.._MOD.DEFINES.circuit_mode.send_contents.."-button", style = mod_prefix.."radio"}
				mode_table.add{type = "label", name = mod_prefix.._MOD.DEFINES.circuit_mode.send_contents.."-label", caption = {"gui-control-behavior-modes.read-contents"}, tooltip = {"gui-requester.send-contents"}}
					mode_table[mod_prefix.._MOD.DEFINES.circuit_mode.send_contents.."-label"].style.font = "default-small-semibold"
				mode_table.add{type = "sprite-button", name = mod_prefix.._MOD.DEFINES.circuit_mode.set_requests.."-button", style = mod_prefix.."radio"}
				mode_table.add{type = "label", name = mod_prefix.._MOD.DEFINES.circuit_mode.set_requests.."-label", caption = {"gui-control-behavior-modes.set-requests"}, tooltip = {"gui-requester.set-requests"}}
					mode_table[mod_prefix.._MOD.DEFINES.circuit_mode.set_requests.."-label"].style.font = "default-small-semibold"
				mode_table[mod_prefix..circuitry.mode.."-button"].sprite = mod_prefix.."bullet"
		_gui.show_wires(id, gui)
end

local function click_label(id, gui) --Open the label editor
	local gui_element = gui.center[mod_prefix.."gui"][mod_prefix.."logistics-flow"][mod_prefix.."turret-frame"][mod_prefix.."turret-label"]
	local gui_data, turret, index = _gui.get_data(id)
	local label = gui_data.logicTurrets[turret][index].labels[id] --Current custom label, if any
	local field = gui_element.add{type = "textfield", name = mod_prefix.."edit-field", text = label}
	field.style.minimal_width = gui_element.style.minimal_width
	field.style.maximal_width = gui_element.style.maximal_width
end

local function click_item(id, gui, ammo) --Set the count to the maximum stack size
	local gui_element = gui.center[mod_prefix.."gui"][mod_prefix.."logistics-flow"][mod_prefix.."turret-frame"][mod_prefix.."request-flow"][mod_prefix.."count-field"]
	local count = 0
	if ammo ~= _MOD.DEFINES.blank_in_gui then
		count = game.item_prototypes[ammo].stack_size
	end
	gui_element.text = count --Update textfield
end

local function click_save(id, gui) --Save the currently displayed request to be applied when the GUI closes
	local gui_element = gui.center[mod_prefix.."gui"][mod_prefix.."logistics-flow"][mod_prefix.."turret-frame"]
	local gui_data, turret, index, cache = _gui.get_data(id)
	local logicTurret = gui_data.logicTurrets[turret][index]
	local circuitry = cache.circuitry or _circuitry.get_circuitry(logicTurret)
	local label = gui_element[mod_prefix.."turret-label"].caption
	local message = {"MMT.message.save-empty", label}
	if circuitry.mode == _MOD.DEFINES.circuit_mode.set_requests then --Request slot is overridden by a circuit network
		message = {"MMT.message.circuit-override", label}
	else
		if gui_data.cache[turret][index] == nil then
			gui_data.cache[turret][index] = {}
		end
		local request = cache.request or _logistics.get_request(logicTurret)
		local ammo = gui_element[mod_prefix.."request-flow"][mod_prefix.."item-button"].caption
		local count = tonumber(gui_element[mod_prefix.."request-flow"][mod_prefix.."count-field"].text)
		if ammo == _MOD.DEFINES.blank_in_gui or count == nil or count < 1 then --Request slot will be cleared
			if request ~= nil then
				gui_element[mod_prefix.."ammo-table"][mod_prefix..request.name.."-ammo-button"].style = mod_prefix.."gray" --Change the old request's icon to gray
			end
			gui_element[mod_prefix.."request-flow"][mod_prefix.."count-field"].text = 0 --Update textfield
			gui_data.cache[turret][index].request = {name = _MOD.DEFINES.blank_in_gui} --Add to cache
		else
			local ammo_data = game.item_prototypes[ammo]
			count = math.min(math.floor(count), ammo_data.stack_size) --Round down to the nearest whole number, maximum one stack
			if request ~= nil then
				gui_element[mod_prefix.."ammo-table"][mod_prefix..request.name.."-ammo-button"].style = mod_prefix.."gray" --Change the old request's icon to gray
			end
			gui_element[mod_prefix.."ammo-table"][mod_prefix..ammo.."-ammo-button"].style = mod_prefix.."orange" --Change the new request's icon to orange
			gui_element[mod_prefix.."request-flow"][mod_prefix.."count-field"].text = count --Update textfield
			gui_data.cache[turret][index].request = {name = ammo, count = count} --Add to cache
			message = {"MMT.message.save", label, {"MMT.gui.item", ammo_data.localised_name, count}}
		end
	end
	gui.player.print(message) --Display a message based on the result
end

local function click_copy(id, gui) --Save the currently displayed request to the clipboard
	local gui_element = gui.center[mod_prefix.."gui"][mod_prefix.."logistics-flow"][mod_prefix.."turret-frame"][mod_prefix.."request-flow"]
	local gui_data, turret, index, cache = _gui.get_data(id)
	local category = _logistics.get_ammo_category(turret) --Turret's ammo category
	local ammo = gui_element[mod_prefix.."item-button"].caption
	local count = tonumber(gui_element[mod_prefix.."count-field"].text)
	local message = {"MMT.message.copy-empty"}
	if ammo == _MOD.DEFINES.blank_in_gui or count == nil or count < 1 then
		gui_element[mod_prefix.."count-field"].text = 0 --Update textfield
		globalCall("Clipboard")[id] = {turret = turret, category = category, ammo = _MOD.DEFINES.blank_in_gui}
	else
		local ammo_data = game.item_prototypes[ammo]
		count = math.min(math.floor(count), ammo_data.stack_size) --Round down to the nearest whole number, maximum one stack
		gui_element[mod_prefix.."count-field"].text = count --Update textfield
		globalCall("Clipboard")[id] = {turret = turret, category = category, ammo = ammo, count = count}
		message = {"MMT.message.copy", {"MMT.gui.item", ammo_data.localised_name, count}}
	end
	if gui.player.force.technologies["circuit-network"].researched then --Save the control behavior
		local circuitry = cache.circuitry or _circuitry.get_circuitry(gui_data.logicTurrets[turret][index])
		globalCall("Clipboard", id).circuitry = {mode = circuitry.mode, wires = {red = circuitry.wires.red, green = circuitry.wires.green}}
		local bMessage = {"MMT.message.copy-behavior-off"}
		if circuitry.mode ~= _MOD.DEFINES.circuit_mode.off then
			local wires = _gui.get_wire_string(circuitry)
			if wires ~= nil then
				bMessage = {"MMT.gui.mode", {"MMT.gui.mode-"..circuitry.mode}, {"MMT.gui.wire-"..wires}}
			end
		end
		message = {"MMT.message.combine", message, bMessage}
	end
	gui.player.print(message) --Display a message based on the result
	_gui.show_control_panel(id, gui)
end

local function click_ammo(id, gui, ammo) --Change the request icon to the selected ammo
	local gui_element = gui.center[mod_prefix.."gui"][mod_prefix.."logistics-flow"][mod_prefix.."turret-frame"][mod_prefix.."request-flow"][mod_prefix.."item-button"]
	if ammo == gui_element.caption then --Already selected
		return
	end
	local sprite = ""
	local count = 0
	if ammo ~= _MOD.DEFINES.blank_in_gui then
		sprite = _gui.get_sprite(gui, "item/"..ammo)
		count = game.item_prototypes[ammo].stack_size
	end
	gui_element.caption = ammo --Store ammo name in the caption
	gui_element.sprite = sprite
	gui_element.tooltip = {"MMT.gui.stack", count}
end

local function click_mode(id, gui, mode) --Set the mode of operation
	local gui_element = gui.center[mod_prefix.."gui"][mod_prefix.."circuitry-frame"][mod_prefix.."mode-flow"][mod_prefix.."mode-table"]
	local gui_data, turret, index, cache = _gui.get_data(id)
	local circuitry = cache.circuitry or _circuitry.get_circuitry(gui_data.logicTurrets[turret][index])
	if mode == circuitry.mode then --Already selected
		return
	end
	if gui_data.cache[turret][index] == nil then
		gui_data.cache[turret][index] = {}
	end
	gui_element[mod_prefix..circuitry.mode.."-button"].sprite = ""
	gui_element[mod_prefix..mode.."-button"].sprite = mod_prefix.."bullet"
	gui_data.cache[turret][index].circuitry = {mode = mode, wires = {red = circuitry.wires.red, green = circuitry.wires.green}} --Add to cache
	_gui.show_wires(id, gui)
end

local function click_wire(id, gui, wire) --Set the wires the turret will connect to
	local gui_element = gui.center[mod_prefix.."gui"][mod_prefix.."circuitry-frame"][mod_prefix.."connect-flow"][mod_prefix.."wire-flow"]
	local gui_data, turret, index, cache = _gui.get_data(id)
	local circuitry = cache.circuitry or _circuitry.get_circuitry(gui_data.logicTurrets[turret][index])
	if gui_data.cache[turret][index] == nil then
		gui_data.cache[turret][index] = {}
	end
	if gui_data.cache[turret][index].circuitry == nil then
		gui_data.cache[turret][index].circuitry = {mode = circuitry.mode, wires = {red = circuitry.wires.red, green = circuitry.wires.green}}
	end
	if circuitry.wires[wire] then
		gui_element[mod_prefix..wire.."-button"].style = mod_prefix.."gray"
		gui_data.cache[turret][index].circuitry.wires[wire] = false --Add to cache
	else
		gui_element[mod_prefix..wire.."-button"].style = mod_prefix.."blue"
		gui_data.cache[turret][index].circuitry.wires[wire] = true --Add to cache
	end
end

return
{
	buttons =
	{
		[mod_prefix.."close-button"] = _gui.close,
		[mod_prefix.."prev-button"] = click_nav,
		[mod_prefix.."next-button"] = click_nav,
		[mod_prefix.."all-button"] = click_paste,
		[mod_prefix.."match-button"] = click_paste,
		[mod_prefix.."behavior-button"] = click_paste_behavior,
		[mod_prefix.."circuitry-button"] = click_circuitry,
		[mod_prefix.."turret-label"] = click_label,
		[mod_prefix.."save-button"] = click_save,
		[mod_prefix.."copy-button"] = click_copy,
		[mod_prefix.._MOD.DEFINES.circuit_mode.off.."-button"] = click_mode,
		[mod_prefix.._MOD.DEFINES.circuit_mode.send_contents.."-button"] = click_mode,
		[mod_prefix.._MOD.DEFINES.circuit_mode.set_requests.."-button"] = click_mode,
		[mod_prefix.."red-button"] = click_wire,
		[mod_prefix.."green-button"] = click_wire
	},
	click_ammo = click_ammo,
	click_item = click_item,
	click_turret = click_turret,
	open = _gui.open,
	close = _gui.close,
	destroy = _gui.destroy,
	interrupt = _gui.interrupt,
	compose_message = _gui.compose_message,
	get_label = _gui.get_label,
	rename_turret = _gui.rename_turret
}