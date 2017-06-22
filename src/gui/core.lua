local _MOD = require("src/constants")
local _util = require("src/util")
local _core = require("src/core")
local _logistics = require("src/logistics")
local _circuitry = require("src/circuitry")
local mod_prefix = _MOD.DEFINES.prefix
local globalCall = _util.globalCall

local function get_data(id) --Get GUI metadata
	local gui_data = globalCall("TurretGUI", id)
	local turret = gui_data.turret
	local index = gui_data.index[turret]
	local cache = gui_data.cache[turret][index] or {}
	return gui_data, turret, index, cache
end

local function get_label(logicTurret, id) --Get a turret's label
	return (logicTurret.labels[id] or {"MMT.gui.turret-label", logicTurret.entity.localised_name, logicTurret.id})
end

local function get_sprite(gui, sprite) --Use a generic sprite if the object doesn't have an icon
	if gui.is_valid_sprite_path(sprite) then
		return sprite
	else
		return mod_prefix.."unknown"
	end
end

local function get_network(logicTurret) --Check if the turret is connected to a circuit network --TODO: Add network_id and support multiple networks in v0.15
	local networks = logicTurret.components.interface.circuit_connected_entities
	for wire, enabled in pairs(_circuitry.get_circuitry(logicTurret).wires) do
		if enabled and #networks[wire] > 1 then
			return {"gui-control-behavior.connected-to-network"}
		end
	end
	return {"gui-control-behavior.not-connected"}
end

local function get_wire_string(circuitry) --Returns a string detailing which wires are in use, or nil if none
	if circuitry.wires.red and circuitry.wires.green then
		return "both"
	elseif circuitry.wires.red then
		return "red"
	elseif circuitry.wires.green then
		return "green"
	end
end

local function compose_message(paste_data, clipboard) --Compose a message to print to the player's console based on the result of their paste action
	local message = {"MMT.message.paste-fail"}
	local rMessage = nil
	local bMessage = nil
	local oMessage = nil
	if paste_data.rUnit ~= nil then
		if paste_data.rCount == 1 then
			if clipboard.ammo == _MOD.DEFINES.blank_in_gui then
				rMessage = {"MMT.message.save-empty", paste_data.rUnit}
			else
				rMessage = {"MMT.message.save", paste_data.rUnit, {"MMT.gui.item", game.item_prototypes[clipboard.ammo].localised_name, clipboard.count}}
			end
		elseif paste_data.rCount > 1 then
			if clipboard.ammo == _MOD.DEFINES.blank_in_gui then
				rMessage = {"MMT.message.paste-empty", paste_data.rCount}
			else
				rMessage = {"MMT.message.paste", paste_data.rCount, {"MMT.gui.item", game.item_prototypes[clipboard.ammo].localised_name, clipboard.count}}
			end
		end
	end
	if paste_data.bUnit ~= nil then
		local wires = get_wire_string(clipboard.circuitry)
		if paste_data.bCount == 1 then
			if clipboard.circuitry.mode == _MOD.DEFINES.circuit_mode.off or wires == nil then
				bMessage = {"MMT.message.paste-behavior-off", paste_data.bUnit}
			else
				bMessage = {"MMT.message.paste-behavior", paste_data.bUnit, {"MMT.gui.mode", {"MMT.gui.mode-"..clipboard.circuitry.mode}, {"MMT.gui.wire-"..wires}}}
			end
		elseif paste_data.bCount > 1 then
			if clipboard.circuitry.mode == _MOD.DEFINES.circuit_mode.off or wires == nil then
				bMessage = {"MMT.message.paste-behaviors-off", paste_data.bCount}
			else
				bMessage = {"MMT.message.paste-behaviors", paste_data.bCount, {"MMT.gui.mode", {"MMT.gui.mode-"..clipboard.circuitry.mode}, {"MMT.gui.wire-"..wires}}}
			end
		end
	end
	if paste_data.oUnit ~= nil then
		if paste_data.bCount ~= nil and paste_data.bCount > 0 then
			paste_data.oCount = paste_data.oCount - paste_data.bCount
		end
		if paste_data.oCount == 1 then
			oMessage = {"MMT.message.circuit-override", paste_data.oUnit}
		elseif paste_data.oCount > 1 then
			oMessage = {"MMT.message.circuit-overrides", paste_data.oCount}
		end
	end
	if rMessage ~= nil and bMessage ~= nil then
		message = {"MMT.message.combine", rMessage, bMessage}
	elseif rMessage ~= nil and oMessage ~= nil then
		message = {"MMT.message.combine", rMessage, oMessage}
	elseif bMessage ~= nil and oMessage ~= nil then
		message = {"MMT.message.combine", bMessage, oMessage}
	elseif rMessage ~= nil then
		message = rMessage
	elseif bMessage ~= nil then
		message = bMessage
	elseif oMessage ~= nil then
		message = oMessage
	end
	return message
