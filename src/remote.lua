local _MOD = require("src/constants")
local _util = require("src/util")
local _core = require("src/core")
local _loader = require("src/loader")
local _gui = require("src/gui/main")
local protect = require("src/protect")
local globalCall = _util.globalCall

local function remote_turret_lookup(entity) --Safely get a logistic turret
	local status, logicTurret = pcall(_core.lookup_turret, entity)
	if status then
		return logicTurret
	end
end

-- Configure a type of logistic turret
-- Parameters:
--   turret :: string; the name of a turret prototype
--   config :: true or "empty" or a table:
--     true: configure a turret without a default request
--     "empty": equivalent to true
--     table: configure a turret with a default request; takes two fields:
--       ammo :: string; the name of an ammo prototype
--       count :: int; the amount of ammo to request
-- Return value:
--   If the configuration was successful and included a default request:
--     config :: table; the turret's new default request
--   If the configuration was successful but did not include a default request:
--     "empty" :: string
--   If the configuration was unsuccessful:
--     nil
local function configure_logistic_turret(turret, config)
	if type(turret) ~= "string" then return end
	globalCall("RemoteTurretConfig")[turret] = _loader.validate_config(turret, config)
	if global.RemoteTurretConfig[turret] ~= nil then
		return _util.table_deepcopy(global.RemoteTurretConfig[turret])
	end
end

-- Change a turret's request
-- Parameters:
--   turret :: LuaEntity; a turret entity
--   ammo (optional, default: "empty") :: string; the name of an ammo prototype or "empty"
--   count (optional, default: one full stack) :: int; the amount of ammo to request
-- Return value:
--   If the request slot was successfully changed:
--     count :: int; the amount of ammo the turret is now requesting
--   If the request slot was successfully cleared:
--     true :: boolean
--   If the operation was unsuccessful:
--     false :: boolean
local function change_request_slot(turret, ammo, count)
	local logicTurret = remote_turret_lookup(turret)
	if logicTurret == nil then return false end
	if _core.circuitry.get_circuitry(logicTurret).mode ~= _MOD.DEFINES.circuit_mode.set_requests then
		if ammo == nil or ammo == "empty" or (count ~= nil and type(count) == "number" and count < 1) then
			_gui.interrupt(turret)
			_core.logistics.set_request(logicTurret, "empty")
			return true
		elseif type(ammo) == "string" then
			local ammo_data = game.item_prototypes[ammo]
			if ammo_data ~= nil and ammo_data.type == "ammo" and globalCall("AmmoData", "Categories")[ammo] == globalCall("AmmoData", "AmmoLists", turret.name)[0] then
				if count ~= nil and type(count) == "number" and count >= 1 then
					count = math.min(math.floor(count), ammo_data.stack_size)
				else
					count = ammo_data.stack_size
				end
				_gui.interrupt(turret)
				_core.logistics.set_request(logicTurret, {ammo = ammo, count = count})
				return count
			end
		end
	end
	return false
end

-- Change a turret's circuit mode
-- Parameters:
--   turret :: LuaEntity; a turret entity
--   mode (optional; default: "off") :: string; one of three strings:
--     "off": configure the turret to not interact with a circuit network
--     "output": configure the turret to transmit its inventory to the circuit network ("send contents" mode)
--     "input": configure the turret to change its request slot based on the circuit network signals it is receiving ("set requests" mode)
--   wires (optional) :: table; a table with two fields:
--     red (optional, default: false) :: true or false; configure the turret to interact with red wires
--     green (optional, default: false) :: true or false; configure the turret to interact with green wires
-- Return value:
--   If the operation was successful:
--     true :: boolean
--   If the operation was unsuccessful:
--     false :: boolean
local function change_circuit_mode(turret, mode, wires)
	local logicTurret = remote_turret_lookup(turret)
	if logicTurret == nil then return false end
	if mode == nil or mode == _MOD.DEFINES.circuit_mode.off or mode == _MOD.DEFINES.circuit_mode.send_contents or mode == _MOD.DEFINES.circuit_mode.set_requests then
		if type(wires) == "table" then
			wires.red = (wires.red == true)
			wires.green = (wires.green == true)
		else
			wires = {red = false, green = false}
		end
		_gui.interrupt(turret)
		_core.circuitry.set_circuitry(logicTurret, mode, wires)
		return true
	end
	return false
end

-- Change a turret's custom label for a player
-- Parameters:
--   turret :: LuaEntity; a turret entity
--   player :: LuaPlayer or int or string; a player object, index, or name
--   label (optional, default: nil) :: string; the custom label to assign to the turret
-- Return value:
--   If the custom label was successfully changed:
--     label :: string; the label to assigned to the turret
--   If the custom label was successfully cleared:
--     true :: boolean
--   If the operation was unsuccessful:
--     false :: boolean
local function change_custom_label(turret, player, label)
	local logicTurret = remote_turret_lookup(turret)
	if logicTurret == nil or player == nil then return false end
	if type(player) == "string" then
		player = game.players[player]
	end
	for id, playr in pairs(game.players) do
		if player == id then
			player = playr
		end
		if player.valid and player == playr then
			if label ~= nil then
				label = _util.string_trim(tostring(label) or "")
				if label == "" then
					label = nil
				end
			end
			_gui.destroy(id)
			logicTurret.labels[id] = label
			return (label or true)
		end
	end
	return false
end

