local _MOD = require("src/constants")
local _util = require("src/util")
local _core = require("src/core")
local _logistics = require("src/logistics")
local _circuitry = require("src/circuitry")
local globalCall = _util.globalCall

local _migration = {}

_migration["1.1.6"] = function()
--TODO: logicTurret.magazine vs. logicTurret.inventory.magazine
end

_migration["1.1.4"] = function()
	globalCall("TurretArrays", "Active")
	globalCall("TurretArrays", "Idle")
	globalCall("TurretArrays", "Dormant")
	globalCall("LookupTable", "Contents")
	globalCall("LookupTable", "Registry")
	globalCall("AmmoData", "AmmoLists")
	globalCall("AmmoData", "Categories")
	globalCall("GhostData", "Connections")
	globalCall("GhostData", "OldConnections")
	globalCall("GhostData", "BlueWire", "Log")
	globalCall("GhostData", "BlueWire", "Queue")
	globalCall("GhostData", "BlueWire").Tick = 1
	globalCall().ActiveCounter = 1
	globalCall().IdleCounter = 1
	global.LogicTurrets = {}
	global.ActiveLogicTurrets = nil
	global.DormantLogicTurrets = nil
	global.GhostConnections = nil
	global.AmmoCategories = nil
	global.TurretAmmoSets = nil
	global.Counter = nil
	for _, surface in pairs(game.surfaces) do
		local index = surface.index
		if globalCall("LookupTable")[index] ~= nil then
			for x in pairs(global.LookupTable[index]) do
				for y, logicTurret in pairs(global.LookupTable[index][x]) do
					if logicTurret.turret.valid and not logicTurret.destroy then
						local new_logicTurret = _core.add_components(logicTurret.turret)
						new_logicTurret.damage_dealt = logicTurret.damageDealt or new_logicTurret.damage_dealt
						new_logicTurret.labels = logicTurret.label or new_logicTurret.labels
						if logicTurret.chest.valid then
							local request = logicTurret.chest.get_request_slot(1)
							if request == nil then
								_logistics.set_request(new_logicTurret, _MOD.DEFINES.blank_request)
							elseif logicTurret.insertLimit == nil then
								_logistics.set_request(new_logicTurret, globalCall("LogicTurretConfig")[new_logicTurret.entity.name])
							else
								if logicTurret.insertLimit < math.huge then
									request.count = request.count + math.floor(logicTurret.insertLimit)
								end
								_logistics.set_request(new_logicTurret, {ammo = request.name, count = request.count})
							end
							new_logicTurret.components.chest.get_inventory(defines.inventory.chest)[1].set_stack(logicTurret.chest.get_inventory(defines.inventory.chest)[1])
						end
						if logicTurret.interface.valid then
							local connections = logicTurret.interface.circuit_connection_definitions
							for i = 1, #connections do
								new_logicTurret.components.interface.connect_neighbour(connections[i])
							end
						end
						if logicTurret.circuitry ~= nil then
							_circuitry.set_circuitry(new_logicTurret, logicTurret.circuitry.mode, logicTurret.circuitry.wires)
						end
						if logicTurret.bin.valid then logicTurret.bin.destroy() end
						if logicTurret.chest.valid then logicTurret.chest.destroy() end
						if logicTurret.combinator.valid then logicTurret.combinator.destroy() end
						if logicTurret.interface.valid then logicTurret.interface.destroy() end
					end
				end
			end
			global.LookupTable[index] = nil
		end
	end
end

_migration["1.1.0"] = function()
	local lists = {globalCall("LogicTurrets"), global.IdleLogicTurrets}
	for i = 1, #lists do
		local turret_list = lists[i]
		for j = #turret_list, 1, -1 do
			local logicTurret = turret_list[j]
			local turret = logicTurret[1]
			local chest = logicTurret[2]
			if chest.valid then
				if turret.valid then
					local new_logicTurret =
					{
						turret = turret,
						chest = chest,
						bin = {valid = false},
						combinator = {valid = false},
						interface = {valid = false}
					}
					local pos = turret.position
					globalCall("LookupTable", turret.surface.index, pos.x)[pos.y] = new_logicTurret
				else
					chest.destroy()
				end
			end
		end
	end
	for _, force in pairs(game.forces) do
		force.recipes[_MOD.DEFINES.remote_control].reload()
	end
	global.IconSets = nil
	global.IdleLogicTurrets = nil
end

local function patch_to(version, ...)
	return _migration[version](...)
end

return
{
	patch_to = patch_to
}