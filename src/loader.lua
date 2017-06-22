local _MOD = require("src/constants")
local _util = require("src/util")
local _core = require("src/core")
local _gui = require("src/gui/main")
local _autofill = require("src/autofill")
local globalCall = _util.globalCall

local function find_turrets(new_turrets) --Find the turrets of new entries
	if new_turrets == nil or next(new_turrets) == nil then --No new turrets
		return
	end
	for _, surface in pairs(game.surfaces) do
		for name in pairs(new_turrets) do
			local turrets = surface.find_entities_filtered{name = name, type = "ammo-turret"}
			for i = 1, #turrets do
				local turret = turrets[i]
				if turret.valid and _core.lookup_turret(turret) == nil then
					_core.add_components(turret) --Create logistic turret
				end
			end
		end
	end
end

local function fix_components() --Validate and fix component entities
	local ammo_lists = globalCall("AmmoData", "AmmoLists")
	local ammo_types = globalCall("AmmoData", "Categories")
	local request_flags =
	{
		[_MOD.DEFINES.request_flag.full] = true,
		[_MOD.DEFINES.request_flag.half] = true,
		[_MOD.DEFINES.request_flag.override] = true,
		[_MOD.DEFINES.request_flag.circuitry.input] = true,
		[_MOD.DEFINES.request_flag.circuitry.output] = true,
		[_MOD.DEFINES.request_flag.circuitry.wires.red] = true,
		[_MOD.DEFINES.request_flag.circuitry.wires.green] = true
	}
	for id, logicTurret in pairs(globalCall("LogicTurrets")) do
		if _core.get_valid_turret(logicTurret) ~= nil then
			local turret = logicTurret.entity
			local surface = turret.surface
			local position = turret.position
			for key, component in pairs(logicTurret.components) do
				local pos = component.position
				if not (component.surface == surface and pos.x == position.x and pos.y == position.y) then --Move to the turret's position
					component.teleport(position, surface)
				end
				if key == "interface" then
					component.minable = (turret.minable and turret.prototype.mineable_properties.minable) --Set minable status to that of the parent turret
				end
				component.health = 1
				component.active = false
				component.destructible = false
				component.operable = false
			end
			local turret_name = turret.name
			local stash = logicTurret.inventory.stash
			local trash = logicTurret.inventory.trash
			if trash.valid_for_read and request_flags[trash.name] ~= nil then
				trash.clear()
			end
			if stash.valid_for_read then
				local name = stash.name
				if request_flags[name] ~= nil then
					stash.clear()
				elseif ammo_types[name] ~= ammo_lists[turret_name][0] then --Stash's ammo category does not match the turret's ammo category
					_core.logistics.move_ammo(stash, trash)
					_util.spill_stack(turret, stash)
				end
			end
			local force = turret.force
			if _core.is_remote_enabled(force) and not turret.to_be_deconstructed(force) then
				local request = _core.logistics.get_request(logicTurret)
				if request ~= nil then
					if ammo_types[request.name] ~= ammo_lists[turret_name][0] then --Request's ammo category does not match the turret's ammo category
						_core.logistics.set_request(logicTurret, globalCall("LogicTurretConfig")[turret_name]) --Reset to default
					else
						_core.logistics.set_request(logicTurret, {ammo = request.name, count = request.count})
					end
				else
					_core.logistics.set_request(logicTurret, "empty")
				end
			else
				_core.logistics.set_request(logicTurret, "empty")
				local magazine = turret.get_inventory(defines.inventory.turret_ammo)
				if magazine ~= nil and magazine.valid then
					for i = 1, #magazine do
						_core.logistics.move_ammo(stash, magazine[i])
					end
				end
				_core.logistics.move_ammo(stash, trash)
				_util.spill_stack(turret, stash)
			end
			local circuitry = _core.circuitry.get_circuitry(logicTurret)
			_core.circuitry.set_circuitry(logicTurret, circuitry.mode, circuitry.wires)
		end
	end
	find_turrets(globalCall("LogicTurretConfig"))