end

local function show_control_panel(id, gui) --Updates the paste icons according to the contents of the clipboard and currently selected turret
	local gui_element = gui.center[mod_prefix.."gui"][mod_prefix.."logistics-flow"][mod_prefix.."navigation-flow"][mod_prefix.."control-flow"]
	local turret = select(2, get_data(id))
	local clipboard = globalCall("Clipboard")[id]
	local turret_name = game.entity_prototypes[turret].localised_name
	local padding = {76, 56, 37, 17} --1 button: 76, 2 buttons: 56, 3 buttons: 37, 4 buttons: 17
	local width = 0 --Width depends on the number of buttons
	if gui_element[mod_prefix.."panel-flow"] ~= nil then
		gui_element[mod_prefix.."panel-flow"].destroy() --Remove the previous turret's options
	end
	local control_panel = gui_element.add{type = "flow", name = mod_prefix.."panel-flow", direction = "horizontal", style = "slot_table_spacing_flow_style"}
	if clipboard ~= nil then
		local category, ammo, count = clipboard.category, clipboard.ammo, clipboard.count --Clipboard contents
		if ammo == _MOD.DEFINES.blank_in_gui or _logistics.get_ammo_category(turret) == category then --Current turret's ammo category matches the copied turret's
			local tooltip = {"MMT.gui.paste-match-empty", turret_name}
			if ammo ~= _MOD.DEFINES.blank_in_gui then
				tooltip = {"MMT.gui.paste-match", turret_name, {"MMT.gui.item", game.item_prototypes[ammo].localised_name, count}}
			end
			control_panel.add{type = "sprite-button", name = mod_prefix.."match-button", style = mod_prefix.."icon", sprite = mod_prefix.."paste-match", tooltip = tooltip}
			width = width + 1
		end
		local tooltip = {"MMT.gui.paste-all-empty"}
		if ammo ~= _MOD.DEFINES.blank_in_gui then
			tooltip = {"MMT.gui.paste-all", {"ammo-category-name."..category}, {"MMT.gui.item", game.item_prototypes[ammo].localised_name, count}}
		end
		control_panel.add{type = "sprite-button", name = mod_prefix.."all-button", style = mod_prefix.."icon", sprite = mod_prefix.."paste-all", tooltip = tooltip}
		width = width + 1
	end
	if gui.player.force.technologies["circuit-network"].researched then --Add circuit network buttons
		if clipboard ~= nil and clipboard.circuitry ~= nil then
			local circuitry = clipboard.circuitry
			local tooltip = {"MMT.gui.paste-behavior-off", turret_name}
			if circuitry.mode ~= _MOD.DEFINES.circuit_mode.off then
				local wires = get_wire_string(circuitry)
				if wires ~= nil then
					tooltip = {"MMT.gui.paste-behavior", turret_name, {"MMT.gui.mode", {"MMT.gui.mode-"..circuitry.mode}, {"MMT.gui.wire-"..wires}}}
				end
			end
			control_panel.add{type = "sprite-button", name = mod_prefix.."behavior-button", style = mod_prefix.."icon", sprite = mod_prefix.."paste-behavior", tooltip = tooltip}
			width = width + 1
		end
		control_panel.add{type = "sprite-button", name = mod_prefix.."circuitry-button", style = mod_prefix.."icon", sprite = mod_prefix.."circuitry", tooltip = {"gui-control-behavior.circuit-network"}}
		width = width + 1
	end
	control_panel.style.left_padding = padding[width] --Padding depends on the number of buttons to keep GUI the same width
