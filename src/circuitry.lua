local _MOD = require("src/constants")
local _util = require("src/util")
local _logistics = require("src/logistics")
local circuit_mode = _MOD.DEFINES.circuit_mode
local request_flag = _MOD.DEFINES.request_flag
local request_slot = _MOD.DEFINES.request_slot
local interval = _MOD.ACTIVE_INTERVAL
local spairs = _util.spairs
local sort_by_value = _util.sort_by.value
local set_request = _logistics.set_request
local request_override = _logistics.request_override
local next = next
local pairs = pairs

local function get_mode(logicTurret) --Get a turret's current circuit mode of operation
	local mode = logicTurret.components.chest.get_request_slot(request_slot.mode)
	if mode ~= nil then
		if mode.name == request_flag.circuitry.output then
			return circuit_mode.send_contents
		elseif mode.name == request_flag.circuitry.input then
			return circuit_mode.set_requests
		end
	end
	return circuit_mode.off
end

local function get_wires(logicTurret) --Get the wire types the turret is allowed to connect to
	local chest = logicTurret.components.chest
	return {red = (chest.get_request_slot(request_slot.red) ~= nil), green = (chest.get_request_slot(request_slot.green) ~= nil)}
end

local function get_circuitry(logicTurret) --Get a turret's circuitry settings
	return {mode = get_mode(logicTurret), wires = get_wires(logicTurret)}
end

local function set_circuitry(logicTurret, mode, wires) --Wire the turret's internal components and set the mode of operation
	local chest = logicTurret.components.chest
	local combinator = logicTurret.components.combinator
	local interface = logicTurret.components.interface
	local signal = combinator.get_or_create_control_behavior()
	chest.get_or_create_control_behavior().circuit_mode_of_operation = defines.control_behavior.logistic_container.circuit_mode_of_operation.send_contents --Reset to "send contents"
	if mode == nil or mode == circuit_mode.off or not (wires.red or wires.green) then --Remove all wires, reset all settings
		for wire in pairs(wires) do
			chest.clear_request_slot(request_slot[wire]) --Remove wire flag
			combinator.disconnect_neighbour(defines.wire_type[wire])
		end
		chest.clear_request_slot(request_slot.mode) --Remove mode flag
		signal.parameters = {parameters = {}} --Reset signals
		signal.enabled = false --Turn combinator off
		logicTurret.circuitry = nil
	elseif mode == circuit_mode.send_contents or mode == circuit_mode.set_requests then
		logicTurret.circuitry = {}
		for wire, enabled in pairs(wires) do
			if enabled then
				chest.set_request_slot({name = request_flag.circuitry.wires[wire], count = 1}, request_slot[wire]) --Set wire flag
				combinator.connect_neighbour({wire = defines.wire_type[wire], target_entity = interface})
			else
				chest.clear_request_slot(request_slot[wire]) --Remove wire flag
				combinator.disconnect_neighbour(defines.wire_type[wire])
			end
		end
		if mode == circuit_mode.send_contents then
			signal.enabled = true --Turn combinator on
		elseif mode == circuit_mode.set_requests then
			signal.parameters = {parameters = {}} --Reset signals
			signal.enabled = false --Turn combinator off
			request_override(logicTurret, false) --Remove override flag
			logicTurret.circuitry.override = true --Delays activating input mode to give the circuit network time to update; otherwise a turret switching from "send contents" to "set requests" could read its own inventory
		end
		chest.set_request_slot({name = request_flag.circuitry[mode], count = 1}, request_slot.mode) --Set mode flag
		logicTurret.circuitry.signal = signal
	end
end
--[ --TODO: Optimize input mode in v0.15
local function get_network_signals(logicTurret) --Combine signals from red and green networks, filtering out anything that isn't useable ammo
	local ammo_types = global.AmmoData.Categories
	local category = global.AmmoData.AmmoLists[logicTurret.entity.name][0] --Turret's ammo category
	local input = {}
	local interface = logicTurret.components.interface
	for wire, enabled in pairs(get_circuitry(logicTurret).wires) do
		if enabled then
			local network = interface.get_circuit_network(defines.wire_type[wire])
			if network ~= nil and network.valid then
				local signals = network.signals --Signals last tick
				for i = 1, #signals do
					local signal = signals[i]
					local item = signal.signal.name
					local count = signal.count
					if signal.signal.type == "item" and ammo_types[item] == category and count >= 1 then --Item's ammo category matches the turret's ammo category
						input[item] = (input[item] ~= nil) and (input[item] + count) or count
					end
				end
			end
		end
	end
	return input
end
--]]
--[[--TODO: Optimize input mode in v0.15
local function get_network_signals(network) --Get a network's signals, filtering out anything that isn't useable ammo, and cache the result for other turrets on the same network
--local id = network.network_id --New API method being added in v0.15; this code will not work without it
	local input = global.CircuitNetworks[id] or {}
	local tick = game.tick
	if next(input) == nil or tick >= input._do_update then --Check for updated signals
		local ammo_types = global.AmmoData.Categories
		local signals = network.signals --Signals last tick
		input = {_do_update = input._do_update, _last_update = input._last_update}
		for i = 1, #signals do
			local signal = signals[i]
			local item = signal.signal.name
			local count = signal.count
			if signal.signal.type == "item" and ammo_types[item] ~= nil and count >= 1 then
				input[item] = count
			end
		end
		if signal_has_changed(global.CircuitNetworks[id], input) then --Save the tick so querying turrets know there's a new list available
			input._last_update = tick
			global.CircuitNetworks[id] = input --Update cache
		end
		global.CircuitNetworks[id]._do_update = tick + interval --Next update will take place at least <interval> ticks from now
	end
	return input
end
--]]
local function signal_has_changed(cache, signals) --Compare signals to a cached value
	if cache == nil then
		return true
	end
	for item, count in pairs(cache) do
		if count ~= signals[item] then
			return true
		end
	end
	for item, count in pairs(signals) do
		if count ~= cache[item] then
			return true
		end
	end
	return false --No changes