end

local function update_requests(updated_turrets) --Update the request slots of turrets whose entries have changed
	if updated_turrets == nil or next(updated_turrets) == nil then --No changes
		return
	end
	for id, logicTurret in pairs(globalCall("LogicTurrets")) do
		if _core.get_valid_turret(logicTurret) ~= nil then
			local turret = logicTurret.entity.name
			if updated_turrets[turret] then --Turret's entry has changed
				local config = globalCall("LogicTurretConfig")[turret]
				if config == nil then --Turret's entry was removed
					_core.clear_ammo(logicTurret)
					_core.destroy_components(logicTurret) --Remove from the logistic turret lists
				elseif _core.logistics.request_override(logicTurret) then --Turret's request has been edited in-game, and should therefore ignore the config file
					local request = _core.logistics.get_request(logicTurret)
					if request == nil then
						if config == "empty" then --Override is the same as the new request
							_core.logistics.request_override(logicTurret, false) --Remove override flag
						end
					elseif config ~= "empty" then
						if request.name == config.ammo and request.count == config.count then --Override is the same as the new request
							_core.logistics.request_override(logicTurret, false) --Remove override flag
						end
					end
				elseif _core.circuitry.get_circuitry(logicTurret).mode ~= _MOD.DEFINES.circuit_mode.set_requests then
					_core.set_request(logicTurret, config)
				end
			end
		end
	end
	for force, dormant_turrets in pairs(globalCall("TurretArrays", "Dormant")) do
		for i = #dormant_turrets, 1, -1 do
			local logicTurret = _core.get_valid_turret(globalCall("LogicTurrets")[dormant_turrets[i]])
			if logicTurret == nil then
				table.remove(dormant_turrets, i)
			else
				local turret = logicTurret.entity.name
				if updated_turrets[turret] and globalCall("LogicTurretConfig")[turret] == nil then --Turret's entry was removed
					_core.clear_ammo(logicTurret)
					_core.destroy_components(logicTurret) --Remove from the logistic turret lists
					table.remove(dormant_turrets, i)
				end
			end
		end
		if #dormant_turrets <= 0 then
			global.TurretArrays.Dormant[force] = nil --Delete list
		end
	end
end

local function validate_config(turret, config) --Sanity checks config entries, detects new and updated entries
	if turret == nil or config == nil or type(turret) ~= "string" then return end
	local turret_data = game.entity_prototypes[turret]; if turret_data == nil or turret_data.type ~= "ammo-turret" then return end
	local ammo_list = globalCall("AmmoData", "AmmoLists")[turret]; if ammo_list == nil then return end
	local old_config = globalCall("LogicTurretConfig")[turret]
	local valid_config = nil
	local new_turret = nil
	local updated_turret = nil
	if config == true or config == "empty" then
		if old_config ~= nil then --Previous entry exists
			if old_config ~= "empty" then
				updated_turret = true
			end
		else
			new_turret = true
		end
		valid_config = "empty" --All checks passed
	elseif type(config) == "table" then
		local ammo = config.ammo
		local count = config.count
		if ammo == nil or count == nil or type(ammo) ~= "string" or type(count) ~= "number" or count < 1 then return end
		local ammo_data = game.item_prototypes[ammo]; if ammo_data == nil or ammo_data.type ~= "ammo" then return end
		if old_config ~= nil and old_config ~= "empty" and old_config.ammo == ammo then --Previous entry exists and ammo type is the same
			if old_config.count ~= count then --Ammo count has changed
				count = math.min(math.floor(count), ammo_data.stack_size) --Round down to the nearest whole number, maximum one stack
				updated_turret = true
			end
			valid_config = {ammo = ammo, count = count} --All checks passed
		elseif globalCall("AmmoData", "Categories")[ammo] == ammo_list[0] then --Item's ammo category matches the turret's ammo category
			if old_config ~= nil then --Previous entry exists
				updated_turret = true
			else
				new_turret = true
			end
			count = math.min(math.floor(count), ammo_data.stack_size) --Round down to the nearest whole number, maximum one stack
			valid_config = {ammo = ammo, count = count} --All checks passed
		end
	end
	return valid_config, new_turret, updated_turret --Return results
