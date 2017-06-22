local _MOD = require("src/constants")
local _util = require("src/util")
local _logistics = require("src/logistics")
local _circuitry = require("src/circuitry")
local _blueprint = require("src/blueprint/main")
local globalCall = _util.globalCall
local pairs = pairs

local function add_to_array(logicTurret, enabled) --Add a turret to the appropriate array
	if logicTurret == nil then
		return
	end
	local force = logicTurret.entity.force.name
	if enabled then
		if (#globalCall("TurretArrays", "Active") + #globalCall("TurretArrays", "Idle")) <= 0 then --Register the on_tick handler if this is the first logistic turret
			_util.raise_event(_MOD.DEFINES.events.control_event, {enabled = true})
		end
		table.insert(global.TurretArrays.Idle, logicTurret)
	else
		table.insert(globalCall("TurretArrays", "Dormant", force), logicTurret) --Remain dormant until the logistic system is researched
	end
end

local function add_to_lookup(logicTurret) --Add a turret to the lookup table
	if logicTurret == nil then
		return
	end
	local turret_id = logicTurret.id
	local turret_name = logicTurret.entity.name
	local registry = {[turret_name] = turret_id}
	for key, component in pairs(logicTurret.components) do
		local id = component.unit_number
		local name = _MOD.DEFINES.logic_turret[key]
		globalCall("LookupTable", "Contents", name)[id] = turret_id
		registry[name] = id
	end
	globalCall("LookupTable", "Contents", turret_name)[turret_id] = turret_id
	globalCall("LookupTable", "Registry")[turret_id] = registry
	globalCall("LogicTurrets")[turret_id] = logicTurret
end

local function remove_from_lookup(logicTurret) --Remove a turret from the lookup table
	if logicTurret == nil then
		return
	end
	local id = logicTurret.id
	for key, component_id in pairs(globalCall("LookupTable", "Registry")[id]) do
		globalCall("LookupTable", "Contents", key)[component_id] = nil
		if next(global.LookupTable.Contents[key]) == nil then
			global.LookupTable.Contents[key] = nil
		end
	end
	globalCall("LogicTurrets")[id] = nil
	global.LookupTable.Registry[id] = nil
end

local function clear_ammo(logicTurret) --Empty a turret's internal components of ammo
	if logicTurret == nil then
		return
	end
	local turret = logicTurret.entity
	if turret.valid then
		local magazine = turret.get_inventory(defines.inventory.turret_ammo)
		if magazine ~= nil and magazine.valid then
			local stash = logicTurret.inventory.stash
			local trash = logicTurret.inventory.trash
			for i = 1, #magazine do
				local slot = magazine[i]
				_logistics.move_ammo(stash, slot)
				_logistics.move_ammo(trash, slot)
			end
			_util.spill_stack(turret, stash)
			_util.spill_stack(turret, trash)
		end
	end
end

local function destroy_components(logicTurret) --Remove a turret from the logistic turret lists and destroy its internal components
	if logicTurret == nil then
		return
	end
	for _, component in pairs(logicTurret.components) do
		if component.valid then
			component.destroy()
		end
	end
	remove_from_lookup(logicTurret) --Remove turret from the lookup table
	logicTurret.destroy = true --Flag turret for removal from the logistic turret array during on_tick
end

local function get_valid_turret(logicTurret) --Check if all parts of a logistic turret are valid
	if logicTurret == nil or logicTurret.destroy then
		return
	end
	if not logicTurret.entity.valid then
		destroy_components(logicTurret) --Remove from the logistic turret lists
		return
	end
	for _, component in pairs(logicTurret.components) do
		if not component.valid then
			clear_ammo(logicTurret)
			destroy_components(logicTurret) --Remove from the logistic turret lists
			return
		end
	end
	return logicTurret
end

local function is_remote_enabled(force) --Check if the logistic turret remote is enabled
	if type(force) == "string" then
		force = game.forces[force]
	end
	if force ~= nil and force.valid then
		return force.recipes[_MOD.DEFINES.logic_turret.remote].enabled
	end
end

local function add_components(turret) --Create a logistic turret
	if turret == nil or not turret.valid then
		return
	end
	local surface = turret.surface
	local pos = turret.position
	local force = turret.force
	local ghost_data = _blueprint.revive_ghosts(turret) --Get any saved data if this turret was rebuilt from a ghost
	local components =
	{
		bin = surface.create_entity{name = _MOD.DEFINES.logic_turret.bin, position = pos, force = force}, --Recycle bin for unwanted ammo
		chest = ghost_data.chest or surface.create_entity{name = _MOD.DEFINES.logic_turret.chest, position = pos, force = force}, --Internal inventory that requests ammo for the turret
		combinator = surface.create_entity{name = _MOD.DEFINES.logic_turret.combinator, position = pos, force = force}, --Outputs turret inventory/filters incoming signals
		interface = ghost_data.interface or surface.create_entity{name = _MOD.DEFINES.logic_turret.interface, position = pos, force = force} --Circuit network interface
	}
	for _, component in pairs(components) do
		if component == nil or not component.valid then
			for k, entity in pairs(components) do
				if entity ~= nil and entity.valid then
					entity.destroy()
				end
			end
			return
		end
		component.active = false
		component.destructible = false
		component.operable = false
	end
	components.combinator.get_or_create_control_behavior().enabled = false --Turn combinator off
	components.interface.minable = (turret.minable and turret.prototype.mineable_properties.minable) --Only minable if the turret is
	components.interface.last_user = turret.last_user
	local logicTurret =
	{
		entity = turret,
		id = turret.unit_number,
		components = components,
		inventory =
		{
			magazine = turret.get_inventory(defines.inventory.turret_ammo)[1],
			stash = components.chest.get_inventory(defines.inventory.chest)[1],
			trash = components.bin.get_inventory(defines.inventory.chest)[1]
		},
		damage_dealt = turret.damage_dealt, --Used to keep track of when turret is in combat
		labels = ghost_data.labels or {} --Custom labels assigned by players
	}
	local enabled = is_remote_enabled(force)
	local circuitry = _circuitry.get_circuitry(logicTurret)
	if enabled and _logistics.get_request(logicTurret) == nil and not _logistics.request_override(logicTurret) and circuitry.mode ~= _MOD.DEFINES.circuit_mode.set_requests then
		_logistics.set_request(logicTurret, globalCall("LogicTurretConfig")[turret.name])
	end
	if circuitry.mode ~= _MOD.DEFINES.circuit_mode.off then --Re-wire the internal components if this turret was rebuilt from a ghost
		_circuitry.set_circuitry(logicTurret, circuitry.mode, circuitry.wires)
	end
	add_to_lookup(logicTurret)
	add_to_array(logicTurret, enabled)
	return logicTurret
end

local function awaken_dormant_turrets(force) --Awaken the dormant turrets of a force
	local dormant_turrets = globalCall("TurretArrays", "Dormant")[force]
	if dormant_turrets == nil then
		return
	end
	for i = 1, #dormant_turrets do
		local logicTurret = get_valid_turret(globalCall("LogicTurrets")[dormant_turrets[i]])
		if logicTurret ~= nil then
			_logistics.set_request(logicTurret, globalCall("LogicTurretConfig")[logicTurret.entity.name])
			add_to_array(logicTurret, true)
		end
	end
	global.TurretArrays.Dormant[force] = nil --Delete list
end

local function lookup_turret(entity) --Get a logistic turret
	if entity == nil or not entity.valid then
		return
	end
	local id = entity.unit_number
	local logicTurret = globalCall("LogicTurrets")[id]
	if logicTurret ~= nil then
		return get_valid_turret(logicTurret)
	else
		logicTurret = globalCall("LookupTable", "Contents")[entity.name]
		if logicTurret ~= nil then
			id = logicTurret[id]
			if id ~= nil then
				return get_valid_turret(global.LogicTurrets[id])
			end
		end
	end
end

return
{
	add_components = add_components,
	awaken_dormant_turrets = awaken_dormant_turrets,
	clear_ammo = clear_ammo,
	destroy_components = destroy_components,
	get_valid_turret = get_valid_turret,
	is_remote_enabled = is_remote_enabled,
	lookup_turret = lookup_turret
}