end

local function show_wires(id, gui) --Show, hide, or update the curret turret's wire options
	local gui_element = gui.center[mod_prefix.."gui"][mod_prefix.."circuitry-frame"]
	local gui_data, turret, index, cache = get_data(id)
	local circuitry = cache.circuitry or _circuitry.get_circuitry(gui_data.logicTurrets[turret][index])
	if circuitry.mode == _MOD.DEFINES.circuit_mode.off then
		if gui_element[mod_prefix.."connect-flow"] ~= nil then
			gui_element[mod_prefix.."connect-flow"].destroy()
		end
		return
	end
	local red_style = "gray"
	local green_style = "gray"
	if circuitry.wires.red then
		red_style = "blue"
	end
	if circuitry.wires.green then
		green_style = "blue"
	end
	if gui_element[mod_prefix.."connect-flow"] ~= nil then
		gui_element[mod_prefix.."connect-flow"][mod_prefix.."wire-flow"][mod_prefix.."red-button"].style = mod_prefix..red_style
		gui_element[mod_prefix.."connect-flow"][mod_prefix.."wire-flow"][mod_prefix.."green-button"].style = mod_prefix..green_style
	else
		local connect_flow = gui_element.add{type = "flow", name = mod_prefix.."connect-flow", direction = "vertical", style = "table_spacing_flow_style"}
			connect_flow.style.minimal_height = 58
			connect_flow.add{type = "label", name = mod_prefix.."connect-label", style = "description_label_style", caption = {"MMT.gui.connect"}, tooltip = {"MMT.gui.connect-description"}}
			local wire_flow = connect_flow.add{type = "flow", name = mod_prefix.."wire-flow", direction = "horizontal", style = "slot_table_spacing_flow_style"}
				wire_flow.add{type = "sprite-button", name = mod_prefix.."red-button", style = mod_prefix..red_style, sprite = "item/red-wire", tooltip = {"item-name.red-wire"}}
				wire_flow.add{type = "sprite-button", name = mod_prefix.."green-button", style = mod_prefix..green_style, sprite = "item/green-wire", tooltip = {"item-name.green-wire"}}
	end
end

local function show_circuit_panel(id, gui) --Show the current turret's circuitry panel
	local gui_element = gui.center[mod_prefix.."gui"][mod_prefix.."circuitry-frame"]
	if gui_element == nil then
		return
	end
	local gui_data, turret, index, cache = get_data(id)
	local logicTurret = gui_data.logicTurrets[turret][index]
	local circuitry = cache.circuitry or _circuitry.get_circuitry(logicTurret)
	gui_element[mod_prefix.."network-label"].caption = get_network(logicTurret)
	gui_element[mod_prefix.."mode-flow"][mod_prefix.."mode-table"][mod_prefix.._MOD.DEFINES.circuit_mode.off.."-button"].sprite = ""
	gui_element[mod_prefix.."mode-flow"][mod_prefix.."mode-table"][mod_prefix.._MOD.DEFINES.circuit_mode.send_contents.."-button"].sprite = ""
	gui_element[mod_prefix.."mode-flow"][mod_prefix.."mode-table"][mod_prefix.._MOD.DEFINES.circuit_mode.set_requests.."-button"].sprite = ""
	gui_element[mod_prefix.."mode-flow"][mod_prefix.."mode-table"][mod_prefix..circuitry.mode.."-button"].sprite = mod_prefix.."bullet"
	show_wires(id, gui)
