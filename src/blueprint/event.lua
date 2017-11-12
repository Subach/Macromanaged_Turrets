local _MOD = require("src/constants")
local _util = require("src/util")
local _blueprint = require("src/blueprint/core")
local globalCall = _util.globalCall
local get_player = _util.get_player
local remove_old_ghosts = _blueprint.remove_old_ghosts
local update_ghost_wires = _blueprint.update_ghost_wires
local next = next

local function on_tick(tick) --Remove and update ghost wires
	local blue_wire = global.GhostData.BlueWire
	local id = blue_wire.Queue[tick]
	if id ~= nil then
		update_ghost_wires(global.LogicTurrets[id])
		blue_wire.Log[id] = nil
		blue_wire.Queue[tick] = nil
	end
	return (remove_old_ghosts(tick) and (next(blue_wire.Queue) ~= nil))
end

local function on_entity_died(logicTurret) --Save this turret's ghost data for when it gets rebuilt
	local turret = logicTurret.entity
	local ghost_timer = turret.force.ghost_time_to_live
	if ghost_timer > 0 then
		local chest = logicTurret.components.chest
		local memory = logicTurret.components.memory
		if chest.valid and memory.valid then
			update_ghost_wires(logicTurret)
			if chest.die() and memory.die() then
				local ghost_data = {turret = turret.name, labels = logicTurret.labels, expiration = game.tick + ghost_timer}
				_blueprint.set_ghost_data(turret, ghost_data)
				table.insert(globalCall("GhostData", "OldConnections", ghost_data.expiration), _blueprint.get_valid_ghost(turret, _MOD.DEFINES.logic_turret.chest))
				table.insert(globalCall("GhostData", "OldConnections", ghost_data.expiration), _blueprint.get_valid_ghost(turret, _MOD.DEFINES.logic_turret.memory))
			end
		end
	end
end

local function on_built_entity(entity) --Set ghost data when a blueprint is stamped down
	if entity.name ~= "entity-ghost" or not (entity.ghost_name == _MOD.DEFINES.logic_turret.chest or entity.ghost_name == _MOD.DEFINES.logic_turret.memory) then
		return
	end
	local turret = _blueprint.get_ghost_turret(entity)
	if turret ~= nil then
		_blueprint.set_ghost_data(turret, {turret = turret.ghost_name, expiration = math.huge})
	else
		entity.destroy()
	end
end

local function on_mined_entity(entity) --Remove ghost data when a ghost is mined
	if entity.name ~= "entity-ghost" or globalCall("LogicTurretConfig")[entity.ghost_name] == nil then
		return
	end
	local pos = entity.position
	local chest = _blueprint.get_valid_ghost(entity, _MOD.DEFINES.logic_turret.chest)
	local memory = _blueprint.get_valid_ghost(entity, _MOD.DEFINES.logic_turret.memory)
	if chest ~= nil then
		chest.destroy()
	end
	if memory ~= nil then
		memory.destroy()
	end
	_blueprint.remove_ghost_data(entity.surface.index, pos.x, pos.y, entity.force.name)
end

local function on_player_selected_area(event) --Add selected turrets to the wire update queue
	if event.item ~= _MOD.DEFINES.remote_control then
		return
	end
	local entities = event.entities
	local turret_list = {}
	for i = 1, #entities do
		local entity = entities[i]
		if entity.valid and globalCall("LogicTurretConfig")[entity.name] ~= nil then
			turret_list[entity.unit_number] = true
		end
	end
	_blueprint.queue_wire_update(turret_list)
end

local function on_selected_entity_changed(id) --Add selected turret to the wire update queue
	local player = get_player(id)
	if player == nil then
		return
	end
	local entity = player.selected
	if entity ~= nil and entity.valid and globalCall("LogicTurretConfig")[entity.name] ~= nil then
		_blueprint.queue_wire_update({[entity.unit_number] = true})
	end
end

return
{
	dispatch =
	{
		[defines.events.on_entity_died] = on_entity_died,
		[defines.events.on_built_entity] = on_built_entity,
		[defines.events.on_robot_built_entity] = on_built_entity,
		[defines.events.on_player_selected_area] = on_player_selected_area,
		[defines.events.on_player_alt_selected_area] = on_player_selected_area,
		[defines.events.on_selected_entity_changed] = on_selected_entity_changed,
		[defines.events.on_robot_mined_entity] = on_mined_entity,
		[defines.events.on_player_mined_entity] = on_mined_entity
	},
	on_tick = on_tick,
	queue_wire_update = _blueprint.queue_wire_update,
	revive_ghosts = _blueprint.revive_ghosts,
	validate_ghost_data = _blueprint.validate_ghost_data
}