-- Get the default configuration of a type of logistic turret
-- Parameters:
--   turret (optional) :: string; the name of a turret prototype
-- Return value:
--   If a turret was specified:
--     If the turret does not have a default request:
--       "empty" :: string
--     If the turret has a default request:
--       request :: table; a table with two fields:
--         ammo :: string; the name of an ammo prototype
--         count :: int; the amount of ammo to request
--     If the turret has not been configured:
--       nil
--   If a turret was not specified:
--     config :: table; a table containing the default configurations of all logistic turrets, indexed by name
local function get_default_configuration(turret)
	if turret == nil then
		return _util.table_deepcopy(globalCall("LogicTurretConfig"))
	elseif type(turret) == "string" then
		return _util.table_deepcopy(globalCall("LogicTurretConfig")[turret])
	end
end

-- Get a turret's request
-- Parameters:
--   turret :: LuaEntity; a turret entity
-- Return value:
--   If the turret is currently requesting ammo:
--     request :: table; a table with two fields:
--       name :: string; the name of an ammo prototype
--       count :: int; the amount of ammo the turret is requesting
--   If the turret is not currently requesting ammo:
--     nil
local function get_request_slot(turret)
	local logicTurret = remote_turret_lookup(turret)
	if logicTurret == nil then return end
	return _core.logistics.get_request(logicTurret)
end

-- Get a turret's circuit mode
-- Parameters:
--   turret :: LuaEntity; a turret entity
-- Return value:
--   circuitry :: table; a table with two fields:
--     mode :: string; one of three strings:
--       "off": the turret is not configured to interact with a circuit network
--       "output": the turret is transmitting its inventory to the circuit network ("send contents" mode)
--       "input": the turret is changing its request slot based on the circuit network signals it is receiving ("set requests" mode)
--     wires :: table; a table with two fields:
--       red :: true or false; whether or not the turret is configured to interact with red wires
--       green :: true or false; whether or not the turret is configured to interact with green wires
local function get_circuit_mode(turret)
	local logicTurret = remote_turret_lookup(turret)
	if logicTurret == nil then return end
	return _util.table_deepcopy(_core.circuitry.get_circuitry(logicTurret))
end

-- Get a turret's custom label(s)
-- Parameters:
--   turret :: LuaEntity; a turret entity
--   player (optional) :: LuaPlayer or int or string; a player object, index, or name
-- Return value:
--   If a player was specified and that player has assigned a custom label to the turret:
--     label :: string; the turret's custom label
--   If a player was specified and that player has not assigned a custom label to the turret:
--     nil
--   If a player was not specified:
--     labels :: table; a table containing all custom labels assigned to the turret, indexed by player_index
local function get_custom_label(turret, player)
	local logicTurret = remote_turret_lookup(turret)
	if logicTurret == nil then return end
	if player ~= nil then
		if type(player) == "string" then
			player = game.players[player]
		end
		for id, playr in pairs(game.players) do
			if player == id then
				player = playr
			end
			if player.valid and player == playr then
				return logicTurret.labels[id]
			end
		end
	else
		return _util.table_deepcopy(logicTurret.labels)
	end
end

-- Check if the logistic turret remote is enabled for a force, or enable it for a force
-- Parameters:
--   force :: LuaForce or string; a force object or name
--   enable (optional, default: false) :: true or false; whether or not to enable the logistic turret remote without needing to research it
-- Return value:
--   If the logistic turret remote is enabled:
--     true :: boolean
--   If the logistic turret remote is not enabled:
--     false :: boolean
--   If the force doesn't exist:
--     nil
local function remote_control(force, enable)
	if force == nil then return end
	for name, phorce in pairs(game.forces) do
		if force == name then
			force = phorce
		end
		if force.valid and force == phorce then
			if enable == true and not _core.is_remote_enabled(force) then
				force.recipes[_MOD.DEFINES.logic_turret.remote].enabled = true
				_core.awaken_dormant_turrets(name)
			end
			return _core.is_remote_enabled(force)
		end
	end
end

-- Resets most settings and may fix certain problems
-- Can only be called from the in-game console
local function reset_mod()
	if game.player == nil then return end
	globalCall("GhostData", "BlueWire").Tick = 1
	globalCall().ActiveCounter = 1
	globalCall().IdleCounter = 1
	_core.decorate_workshop()
	_core.sort_ammo_types()
	_core.reload_tech()
	_loader.fix_components()
	_loader.load_config()
end

-- Displays information about the mod in the player's console
-- Can only be called from the in-game console
-- Return value:
--   info :: table; a table containing the same information displayed to the player
local function mod_info()
	local player = game.player
	if player == nil then return end
	local info = _util.table_deepcopy(_MOD)
	info.LOGISTIC_TURRETS = _util.table_deepcopy(globalCall("LogicTurretConfig"))
	info.DEFINES = nil
	player.print(serpent.block(info, {indent = "", sortkeys = false, comment = false, compact = true}))
	return info
end

local _remote =
{
	configure_logistic_turret = configure_logistic_turret,
	change_request_slot = change_request_slot,
	change_circuit_mode = change_circuit_mode,
	change_custom_label = change_custom_label,
	get_default_configuration = get_default_configuration,
	get_request_slot = get_request_slot,
	get_circuit_mode = get_circuit_mode,
	get_custom_label = get_custom_label,
	remote_control = remote_control,
	reset_mod = reset_mod,
	mod_info = mod_info
}

for k, f in pairs(_remote) do
	_remote[k] = function(...) return protect(f, ...) end
end

return _remote