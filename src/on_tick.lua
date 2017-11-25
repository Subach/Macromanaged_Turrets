local _MOD = require("src/constants")
local _util = require("src/util")
local _core = require("src/core")
local _logistics = require("src/logistics")
local _circuitry = require("src/circuitry")
local _blueprint = require("src/blueprint/main")
local table_compact = _util.table_compact
local get_valid_turret = _core.get_valid_turret
local get_insert_limit = _logistics.get_insert_limit
local move_ammo = _logistics.move_ammo
local set_signal = _circuitry.set_signal
local ghost_handler = _blueprint.on_tick

local function in_combat(logicTurret) --Compare damage dealt to a cached value
	local damage = logicTurret.entity.damage_dealt
	if logicTurret.damage_dealt ~= damage then --Turret is probably in combat
		logicTurret.damage_dealt = damage --Update cache
		return true
	end
end

local function request_fulfilled(logicTurret) --Check if a turret needs reloading
	local stash = logicTurret.inventory.stash
	if not stash.valid_for_read then --Stash is empty, no need for the turret to be active if there's nothing to move
		return true
	else
		local magazine = logicTurret.magazine
		return (magazine.valid_for_read and (magazine.name ~= stash.name or magazine.count >= get_insert_limit(logicTurret))) --Returns false if turret is empty or below its insert limit threshold
	end
end

local function process_active_turret(logicTurret) --Reload turret from its stash
	local magazine = logicTurret.magazine
	if magazine.valid_for_read then
		local reload = get_insert_limit(logicTurret) - magazine.count
		if reload > 0 then --Turret needs reloading
			move_ammo(logicTurret.inventory.stash, magazine, reload)
		end
	else --Turret is empty
		move_ammo(logicTurret.inventory.stash, magazine, get_insert_limit(logicTurret))
	end
end

local function process_idle_turret(logicTurret) --Move unwanted ammo to the bin
	local magazine = logicTurret.magazine
	if magazine.valid_for_read then
		local request = logicTurret.components.chest.get_request_slot(1)
		if request ~= nil and request.name ~= magazine.name then --Turret's ammo does not match its request
			move_ammo(magazine, logicTurret.inventory.trash, 1)
			move_ammo(logicTurret.inventory.stash, magazine, 1)
		end
	end
end

local function on_tick(event) --Controls the behavior of logistic turrets
	local active_turrets = global.TurretArrays.Active
	local idle_turrets = global.TurretArrays.Idle
	local aIndex = #active_turrets
	local iIndex = #idle_turrets
	if iIndex > 0 then --Check idle turrets
		local rIndex = nil
		local i = global.IdleCounter
		while i <= iIndex do
			local logicTurret = idle_turrets[i]
			if logicTurret == nil or logicTurret.destroy then
				if rIndex == nil then
					rIndex = i --First removed entry
				end
				idle_turrets[i] = nil
			elseif get_valid_turret(logicTurret) ~= nil and logicTurret.timer == nil and logicTurret.entity.active then
				if in_combat(logicTurret) or not request_fulfilled(logicTurret) then --Add to active list
					logicTurret.timer = 0 --Start the turret's timer
					aIndex = aIndex + 1
					active_turrets[aIndex] = logicTurret
				else
					if logicTurret.inventory.stash.valid_for_read then
						process_idle_turret(logicTurret)
					end
					set_signal(logicTurret)
				end
			end
			i = i + _MOD.IDLE_INTERVAL
		end
		if rIndex ~= nil then --At least one entry was removed
			iIndex = table_compact(idle_turrets, iIndex, rIndex) --Close the gaps left by removed entries
		end
		global.IdleCounter = (global.IdleCounter % _MOD.IDLE_INTERVAL) + 1
	end
	if aIndex > 0 then --Check active turrets
		local rIndex = nil
		local i = global.ActiveCounter
		while i <= aIndex do
			local logicTurret = active_turrets[i]
			if logicTurret == nil or logicTurret.destroy then
				if rIndex == nil then
					rIndex = i --First removed entry
				end
				active_turrets[i] = nil
			elseif get_valid_turret(logicTurret) ~= nil then
				logicTurret.timer = (logicTurret.timer % _MOD.ACTIVE_TIMER) + 1 --Increment the turret's timer
				if logicTurret.timer == _MOD.ACTIVE_TIMER and not in_combat(logicTurret) and request_fulfilled(logicTurret) then --Remove from active list
					if rIndex == nil then
						rIndex = i --First removed entry
					end
					logicTurret.timer = nil
					active_turrets[i] = nil
				else
					if logicTurret.inventory.stash.valid_for_read then
						process_active_turret(logicTurret)
					end
					set_signal(logicTurret)
				end
			end
			i = i + _MOD.ACTIVE_INTERVAL
		end
		if rIndex ~= nil then --At least one entry was removed
			aIndex = table_compact(active_turrets, aIndex, rIndex) --Close the gaps left by removed entries
		end
		global.ActiveCounter = (global.ActiveCounter % _MOD.ACTIVE_INTERVAL) + 1
	end
	if not ghost_handler(event.tick) and (aIndex + iIndex) <= 0 then --De-register the on_tick handler
		_util.raise_event(_MOD.DEFINES.events.control_event)
	end
end

return on_tick