end

local function check_config() --Compile a list of all valid config entries
	local new_turrets = {} --New entries will end up here
	local updated_turrets = {} --Updated entries will end up here
	local turret_list = {}
	if not _MOD.UNINSTALL then
		for turret, config in pairs(_MOD.LOGISTIC_TURRETS) do --Gather turrets from the user's config file
			turret_list[turret] = config
		end
		if _MOD.ALLOW_REMOTE_CONFIG then --Gather turrets added by remote calls
			for turret, config in pairs(globalCall("RemoteTurretConfig")) do
				turret_list[turret] = turret_list[turret] or config
			end
		end
		if _MOD.USE_BOBS_DEFAULT and game.active_mods["bobwarfare"] ~= nil then --Gather Bob's turrets
			for turret, entity in pairs(game.entity_prototypes) do
				if entity.type == "ammo-turret" and _util.string_starts_with(turret, "bob-") then --Find turrets with names prefixed by "bob-"
					turret_list[turret] = turret_list[turret] or _MOD.BOBS_DEFAULT
				end
			end
		end
		for turret, config in pairs(turret_list) do --Screen the list for new, updated, and invalid entries
			turret_list[turret], new_turrets[turret], updated_turrets[turret] = validate_config(turret, config)
		end
	end
	for turret in pairs(globalCall("LogicTurretConfig")) do
		if turret_list[turret] == nil then --Previous entry was removed from the config file/became invalid
			updated_turrets[turret] = true
		end
	end
	_util.save_to_global(turret_list, "LogicTurretConfig") --Overwrite the old list with the new
	return new_turrets, updated_turrets
end

local function load_config() --Main loader; runs on the first tick after loading a world
	local tick = game.tick
--[[--TODO: Optimize input mode in v0.15
	local timeout = _MOD.IDLE_INTERVAL * _MOD.UPDATE_INTERVAL
	for id, data in pairs(globalCall("CircuitNetworks")) do --Clear the cache of any circuit networks that are no longer in use
		if (tick - data._do_update) >= timeout then
			global.CircuitNetworks[id] = nil
		end
	end
--]]
	for tock, ghosts in pairs(globalCall("GhostData", "OldConnections")) do --Remove any ghost wires of expired ghost turrets
		if tick >= tock then
			for i = 1, #ghosts do
				local ghost = ghosts[i]
				if ghost.valid then
					ghost.destroy()
				end
			end
			global.GhostData.OldConnections[tock] = nil
		end
	end
	for tock, id in pairs(globalCall("GhostData", "BlueWire", "Queue")) do --Clear old entries from the wire update queue
		if tick >= tock then
			globalCall("GhostData", "BlueWire", "Log")[id] = nil
			global.GhostData.BlueWire.Queue[tock] = nil
		end
	end
	local new_turrets, updated_turrets = check_config() --Check config file for any changes
	update_requests(updated_turrets) --Apply changes
	find_turrets(new_turrets) --Apply new entries
	_autofill.set_profiles({new_turrets, updated_turrets}) --Update Autofill profiles
	_core.blueprint.validate_ghost_data() --Remove any invalid ghosts from the ghost lookup table
	_core.blueprint.queue_wire_update(globalCall("LogicTurrets")) --Add all logistic turrets to the wire update queue
	_util.raise_event(_MOD.DEFINES.events.control_event, {enabled = ((#globalCall("TurretArrays", "Active") + #globalCall("TurretArrays", "Idle")) > 0)}) --Register the on_tick handler if at least one logistic turret exists
end

return
{
	autofill = _autofill,
	fix_components = fix_components,
	load_config = load_config,
	validate_config = validate_config
}