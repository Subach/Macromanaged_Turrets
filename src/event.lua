local _MOD = require("src/constants")
local _util = require("src/util")
local _core = require("src/core")
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
		_core.blueprint:handler(event.name, logicTurret)
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
	_core.blueprint:handler(event.name, entity)
end

local function on_pre_mined_entity(event) --Remove turret from the logistic turret list, handle any leftover ammo, and destroy its internal components
	local entity = event.entity
	if entity == nil or not entity.valid then
		return
	end
	local logicTurret = _core.lookup_turret(entity)
	if logicTurret ~= nil then
		local id = event.player_index
		local player = _util.get_player(id)
		local turret = logicTurret.entity
		_gui.interrupt(turret) --Close this turret's GUI for all players
		if player ~= nil then
			if entity.name == _MOD.DEFINES.logic_turret.interface then --Player mined the circuit network interface
				_util.raise_event(defines.events.on_preplayer_mined_item, {entity = turret, player_index = id}) --Raise an event as though the turret was mined
				if turret.valid then --Check if the turret is still valid after raising the event
					_core.logistics.transfer_inventory(turret, player) --Transfer the turret's inventory to the player
					if not turret.has_items_inside() then
						local health = turret.health / turret.prototype.max_health
						if health == 1 then
							health = nil
						end
						local products = turret.prototype.mineable_properties.products
						for i = 1, #products do
							local product = products[i]
							if product.type == "item" then
								local count = product.amount or (math.random(product.amount_min, product.amount_max) * ((product.probability >= math.random()) and 1 or 0))
								if count ~= nil and count > 0 then
									local name = product.name
									local inserted = player.insert({name = name, count = count, health = health}) --Add the turret to the player's inventory
									if inserted < count then
										turret.surface.spill_item_stack(turret.position, {name = name, count = count - inserted, health = health}) --Drop turret on the ground if it didn't fit in the player's inventory
									end
									_util.raise_event(defines.events.on_player_mined_item, {item_stack = {name = name, count = count}, player_index = id}) --Raise an event as though the turret was mined
								end
							end
						end
						turret.destroy() --Remove turret
					end
				end
				return
			end
			_core.logistics.transfer_inventory(turret, player, logicTurret.inventory.stash, logicTurret.inventory.trash) --Transfer the turret's inventory to the player
		else
			_core.clear_ammo(logicTurret)
		end
		_core.destroy_components(logicTurret) --Remove from the logistic turret lists
	end
	_core.blueprint:handler(event.name, entity)
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
			if effects[i].recipe == _MOD.DEFINES.logic_turret.remote then --Logistic system is researched
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
		_core.logistics.set_request(logicTurret, "empty")
		_core.logistics.request_override(logicTurret, true) --Set override flag
	end
	_core.blueprint:handler(event.name, entity)
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
				_core.logistics.set_request(logicTurret, config)
			end
			_core.logistics.request_override(logicTurret, false) --Remove override flag
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

local function on_pre_entity_settings_pasted(event) --Prevent a player from copying the interface's settings with shift + right-click
	local source = event.source
	local destination = event.destination
	if source == nil or destination == nil or not (source.valid and destination.valid) then
		return
	end
	if source.name == _MOD.DEFINES.logic_turret.interface then
		local settings = destination.get_control_behavior()
		if settings ~= nil then
			globalCall("Clipboard", _MOD.DEFINES.logic_turret.interface)[destination.unit_number] = --Save the destination's settings
			{
				destination.circuit_connection_definitions,
				settings.circuit_condition,
				settings.connect_to_logistic_network,
				settings.logistic_condition,
				settings.use_colors
			}
		end
	end
end

local function on_entity_settings_pasted(event) --Prevent a player from copying the interface's settings with shift + right-click
	local source = event.source
	local destination = event.destination
	if source == nil or destination == nil or not (source.valid and destination.valid) then
		return
	end
	if source.name == _MOD.DEFINES.logic_turret.interface then
		local id = destination.unit_number
		local clipboard = globalCall("Clipboard", _MOD.DEFINES.logic_turret.interface)[id]
		if clipboard ~= nil then
			local settings = destination.get_or_create_control_behavior() --Give the destination its settings back
			local connections = clipboard[1]
			for i = 1, #connections do
				destination.connect_neighbour(connections[i])
			end
			settings.circuit_condition = clipboard[2]
			settings.connect_to_logistic_network = clipboard[3]
			settings.logistic_condition = clipboard[4]
			settings.use_colors = clipboard[5]
			global.Clipboard[_MOD.DEFINES.logic_turret.interface][id] = nil
		end
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
	_core.blueprint:handler(event.name, event)
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
	if cursor.valid_for_read and cursor.name == _MOD.DEFINES.logic_turret.remote then
		player.clean_cursor()
	elseif player.get_item_count(_MOD.DEFINES.logic_turret.remote) > 0 then
		player.clean_cursor()
		player.remove_item({name = _MOD.DEFINES.logic_turret.remote, count = 1})
		cursor.set_stack({name = _MOD.DEFINES.logic_turret.remote, count = 1})
	end
end

local function on_player_changed_surface(event) --Prevent a player from teleporting to the workshop
	local player = _util.get_player(event.player_index)
	if player == nil then
		return
	end
	local workshop = game.surfaces[_MOD.DEFINES.workshop]
	if workshop ~= nil and workshop.valid and player.surface == workshop then
		local surface = game.surfaces[event.surface_index]
		if surface == nil or not surface.valid then
			surface = game.surfaces["nauvis"]
		end
		player.teleport(player.position, surface)
	end
end
--[[--TODO: Finish wire update queue in v0.15
local function on_selected_entity_changed(event) --Add selected turret to the wire update queue
--This event does not exist in v0.14
end
--]]
return
{
	dispatch =
	{
		[defines.events.on_gui_click] = on_gui_click,
		[defines.events.on_entity_died] = on_entity_died,
		[defines.events.on_built_entity] = on_built_entity,
		[defines.events.on_preplayer_mined_item] = on_pre_mined_entity,
		[defines.events.on_robot_built_entity] = on_built_entity,
		[defines.events.on_robot_pre_mined] = on_pre_mined_entity,
		[defines.events.on_research_finished] = on_research_finished,
		[defines.events.on_marked_for_deconstruction] = on_marked_for_deconstruction,
		[defines.events.on_canceled_deconstruction] = on_canceled_deconstruction,
		[defines.events.on_forces_merging] = on_forces_merging,
		[defines.events.on_pre_entity_settings_pasted] = on_pre_entity_settings_pasted,
		[defines.events.on_entity_settings_pasted] = on_entity_settings_pasted,
		[defines.events.on_pre_player_died] = on_pre_player_died,
		[defines.events.on_player_left_game] = on_player_left_game,
		[defines.events.on_player_selected_area] = on_player_selected_area,
		[defines.events.on_player_alt_selected_area] = on_player_selected_area,
		[defines.events.on_player_changed_surface] = on_player_changed_surface,
	--[defines.events.on_selected_entity_changed] = on_selected_entity_changed --TODO: Finish wire update queue in v0.15
	},
	hotkey =
	{
		[_MOD.DEFINES.custom_input.close_gui] = on_custom_input_close_gui,
		[_MOD.DEFINES.custom_input.select_remote] = on_custom_input_select_remote
	},
	on_tick = require("src/on_tick")
}