end

local function set_signal(logicTurret) --Set the combinator's signal
	local circuitry = logicTurret.circuitry
	local mode = get_mode(logicTurret)
	if mode == circuit_mode.send_contents then --Send contents
		local magazine = logicTurret.entity.get_inventory(defines.inventory.turret_ammo) --Turret's inventory
		if magazine ~= nil and magazine.valid then
			local output = magazine.get_contents()
			if signal_has_changed(circuitry.cache, output) then --Build a new signal list
				local index = 0
				local signals = {}
				for item, count in spairs(output, sort_by_value) do 
					index = index + 1
					signals[index] = {signal = {type = "item", name = item}, count = count, index = index}
					if index >= 10 then --Combinator only supports 10 signals
						break
					end
				end
				circuitry.signal.parameters = {parameters = signals} --Set the combinator's signals
				circuitry.cache = output --Update cache
			end
		end
	elseif mode == circuit_mode.set_requests then --Set request
		if circuitry.override then
			logicTurret.components.chest.get_or_create_control_behavior().circuit_mode_of_operation = defines.control_behavior.logistic_container.circuit_mode_of_operation.set_requests --Activate input mode
		--circuitry.cache = {count = 0, tick = game.tick} --TODO: Optimize input mode in v0.15
			circuitry.override = nil
			return
		end
--[ --TODO: Optimize input mode in v0.15
		local input = get_network_signals(logicTurret)
		if signal_has_changed(circuitry.cache, input) then --Build a new signal list
			local found = false
			for item, sCount in spairs(input, sort_by_value) do
				local count = game.item_prototypes[item].stack_size
				set_request(logicTurret, {ammo = item, count = ((count <= sCount) and count or sCount)}) --Maximum one stack
				request_override(logicTurret, false) --Remove override flag
				found = true
				break --Only get one signal
			end
			if not found then
				set_request(logicTurret) --Clear request slot
				request_override(logicTurret, false) --Remove override flag
			end
			circuitry.cache = input --Update cache
		end
--]]
--[[--TODO: Optimize input mode in v0.15
		local ix = 0
		local input = {}
		local last_updated = circuitry.cache.tick
		local interface = logicTurret.components.interface
		for wire, enabled in pairs(get_circuitry(logicTurret).wires) do
			if enabled then
				local network = interface.get_circuit_network(defines.wire_type[wire])
				if network ~= nil and network.valid then
					ix = ix + 1
					input[ix] = get_network_signals(network)
					local list_updated = input[ix]._last_update
					last_updated = (last_updated >= list_updated) and last_updated or list_updated
				end
			end
		end
		if ix ~= circuitry.cache.count or last_updated > circuitry.cache.tick then --Build a new signal list
			if ix == 1 then
				input = input[ix]
			elseif ix > 1 then
				local merged_input = {}
				for i = 1, ix do
					for item, count in pairs(input[i]) do
						merged_input[item] = (merged_input[item] ~= nil) and (merged_input[item] + count) or count
					end
				end
				input = merged_input
			end
			local ammo_types = global.AmmoData.Categories
			local category = global.AmmoData.AmmoLists[logicTurret.entity.name][0] --Turret's ammo category
			local found = false
			for item, sCount in spairs(input, sort_by_value) do
				if ammo_types[item] == category then --Item's ammo category matches the turret's ammo category
					local count = game.item_prototypes[item].stack_size
					set_request(logicTurret, {ammo = item, count = ((count <= sCount) and count or sCount)}) --Maximum one stack
					request_override(logicTurret, false) --Remove override flag
					found = true
					break --Only get one signal
				end
			end
			if not found then
				set_request(logicTurret) --Clear request slot
				request_override(logicTurret, false) --Remove override flag
			end
			circuitry.cache.count = ix
			circuitry.cache.tick = last_updated --Update cache
		end
--]]
	end
end

return
{
	get_circuitry = get_circuitry,
	set_circuitry = set_circuitry,
	set_signal = set_signal
}