end

local function show_ammo_table(id, gui) --Shows the list of ammo the current turret can request
	local gui_element = gui.center[mod_prefix.."gui"][mod_prefix.."logistics-flow"][mod_prefix.."turret-frame"]
	local gui_data, turret, index, cache = get_data(id)
	local request = cache.request or _logistics.get_request(gui_data.logicTurrets[turret][index])
	local ammo_list = _logistics.get_ammo_list(turret) --The list of ammo the turret can use
	if gui_element[mod_prefix.."ammo-table"] ~= nil then
		gui_element[mod_prefix.."ammo-table"].destroy() --Remove the previous turret's list
	end
	local ammo_table = gui_element.add{type = "table", name = mod_prefix.."ammo-table", style = "slot_table_style", colspan = 5}
		ammo_table.add{type = "sprite-button", name = mod_prefix.._MOD.DEFINES.blank_in_gui.."-ammo-button", style = mod_prefix.."gray", tooltip = {"MMT.gui.empty"}} --Blank request
		for i = 1, #ammo_list do
			local ammo = ammo_list[i]
			local style = "gray"
			if request ~= nil and ammo == request.name then --Highlight current request
				style = "orange"
			end
			ammo_table.add{type = "sprite-button", name = mod_prefix..ammo.."-ammo-button", style = mod_prefix..style, sprite = get_sprite(gui, "item/"..ammo), tooltip = game.item_prototypes[ammo].localised_name}
		end
end

local function show_request(id, gui) --Show the current turret's request
	local gui_element = gui.center[mod_prefix.."gui"][mod_prefix.."logistics-flow"][mod_prefix.."turret-frame"]
	local gui_data, turret, index, cache = get_data(id)
	local logicTurret = gui_data.logicTurrets[turret][index]
	local request = _logistics.get_request(logicTurret)
	local caption = _MOD.DEFINES.blank_in_gui
	local sprite = ""
	local tooltip = {"MMT.gui.stack", 0}
	local count = 0
	if cache.request ~= nil then --Turret has a cached request
		if cache.request.name ~= _MOD.DEFINES.blank_in_gui then
			caption = cache.request.name --Store ammo name in the caption
			sprite = get_sprite(gui, "item/"..cache.request.name)
			tooltip = {"MMT.gui.stack", game.item_prototypes[cache.request.name].stack_size}
			count = cache.request.count
		end
	elseif request ~= nil then
		caption = request.name --Store ammo name in the caption
		sprite = get_sprite(gui, "item/"..request.name)
		tooltip = {"MMT.gui.stack", game.item_prototypes[request.name].stack_size}
		count = request.count
	end
	gui_element[mod_prefix.."turret-label"].caption = get_label(logicTurret, id)
	gui_element[mod_prefix.."request-flow"][mod_prefix.."item-button"].caption = caption
	gui_element[mod_prefix.."request-flow"][mod_prefix.."item-button"].sprite = sprite
	gui_element[mod_prefix.."request-flow"][mod_prefix.."item-button"].tooltip = tooltip
	gui_element[mod_prefix.."request-flow"][mod_prefix.."count-field"].text = count
	show_ammo_table(id, gui)
	show_circuit_panel(id, gui)
end

local function rename_turret(id, gui) --Save or delete the custom label
	local gui_element = gui.center[mod_prefix.."gui"][mod_prefix.."logistics-flow"][mod_prefix.."turret-frame"][mod_prefix.."turret-label"]
	local gui_data, turret, index = get_data(id)
	local logicTurret = gui_data.logicTurrets[turret][index]
	local label = _util.string_trim(gui_element[mod_prefix.."edit-field"].text) --Remove leading and trailing whitespace
	if label == "" then
		label = nil --Reset to default
	end
	logicTurret.labels[id] = label
	gui_element.caption = get_label(logicTurret, id)
	gui_element[mod_prefix.."edit-field"].destroy()
