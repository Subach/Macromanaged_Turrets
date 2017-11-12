local _MOD = require("src/constants")
local _util = require("src/util")
local _core = require("src/core")
local _logistics = require("src/logistics")
local _circuitry = require("src/circuitry")
local _blueprint = require("src/blueprint/main")
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
	local memory_flags =
	{
		[_MOD.DEFINES.memory_flag.full] = true,
		[_MOD.DEFINES.memory_flag.half] = true,
		[_MOD.DEFINES.memory_flag.override] = true,
		[_MOD.DEFINES.memory_flag.circuitry.input] = true,
		[_MOD.DEFINES.memory_flag.circuitry.output] = true,
		[_MOD.DEFINES.memory_flag.circuitry.wires.red] = true,
		[_MOD.DEFINES.memory_flag.circuitry.wires.green] = true
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
				component.active = false
				component.destructible = false
				component.operable = false
			end
			local turret_name = turret.name
			local stash = logicTurret.inventory.stash
			local trash = logicTurret.inventory.trash
			local memory = logicTurret.components.memory.get_inventory(defines.inventory.chest)[1]
			if trash.valid_for_read and memory_flags[trash.name] ~= nil then --Remove any dummy items that somehow made it into the trash
				trash.clear()
			end
			if stash.valid_for_read then
				local name = stash.name
				if memory_flags[name] ~= nil then --Remove any dummy items that somehow made it into the stash
					stash.clear()
				elseif not _logistics.turret_can_request(turret_name, name) then --Stash's ammo category does not match the turret's ammo category
					_logistics.move_ammo(stash, trash)
					_util.spill_stack(turret, stash)
				end
			end
			if memory.valid_for_read then
				if memory_flags[memory.name] ~= nil then --Remove any dummy items that somehow made it into memory
					memory.clear()
				else
					_logistics.move_ammo(memory, trash)
					_util.spill_stack(turret, memory)
				end
			end
			local force = turret.force
			if _core.is_remote_enabled(force) and not turret.to_be_deconstructed(force) then --Turret is allowed to request ammo
				local request = _logistics.get_request(logicTurret)
				if request ~= nil then
					if not _logistics.turret_can_request(turret_name, request.name) then --Request's ammo category does not match the turret's ammo category
						_logistics.set_request(logicTurret, globalCall("LogicTurretConfig")[turret_name]) --Reset to default
					else
						_logistics.set_request(logicTurret, {ammo = request.name, count = request.count}) --Re-apply the request settings to correct any erroneous flags
					end
				else
					_logistics.set_request(logicTurret, _MOD.DEFINES.blank_request) --Re-apply the request settings to correct any erroneous flags
				end
			else --Turret should not be requesting anything
				_logistics.set_request(logicTurret, _MOD.DEFINES.blank_request)
				if stash.valid_for_read then --Empty the stash
					local magazine = turret.get_inventory(defines.inventory.turret_ammo)
					if magazine ~= nil and magazine.valid then
						for i = 1, #magazine do
							_logistics.move_ammo(stash, magazine[i])
						end
					end
					_logistics.move_ammo(stash, trash)
					_util.spill_stack(turret, stash)
				end
			end
			local circuitry = _circuitry.get_circuitry(logicTurret)
			_circuitry.set_circuitry(logicTurret, circuitry.mode, circuitry.wires) --Re-apply the circuitry settings to correct any erroneous flags
		end
	end
	find_turrets(globalCall("LogicTurretConfig")) --Find any turrets that are missing their component entities
end

local function reload_tech() --Reload any technologies that unlock the logistic turret remote and awaken dormant turrets if necessary
	for name, force in pairs(game.forces) do
		for _, tech in pairs(force.technologies) do
			local effects = tech.effects
			if effects ~= nil then
				for i = 1, #effects do
					if effects[i].recipe == "logistic-chest-requester" then
						tech.reload()
						break
					end
				end
			end
		end
		local logistic_system = force.technologies["logistic-system"]
		local requester_chest = force.recipes["logistic-chest-requester"]
		local remote_control = force.recipes[_MOD.DEFINES.remote_control]
		remote_control.enabled = remote_control.enabled or (requester_chest ~= nil and requester_chest.enabled) or (logistic_system ~= nil and logistic_system.enabled) --Enable the remote if the logistic system is researched
		if remote_control.enabled and globalCall("TurretArrays", "Dormant")[name] ~= nil then --Logistic system is researched
			awaken_dormant_turrets(name)
		end
	end
end

local function sort_ammo_types() --Compile lists of ammo categories and the turrets that can use them
	local ammo_lists = {}
	local ammo_types = {}
	for ammo, item in pairs(game.item_prototypes) do
		local ammo_type = item.get_ammo_type()
		if ammo_type ~= nil and not item.has_flag("hidden") then --Skip hidden items
			ammo_types[ammo] = ammo_type.category --Save as dictionary
		end
	end
	for turret, entity in pairs(game.entity_prototypes) do
		if entity.type == "ammo-turret" then
			local ammo_category = entity.attack_parameters.ammo_category
			if ammo_category ~= nil then
				for ammo, category in pairs(ammo_types) do
					if ammo_category == category then --Turret's ammo category matches the item's ammo category
						if ammo_lists[turret] == nil then
							ammo_lists[turret] = {[0] = ammo_category} --Save category as index zero
						end
						ammo_lists[turret][#ammo_lists[turret] + 1] = ammo --Save as array
					end
				end
			end
		end
	end
	_util.save_to_global(ammo_lists, "AmmoData", "AmmoLists") --Save lists in the global table
	_util.save_to_global(ammo_types, "AmmoData", "Categories")
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
				elseif _logistics.request_override(logicTurret) then --Turret's request has been edited in-game, and should therefore ignore the config file
					local request = _logistics.get_request(logicTurret)
					if request == nil then
						if config == _MOD.DEFINES.blank_request then --Override is the same as the new request
							_logistics.request_override(logicTurret, false) --Remove override flag
						end
					elseif config ~= _MOD.DEFINES.blank_request then
						if request.name == config.ammo and request.count == config.count then --Override is the same as the new request
							_logistics.request_override(logicTurret, false) --Remove override flag
						end
					end
				elseif _circuitry.get_circuitry(logicTurret).mode ~= _MOD.DEFINES.circuit_mode.set_requests then
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
	if turret == nil or config == nil or type(turret) ~= "string" then
		return
	end
	local turret_data = game.entity_prototypes[turret]
	if turret_data == nil or turret_data.type ~= "ammo-turret" then
		return
	end
	local inventory_size = turret_data.get_inventory_size(defines.inventory.turret_ammo)
	if inventory_size == nil or inventory_size <= 0 then
		return
	end
	local valid_config = nil
	local new_turret = nil
	local updated_turret = nil
	local old_config = globalCall("LogicTurretConfig")[turret]
	if config == true or config == "true" or config == _MOD.DEFINES.blank_request then
		if old_config ~= nil then --Previous entry exists
			if old_config ~= _MOD.DEFINES.blank_request then
				updated_turret = true
			end
		else
			new_turret = true
		end
		valid_config = _MOD.DEFINES.blank_request --All checks passed
	elseif type(config) == "table" then
		local ammo = config.ammo
		local count = config.count
		if ammo == nil or count == nil or type(ammo) ~= "string" or type(count) ~= "number" or count < 1 then
			return
		end
		local ammo_data = game.item_prototypes[ammo]
		if ammo_data == nil or ammo_data.type ~= "ammo" then
			return
		end
		if old_config ~= nil and old_config ~= _MOD.DEFINES.blank_request and old_config.ammo == ammo then --Previous entry exists and ammo type is the same
			if old_config.count ~= count then --Ammo count has changed
				count = math.min(math.floor(count), ammo_data.stack_size) --Round down to the nearest whole number, maximum one stack
				updated_turret = true
			end
			valid_config = {ammo = ammo, count = count} --All checks passed
		elseif _logistics.turret_can_request(turret, ammo) then
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
	if not settings.global[_MOD.DEFINES.prefix.."uninstall-mod"].value then
		for turret, config in pairs(_MOD.LOGISTIC_TURRETS) do --Gather turrets from the user's config file
			turret_list[turret] = config
		end
		if settings.global[_MOD.DEFINES.prefix.."allow-remote-config"].value then --Gather turrets added by remote calls
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
	if tick <= 0 then
		return
	end
	local timeout = _MOD.IDLE_INTERVAL * 2
	for id, data in pairs(globalCall("CircuitNetworks")) do --Clear the cache of any circuit networks that are no longer in use
		if (tick - data._do_update) >= timeout then
			global.CircuitNetworks[id] = nil
		end
	end
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
	_autofill.set_profiles(new_turrets) --Create Autofill profiles
	_blueprint.validate_ghost_data() --Remove any invalid ghosts from the ghost lookup table
	_blueprint.queue_wire_update(globalCall("LogicTurrets")) --Add all logistic turrets to the wire update queue
	_util.raise_event(_MOD.DEFINES.events.control_event, {enabled = ((#globalCall("TurretArrays", "Active") + #globalCall("TurretArrays", "Idle")) > 0)}) --Register the on_tick handler if at least one logistic turret exists
end

return
{
	autofill = _autofill,
	fix_components = fix_components,
	load_config = load_config,
	reload_tech = reload_tech,
	sort_ammo_types = sort_ammo_types,
	validate_config = validate_config
}