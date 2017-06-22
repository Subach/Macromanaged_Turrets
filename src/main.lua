local _MOD = require("src/constants")
local _util = require("src/util")
local _core = require("src/core")
local _event = require("src/event")
local _loader = require("src/loader")
local _migration = require("src/migration")
local protect = require("src/protect")
local globalCall = _util.globalCall

local function load_config() --Run the loader in protected mode
	protect(_loader.load_config)
end

local function on_load() --Register the loader to run on the first tick
	script.on_event(defines.events.on_tick, load_config)
end

local function on_init() --Initialize globals
	globalCall("LogicTurretConfig")
	globalCall("RemoteTurretConfig")
	globalCall("LogicTurrets")
	globalCall("TurretArrays", "Active")
	globalCall("TurretArrays", "Idle")
	globalCall("TurretArrays", "Dormant")
	globalCall("LookupTable", "Contents")
	globalCall("LookupTable", "Registry")
	globalCall("AmmoData", "AmmoLists")
	globalCall("AmmoData", "Categories")
	globalCall("Clipboard")
	globalCall("TurretGUI")
--globalCall("CircuitNetworks") --TODO: Optimize input mode in v0.15
	globalCall("GhostData", "Connections")
	globalCall("GhostData", "OldConnections")
	globalCall("GhostData", "BlueWire", "Log")
	globalCall("GhostData", "BlueWire", "Queue")
	globalCall("GhostData", "BlueWire").Tick = 1
	global.ActiveCounter = 1
	global.IdleCounter = 1
	_loader.sort_ammo_types() --Create lists of ammo categories
	on_load()
end

local function on_configuration_changed(data) --Update mod
	local mod_changes = data.mod_changes
	if mod_changes == nil then
		return
	end
	local mod = mod_changes[_MOD._NAME]
	if mod ~= nil then
		local old_version = mod.old_version
		if old_version ~= nil then
			if _util.is_older_than("1.1.0", old_version) then _migration.patch_to("1.1.0") end
			if _util.is_older_than("1.1.4", old_version) then _migration.patch_to("1.1.4") end
		end
	end
	_loader.sort_ammo_types() --Re-create the ammo lists
	_loader.reload_tech() --Reload any technologies that unlock the logistic turret remote and awaken dormant turrets if necessary
	_loader.fix_components() --Validate and fix logistic turret entities
	if mod_changes["autofill"] ~= nil and mod_changes["autofill"].old_version == nil then --Autofill was installed
		_loader.autofill.set_profiles(globalCall("LogicTurretConfig"))
	end
end

local function on_event(event) --Run events in protected mode
	protect(_event.dispatch[event.name], event)
end

local function on_hotkey(event) --Run hotkey events in protected mode
	protect(_event.hotkey[event.input_name], event)
end

local function on_tick_controller(event) --Enable or disable the on_tick handler by raising a custom event
	if event.enabled then
		script.on_event(defines.events.on_tick, _event.on_tick)
	else
		script.on_event(defines.events.on_tick, nil)
	end
end

script.on_init(on_init)
script.on_load(on_load)
script.on_configuration_changed(on_configuration_changed)
script.on_event(_MOD.DEFINES.events.control_event, on_tick_controller)
for id in pairs(_event.dispatch) do
	script.on_event(id, on_event)
end
for id in pairs(_event.hotkey) do
	script.on_event(id, on_hotkey)
end
remote.add_interface(_MOD._NAME, require("src/remote"))