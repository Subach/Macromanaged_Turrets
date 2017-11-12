local _MOD = require("src/constants")
local _util = require("src/util")
local globalCall = _util.globalCall
local position_to_area = _util.position_to_area
local next = next
local pairs = pairs

local function get_ghosts(locus) --Get all the ghosts at a position
	return locus.surface.find_entities_filtered{name = "entity-ghost", type = "entity-ghost", area = position_to_area(locus.position), force = locus.force}
end

local function get_ghost_data(index, x, y, force) --Get an entry from the ghost lookup table
	local ghost_data = globalCall("GhostData", "Connections")[index]
	if ghost_data ~= nil then
		ghost_data = ghost_data[x]
		if ghost_data ~= nil then
			ghost_data = ghost_data[y]
			if ghost_data ~= nil then
				return ghost_data[force]
			end
		end
	end
end

local function get_ghost_turret(entity) --Check if a ghost turret exists in the same location as an entity
	if entity == nil or not entity.valid then
		return
	end
	local ghosts = get_ghosts(entity)
	for i = 1, #ghosts do
		local ghost = ghosts[i]
		if ghost.valid then
			if globalCall("LogicTurretConfig")[ghost.ghost_name] ~= nil then
				return ghost
			end
		end
	end
end

local function get_valid_ghost(locus, name) --Get a ghost with a specific name
	local ghosts = get_ghosts(locus)
	for i = 1, #ghosts do
		local ghost = ghosts[i]
		if ghost.valid and ghost.ghost_name == name then
			return ghost
		end
	end
end

local function queue_wire_update(turret_list) --Add a list of turrets to the wire update queue
	local tick = game.tick
	local blue_wire = globalCall("GhostData", "BlueWire")
	local bTick = blue_wire.Tick
	if (bTick - tick) < 150 then
		bTick = tick + 150
	end
	for id in pairs(turret_list) do
		if blue_wire.Log[id] == nil then
			blue_wire.Queue[bTick] = id
			blue_wire.Log[id] = bTick
			bTick = bTick + 1
		end
	end
	blue_wire.Tick = bTick
end

local function remove_ghost_data(index, x, y, force) --Remove an entry from the ghost lookup table
	if get_ghost_data(index, x, y, force) ~= nil then
		local ghost_connections = globalCall("GhostData", "Connections")
		ghost_connections[index][x][y][force] = nil
		if next(ghost_connections[index][x][y]) == nil then
			ghost_connections[index][x][y] = nil
			if next(ghost_connections[index][x]) == nil then
				ghost_connections[index][x] = nil
				if next(ghost_connections[index]) == nil then
					ghost_connections[index] = nil
				end
			end
		end
	end
end

local function remove_old_ghosts(tick) --Remove ghost wires of expired ghost turrets
	local old_ghosts = global.GhostData.OldConnections
	local ghosts = old_ghosts[tick]
	if ghosts ~= nil then
		for _, ghost in pairs(ghosts) do
			if ghost.valid then
				ghost.destroy()
			end
		end
		old_ghosts[tick] = nil
	end
	return (next(old_ghosts) ~= nil)
end

local function revive_component(locus, name) --Revive a specific component
	local ghost = get_valid_ghost(locus, name)
	if ghost ~= nil then
		local entity = select(2, ghost.revive(false))
		if entity ~= nil and entity.valid then
			return entity
		elseif ghost.valid then
			ghost.destroy() --Destroy ghost if it failed to revive
		end
	end
end

local function revive_ghosts(turret) --Revive components and reconnect wires when a ghost turret is rebuilt
	if turret == nil or not turret.valid then
		return
	end
	local surface = turret.surface
	local index = surface.index
	local pos = turret.position
	local force = turret.force.name
	local ghost_data = get_ghost_data(index, pos.x, pos.y, force) or {}
	if ghost_data.turret == turret.name and ghost_data.expiration > game.tick then
		local chest = revive_component(turret, _MOD.DEFINES.logic_turret.chest)
		local memory = revive_component(turret, _MOD.DEFINES.logic_turret.memory)
		if chest ~= nil then
			ghost_data.chest = chest
		end
		if memory ~= nil then
			local connections = memory.circuit_connection_definitions
			if #connections > 0 then --Re-wire the interface's connections
				local interface = surface.create_entity{name = _MOD.DEFINES.logic_turret.interface, position = pos, force = force}
				if interface ~= nil and interface.valid then
					for i = 1, #connections do
						local connection = connections[i]
						local target = connection.target_entity
						if target.valid then
							if target.name == _MOD.DEFINES.logic_turret.memory then
								target = surface.find_entities_filtered{name = _MOD.DEFINES.logic_turret.interface, area = position_to_area(target.position), force = force, limit = 1}[1]
								if target ~= nil and target.valid then
									interface.connect_neighbour({wire = connection.wire, target_entity = target, target_circuit_id = connection.target_circuit_id})
								end
							else
								interface.connect_neighbour({wire = connection.wire, target_entity = target, target_circuit_id = connection.target_circuit_id})
							end
						end
					end
					ghost_data.interface = interface
				end
			end
			ghost_data.memory = memory
		end
	end
	remove_ghost_data(index, pos.x, pos.y, force)
	return ghost_data
