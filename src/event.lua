local _MOD = require("src/constants")
local _util = require("src/util")
local _core = require("src/core")
local _logistics = require("src/logistics")
local _blueprint = require("src/blueprint/main")
local _gui = require("src/gui/main")
local globalCall = _util.globalCall

local function on_gui_click(event) --Perform GUI functions
	_gui:handler(event.name, event)
end

local function on_entity_died(event) --Remove turret from the logistic turret list and destroy its internal components
	local entity = event.entity
	if entity == nil or not entity.valid or globalCall("LogicTurretConfig")[entity.name] == nil then
		return
	end
	local logicTurret = _core.lookup_turret(entity)
	if logicTurret ~= nil then
		_gui.interrupt(entity) --Close this turret's GUI for all players
		_blueprint:handler(event.name, logicTurret)
		_core.destroy_components(logicTurret) --Remove from the logistic turret lists
	end
end

local function on_built_entity(event) --Add turret to the logistic turret list
	local entity = event.created_entity
	if entity == nil or not entity.valid then
		return
	end
	if globalCall("LogicTurretConfig")[entity.name] ~= nil then
		_core.add_components(entity) --Create logistic turret
	end
	_blueprint:handler(event.name, entity)
end

local function on_mined_entity(event) --Remove turret from the logistic turret list, handle any leftover ammo, and destroy its internal components
	local entity = event.entity
	if entity == nil or not entity.valid then
		return
	end
	local logicTurret = _core.lookup_turret(entity)
	if logicTurret ~= nil then
		if entity.name == _MOD.DEFINES.logic_turret.interface then --Player mined the circuit network interface
			local player = _util.get_player(event.player_index)
			if player ~= nil and player.mine_entity(logicTurret.entity, false) then --Mine the turret too
				_core.destroy_components(logicTurret) --Remove from the logistic turret lists
			end
			return
		end
		_gui.interrupt(logicTurret.entity) --Close this turret's GUI for all players
		local buffer = event.buffer
		if buffer ~= nil and buffer.valid then
			for _, item in pairs(logicTurret.inventory) do
				if item.valid_for_read then
					buffer.insert(item)
					item.clear()
				end
			end
		end
		if event.robot ~= nil then
			_core.destroy_components(logicTurret) --Remove from the logistic turret lists
		end
	end
	_blueprint:handler(event.name, entity)
end

local function on_research_finished(event) --Awaken dormant turrets when the logistic system is researched
	local tech = event.research
	if tech == nil or not tech.valid then
		return
	end
	local force = tech.force.name
	if globalCall("TurretArrays", "Dormant")[force] == nil then --Force has no dormant turrets
		return
	end
	local effects = tech.effects
	if effects ~= nil then
		for i = 1, #effects do
			if effects[i].recipe == _MOD.DEFINES.remote_control then --Logistic system is researched
				_core.awaken_dormant_turrets(force)
				break
			end
		end
	end
end

local function on_marked_for_deconstruction(event) --Clear the chest's request slot when the turret is marked for deconstruction
	local entity = event.entity
	if entity == nil or not entity.valid then
		return
	end
	local logicTurret = _core.lookup_turret(entity)
	if logicTurret ~= nil then
		_gui.interrupt(entity) --Close this turret's GUI for all players
		_logistics.set_request(logicTurret, _MOD.DEFINES.blank_request)
		_logistics.request_override(logicTurret, true) --Set override flag
	end
end

local function on_canceled_deconstruction(event) --Reset the chest's request slot when deconstruction is canceled
	local entity = event.entity
	if entity == nil or not entity.valid then
		return
	end
	local config = globalCall("LogicTurretConfig")[entity.name]
	if config ~= nil then
		local logicTurret = _core.lookup_turret(entity)
		if logicTurret ~= nil then
			if _core.is_remote_enabled(entity.force) then --Logistic system is researched
				_logistics.set_request(logicTurret, config)
			end
			_logistics.request_override(logicTurret, false) --Remove override flag
		else --Bots started mining the turret, but didn't finish the job
			_core.add_components(entity) --Re-create logistic turret
		end
	end
end