end

local function open(id) --Create the GUI
	local player = _util.get_player(id)
	if player == nil then
		return
	end
	local gui = player.gui
	local gui_data = globalCall("TurretGUI", id)
	local root = gui.center.add{type = "flow", name = mod_prefix.."gui", direction = "horizontal", style = "achievements_flow_style"}
		local logistic_flow = root.add{type = "flow", name = mod_prefix.."logistics-flow", direction = "vertical", style = "achievements_flow_style"}
			local nav_frame = logistic_flow.add{type = "frame", name = mod_prefix.."navigation-flow", direction = "vertical"}
				nav_frame.style.minimal_width = 188
				local title_flow = nav_frame.add{type = "flow", name = mod_prefix.."title-flow", direction = "horizontal"}
					title_flow.add{type = "label", name = mod_prefix.."title-label", style = "description_title_label_style", caption = {"MMT.gui.title"}}
						title_flow[mod_prefix.."title-label"].style.minimal_width = 145
					title_flow.add{type = "sprite-button", name = mod_prefix.."close-button", style = mod_prefix.."nav", sprite = mod_prefix.."close"}
				local turret_table = nav_frame.add{type = "table", name = mod_prefix.."turret-table", style = "slot_table_style", colspan = 5}
					for turret in pairs(gui_data.logicTurrets) do
						if gui_data.turret == nil then
							gui_data.turret = turret --Current turret
						end
						gui_data.index[turret] = 1 --Current index
						gui_data.cache[turret] = {} --Create cache
						local turret_name = game.entity_prototypes[turret].localised_name
						local tooltip = {"MMT.gui.turret-tooltip", turret_name}
						local style = "gray"
						if #gui_data.logicTurrets[turret] > 1 then
							tooltip = {"MMT.gui.turrets-tooltip", turret_name, #gui_data.logicTurrets[turret]}
						end
						if turret == gui_data.turret then --Highlight current turret
							style = "orange"
						end
						turret_table.add{type = "sprite-button", name = mod_prefix..turret.."-turret-button", style = mod_prefix..style, sprite = get_sprite(gui, "entity/"..turret), tooltip = tooltip}
					end
			local turret = gui_data.turret
				local control_flow = nav_frame.add{type = "flow", name = mod_prefix.."control-flow", direction = "horizontal", style = "achievements_flow_style"}
					control_flow.add{type = "sprite-button", name = mod_prefix.."prev-button", style = mod_prefix.."nav", sprite = mod_prefix.."prev"}
					control_flow.add{type = "label", name = mod_prefix.."index-label", style = mod_prefix.."index", caption = gui_data.index[turret].."/"..#gui_data.logicTurrets[turret]}
					control_flow.add{type = "sprite-button", name = mod_prefix.."next-button", style = mod_prefix.."nav", sprite = mod_prefix.."next"}
					show_control_panel(id, gui)
			local logicTurret = gui_data.logicTurrets[turret][gui_data.index[turret]]
			local request = _logistics.get_request(logicTurret)
			local caption = _MOD.DEFINES.blank_in_gui
			local sprite = ""
			local tooltip = {"MMT.gui.stack", 0}
			local count = 0
			if request ~= nil then
				caption = request.name --Store ammo name in the caption
				sprite = get_sprite(gui, "item/"..request.name)
				tooltip = {"MMT.gui.stack", game.item_prototypes[request.name].stack_size}
				count = request.count
			end
			local turret_frame = logistic_flow.add{type = "frame", name = mod_prefix.."turret-frame", direction = "vertical"}
				turret_frame.style.minimal_width = 188
				local turret_label = turret_frame.add{type = "label", name = mod_prefix.."turret-label", style = "description_label_style", caption = get_label(logicTurret, id), tooltip = {"gui-edit-label.edit-label"}}
					turret_label.style.minimal_width = 167
					turret_label.style.maximal_width = 167
				local request_flow = turret_frame.add{type = "flow", name = mod_prefix.."request-flow", direction = "horizontal"}
					request_flow.add{type = "sprite-button", name = mod_prefix.."item-button", style = mod_prefix.."gray", caption = caption, sprite = sprite, tooltip = tooltip}
					request_flow.add{type = "textfield", name = mod_prefix.."count-field", text = count}
						request_flow[mod_prefix.."count-field"].style.minimal_width = 54
					local cache_flow = request_flow.add{type = "flow", name = mod_prefix.."cache-flow", direction = "horizontal", style = "slot_table_spacing_flow_style"}
						cache_flow.add{type = "sprite-button", name = mod_prefix.."save-button", style = mod_prefix.."gray", sprite = mod_prefix.."save", tooltip = {"gui-save-game.save"}}
						cache_flow.add{type = "sprite-button", name = mod_prefix.."copy-button", style = mod_prefix.."gray", sprite = mod_prefix.."copy", tooltip = {"MMT.gui.copy"}}
			show_ammo_table(id, gui)
end

local function destroy(id) --Close the GUI without applying saved changes
	local player = _util.get_player(id)
	if player ~= nil then
		local gui = player.gui.center[mod_prefix.."gui"]
		if gui ~= nil and gui.valid then
			gui.destroy() --Close GUI
		end
	end
	globalCall("TurretGUI")[id] = nil --Delete GUI metadata
end

local function interrupt(turret, caller_id) --Close a turret's GUI for any player that may have it open
	if turret == nil or not turret.valid then
		return
	end
	for id, gui_data in pairs(globalCall("TurretGUI")) do
		if caller_id == nil or id ~= caller_id then
			local found = false
			for _, logicTurrets in pairs(gui_data.logicTurrets) do
				for i = 1, #logicTurrets do
					if logicTurrets[i].entity == turret then --Player's GUI contains this turret
						destroy(id)
						found = true
						break
					end
				end
				if found then
					break
				end
			end
		end
	end
end

local function close(id) --Close the GUI and apply saved changes
	local gui_data = globalCall("TurretGUI")[id]
	if gui_data == nil then
		destroy(id)
		return
	end
	local player = _util.get_player(id)
	if player ~= nil then
		local gui = player.gui.center[mod_prefix.."gui"]
		if gui ~= nil and gui.valid then
			if gui[mod_prefix.."logistics-flow"][mod_prefix.."turret-frame"][mod_prefix.."turret-label"][mod_prefix.."edit-field"] ~= nil then --Close the label editor
				rename_turret(id, player.gui)
			end
			for turret, data in pairs(gui_data.cache) do
				for index, cache in pairs(data) do
					local logicTurret = gui_data.logicTurrets[turret][index]
					local circuitry = cache.circuitry
					local request = cache.request
					interrupt(logicTurret.entity, id) --Close this turret's GUI for all players
					if circuitry ~= nil then --Turret has a cached control behavior
						_circuitry.set_circuitry(logicTurret, circuitry.mode, circuitry.wires)
					end
					if request ~= nil then --Turret has a cached request
						if request.name == _MOD.DEFINES.blank_in_gui then
							_logistics.set_request(logicTurret, _MOD.DEFINES.blank_request)
						else
							_logistics.set_request(logicTurret, {ammo = request.name, count = request.count})
						end
					end
				end
			end
		end
	end
	destroy(id)
end

return
{
	open = open,
	close = close,
	destroy = destroy,
	interrupt = interrupt,
	compose_message = compose_message,
	get_data = get_data,
	get_label = get_label,
	get_network = get_network,
	get_sprite = get_sprite,
	get_wire_string = get_wire_string,
	rename_turret = rename_turret,
	show_ammo_table = show_ammo_table,
	show_circuit_panel = show_circuit_panel,
	show_control_panel = show_control_panel,
	show_request = show_request,
	show_wires = show_wires
}