end

local function set_ghost_data(entity, data) --Save an entity's ghost data
	local pos = entity.position
	globalCall("GhostData", "Connections", entity.surface.index, pos.x, pos.y)[entity.force.name] = data
end

local function circuit_has_changed(cache, connections) --Compare wire connections to a cached value
	if cache == nil then
		return true
	end
	for wire, entities in pairs(cache) do
		if connections[wire] == nil then
			return true
		end
		for id, connection in pairs(entities) do
			if connections[wire][id] == nil then
				return true
			end
			for k, v in pairs(connection) do
				if connections[wire][id][k] ~= v then
					return true
				end
			end
		end
	end
	for wire, entities in pairs(connections) do
		if cache[wire] == nil then
			return true
		end
		for id, connection in pairs(entities) do
			if cache[wire][id] == nil then
				return true
			end
			for k, v in pairs(connection) do
				if cache[wire][id][k] ~= v then
					return true
				end
			end
		end
	end
	return false --No changes
end

local function get_wire_connections(entity) --Sort a turret's wire connections, filtering out its internal components
	local connections = {}
	local definitions = entity.circuit_connection_definitions
	for i = 1, #definitions do
		local connection = definitions[i]
		local wire = connection.wire
		local target = connection.target_entity
		if target.valid and target.name ~= _MOD.DEFINES.logic_turret.combinator then
			if connections[wire] == nil then
				connections[wire] = {}
			end
			connections[wire][target.unit_number] = {target_entity = target, target_circuit_id = connection.target_circuit_id}
		end
	end
	return connections
end

local function update_ghost_wires(logicTurret) --Copy the interface's wire connections to memory so they can be saved in blueprints
	if logicTurret == nil or logicTurret.destroy then
		return
	end
	local interface = logicTurret.components.interface
	local memory = logicTurret.components.memory
	if interface ~= nil and memory ~= nil and interface.valid and memory.valid then
		local connections = get_wire_connections(interface)
		if circuit_has_changed(logicTurret.wire_cache, connections) then
			local force = memory.force
			memory.disconnect_neighbour(defines.wire_type.red)
			memory.disconnect_neighbour(defines.wire_type.green)
			for wire, entities in pairs(connections) do
				for id, connection in pairs(entities) do
					local target = connection.target_entity
					if target.valid then
						if target.name == _MOD.DEFINES.logic_turret.interface then
							target = memory.surface.find_entities_filtered{name = _MOD.DEFINES.logic_turret.memory, area = position_to_area(target.position), force = force, limit = 1}[1]
							if target ~= nil and target.valid then
								memory.connect_neighbour({wire = wire, target_entity = target, target_circuit_id = connection.target_circuit_id})
							end
						else
							memory.connect_neighbour({wire = wire, target_entity = target, target_circuit_id = connection.target_circuit_id})
						end
					end
				end
			end
			logicTurret.wire_cache = connections --Update cache
		end
	end
end

local function validate_ghost_data() --Remove expired entries from the ghost lookup table
	local tick = game.tick
	for index, exes in pairs(globalCall("GhostData", "Connections")) do
		local surface = game.surfaces[index]
		if surface == nil or not surface.valid then
			global.GhostData.Connections[index] = nil
		else
			for x, whys in pairs(exes) do
				for y, forsees in pairs(whys) do
					for force, ghost_data in pairs(forsees) do
						if ghost_data.expiration <= tick or globalCall("LogicTurretConfig")[ghost_data.turret] == nil or get_valid_ghost({surface = surface, position = {x, y}, force = force}, ghost_data.turret) == nil then
							remove_ghost_data(index, x, y, force) --Remove entry from the ghost lookup table
						end
					end
				end
			end
		end
	end
end

return
{
	get_ghost_turret = get_ghost_turret,
	get_valid_ghost = get_valid_ghost,
	queue_wire_update = queue_wire_update,
	remove_ghost_data = remove_ghost_data,
	remove_old_ghosts = remove_old_ghosts,
	revive_ghosts = revive_ghosts,
	set_ghost_data = set_ghost_data,
	update_ghost_wires = update_ghost_wires,
	validate_ghost_data = validate_ghost_data
}