local function on_forces_merging(event) --Migrate or awaken dormant turrets
	local source = event.source
	local destination = event.destination
	if source == nil or destination == nil or not (source.valid and destination.valid) then
		return
	end
	source = source.name
	local dormant_turrets = globalCall("TurretArrays", "Dormant")[source]
	if dormant_turrets == nil then
		return
	end
	if _core.is_remote_enabled(destination) then --Logistic system is researched
		_core.awaken_dormant_turrets(source)
	else
		destination = destination.name
		for i = 1, #dormant_turrets do
			local logicTurret = get_valid_turret(dormant_turrets[i])
			if logicTurret ~= nil then
				table.insert(globalCall("TurretArrays", "Dormant", destination), logicTurret.id) --Remain dormant until the logistic system is researched
			end
		end
		global.TurretArrays.Dormant[source] = nil --Delete list
	end
end

local function on_pre_player_died(event) --Close the turret GUI when a player dies
	_gui:handler(event.name, event.player_index)
end

local function on_player_left_game(event) --Close the turret GUI and clear the clipboard when a player leaves the game
	_gui:handler(event.name, event)
end

local function on_player_selected_area(event) --Use the logistic turret remote to open the turret GUI
	_gui:handler(event.name, event)
	_blueprint:handler(event.name, event)
end

local function on_custom_input_close_gui(event) --Close the turret GUI
	_gui:handler(event.input_name, event.player_index)
end

local function on_custom_input_select_remote(event) --Equip or stow the logistic turret remote
	local player = _util.get_player(event.player_index)
	if player == nil then
		return
	end
	local cursor = player.cursor_stack
	if cursor.valid_for_read and cursor.name == _MOD.DEFINES.remote_control then
		player.clean_cursor()
	elseif player.get_item_count(_MOD.DEFINES.remote_control) > 0 and player.clean_cursor() then
		player.remove_item({name = _MOD.DEFINES.remote_control, count = 1})
		cursor.set_stack({name = _MOD.DEFINES.remote_control, count = 1})
	end
end

local function on_selected_entity_changed(event) --Add selected turret to the wire update queue
	_blueprint:handler(event.name, event.player_index)
end

local function on_runtime_mod_setting_changed(event) --Update mod settings
	local setting = event.setting
	if setting == _MOD.DEFINES.prefix.."tick-interval" --[[ or setting == _MOD.DEFINES.prefix.."time-factor" --]] then
		local interval = settings.global[_MOD.DEFINES.prefix.."tick-interval"].value
--[[ --TODO: desync
		local time_factor = math.min(settings.global[_MOD.DEFINES.prefix.."time-factor"].value, math.floor(interval / 2))
		_MOD.ACTIVE_INTERVAL = math.max(math.floor(interval / time_factor), 1)
		_MOD.IDLE_INTERVAL = math.max(math.floor(interval / time_factor), 1) * 5
		_MOD.ACTIVE_TIMER = math.max(math.floor(900 / interval), 1)
		_MOD.UPDATE_INTERVAL = time_factor
		_MOD.UPDATE_TICK = time_factor - 1
--]]
		_MOD.ACTIVE_INTERVAL = interval
		_MOD.IDLE_INTERVAL = interval * 5
		_MOD.ACTIVE_TIMER = math.max(math.floor(900 / interval), 1)
	end
end

return
{
	dispatch =
	{
		[defines.events.on_gui_click] = on_gui_click,
		[defines.events.on_entity_died] = on_entity_died,
		[defines.events.on_built_entity] = on_built_entity,
		[defines.events.on_robot_built_entity] = on_built_entity,
		[defines.events.on_research_finished] = on_research_finished,
		[defines.events.on_marked_for_deconstruction] = on_marked_for_deconstruction,
		[defines.events.on_canceled_deconstruction] = on_canceled_deconstruction,
		[defines.events.on_forces_merging] = on_forces_merging,
		[defines.events.on_pre_player_died] = on_pre_player_died,
		[defines.events.on_player_left_game] = on_player_left_game,
		[defines.events.on_player_selected_area] = on_player_selected_area,
		[defines.events.on_player_alt_selected_area] = on_player_selected_area,
		[defines.events.on_selected_entity_changed] = on_selected_entity_changed,
		[defines.events.on_runtime_mod_setting_changed] = on_runtime_mod_setting_changed,
		[defines.events.on_robot_mined_entity] = on_mined_entity,
		[defines.events.on_player_mined_entity] = on_mined_entity
	},
	hotkey =
	{
		[_MOD.DEFINES.custom_input.close_gui] = on_custom_input_close_gui,
		[_MOD.DEFINES.custom_input.select_remote] = on_custom_input_select_remote
	},
	on_tick = require("src/on_tick")
}