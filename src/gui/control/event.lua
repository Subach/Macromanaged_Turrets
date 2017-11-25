local _MOD = require("src/constants")
local _util = require("src/util")
local _core = require("src/core")
local _logistics = require("src/logistics")
local _circuitry = require("src/circuitry")
local _control = require("src/gui/control/buttons")
local mod_prefix = _MOD.DEFINES.prefix
local gui_prefix = mod_prefix.."control-"
local globalCall = _util.globalCall

local function on_gui_click(event) --Perform GUI functions
	local name = event.element.name
	if not _util.string_starts_with(name, gui_prefix) then
		return
	end
	local id = event.player_index
	if globalCall("TurretGUI")[id] == nil then
		_control.destroy(id)
		return
	end
	local player = _util.get_player(id)
	if player == nil then
		return
	end
	local gui = player.gui
	if gui.center[gui_prefix.."gui"] == nil then
		return
	end
	if name ~= gui_prefix.."edit-field" and gui.center[gui_prefix.."gui"][gui_prefix.."logistics-flow"][gui_prefix.."turret-frame"][gui_prefix.."turret-label"][gui_prefix.."edit-field"] ~= nil then
		_control.rename_turret(id, gui) --Close the label editor whenever anything else is clicked
	end
	if name == gui_prefix.."item-button" then
		_control.click_item(id, gui, event.element.caption)
	elseif _control.buttons[name] ~= nil then
		_control.buttons[name](id, gui, name:sub(#gui_prefix + 1, -8))
	elseif _util.string_ends_with(name, "-ammo-button") then
		_control.click_ammo(id, gui, name:sub(#gui_prefix + 1, -13))
	elseif _util.string_ends_with(name, "-turret-button") then
		_control.click_turret(id, gui, name:sub(#gui_prefix + 1, -15))
	end
end

local function on_pre_player_died(event) --Close GUI
	_control.close(event.player_index)
end

local function on_player_left_game(event) --Close GUI and clear clipboard
	local id = event.player_index
	_control.destroy(id)
	globalCall("Clipboard")[id] = nil --Delete clipboard data
end

local function on_player_selected_area(event) --Use the logistic turret remote to open the turret GUI
	if event.item ~= _MOD.DEFINES.remote_control then
		return
	end
	local id = event.player_index
	local player = _util.get_player(id)
	if player == nil then
		return
	end
	_control.close(id) --Close any open GUI before proceeding
	local force = player.force
	if not _core.is_remote_enabled(force) then --Logistic system is not researched
		player.print({"MMT.message.remote-fail"})
		return
	end
	local entities = event.entities
	local turret_list = {}
	for i = 1, #entities do
		local entity = entities[i]
		if entity.valid then
			local name = entity.name
			if globalCall("LogicTurretConfig")[name] ~= nil and entity.operable and not entity.to_be_deconstructed(force) then
				local logicTurret = _core.lookup_turret(entity)
				if logicTurret ~= nil then
					if turret_list[name] == nil then
						turret_list[name] = {}
					end
					turret_list[name][#turret_list[name] + 1] = logicTurret --Sort turrets into lists by name
				end
			end
		end
	end
	if next(turret_list) ~= nil then
		local logicTurrets = {}
		local count = 0
		for name, data in _util.spairs(turret_list, _util.sort_by.length) do
			logicTurrets[name] = data
			count = count + 1
			if count >= 5 then --Limit to five types
				break
			end
		end
		globalCall("TurretGUI")[id] = {logicTurrets = logicTurrets, index = {}, cache = {}, version = settings.get_player_settings(player)[mod_prefix.."GUI-version"].value} --GUI metadata
		_control.open(id)
	end
end

local function on_player_alt_selected_area(event) --Quick-paste mode
	if event.item ~= _MOD.DEFINES.remote_control then
		return
	end
	local id = event.player_index
	local player = _util.get_player(id)
	if player == nil then
		return
	end
	_control.close(id) --Close any open GUI before proceeding
	local force = player.force
	if not _core.is_remote_enabled(force) then --Logistic system is not researched
		player.print({"MMT.message.remote-fail"}) --Display a message
		return
	end
	local clipboard = globalCall("Clipboard")[id]
	if clipboard == nil then --Clipboard is empty
		player.print({"MMT.message.paste-nil"}) --Display a message
		return
	end
	local copied_turret, category, ammo, count, circuitry = clipboard.turret, clipboard.category, clipboard.ammo, clipboard.count, clipboard.circuitry --Clipboard contents
	local mod_settings = player.mod_settings
	local is_compatible = function() return false end
	if mod_settings[mod_prefix.."quickpaste-mode"].value == _MOD.DEFINES.quickpaste_mode.ammo_category then
		is_compatible = function(turret)
			if _logistics.get_ammo_category(turret) == category then return true end
		end
	elseif mod_settings[mod_prefix.."quickpaste-mode"].value == _MOD.DEFINES.quickpaste_mode.turret_name then
		is_compatible = function(turret)
			if turret == copied_turret then return true end
		end
	end
	local paste_data =
	{
		rCount = 0,
		bCount = 0,
		oCount = 0,
		rUnit = nil,
		bUnit = nil,
		oUnit = nil
	}
	local entities = event.entities
	for i = 1, #entities do
		local entity = entities[i]
		if entity.valid then
			local name = entity.name
			if globalCall("LogicTurretConfig")[name] ~= nil and is_compatible(name) and entity.operable and not entity.to_be_deconstructed(force) then
				local logicTurret = _core.lookup_turret(entity)
				if logicTurret ~= nil then
					_control.interrupt(entity) --Close this turret's GUI for all players
					if circuitry ~= nil and mod_settings[mod_prefix.."quickpaste-circuitry"].value then
						_circuitry.set_circuitry(logicTurret, circuitry.mode, circuitry.wires)
						if paste_data.bUnit == nil then
							paste_data.bUnit = _control.get_label(logicTurret, id)
						end
						paste_data.bCount = paste_data.bCount + 1
					end
					if _circuitry.get_circuitry(logicTurret).mode == _MOD.DEFINES.circuit_mode.set_requests then --Request slot is overridden by a circuit network
						if paste_data.oUnit == nil then
							paste_data.oUnit = _control.get_label(logicTurret, id)
						end
						paste_data.oCount = paste_data.oCount + 1
					else
						if ammo == _MOD.DEFINES.blank_in_gui then
							_logistics.set_request(logicTurret, _MOD.DEFINES.blank_request)
						else
							_logistics.set_request(logicTurret, {ammo = ammo, count = count})
						end
						if paste_data.rUnit == nil then
							paste_data.rUnit = _control.get_label(logicTurret, id)
						end
						paste_data.rCount = paste_data.rCount + 1
					end
				end
			end
		end
	end
	player.print(_control.compose_message(paste_data, clipboard)) --Display a message based on the result
end

local function on_player_removed(event) --Close all GUIs and clear all clipboard data
	for id in pairs(globalCall("TurretGUI")) do
		_control.destroy(id)
	end
	for id in pairs(globalCall("Clipboard")) do
		global.Clipboard[id] = nil
	end
end

local function on_custom_input_close_gui(event) --Close GUI
	_control.close(event.player_index)
end

return
{
	dispatch =
	{
		[defines.events.on_gui_click] = on_gui_click,
		[defines.events.on_pre_player_died] = on_pre_player_died,
		[defines.events.on_player_left_game] = on_player_left_game,
		[defines.events.on_player_selected_area] = on_player_selected_area,
		[defines.events.on_player_alt_selected_area] = on_player_alt_selected_area,
		[defines.events.on_player_removed] = on_player_removed,
		[_MOD.DEFINES.custom_input.close_gui] = on_custom_input_close_gui
	},
	destroy = _control.destroy,
	interrupt = _control.interrupt
}