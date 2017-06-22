require("config")

local math = math
local next = next
local pairs = pairs
local select = select
local sort = table.sort

local ModName = "Macromanaged_Turrets"
local ModPrefix = "MMT-"
local TurretChest = ModPrefix.."logistic-turret-chest"
local TurretBin = ModPrefix.."logistic-turret-bin"
local TurretCombinator = ModPrefix.."logistic-turret-combinator"
local TurretInterface = ModPrefix.."logistic-turret-interface"
local TurretRemote = ModPrefix.."logistic-turret-remote"
local BlankInGUI = "BIG-MMT" --GIANT ROBO-SCORPION™ not included
local OffMode = "off"
local SendContentsMode = "output"
local SetRequestsMode = "input"

local Interval = math.max(math.floor(tonumber(TickInterval) or 30), 1)
local IdleInterval = Interval * 5
local ActiveTimer = math.max(math.floor(900 / Interval), 1)
local QuickpasteMode = tostring(QuickPasteMode) or "match-ammo-category"
local QuickpasteBehavior = (QuickPasteCircuitry ~= false)
local AllowRemoteConfig = (AllowRemoteConfig ~= false)

local loaded = false

----------------------------------------------------------------------------------------------------
--Library
----------------------------------------------------------------------------------------------------
--Prototypes----------------------------------------------------------------------------------------
local onTick
local get_ghost_data
local set_circuitry

--Utility-------------------------------------------------------------------------------------------
local function globalCall(...) --Get or create a global table
	if global == nil then
		global = {}
	end
	local t = global
	local keys = {...}
	for i = 1, #keys do
		if t[keys[i]] == nil then
			t[keys[i]] = {}
		end
		t = t[keys[i]]
	end
	return t
end

local function save_to_global(t, key) --Overwrite a global table
	for k in pairs(globalCall(key)) do
		global[key][k] = nil
	end
	for k, v in pairs(t) do
		global[key][k] = v
	end
end

local function spairs(t, op) --Sort pairs
	local keys = {}
	for k in pairs(t) do
		keys[#keys + 1] = k
	end
	if op ~= nil then
		sort(keys, function(a, b) return op(t, a, b) end)
	else
		sort(keys)
	end
	local i = 0
	return function()
		i = i + 1
		if keys[i] ~= nil then
			return keys[i], t[keys[i]]
		end
	end
end

local function starts_with(s, start)
	return (string.find(s, start, 1, true) == 1)
end

local function ends_with(s, nd)
	return (#s >= #nd and string.find(s, nd, (#s - #nd) + 1, true) and true or false)
end

local function table_compact(t, r, z)
	local j = r - 1
	for i = r, z do
		if t[i] ~= nil then
			j = j + 1
			t[j] = t[i]
		end
	end
	for i = j + 1, z do
		t[i] = nil
	end
	return #t
end

--Core----------------------------------------------------------------------------------------------
local function is_remote_enabled(force) --Check if the logistic turret remote is enabled
	if type(force) == "string" then
		force = game.forces[force]
	end
	if force == nil or not force.valid then
		return
	end
	return force.recipes[TurretRemote].enabled
end

local function add_components(turret) --Add internal components
	if turret == nil or not turret.valid then
		return
	end
	local surface = turret.surface
	local pos = turret.position
	local force = turret.force
	local ghostData = get_ghost_data(turret) or {} --Get any saved data if this turret was rebuilt from a ghost
	local request = ghostData.request
	local insertLimit = ghostData.insertLimit or math.huge --No limit
	local mode = ghostData.mode or OffMode
	local wires = ghostData.wires or {red = false, green = false}
	local label = ghostData.label or {}
	local override = ghostData.override
	if request ~= nil then
		request = {{name = request.name, count = request.count, index = 1}} --Set request
	elseif mode ~= SetRequestsMode and not override and is_remote_enabled(force) then --Logistic system is researched
		local config = globalCall("LogicTurretConfig")[turret.name]
		if config ~= "empty" then --Turret has a default request
			if config.count <= 1 then
				insertLimit = 0.5 --Split single ammo item between the turret and chest
			else
				insertLimit = math.ceil(config.count / 2) --Split ammo between the turret and chest
			end
			request = {{name = config.ammo, count = math.max(config.count - insertLimit, 1), index = 1}} --Set request
		end
	end
	local interface = ghostData.interface or surface.create_entity{name = TurretInterface, position = pos, force = force} --Circuit network interface
	local combinator = surface.create_entity{name = TurretCombinator, position = pos, force = force} --Outputs turret inventory/filters incoming signals
	local bin = surface.create_entity{name = TurretBin, position = pos, force = force} --Recycle bin for unwanted ammo
	local chest = surface.create_entity{name = TurretChest, position = pos, force = force, request_filters = request} --Internal inventory that requests ammo for the turret
	if chest == nil or bin == nil or combinator == nil or interface == nil or not (chest.valid and bin.valid and combinator.valid and interface.valid) then
		if chest ~= nil and chest.valid then
			chest.destroy()
		end
		if bin ~= nil and bin.valid then
			bin.destroy()
		end
		if combinator ~= nil and combinator.valid then
			combinator.destroy()
		end
		if interface ~= nil and interface.valid then
			interface.destroy()
		end
		return
	end
	interface.last_user = turret.last_user
	interface.minable = (turret.minable and turret.prototype.mineable_properties.minable) --Only minable if the turret is
	interface.operable = false
	local logicTurret =
	{
		turret = turret,
		chest = chest,
		bin = bin,
		combinator = combinator,
		interface = interface,
		magazine = turret.get_inventory(defines.inventory.turret_ammo)[1],
		stash = chest.get_inventory(defines.inventory.chest)[1],
		trash = bin.get_inventory(defines.inventory.chest)[1],
		insertLimit = insertLimit, --The amount of ammo the turret will attempt to keep in its inventory
		damageDealt = turret.damage_dealt, --Used to keep track of when turret is in combat
		label = label, --Custom labels assigned by players
		override = override, --A turret with the override flag has had its request changed through the in-game GUI, and will therefore ignore any changes to its config entry
		circuitry =
		{
			mode = mode,
			wires = wires
		}
	}
	globalCall("LookupTable", surface.index, pos.x)[pos.y] = logicTurret --Add to lookup table
	if logicTurret.circuitry.mode ~= OffMode then --Re-wire the internal components if this turret was rebuilt from a ghost
		set_circuitry(logicTurret, logicTurret.circuitry.mode, logicTurret.circuitry.wires)
	end
	return logicTurret
end

local function add_logistic_turret(logicTurret, enabled) --Add a turret to the logistic turret list
	if logicTurret == nil then
		return
	end
	local force = logicTurret.turret.force.name
	if enabled or is_remote_enabled(force) then
		if #globalCall("LogicTurrets") + #globalCall("ActiveLogicTurrets") <= 0 then --If this is the first logistic turret, start the onTick function
			script.on_event(defines.events.on_tick, onTick)
		end
		global.LogicTurrets[#global.LogicTurrets + 1] = logicTurret --Add to turret list
	else
		globalCall("DormantLogicTurrets", force)[#global.DormantLogicTurrets[force] + 1] = logicTurret --Remain dormant until the logistic system is researched
	end
end

local function remove_address(index, x, y) --Remove an entry from the lookup table
	globalCall("LookupTable", index, x)[y] = nil
	if next(global.LookupTable[index][x]) == nil then
		global.LookupTable[index][x] = nil
		if next(global.LookupTable[index]) == nil then
			global.LookupTable[index] = nil
		end
	end
end

local function destroy_components(logicTurret) --Remove a turret from the logistic turret lists and destroy its internal components
	if logicTurret == nil then
		return
	end
	local index = nil
	local pos = nil
	if logicTurret.turret.valid then
		index = logicTurret.turret.surface.index
		pos = logicTurret.turret.position
	end
	if logicTurret.chest.valid then
		index = index or logicTurret.chest.surface.index
		pos = pos or logicTurret.chest.position
		logicTurret.chest.destroy()
	end
	if logicTurret.bin.valid then
		index = index or logicTurret.bin.surface.index
		pos = pos or logicTurret.bin.position
		logicTurret.bin.destroy()
	end
	if logicTurret.combinator.valid then
		index = index or logicTurret.combinator.surface.index
		pos = pos or logicTurret.combinator.position
		logicTurret.combinator.destroy()
	end
	if logicTurret.interface.valid then
		index = index or logicTurret.interface.surface.index
		pos = pos or logicTurret.interface.position
		logicTurret.interface.destroy()
	end
	if index ~= nil and pos ~= nil then
		remove_address(index, pos.x, pos.y) --Remove turret from the lookup table
	else
		local found = false
		for index, exes in pairs(globalCall("LookupTable")) do
			for x, whys in pairs(exes) do
				for y, tablet in pairs(whys) do
					if tablet == logicTurret then
						remove_address(index, x, y) --Remove turret from the lookup table
						found = true
						break
					end
				end
				if found then
					break
				end
			end
			if found then
				break
			end
		end
	end
	logicTurret.destroy = true --Flag turret for removal from the logistic turret list
end

local function is_valid_turret(logicTurret) --Check if all parts of a logistic turret are valid
	if logicTurret == nil or logicTurret.destroy then
		return
	end
	if logicTurret.turret.valid and logicTurret.chest.valid and logicTurret.bin.valid and logicTurret.combinator.valid and logicTurret.interface.valid then
		return logicTurret
	else
		destroy_components(logicTurret) --Remove a turret from the logistic turret list and destroy its internal components
	end
end

local function lookup_turret(entity) --Get a logistic turret entry
	if entity == nil or not entity.valid then
		return
	end
	local index = entity.surface.index
	local pos = entity.position
	if globalCall("LookupTable")[index] ~= nil and global.LookupTable[index][pos.x] ~= nil then
		return is_valid_turret(global.LookupTable[index][pos.x][pos.y])
	end
end

local function get_player(id) --Get a player object
	if id == nil or not (type(id) == "number" or type(id) == "string") then
		return
	end
	local player = game.players[id]
	if player ~= nil and player.valid then
		return player
	end
end

--Logistics-----------------------------------------------------------------------------------------
local function get_player_inventory(player) --Get inventories for each controller type
	if player == nil or not player.valid then
		return
	end
	local controller = player.controller_type
	if controller == defines.controllers.character then
		return
		{
			player.get_inventory(defines.inventory.player_ammo),
			player.get_inventory(defines.inventory.player_main),
			player.get_inventory(defines.inventory.player_quickbar),
			player.get_inventory(defines.inventory.player_trash)
		}
	elseif controller == defines.controllers.god then
		return
		{
			player.get_inventory(defines.inventory.god_main),
			player.get_inventory(defines.inventory.god_quickbar)
		}
	end
end

local function move_ammo(source, destination, count) --Move ammo between the turret's internal components, preserving the amount of ammo in each item
	if source == nil or not source.valid_for_read then
		return
	end
	if destination.valid_for_read then
		if destination.name == source.name then
			count = count or source.count
			destination.add_ammo(source.drain_ammo(math.ceil(count * source.prototype.magazine_size)))
		end
	else
		count = count or source.count
		destination.set_stack({name = source.name, count = 1})
		destination.ammo = 1
		destination.add_ammo(source.drain_ammo(math.ceil(count * source.prototype.magazine_size)) - 1)
	end
end

local function player_insert_ammo(player, item) --Insert ammo into the player's inventory, preserving the amount of ammo in each item
	if player == nil or item == nil or not (player.valid and item.valid_for_read) then
		return 0
	end
	local inserted = player.insert({name = item.name, count = item.count})
	if inserted > 0 then
		local magazine_size = item.prototype.magazine_size
		if magazine_size > item.ammo then --Find the item just inserted and update its ammo count
			local found = false
			local inventories = get_player_inventory(player)
			if inventories ~= nil then
				for i = 1, #inventories do
					local inventory = inventories[i]
					if inventory ~= nil and inventory.valid then
						for j = #inventory, 1, -1 do
							local stack = inventory[j]
							if stack.valid_for_read and stack.type == "ammo" and stack.name == item.name then --Item found
								stack.drain_ammo(magazine_size - item.ammo)
								found = true
								break
							end
						end
						if found then
							break
						end
					end
				end
			end
			if not found then
				local stack = player.cursor_stack
				if stack.valid_for_read and stack.type == "ammo" and stack.name == item.name then --Item found
					stack.drain_ammo(magazine_size - item.ammo)
				end
			end
		end
	end
	return inserted
end

local function transfer_inventory(turret, player, ...) --Transfer a logistic turret's inventory to a player
	if turret == nil or player == nil or not (turret.valid and player.valid) then
		return
	end
	local items = {}
	local magazine = turret.get_inventory(defines.inventory.turret_ammo)
	local stacks = {...} --Component inventories
	for i = 1, #stacks do
		for j = 1, #magazine do
			move_ammo(stacks[i], magazine[j]) --Compact ammo into as few slots as possible
		end
		if stacks[i].valid_for_read then
			items[#items + 1] = stacks[i]
		end
	end
	for i = #magazine, 2, -1 do
		for j = 1, i - 1 do
			move_ammo(magazine[i], magazine[j]) --Compact ammo into as few slots as possible
		end
		if magazine[i].valid_for_read then
			items[#items + 1] = magazine[i]
		end
	end
	if magazine[1].valid_for_read then
		items[#items + 1] = magazine[1]
	end
	if #items > 0 then
		local surface = turret.surface
		local pos = turret.position
		local text = {"MMT.message.player-insert", nil, nil, nil}
		local floater = {name = ModPrefix.."flying-text", position = pos, text = text, force = "neutral"}
		for _, item in spairs(items, function(t, a, b) return t[a].count > t[b].count end) do --Sort by count
			local inserted = player_insert_ammo(player, item)
			if inserted > 0 then
				text[2] = item.prototype.localised_name
				text[3] = item.count
				text[4] = player.get_item_count(item.name)
				item.count = item.count - inserted
				surface.create_entity(floater) --Create floating text
				pos.y = pos.y + 0.5
			end
		end
	end
end

local function set_request(logicTurret, request) --Set the chest's request slot
	if logicTurret == nil or logicTurret.circuitry.mode == SetRequestsMode then --Request slot is overridden by a circuit network
		return
	end
	local config = globalCall("LogicTurretConfig")[logicTurret.turret.name]
	if request == nil or request == "empty" then
		if config == "empty" then --New request is the same as the default
			logicTurret.override = nil --Remove override flag
		else
			logicTurret.override = true --Set override flag
		end
		logicTurret.insertLimit = math.huge --No limit
		logicTurret.chest.clear_request_slot(1)
	else
		if config ~= "empty" and request.ammo == config.ammo and request.count == config.count then --New request is the same as the default
			logicTurret.override = nil --Remove override flag
		else
			logicTurret.override = true --Set override flag
		end
		if request.count <= 1 then
			logicTurret.insertLimit = 0.5 --Split single ammo item between the turret and chest
		else
			logicTurret.insertLimit = math.ceil(request.count / 2) --Split ammo between the turret and chest
		end
		logicTurret.chest.set_request_slot({name = request.ammo, count = math.max(request.count - logicTurret.insertLimit, 1)}, 1) --Set request
	end
end

local function spill_stack(entity, stack) --Spill items on the ground and mark them for deconstruction
	if entity == nil or stack == nil or not (entity.valid and stack.valid_for_read) then
		return
	end
	local surface, pos, force = entity.surface, entity.position, entity.force
	local name, count = stack.name, stack.count
	local collision = entity.prototype.collision_box or {left_top = {x = 0, y = 0}, right_bottom = {x = 0, y = 0}}
	surface.spill_item_stack(pos, stack, true)
	stack.clear() --Remove original stack
	local items = surface.find_entities_filtered{name = "item-on-ground", type = "item-entity", area = { --Note: the "limit" parameter causes issues when spilling multiple stacks
		{x = pos.x - math.abs(collision.left_top.x) - 3, y = pos.y - math.abs(collision.left_top.y) - 3},
		{x = pos.x + math.abs(collision.right_bottom.x) + 3, y = pos.y + math.abs(collision.right_bottom.y) + 3}}}
	count = count < #items and count or #items --If there are items already on the ground, only mark enough to match the number spilled
	for i = 1, #items do
		local item = items[i]
		if item.valid and item.stack.name == name and not item.to_be_deconstructed(force) then
			item.order_deconstruction(force)
			count = count - 1
			if count <= 0 then
				break
			end
		end
	end
end

--Circuitry-----------------------------------------------------------------------------------------
set_circuitry = function(logicTurret, mode, wires) --Wire the turret's internal components and set the mode of operation
	if logicTurret == nil then
		return
	end
	local chest = logicTurret.chest
	local combinator = logicTurret.combinator
	local interface = logicTurret.interface
	local circuitry = logicTurret.circuitry
	local signal = combinator.get_or_create_control_behavior()
	chest.get_or_create_control_behavior().circuit_mode_of_operation = defines.control_behavior.logistic_container.circuit_mode_of_operation.send_contents --Reset to "send contents"
	if mode == OffMode or not (wires.red or wires.green) then --Remove all wires, reset all settings
		combinator.disconnect_neighbour({wire = defines.wire_type.red, target_entity = chest})
		combinator.disconnect_neighbour({wire = defines.wire_type.red, target_entity = interface})
		combinator.disconnect_neighbour({wire = defines.wire_type.green, target_entity = chest})
		combinator.disconnect_neighbour({wire = defines.wire_type.green, target_entity = interface})
		signal.parameters = {parameters = {}} --Reset signals
		logicTurret.interface.get_or_create_control_behavior().circuit_condition = {condition = nil} --LED cannot turn green
		circuitry.mode = OffMode
		circuitry.wires.red = false
		circuitry.wires.green = false
		circuitry.signal = nil
		circuitry.cache = nil
		circuitry.override = nil
	elseif mode == SendContentsMode or mode == SetRequestsMode then
		if mode == SendContentsMode then --Connect chest, combinator, and interface
			if wires.red then
				combinator.connect_neighbour({wire = defines.wire_type.red, target_entity = chest})
				combinator.connect_neighbour({wire = defines.wire_type.red, target_entity = interface})
			else
				combinator.disconnect_neighbour({wire = defines.wire_type.red, target_entity = chest})
				combinator.disconnect_neighbour({wire = defines.wire_type.red, target_entity = interface})
			end
			if wires.green then
				combinator.connect_neighbour({wire = defines.wire_type.green, target_entity = chest})
				combinator.connect_neighbour({wire = defines.wire_type.green, target_entity = interface})
			else
				combinator.disconnect_neighbour({wire = defines.wire_type.green, target_entity = chest})
				combinator.disconnect_neighbour({wire = defines.wire_type.green, target_entity = interface})
			end
			circuitry.override = nil
		elseif mode == SetRequestsMode then --Connect chest and combinator
			combinator.disconnect_neighbour({wire = defines.wire_type.red, target_entity = chest})
			combinator.disconnect_neighbour({wire = defines.wire_type.red, target_entity = interface})
			combinator.connect_neighbour({wire = defines.wire_type.green, target_entity = chest})
			combinator.disconnect_neighbour({wire = defines.wire_type.green, target_entity = interface})
			signal.parameters = {parameters = {}} --Reset signals
			circuitry.override = true --Delays activating input mode to give the circuit network time to update; otherwise a turret switching from "send contents" to "set requests" could read its own inventory
			logicTurret.override = nil --Remove override flag
		end
		logicTurret.interface.get_or_create_control_behavior().circuit_condition = {condition = {first_signal = {type = "virtual", name = "signal-everything"}, constant = -2147483648}} --Allow the LED to turn green
		circuitry.mode = mode
		circuitry.wires.red = wires.red
		circuitry.wires.green = wires.green
		circuitry.signal = signal
		circuitry.cache = {}
	end
end

local function get_network_signals(logicTurret) --Combine signals from red and green networks, filtering out anything that isn't useable ammo
	local category = global.TurretAmmoSets[logicTurret.turret.name][0] --Turret's ammo category
	local input = {}
	local networks = {}
	if logicTurret.circuitry.wires.red then --Read red network
		networks.red = logicTurret.interface.get_circuit_network(defines.wire_type.red)
	end
	if logicTurret.circuitry.wires.green then --Read green network
		networks.green = logicTurret.interface.get_circuit_network(defines.wire_type.green)
	end
	for _, network in pairs(networks) do
		if network ~= nil and network.valid then
			local signals = network.signals --Signals last tick
			for i = 1, #signals do
				local signal = signals[i]
				local item = signal.signal.name
				local count = signal.count
				if signal.signal.type == "item" and global.AmmoCategories[item] == category and count >= 1 then --Item's ammo category matches the turret's ammo category
					if input[item] ~= nil then
						input[item] = input[item] + count --Combine network counts
					else
						input[item] = count
					end
				end
			end
		end
	end
	return input
end

local function signal_has_changed(cache, signals) --Compare signals to a cached value
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
	if circuitry.mode == SendContentsMode then --Send contents
		local output = logicTurret.turret.get_inventory(defines.inventory.turret_ammo).get_contents() --Turret's inventory
		if signal_has_changed(circuitry.cache, output) then --Build a new signal list
			local index = 0
			local signals = {}
			for item, count in spairs(output, function(t, a, b) return t[a] > t[b] end) do --Sort by count
				index = index + 1
				signals[index] = {signal = {type = "item", name = item}, count = count, index = index}
				if index >= 10 then --Combinator only supports 10 signals
					break
				end
			end
			circuitry.signal.parameters = {parameters = signals} --Set the combinator's signals
			circuitry.cache = output --Update cache
		end
	elseif circuitry.mode == SetRequestsMode then --Set request
		if circuitry.override then
			logicTurret.chest.get_or_create_control_behavior().circuit_mode_of_operation = defines.control_behavior.logistic_container.circuit_mode_of_operation.set_requests --Activate input mode
			circuitry.override = nil
			return
		end
		local input = get_network_signals(logicTurret) --Incoming signals
		if signal_has_changed(circuitry.cache, input) then --Build a new signal list
			local index = 0
			local signals = {}
			for item, count in spairs(input, function(t, a, b) return t[a] > t[b] end) do --Sort by count
				local sCount = math.min(count, game.item_prototypes[item].stack_size) --Maximum one stack
				if sCount <= 1 then
					logicTurret.insertLimit = 0.5 --Split single ammo item between the turret and chest
				else
					logicTurret.insertLimit = math.ceil(sCount / 2) --Split ammo between the turret and chest
				end
				index = index + 1
				signals[index] = {signal = {type = "item", name = item}, count = math.max(sCount - logicTurret.insertLimit, 1), index = index}
				break --Only set one signal
			end
			circuitry.signal.parameters = {parameters = signals} --Set the combinator's signal
			circuitry.cache = input --Update cache
		end
	end
end

--On tick-------------------------------------------------------------------------------------------
local function in_combat(logicTurret) --Compare damage dealt to a cached value
	local damage = logicTurret.turret.damage_dealt
	if logicTurret.damageDealt ~= damage then --Turret is probably in combat
		logicTurret.damageDealt = damage --Update cache
		return true
	end
end

local function request_fulfilled(logicTurret) --Check if turret needs reloading
	local stash = logicTurret.stash
	if not stash.valid_for_read then --Stash is empty
		return true
	else
		local magazine = logicTurret.magazine
		return (magazine.valid_for_read and (magazine.name ~= stash.name or magazine.count >= logicTurret.insertLimit)) --Returns false if turret is empty or below its insertLimit threshold
	end
end

local function process_active_turret(logicTurret) --Reload turret from chest
	local magazine = logicTurret.magazine
	if magazine.valid_for_read then
		local reload = logicTurret.insertLimit - magazine.count
		if reload > 0 then --Turret needs reloading
			move_ammo(logicTurret.stash, magazine, reload)
		end
	else --Turret is empty
		move_ammo(logicTurret.stash, magazine, logicTurret.insertLimit)
	end
end

local function process_idle_turret(logicTurret) --Move unwanted ammo to bin
	local magazine = logicTurret.magazine
	if magazine.valid_for_read then
		local request = logicTurret.chest.get_request_slot(1)
		if request ~= nil and request.name ~= magazine.name then --Turret's ammo does not match its request
			move_ammo(magazine, logicTurret.trash, 1)
			move_ammo(logicTurret.stash, magazine, 1)
		end
	end
end

--Miscellaneous-------------------------------------------------------------------------------------
local function awaken_dormant_turrets(force) --Awaken the dormant turrets of a force
	local turretArray = globalCall("DormantLogicTurrets")[force]
	if turretArray == nil then
		return
	end
	for i = 1, #turretArray do
		local logicTurret = is_valid_turret(turretArray[i])
		if logicTurret ~= nil then
			set_request(logicTurret, globalCall("LogicTurretConfig")[logicTurret.turret.name])
			add_logistic_turret(logicTurret, true) --Add to logistic turret list
		end
	end
	global.DormantLogicTurrets[force] = nil --Delete list
end

local function destroy_gui(id)
	local player = get_player(id)
	if player ~= nil then
		local gui = player.gui.center[ModPrefix.."gui"]
		if gui ~= nil and gui.valid then
			gui.destroy() --Close GUI
		end
	end
	globalCall("TurretGUI")[id] = nil --Delete GUI metadata
end

local function close_turret_gui(turret) --Close this turret's GUI for any player that may have it open
	if turret == nil or not turret.valid then
		return
	end
	for id, guiData in pairs(globalCall("TurretGUI")) do
		local found = false
		for _, logicTurrets in pairs(guiData.logicTurrets) do
			for i = 1, #logicTurrets do
				if logicTurrets[i].turret == turret then --Player's GUI contains this turret
					destroy_gui(id)
					found = true
					break
				end
			end
			if found then
				break
			end
		end
	end
end

local function remove_ghost_data(index, x, y, force) --Remove an entry from the ghost lookup table
	globalCall("GhostConnections", index, x, y)[force] = nil
	if next(global.GhostConnections[index][x][y]) == nil then
		global.GhostConnections[index][x][y] = nil
		if next(global.GhostConnections[index][x]) == nil then
			global.GhostConnections[index][x] = nil
			if next(global.GhostConnections[index]) == nil then
				global.GhostConnections[index] = nil
			end
		end
	end
end

local function set_ghost_data(logicTurret) --Save a turret's data when it turns into a ghost
	if logicTurret == nil then
		return
	end
	local interface = logicTurret.interface
	local ghostTimer = interface.force.ghost_time_to_live
	if ghostTimer > 0 then
		local pos = interface.position
		local connections = interface.circuit_connection_definitions
		local data = {}
		for i = 1, #connections do
			local connection = connections[i]
			local target = connection.target_entity
			if target ~= nil and target.valid then
				local wire = connection.wire
				if data[wire] == nil then
					data[wire] = {}
				end
				data[wire][#data[wire] + 1] = {name = target.name, type = target.type, position = {x = target.position.x - pos.x, y = target.position.y - pos.y}, circuit_id = connection.target_circuit_id}
			end
		end
		globalCall("GhostConnections", interface.surface.index, pos.x, pos.y)[interface.force.name] =
		{
			name = logicTurret.turret.name,
			request = logicTurret.chest.get_request_slot(1),
			insertLimit = logicTurret.insertLimit,
			mode = logicTurret.circuitry.mode,
			wires = logicTurret.circuitry.wires,
			label = logicTurret.label,
			override = logicTurret.override,
			connections = data,
			expiration = game.tick + ghostTimer
		}
	end
end

get_ghost_data = function(turret) --Get a turret's data when its ghost is rebuilt
	if turret == nil or not turret.valid then
		return
	end
	local surface = turret.surface
	local index = surface.index
	local pos = turret.position
	local force = turret.force.name
	if globalCall("GhostConnections")[index] ~= nil and global.GhostConnections[index][pos.x] ~= nil and global.GhostConnections[index][pos.x][pos.y] ~= nil then
		local ghostData = global.GhostConnections[index][pos.x][pos.y][force]
		if ghostData ~= nil and ghostData.name == turret.name and game.tick < ghostData.expiration then
			local interface = surface.create_entity{name = TurretInterface, position = pos, force = force}
			if interface ~= nil and interface.valid then
				for wire, targets in pairs(ghostData.connections) do
					for i = 1, #targets do
						local target = targets[i]
						local x = pos.x + target.position.x
						local y = pos.y + target.position.y
						local entity = surface.find_entities_filtered{name = target.name, type = target.type, area = {{x - 0.05, y - 0.05}, {x + 0.05, y + 0.05}}, force = force, limit = 1}[1]
						if entity ~= nil and entity.valid then
							interface.connect_neighbour({wire = wire, target_entity = entity, target_circuit_id = target.circuit_id})
						end
					end
				end
				ghostData.interface = interface
				remove_ghost_data(index, pos.x, pos.y, force) --Remove entry from the ghost lookup table
				return ghostData
			end
		end
		remove_ghost_data(index, pos.x, pos.y, force) --Remove entry from the ghost lookup table
	end
end

local function validate_ghost_data() --Remove expired entries from the ghost lookup table
	for index, exes in pairs(globalCall("GhostConnections")) do
		local surface = game.surfaces[index]
		if surface ~= nil and surface.valid then
			for x, whys in pairs(exes) do
				for y, forsees in pairs(whys) do
					for force, ghostData in pairs(forsees) do
						local validGhost = false
						if game.tick < ghostData.expiration and globalCall("LogicTurretConfig")[ghostData.name] ~= nil then
							local ghosts = surface.find_entities_filtered{name = "entity-ghost", type = "entity-ghost", area = {{x - 0.05, y - 0.05}, {x + 0.05, y + 0.05}}, force = force}
							for i = 1, #ghosts do
								local ghost = ghosts[i]
								if ghost ~= nil and ghost.valid and ghost.ghost_type == "ammo-turret" and ghost.ghost_name == ghostData.name then
									validGhost = true
									break
								end
							end
						end
						if not validGhost then
							remove_ghost_data(index, x, y, force) --Remove entry from the ghost lookup table
						end
					end
				end
			end
		else
			global.GhostConnections[index] = nil
		end
	end
end

----------------------------------------------------------------------------------------------------
--Event handlers
----------------------------------------------------------------------------------------------------
onTick = function(event) --Controls the behavior of logistic turrets
	if not loaded then
		load_config()
		return
	end
	local iIndex = #global.LogicTurrets
	local aIndex = #global.ActiveLogicTurrets
	if iIndex > 0 then --Check idle turrets
		local rIndex = nil
		local i = global.IdleCounter
		while i <= iIndex do
			local logicTurret = global.LogicTurrets[i]
			if logicTurret == nil or logicTurret.destroy then
				if rIndex == nil then
					rIndex = i --First removed entry
				end
				global.LogicTurrets[i] = nil
			elseif is_valid_turret(logicTurret) and not logicTurret.active and logicTurret.turret.active then
				if in_combat(logicTurret) or not request_fulfilled(logicTurret) then --Add to active list
					aIndex = aIndex + 1
					global.ActiveLogicTurrets[aIndex] = logicTurret
					logicTurret.active = 0 --Start the turret's timer
				else
					if logicTurret.stash.valid_for_read then
						process_idle_turret(logicTurret)
					end
					if logicTurret.circuitry.mode ~= OffMode then
						set_signal(logicTurret)
					end
				end
			end
			i = i + IdleInterval
		end
		if rIndex ~= nil then --At least one entry was removed
			iIndex = table_compact(global.LogicTurrets, rIndex, iIndex) --Close the gaps left by removed entries
		end
		global.IdleCounter = (global.IdleCounter % IdleInterval) + 1
	end
	if aIndex > 0 then --Check active turrets
		local rIndex = nil
		local i = global.Counter
		while i <= aIndex do
			local logicTurret = global.ActiveLogicTurrets[i]
			if logicTurret == nil or logicTurret.destroy then
				if rIndex == nil then
					rIndex = i --First removed entry
				end
				global.ActiveLogicTurrets[i] = nil
				logicTurret.active = nil
			elseif is_valid_turret(logicTurret) then
				logicTurret.active = (logicTurret.active % ActiveTimer) + 1 --Increment the turret's timer
				if logicTurret.active == ActiveTimer and not in_combat(logicTurret) and request_fulfilled(logicTurret) then --Remove from active list
					if rIndex == nil then
						rIndex = i --First removed entry
					end
					global.ActiveLogicTurrets[i] = nil
					logicTurret.active = nil
				else
					if logicTurret.stash.valid_for_read then
						process_active_turret(logicTurret)
					end
					if logicTurret.circuitry.mode ~= OffMode then
						set_signal(logicTurret)
					end
				end
			end
			i = i + Interval
		end
		if rIndex ~= nil then --At least one entry was removed
			aIndex = table_compact(global.ActiveLogicTurrets, rIndex, aIndex) --Close the gaps left by removed entries
		end
		global.Counter = (global.Counter % Interval) + 1
	end
	if iIndex + aIndex <= 0 then --Stop the onTick function
		script.on_event(defines.events.on_tick, nil)
	end
end

local function onEntityBuilt(event) --Add turret to the logistic turret list when built
	local entity = event.created_entity
	if entity == nil or not entity.valid then
		return
	end
	local name = entity.name
	if globalCall("LogicTurretConfig")[name] ~= nil then
		local logicTurret = add_components(entity) --Add internal components
		if logicTurret ~= nil then
			add_logistic_turret(logicTurret) --Add to logistic turret list
		end
	end
end

local function onEntityDied(event) --Remove turret from the logistic turret list and destroy its internal components
	local entity = event.entity
	if entity == nil or not entity.valid then
		return
	end
	if globalCall("LogicTurretConfig")[entity.name] ~= nil then
		local logicTurret = lookup_turret(entity)
		if logicTurret ~= nil then
			close_turret_gui(entity) --Close this turret's GUI for all players
			set_ghost_data(logicTurret) --Save this turret's data for when it gets rebuilt
			destroy_components(logicTurret)
		end
	end
end

local function onEntityMined(event) --Remove turret from the logistic turret list, handle any leftover ammo, and destroy its internal components
	local entity = event.entity
	if entity == nil or not entity.valid then
		return
	end
	local name = entity.name
	if globalCall("LogicTurretConfig")[name] ~= nil or name == TurretInterface then
		local logicTurret = lookup_turret(entity)
		if logicTurret ~= nil then
			local turret = logicTurret.turret
			close_turret_gui(turret) --Close this turret's GUI for all players
			local id = event.player_index
			local player = get_player(id)
			if player ~= nil and name == TurretInterface then --Player mined the circuit network interface
				game.raise_event(defines.events.on_preplayer_mined_item, {entity = turret, player_index = id}) --Raise an event as though the turret was mined
				if turret.valid then --Check if the turret is still valid after raising the event
					transfer_inventory(turret, player)
					if not turret.has_items_inside() then
						local health = turret.health / turret.prototype.max_health
						local products = turret.prototype.mineable_properties.products
						for i = 1, #products do
							local product = products[i]
							if product.type == "item" then
								local count = product.amount or math.random(product.amount_min, product.amount_max) * (product.probability >= math.random() and 1 or 0)
								if count ~= nil and count > 0 then
									local inserted = player.insert({name = product.name, count = count, health = health}) --Add the turret to the player's inventory
									if inserted < count then
										turret.surface.spill_item_stack(turret.position, {name = product.name, count = count - inserted, health = health}) --Drop turret on the ground if it didn't fit in the player's inventory
									end
									game.raise_event(defines.events.on_player_mined_item, {item_stack = {name = product.name, count = count}, player_index = id}) --Raise an event as though the turret was mined
								end
							end
						end
						turret.destroy() --Remove turret
					end
				end
				return
			end
			if player ~= nil then
				transfer_inventory(turret, player, logicTurret.stash, logicTurret.trash)
			else
				local magazine = turret.get_inventory(defines.inventory.turret_ammo)
				for i = 1, #magazine do
					move_ammo(logicTurret.stash, magazine[i])
					move_ammo(logicTurret.trash, magazine[i])
				end
				spill_stack(turret, logicTurret.stash)
				spill_stack(turret, logicTurret.trash)
			end
			destroy_components(logicTurret)
		end
	elseif name == "entity-ghost" and global.LogicTurretConfig[entity.ghost_name] ~= nil then
		remove_ghost_data(entity.surface.index, entity.position.x, entity.position.y, entity.force.name)
	end
end

local function onEntityMarked(event) --Clear the chest's request slot when the turret is marked for deconstruction
	local entity = event.entity
	if entity == nil or not entity.valid then
		return
	end
	if globalCall("LogicTurretConfig")[entity.name] ~= nil then
		local logicTurret = lookup_turret(entity)
		if logicTurret ~= nil then
			close_turret_gui(entity) --Close this turret's GUI for all players
			set_request(logicTurret, "empty")
			logicTurret.override = true --Set override flag
		end
	end
end

local function onEntityUnmarked(event) --Reset the chest's request slot when deconstruction is canceled
	local entity = event.entity
	if entity == nil or not entity.valid then
		return
	end
	if globalCall("LogicTurretConfig")[entity.name] ~= nil then
		local logicTurret = lookup_turret(entity)
		if logicTurret ~= nil then
			if is_remote_enabled(entity.force) then --Logistic system is researched
				set_request(logicTurret, global.LogicTurretConfig[logicTurret.turret.name])
			end
			logicTurret.override = nil --Remove override flag
		else --Bots started mining the turret but didn't finish the job
			logicTurret = add_components(entity) --Re-add internal components
			if logicTurret ~= nil then
				add_logistic_turret(logicTurret) --Re-add to logistic turret list
			end
		end
	end
end

local function onResearchFinished(event) --Awaken dormant turrets when the logistic system is researched
	local tech = event.research
	if tech == nil or not tech.valid then
		return
	end
	local force = tech.force.name
	if globalCall("DormantLogicTurrets")[force] == nil then --Force has no dormant turrets
		return
	end
	local effects = tech.effects
	if effects ~= nil then
		for i = 1, #effects do
			if effects[i].recipe == TurretRemote then --Logistic system is researched
				awaken_dormant_turrets(force)
				break
			end
		end
	end
end

local function onForcesMerged(event) --Migrate or awaken dormant turrets
	local source = event.source
	local destination = event.destination
	if source == nil or destination == nil or not (source.valid and destination.valid) then
		return
	end
	source = source.name
	if globalCall("DormantLogicTurrets")[source] == nil then --Force has no dormant turrets
		return
	end
	destination = destination.name
	if is_remote_enabled(destination) then --Logistic system is researched
		awaken_dormant_turrets(source)
	else
		local turretArray = global.DormantLogicTurrets[source]
		for i = 1, #turretArray do
			local logicTurret = is_valid_turret(turretArray[i])
			if logicTurret ~= nil then
				globalCall("DormantLogicTurrets", destination)[#global.DormantLogicTurrets[destination] + 1] = logicTurret --Remain dormant until the logistic system is researched
			end
		end
		global.DormantLogicTurrets[source] = nil --Delete list
	end
end

local function onPreSettingsPasted(event) --Prevent the player from being able to copy the interface's settings with shift + right-click
	local source = event.source
	local destination = event.destination
	if source == nil or destination == nil or not (source.valid and destination.valid) then
		return
	end
	if source.name == TurretInterface then
		local settings = destination.get_control_behavior()
		if settings ~= nil then
			globalCall("Clipboard", "entity")[destination.unit_number] = --Save the destination's settings
			{
				destination.circuit_connection_definitions,
				settings.circuit_condition,
				settings.connect_to_logistic_network,
				settings.logistic_condition,
				settings.use_colors
			}
		end
	end
end

local function onSettingsPasted(event) --Prevent the player from being able to copy the interface's settings with shift + right-click
	local source = event.source
	local destination = event.destination
	if source == nil or destination == nil or not (source.valid and destination.valid) then
		return
	end
	if source.name == TurretInterface then
		local id = destination.unit_number
		local clipboard = globalCall("Clipboard", "entity")[id]
		if clipboard ~= nil then --Give the destination its settings back
			local settings = destination.get_or_create_control_behavior()
			for i = 1, #clipboard[1] do
				destination.connect_neighbour(clipboard[1][i])
			end
			settings.circuit_condition = clipboard[2]
			settings.connect_to_logistic_network = clipboard[3]
			settings.logistic_condition = clipboard[4]
			settings.use_colors = clipboard[5]
			global.Clipboard["entity"][id] = nil
		end
		if next(global.Clipboard["entity"]) == nil then
			global.Clipboard["entity"] = nil
		end
	end
end

----------------------------------------------------------------------------------------------------
--GUI
----------------------------------------------------------------------------------------------------
--Library-------------------------------------------------------------------------------------------
local function gui_get_data(id) --Get GUI metadata
	local guiData = globalCall("TurretGUI", id)
	local turret = guiData.turret
	local index = guiData.index[turret]
	local cache = guiData.cache[turret][index] or {}
	return guiData, turret, index, cache
end

local function gui_get_sprite(gui, sprite) --Use a generic sprite if the object doesn't have an icon
	if gui.is_valid_sprite_path(sprite) then
		return sprite
	else
		return ModPrefix.."unknown"
	end
end

local function gui_get_wires(circuitry) --Returns a string detailing which wires are in use, or nil if none
	if circuitry.wires.red and circuitry.wires.green then
		return "both"
	elseif circuitry.wires.red then
		return "red"
	elseif circuitry.wires.green then
		return "green"
	end
end

local function gui_compose_message(pasteData, clipboard) --Compose a message to print to the player's console based on the result of their paste action
	local message = {"MMT.message.paste-fail"}
	local rMessage = nil
	local bMessage = nil
	local oMessage = nil
	if pasteData.rUnit ~= nil then
		if pasteData.rCount == 1 then
			if clipboard.ammo == BlankInGUI then
				rMessage = {"MMT.message.save-empty", pasteData.rUnit}
			else
				rMessage = {"MMT.message.save", pasteData.rUnit, {"MMT.gui.item", game.item_prototypes[clipboard.ammo].localised_name, clipboard.count}}
			end
		elseif pasteData.rCount > 1 then
			if clipboard.ammo == BlankInGUI then
				rMessage = {"MMT.message.paste-empty", pasteData.rCount}
			else
				rMessage = {"MMT.message.paste", pasteData.rCount, {"MMT.gui.item", game.item_prototypes[clipboard.ammo].localised_name, clipboard.count}}
			end
		end
	end
	if pasteData.bUnit ~= nil then
		local wires = gui_get_wires(clipboard.circuitry)
		if pasteData.bCount == 1 then
			if clipboard.circuitry.mode == OffMode or wires == nil then
				bMessage = {"MMT.message.paste-behavior-off", pasteData.bUnit}
			else
				bMessage = {"MMT.message.paste-behavior", pasteData.bUnit, {"MMT.gui.mode", {"MMT.gui.mode-"..clipboard.circuitry.mode}, {"MMT.gui.wire-"..wires}}}
			end
		elseif pasteData.bCount > 1 then
			if clipboard.circuitry.mode == OffMode or wires == nil then
				bMessage = {"MMT.message.paste-behaviors-off", pasteData.bCount}
			else
				bMessage = {"MMT.message.paste-behaviors", pasteData.bCount, {"MMT.gui.mode", {"MMT.gui.mode-"..clipboard.circuitry.mode}, {"MMT.gui.wire-"..wires}}}
			end
		end
	end
	if pasteData.oUnit ~= nil then
		if pasteData.bCount ~= nil and pasteData.bCount > 0 then
			pasteData.oCount = pasteData.oCount - pasteData.bCount
		end
		if pasteData.oCount == 1 then
			oMessage = {"MMT.message.circuit-override", pasteData.oUnit}
		elseif pasteData.oCount > 1 then
			oMessage = {"MMT.message.circuit-overrides", pasteData.oCount}
		end
	end
	if rMessage ~= nil and bMessage ~= nil then
		message = {"MMT.message.combine", rMessage, bMessage}
	elseif rMessage ~= nil and oMessage ~= nil then
		message = {"MMT.message.combine", rMessage, oMessage}
	elseif bMessage ~= nil and oMessage ~= nil then
		message = {"MMT.message.combine", bMessage, oMessage}
	elseif rMessage ~= nil then
		message = rMessage
	elseif bMessage ~= nil then
		message = bMessage
	elseif oMessage ~= nil then
		message = oMessage
	end
	return message
end

local function gui_is_connected(logicTurret) --Check if the turret is connected to a circuit network
	local connected = {"gui-control-behavior.not-connected"}
	local network = logicTurret.interface.circuit_connected_entities
	if logicTurret.circuitry.wires.red and ((logicTurret.circuitry.mode == SendContentsMode and #network.red > 1) or (logicTurret.circuitry.mode == SetRequestsMode and #network.red > 0)) then
		connected = {"gui-control-behavior.connected-to-network"}
	elseif logicTurret.circuitry.wires.green and ((logicTurret.circuitry.mode == SendContentsMode and #network.green > 1) or (logicTurret.circuitry.mode == SetRequestsMode and #network.green > 0)) then
		connected = {"gui-control-behavior.connected-to-network"}
	end
	return connected
end

local function gui_show_control_panel(id, gui) --Updates the paste icons according to the contents of the clipboard and currently selected turret
	local guiElement = gui.center[ModPrefix.."gui"][ModPrefix.."logistics-flow"][ModPrefix.."navigation-flow"][ModPrefix.."control-flow"]
	local turret = select(2, gui_get_data(id))
	local clipboard = globalCall("Clipboard")[id]
	local turretName = game.entity_prototypes[turret].localised_name
	local padding = {76, 56, 37, 17} --1 button: 76, 2 buttons: 56, 3 buttons: 37, 4 buttons: 17
	local width = 0 --Width depends on the number of buttons
	if guiElement[ModPrefix.."panel-flow"] ~= nil then
		guiElement[ModPrefix.."panel-flow"].destroy() --Remove the previous turret's options
	end
	local control_panel = guiElement.add{type = "flow", name = ModPrefix.."panel-flow", direction = "horizontal", style = "slot_table_spacing_flow_style"}
	if clipboard ~= nil then
		local category, ammo, count = clipboard.category, clipboard.ammo, clipboard.count
		if ammo == BlankInGUI or globalCall("TurretAmmoSets", turret)[0] == category then --Current turret's ammo category matches the copied turret's
			local tooltip = {"MMT.gui.paste-match-empty", turretName}
			if ammo ~= BlankInGUI then
				tooltip = {"MMT.gui.paste-match", turretName, {"MMT.gui.item", game.item_prototypes[ammo].localised_name, count}}
			end
			control_panel.add{type = "sprite-button", name = ModPrefix.."match-button", style = ModPrefix.."icon", sprite = ModPrefix.."paste-match", tooltip = tooltip}
			width = width + 1
		end
		local tooltip = {"MMT.gui.paste-all-empty"}
		if ammo ~= BlankInGUI then
			tooltip = {"MMT.gui.paste-all", {"ammo-category-name."..category}, {"MMT.gui.item", game.item_prototypes[ammo].localised_name, count}}
		end
		control_panel.add{type = "sprite-button", name = ModPrefix.."all-button", style = ModPrefix.."icon", sprite = ModPrefix.."paste-all", tooltip = tooltip}
		width = width + 1
	end
	if gui.player.force.technologies["circuit-network"].researched then --Add circuit network buttons
		if clipboard ~= nil and clipboard.circuitry ~= nil then
			local circuitry = clipboard.circuitry
			local tooltip = {"MMT.gui.paste-behavior-off", turretName}
			if circuitry.mode ~= OffMode then
				local wires = gui_get_wires(circuitry)
				if wires ~= nil then
					tooltip = {"MMT.gui.paste-behavior", turretName, {"MMT.gui.mode", {"MMT.gui.mode-"..circuitry.mode}, {"MMT.gui.wire-"..wires}}}
				end
			end
			control_panel.add{type = "sprite-button", name = ModPrefix.."behavior-button", style = ModPrefix.."icon", sprite = ModPrefix.."paste-behavior", tooltip = tooltip}
			width = width + 1
		end
		control_panel.add{type = "sprite-button", name = ModPrefix.."circuitry-button", style = ModPrefix.."icon", sprite = ModPrefix.."circuitry", tooltip = {"gui-control-behavior.circuit-network"}}
		width = width + 1
	end
	control_panel.style.left_padding = padding[width] --Padding depends on the number of buttons to keep GUI the same width
end

local function gui_show_wires(id, gui) --Show, hide, or update the curret turret's wire options
	local guiElement = gui.center[ModPrefix.."gui"][ModPrefix.."circuitry-frame"]
	local guiData, turret, index, cache = gui_get_data(id)
	local circuitry = cache.circuitry or guiData.logicTurrets[turret][index].circuitry
	if circuitry.mode == OffMode then
		if guiElement[ModPrefix.."connect-flow"] ~= nil then
			guiElement[ModPrefix.."connect-flow"].destroy()
		end
		return
	else
		local redStyle = "gray"
		local greenStyle = "gray"
		if circuitry.wires.red then
			redStyle = "blue"
		end
		if circuitry.wires.green then
			greenStyle = "blue"
		end
		if guiElement[ModPrefix.."connect-flow"] ~= nil then
			guiElement[ModPrefix.."connect-flow"][ModPrefix.."wire-flow"][ModPrefix.."red-button"].style = ModPrefix..redStyle
			guiElement[ModPrefix.."connect-flow"][ModPrefix.."wire-flow"][ModPrefix.."green-button"].style = ModPrefix..greenStyle
		else
			local connect_flow = guiElement.add{type = "flow", name = ModPrefix.."connect-flow", direction = "vertical", style = "table_spacing_flow_style"}
				connect_flow.style.minimal_height = 58
				connect_flow.add{type = "label", name = ModPrefix.."connect-label", style = "description_label_style", caption = {"MMT.gui.connect"}, tooltip = {"MMT.gui.connect-description"}}
				local wire_flow = connect_flow.add{type = "flow", name = ModPrefix.."wire-flow", direction = "horizontal", style = "slot_table_spacing_flow_style"}
					wire_flow.add{type = "sprite-button", name = ModPrefix.."red-button", style = ModPrefix..redStyle, sprite = "item/red-wire", tooltip = {"item-name.red-wire"}}
					wire_flow.add{type = "sprite-button", name = ModPrefix.."green-button", style = ModPrefix..greenStyle, sprite = "item/green-wire", tooltip = {"item-name.green-wire"}}
		end
	end
end

local function gui_show_circuit_panel(id, gui) --Show the current turret's circuitry panel
	local guiElement = gui.center[ModPrefix.."gui"][ModPrefix.."circuitry-frame"]
	if guiElement == nil then
		return
	end
	local guiData, turret, index, cache = gui_get_data(id)
	local logicTurret = guiData.logicTurrets[turret][index]
	local circuitry = cache.circuitry or logicTurret.circuitry
	guiElement[ModPrefix.."network-label"].caption = gui_is_connected(logicTurret)
	guiElement[ModPrefix.."mode-flow"][ModPrefix.."mode-table"][ModPrefix..OffMode.."-button"].sprite = ""
	guiElement[ModPrefix.."mode-flow"][ModPrefix.."mode-table"][ModPrefix..SendContentsMode.."-button"].sprite = ""
	guiElement[ModPrefix.."mode-flow"][ModPrefix.."mode-table"][ModPrefix..SetRequestsMode.."-button"].sprite = ""
	guiElement[ModPrefix.."mode-flow"][ModPrefix.."mode-table"][ModPrefix..circuitry.mode.."-button"].sprite = ModPrefix.."bullet"
	gui_show_wires(id, gui)
end

local function gui_show_ammo_table(id, gui) --Shows the list of ammo the current turret can request
	local guiElement = gui.center[ModPrefix.."gui"][ModPrefix.."logistics-flow"][ModPrefix.."turret-frame"]
	local guiData, turret, index, cache = gui_get_data(id)
	local request = cache.request or guiData.logicTurrets[turret][index].chest.get_request_slot(1)
	local ammoList = globalCall("TurretAmmoSets", turret) --The list of ammo the turret can request
	if guiElement[ModPrefix.."ammo-table"] ~= nil then
		guiElement[ModPrefix.."ammo-table"].destroy() --Remove the previous turret's list
	end
	local ammo_table = guiElement.add{type = "table", name = ModPrefix.."ammo-table", style = "slot_table_style", colspan = 5}
		ammo_table.add{type = "sprite-button", name = ModPrefix..BlankInGUI.."-ammo-button", style = ModPrefix.."gray", tooltip = {"MMT.gui.empty"}} --Blank request
		for i = 1, #ammoList do
			local ammo = ammoList[i]
			local style = "gray"
			if request ~= nil and ammo == request.name then --Highlight current request
				style = "orange"
			end
			ammo_table.add{type = "sprite-button", name = ModPrefix..ammo.."-ammo-button", style = ModPrefix..style, sprite = gui_get_sprite(gui, "item/"..ammo), tooltip = game.item_prototypes[ammo].localised_name}
		end
end

local function gui_show_request(id, gui) --Show the current turret's request
	local guiElement = gui.center[ModPrefix.."gui"][ModPrefix.."logistics-flow"][ModPrefix.."turret-frame"]
	local guiData, turret, index, cache = gui_get_data(id)
	local logicTurret = guiData.logicTurrets[turret][index]
	local request = logicTurret.chest.get_request_slot(1)
	local label = logicTurret.label[id] or {"MMT.gui.turret-label", logicTurret.turret.localised_name, logicTurret.turret.unit_number}
	local caption = BlankInGUI
	local sprite = ""
	local tooltip = {"MMT.gui.stack", 0}
	local count = 0
	if cache.request ~= nil then --Turret has a cached request
		if cache.request.name ~= BlankInGUI then
			caption = cache.request.name --Store ammo name in the caption
			sprite = gui_get_sprite(gui, "item/"..cache.request.name)
			tooltip = {"MMT.gui.stack", game.item_prototypes[cache.request.name].stack_size}
			count = cache.request.count
		end
	elseif request ~= nil then
		caption = request.name --Store ammo name in the caption
		sprite = gui_get_sprite(gui, "item/"..request.name)
		tooltip = {"MMT.gui.stack", game.item_prototypes[request.name].stack_size}
		count = request.count + math.floor(logicTurret.insertLimit)
	end
	guiElement[ModPrefix.."turret-label"].caption = label
	guiElement[ModPrefix.."request-flow"][ModPrefix.."item-button"].caption = caption
	guiElement[ModPrefix.."request-flow"][ModPrefix.."item-button"].sprite = sprite
	guiElement[ModPrefix.."request-flow"][ModPrefix.."item-button"].tooltip = tooltip
	guiElement[ModPrefix.."request-flow"][ModPrefix.."count-field"].text = count
	gui_show_ammo_table(id, gui)
	gui_show_circuit_panel(id, gui)
end

local function gui_rename_turret(id, gui) --Save or delete the custom label
	local guiElement = gui.center[ModPrefix.."gui"][ModPrefix.."logistics-flow"][ModPrefix.."turret-frame"][ModPrefix.."turret-label"]
	local guiData, turret, index = gui_get_data(id)
	local logicTurret = guiData.logicTurrets[turret][index]
	local label = string.gsub(guiElement[ModPrefix.."edit-field"].text, "^%s*(.-)%s*$", "%1") --Remove leading and trailing whitespace
	if label == "" then
		label = nil --Reset to default
	end
	guiElement.caption = label or {"MMT.gui.turret-label", logicTurret.turret.localised_name, logicTurret.turret.unit_number}
	guiElement[ModPrefix.."edit-field"].destroy()
	logicTurret.label[id] = label
end

--Button functions----------------------------------------------------------------------------------
local function guiClick_turret(id, gui, turret) --Switch turret list
	local guiElement = gui.center[ModPrefix.."gui"][ModPrefix.."logistics-flow"][ModPrefix.."navigation-flow"]
	local guiData, currentTurret = gui_get_data(id)
	if turret == currentTurret then --Already selected
		return
	end
	guiElement[ModPrefix.."turret-table"][ModPrefix..currentTurret.."-turret-button"].style = ModPrefix.."gray" --Change the old turret's icon to gray
	guiElement[ModPrefix.."turret-table"][ModPrefix..turret.."-turret-button"].style = ModPrefix.."orange" --Change the new turret's icon to orange
	guiElement[ModPrefix.."control-flow"][ModPrefix.."index-label"].caption = guiData.index[turret].."/"..#guiData.logicTurrets[turret]
	guiData.turret = turret
	gui_show_control_panel(id, gui)
	gui_show_request(id, gui)
end

local function guiClick_nav(id, gui, nav) --Move forward or backward through a turret list
	local guiElement = gui.center[ModPrefix.."gui"][ModPrefix.."logistics-flow"][ModPrefix.."navigation-flow"][ModPrefix.."control-flow"][ModPrefix.."index-label"]
	local guiData, turret, oldIndex = gui_get_data(id)
	local zIndex = #guiData.logicTurrets[turret]
	if zIndex <= 1 then --Array only has one turret
		return
	end
	local index = guiData.index
	if nav == ModPrefix.."prev-button" then
		index[turret] = oldIndex - 1 --Move backward through list
		if index[turret] < 1 then
			index[turret] = zIndex --Set to end of list
		end
	elseif nav == ModPrefix.."next-button" then
		index[turret] = oldIndex + 1 --Move forward through list
		if index[turret] > zIndex then
			index[turret] = 1 --Set to beginning of list
		end
	end
	guiElement.caption = index[turret].."/"..zIndex --Update text
	gui_show_request(id, gui)
end

local function guiClick_paste(id, gui, pasteMode) --Paste the contents of the clipboard according to the button pressed
	local clipboard = globalCall("Clipboard")[id]
	if clipboard == nil then --Clipboard is empty
		gui.player.print({"MMT.message.paste-nil"}) --Display a message
		return
	end
	local guiData, currentTurret, currentIndex, cache = gui_get_data(id)
	local category, ammo, count = clipboard.category, clipboard.ammo, clipboard.count --Clipboard contents
	local is_compatible = nil --Which turrets are compatible depends on the button pressed and the contents of the clipboard
	if pasteMode == ModPrefix.."match-button" then --Only available if the selected turret's ammo category matches the copied turret's
		if ammo == BlankInGUI then
			is_compatible = function(turret)
				if turret == currentTurret then return true end --Currently selected turret type
			end
		else
			is_compatible = function(turret)
				if turret == currentTurret and globalCall("TurretAmmoSets", turret)[0] == category then return true end --Currently selected turret type and matching ammo type
			end
		end
	elseif pasteMode == ModPrefix.."all-button" then --Always available
		if ammo == BlankInGUI then
			is_compatible = function(turret) return true end --All turrets
		else
			is_compatible = function(turret)
				if globalCall("TurretAmmoSets", turret)[0] == category then return true end --All turrets with matching ammo type
			end
		end
	end
	local pasteData =
	{
		rCount = 0,
		oCount = 0,
		rUnit = nil,
		oUnit = nil
	}
	for turret, logicTurrets in pairs(guiData.logicTurrets) do
		if is_compatible(turret) then
			for i = 1, #logicTurrets do
				if guiData.cache[turret][i] == nil then
					guiData.cache[turret][i] = {}
				end
				local logicTurret = logicTurrets[i]
				local circuitry = cache.circuitry or logicTurret.circuitry
				if circuitry.mode == SetRequestsMode then --Request slot is overridden by a circuit network
					if pasteData.oUnit == nil then
						pasteData.oUnit = logicTurret.label[id] or {"MMT.gui.turret-label", logicTurret.turret.localised_name, logicTurret.turret.unit_number}
					end
					pasteData.oCount = pasteData.oCount + 1
				else
					guiData.cache[turret][i].request = {name = ammo, count = count} --Add to cache
					if turret == currentTurret and i == currentIndex then --Update the currently displayed turret if necessary
						gui_show_request(id, gui)
					end
					if pasteData.rUnit == nil then
						pasteData.rUnit = logicTurret.label[id] or {"MMT.gui.turret-label", logicTurret.turret.localised_name, logicTurret.turret.unit_number}
					end
					pasteData.rCount = pasteData.rCount + 1
				end
			end
		end
	end
	gui.player.print(gui_compose_message(pasteData, clipboard)) --Display a message based on the result
end

local function guiClick_paste_behavior(id, gui) --Paste the control behavior settings stored in the clipboard
	local clipboard = globalCall("Clipboard")[id]
	if clipboard == nil or clipboard.circuitry == nil then --Clipboard is empty
		gui.player.print({"MMT.message.paste-nil"}) --Display a message
		return
	end
	local guiElement = gui.center[ModPrefix.."gui"][ModPrefix.."circuitry-frame"]
	local guiData, currentTurret, currentIndex = gui_get_data(id)
	local circuitry = clipboard.circuitry --Clipboard contents
	local pasteData =
	{
		bCount = 0,
		bUnit = nil
	}
	for turret, logicTurrets in pairs(guiData.logicTurrets) do
		if turret == currentTurret then
			for i = 1, #logicTurrets do
				if guiData.cache[turret][i] == nil then
					guiData.cache[turret][i] = {}
				end
				guiData.cache[turret][i].circuitry = {mode = circuitry.mode, wires = {red = circuitry.wires.red, green = circuitry.wires.green}} --Add to cache
				if guiElement ~= nil and turret == currentTurret and i == currentIndex then --Update the currently displayed turret if necessary
					gui_show_circuit_panel(id, gui)
				end
				if pasteData.bUnit == nil then
					local logicTurret = logicTurrets[i]
					pasteData.bUnit = logicTurret.label[id] or {"MMT.gui.turret-label", logicTurret.turret.localised_name, logicTurret.turret.unit_number}
				end
				pasteData.bCount = pasteData.bCount + 1
			end
		end
	end
	gui.player.print(gui_compose_message(pasteData, clipboard)) --Display a message based on the result
end

local function guiClick_circuitry(id, gui) --Show or hide the circuit network panel
	local guiElement = gui.center[ModPrefix.."gui"]
	if guiElement[ModPrefix.."circuitry-frame"] ~= nil then
		guiElement[ModPrefix.."circuitry-frame"].destroy()
		return
	end
	local guiData, turret, index, cache = gui_get_data(id)
	local logicTurret = guiData.logicTurrets[turret][index]
	local circuitry = cache.circuitry or logicTurret.circuitry
	local circuit_frame = guiElement.add{type = "frame", name = ModPrefix.."circuitry-frame", direction = "vertical", style = "inner_frame_in_outer_frame_style", caption = {"gui-control-behavior.circuit-connection"}}
		circuit_frame.style.font = "default-bold"
		circuit_frame.style.minimal_width = 161
		circuit_frame.add{type = "label", name = ModPrefix.."network-label", caption = gui_is_connected(logicTurret)}
			circuit_frame[ModPrefix.."network-label"].style.font = "default-small-semibold"
		local mode_flow = circuit_frame.add{type = "flow", name = ModPrefix.."mode-flow", direction = "vertical", style = "slot_table_spacing_flow_style"}
			mode_flow.add{type = "label", name = ModPrefix.."mode-label", style = "description_label_style", caption = {"gui-control-behavior.mode-of-operation"}}
			local mode_table = mode_flow.add{type = "table", name = ModPrefix.."mode-table", style = "slot_table_style", colspan = 2}
				mode_table.style.horizontal_spacing = 4
				mode_table.style.vertical_spacing = 3
				mode_table.add{type = "sprite-button", name = ModPrefix..OffMode.."-button", style = ModPrefix.."radio"}
				mode_table.add{type = "label", name = ModPrefix..OffMode.."-label", caption = {"gui-control-behavior-modes.none"}}
					mode_table[ModPrefix..OffMode.."-label"].style.font = "default-small-semibold"
				mode_table.add{type = "sprite-button", name = ModPrefix..SendContentsMode.."-button", style = ModPrefix.."radio"}
				mode_table.add{type = "label", name = ModPrefix..SendContentsMode.."-label", caption = {"gui-control-behavior-modes.read-contents"}, tooltip = {"gui-requester.send-contents"}}
					mode_table[ModPrefix..SendContentsMode.."-label"].style.font = "default-small-semibold"
				mode_table.add{type = "sprite-button", name = ModPrefix..SetRequestsMode.."-button", style = ModPrefix.."radio"}
				mode_table.add{type = "label", name = ModPrefix..SetRequestsMode.."-label", caption = {"gui-control-behavior-modes.set-requests"}, tooltip = {"gui-requester.set-requests"}}
					mode_table[ModPrefix..SetRequestsMode.."-label"].style.font = "default-small-semibold"
				mode_table[ModPrefix..circuitry.mode.."-button"].sprite = ModPrefix.."bullet"
		gui_show_wires(id, gui)
end

local function guiClick_rename(id, gui) --Open the label editor
	local guiElement = gui.center[ModPrefix.."gui"][ModPrefix.."logistics-flow"][ModPrefix.."turret-frame"][ModPrefix.."turret-label"]
	local guiData, turret, index = gui_get_data(id)
	local label = guiData.logicTurrets[turret][index].label[id] --Current custom label, if any
	local field = guiElement.add{type = "textfield", name = ModPrefix.."edit-field", text = label}
	field.style.minimal_width = guiElement.style.minimal_width
	field.style.maximal_width = guiElement.style.maximal_width
end

local function guiClick_item(id, gui, ammo) --Set the count to the maximum stack size
	local guiElement = gui.center[ModPrefix.."gui"][ModPrefix.."logistics-flow"][ModPrefix.."turret-frame"][ModPrefix.."request-flow"][ModPrefix.."count-field"]
	local count = 0
	if ammo ~= BlankInGUI then
		count = game.item_prototypes[ammo].stack_size
	end
	guiElement.text = count --Update textfield
end

local function guiClick_save(id, gui) --Save the currently displayed request to be applied when the GUI closes
	local guiElement = gui.center[ModPrefix.."gui"][ModPrefix.."logistics-flow"][ModPrefix.."turret-frame"]
	local guiData, turret, index, cache = gui_get_data(id)
	local logicTurret = guiData.logicTurrets[turret][index]
	local circuitry = cache.circuitry or logicTurret.circuitry
	local label = guiElement[ModPrefix.."turret-label"].caption
	local message = {"MMT.message.save-empty", label}
	if circuitry.mode == SetRequestsMode then --Request slot is overridden by a circuit network
		message = {"MMT.message.circuit-override", label}
	else
		if guiData.cache[turret][index] == nil then
			guiData.cache[turret][index] = {}
		end
		local request = cache.request or logicTurret.chest.get_request_slot(1)
		local ammo = guiElement[ModPrefix.."request-flow"][ModPrefix.."item-button"].caption
		local count = tonumber(guiElement[ModPrefix.."request-flow"][ModPrefix.."count-field"].text)
		if ammo == BlankInGUI or count == nil or count < 1 then --Request slot will be cleared
			if request ~= nil then
				guiElement[ModPrefix.."ammo-table"][ModPrefix..request.name.."-ammo-button"].style = ModPrefix.."gray" --Change the old request's icon to gray
			end
			guiElement[ModPrefix.."request-flow"][ModPrefix.."count-field"].text = 0 --Update textfield
			guiData.cache[turret][index].request = {name = BlankInGUI} --Add to cache
		else
			local ammoData = game.item_prototypes[ammo]
			count = math.min(math.floor(count), ammoData.stack_size) --Round down to the nearest whole number, maximum one stack
			if request ~= nil then
				guiElement[ModPrefix.."ammo-table"][ModPrefix..request.name.."-ammo-button"].style = ModPrefix.."gray" --Change the old request's icon to gray
			end
			guiElement[ModPrefix.."ammo-table"][ModPrefix..ammo.."-ammo-button"].style = ModPrefix.."orange" --Change the new request's icon to orange
			guiElement[ModPrefix.."request-flow"][ModPrefix.."count-field"].text = count --Update textfield
			guiData.cache[turret][index].request = {name = ammo, count = count} --Add to cache
			message = {"MMT.message.save", label, {"MMT.gui.item", ammoData.localised_name, count}}
		end
	end
	gui.player.print(message) --Display a message based on the result
end

local function guiClick_copy(id, gui) --Save the currently displayed request to the clipboard
	local guiElement = gui.center[ModPrefix.."gui"][ModPrefix.."logistics-flow"][ModPrefix.."turret-frame"][ModPrefix.."request-flow"]
	local guiData, turret, index, cache = gui_get_data(id)
	local category = globalCall("TurretAmmoSets", turret)[0]
	local ammo = guiElement[ModPrefix.."item-button"].caption
	local count = tonumber(guiElement[ModPrefix.."count-field"].text)
	local message = {"MMT.message.copy-empty"}
	if ammo == BlankInGUI or count == nil or count < 1 then
		guiElement[ModPrefix.."count-field"].text = 0 --Update textfield
		globalCall("Clipboard")[id] = {turret = turret, category = category, ammo = BlankInGUI}
	else
		local ammoData = game.item_prototypes[ammo]
		count = math.min(math.floor(count), ammoData.stack_size) --Round down to the nearest whole number, maximum one stack
		guiElement[ModPrefix.."count-field"].text = count --Update textfield
		globalCall("Clipboard")[id] = {turret = turret, category = category, ammo = ammo, count = count}
		message = {"MMT.message.copy", {"MMT.gui.item", ammoData.localised_name, count}}
	end
	if gui.player.force.technologies["circuit-network"].researched then --Save the control behavior
		local circuitry = cache.circuitry or guiData.logicTurrets[turret][index].circuitry
		globalCall("Clipboard", id).circuitry = {mode = circuitry.mode, wires = {red = circuitry.wires.red, green = circuitry.wires.green}}
		local bMessage = {"MMT.message.copy-behavior-off"}
		if circuitry.mode ~= OffMode then
			local wires = gui_get_wires(circuitry)
			if wires ~= nil then
				bMessage = {"MMT.gui.mode", {"MMT.gui.mode-"..circuitry.mode}, {"MMT.gui.wire-"..wires}}
			end
		end
		message = {"MMT.message.combine", message, bMessage}
	end
	gui.player.print(message) --Display a message based on the result
	gui_show_control_panel(id, gui)
end

local function guiClick_ammo(id, gui, ammo) --Change the request icon to the selected ammo
	local guiElement = gui.center[ModPrefix.."gui"][ModPrefix.."logistics-flow"][ModPrefix.."turret-frame"][ModPrefix.."request-flow"][ModPrefix.."item-button"]
	if ammo == guiElement.caption then --Already selected
		return
	end
	local sprite = ""
	local count = 0
	if ammo ~= BlankInGUI then
		sprite = gui_get_sprite(gui, "item/"..ammo)
		count = game.item_prototypes[ammo].stack_size
	end
	guiElement.caption = ammo --Store ammo name in the caption
	guiElement.sprite = sprite
	guiElement.tooltip = {"MMT.gui.stack", count}
end

local function guiClick_mode(id, gui, mode) --Set the mode of operation
	local guiElement = gui.center[ModPrefix.."gui"][ModPrefix.."circuitry-frame"][ModPrefix.."mode-flow"][ModPrefix.."mode-table"]
	local guiData, turret, index, cache = gui_get_data(id)
	local circuitry = cache.circuitry or guiData.logicTurrets[turret][index].circuitry
	mode = string.sub(mode, #ModPrefix + 1, -8)
	if mode == circuitry.mode then --Already selected
		return
	end
	if guiData.cache[turret][index] == nil then
		guiData.cache[turret][index] = {}
	end
	guiElement[ModPrefix..circuitry.mode.."-button"].sprite = ""
	guiElement[ModPrefix..mode.."-button"].sprite = ModPrefix.."bullet"
	guiData.cache[turret][index].circuitry = {mode = mode, wires = {red = circuitry.wires.red, green = circuitry.wires.green}} --Add to cache
	gui_show_wires(id, gui)
end

local function guiClick_wire(id, gui, wire) --Set the wires the turret will connect to
	local guiElement = gui.center[ModPrefix.."gui"][ModPrefix.."circuitry-frame"][ModPrefix.."connect-flow"][ModPrefix.."wire-flow"]
	local guiData, turret, index, cache = gui_get_data(id)
	local circuitry = cache.circuitry or guiData.logicTurrets[turret][index].circuitry
	wire = string.sub(wire, #ModPrefix + 1, -8)
	if guiData.cache[turret][index] == nil then
		guiData.cache[turret][index] = {}
	end
	if guiData.cache[turret][index].circuitry == nil then
		guiData.cache[turret][index].circuitry = {mode = circuitry.mode, wires = {red = circuitry.wires.red, green = circuitry.wires.green}}
	end
	if circuitry.wires[wire] then
		guiElement[ModPrefix..wire.."-button"].style = ModPrefix.."gray"
		guiData.cache[turret][index].circuitry.wires[wire] = false --Add to cache
	else
		guiElement[ModPrefix..wire.."-button"].style = ModPrefix.."blue"
		guiData.cache[turret][index].circuitry.wires[wire] = true --Add to cache
	end
end

--Open and close functions--------------------------------------------------------------------------
local function open_gui(id) --Create the GUI
	local player = get_player(id)
	if player == nil then
		return
	end
	local gui = player.gui
	local guiData = globalCall("TurretGUI", id)
	local root = gui.center.add{type = "flow", name = ModPrefix.."gui", direction = "horizontal", style = "achievements_flow_style"}
		local logistic_flow = root.add{type = "flow", name = ModPrefix.."logistics-flow", direction = "vertical", style = "achievements_flow_style"}
			local nav_frame = logistic_flow.add{type = "frame", name = ModPrefix.."navigation-flow", direction = "vertical"}
				nav_frame.style.minimal_width = 188
				local title_flow = nav_frame.add{type = "flow", name = ModPrefix.."title-flow", direction = "horizontal"}
					title_flow.add{type = "label", name = ModPrefix.."title-label", style = "description_title_label_style", caption = {"MMT.gui.title"}}
						title_flow[ModPrefix.."title-label"].style.minimal_width = 145
					title_flow.add{type = "sprite-button", name = ModPrefix.."close-button", style = ModPrefix.."nav", sprite = ModPrefix.."close"}
				local turret_table = nav_frame.add{type = "table", name = ModPrefix.."turret-table", style = "slot_table_style", colspan = 5}
					for turret in pairs(guiData.logicTurrets) do
						if guiData.turret == nil then
							guiData.turret = turret --Current turret
						end
						guiData.index[turret] = 1 --Current index
						guiData.cache[turret] = {} --Create cache
						local turretName = game.entity_prototypes[turret].localised_name
						local tooltip = {"MMT.gui.turret-tooltip", turretName}
						local style = "gray"
						if #guiData.logicTurrets[turret] > 1 then
							tooltip = {"MMT.gui.turrets-tooltip", turretName, #guiData.logicTurrets[turret]}
						end
						if turret == guiData.turret then --Highlight current turret
							style = "orange"
						end
						turret_table.add{type = "sprite-button", name = ModPrefix..turret.."-turret-button", style = ModPrefix..style, sprite = gui_get_sprite(gui, "entity/"..turret), tooltip = tooltip}
					end
			local turret = guiData.turret
				local control_flow = nav_frame.add{type = "flow", name = ModPrefix.."control-flow", direction = "horizontal", style = "achievements_flow_style"}
					control_flow.add{type = "sprite-button", name = ModPrefix.."prev-button", style = ModPrefix.."nav", sprite = ModPrefix.."prev"}
					control_flow.add{type = "label", name = ModPrefix.."index-label", style = ModPrefix.."index", caption = guiData.index[turret].."/"..#guiData.logicTurrets[turret]}
					control_flow.add{type = "sprite-button", name = ModPrefix.."next-button", style = ModPrefix.."nav", sprite = ModPrefix.."next"}
					gui_show_control_panel(id, gui)
			local logicTurret = guiData.logicTurrets[turret][guiData.index[turret]]
			local request = logicTurret.chest.get_request_slot(1)
			local label = logicTurret.label[id] or {"MMT.gui.turret-label", logicTurret.turret.localised_name, logicTurret.turret.unit_number}
			local caption = BlankInGUI
			local sprite = ""
			local tooltip = {"MMT.gui.stack", 0}
			local count = 0
			if request ~= nil then
				caption = request.name --Store ammo name in the caption
				sprite = gui_get_sprite(gui, "item/"..request.name)
				tooltip = {"MMT.gui.stack", game.item_prototypes[request.name].stack_size}
				count = request.count + math.floor(logicTurret.insertLimit)
			end
			local turret_frame = logistic_flow.add{type = "frame", name = ModPrefix.."turret-frame", direction = "vertical"}
				turret_frame.style.minimal_width = 188
				local turret_label = turret_frame.add{type = "label", name = ModPrefix.."turret-label", style = "description_label_style", caption = label, tooltip = {"gui-edit-label.edit-label"}}
					turret_label.style.minimal_width = 167
					turret_label.style.maximal_width = 167
				local request_flow = turret_frame.add{type = "flow", name = ModPrefix.."request-flow", direction = "horizontal"}
					request_flow.add{type = "sprite-button", name = ModPrefix.."item-button", style = ModPrefix.."gray", caption = caption, sprite = sprite, tooltip = tooltip}
					request_flow.add{type = "textfield", name = ModPrefix.."count-field", text = count}
						request_flow[ModPrefix.."count-field"].style.minimal_width = 54
					local cache_flow = request_flow.add{type = "flow", name = ModPrefix.."cache-flow", direction = "horizontal", style = "slot_table_spacing_flow_style"}
						cache_flow.add{type = "sprite-button", name = ModPrefix.."save-button", style = ModPrefix.."gray", sprite = ModPrefix.."save", tooltip = {"gui-save-game.save"}}
						cache_flow.add{type = "sprite-button", name = ModPrefix.."copy-button", style = ModPrefix.."gray", sprite = ModPrefix.."copy", tooltip = {"MMT.gui.copy"}}
			gui_show_ammo_table(id, gui)
end

local function close_gui(id) --Close the GUI and apply any saved changes
	local player = get_player(id)
	if player == nil then
		return
	end
	local gui = player.gui
	local guiElement = gui.center[ModPrefix.."gui"]
	if guiElement == nil or not guiElement.valid then
		globalCall("TurretGUI")[id] = nil --Delete GUI metadata
		return
	end
	local guiData = globalCall("TurretGUI", id)
	if guiElement[ModPrefix.."logistics-flow"][ModPrefix.."turret-frame"][ModPrefix.."turret-label"][ModPrefix.."edit-field"] ~= nil then --Close the label editor
		gui_rename_turret(id, gui)
	end
	for turret, data in pairs(guiData.cache) do
		for index, cache in pairs(data) do
			local logicTurret = guiData.logicTurrets[turret][index]
			local circuitry = cache.circuitry
			local request = cache.request
			if circuitry ~= nil then --Turret has a cached control behavior
				set_circuitry(logicTurret, circuitry.mode, circuitry.wires)
			end
			if request ~= nil then --Turret has a cached request
				if request.name == BlankInGUI then
					set_request(logicTurret, "empty")
				else
					set_request(logicTurret, {ammo = request.name, count = request.count})
				end
			end
		end
	end
	guiElement.destroy() --Close GUI
	global.TurretGUI[id] = nil --Delete GUI metadata
end

--Event handlers------------------------------------------------------------------------------------
local guiButtons =
{
	[ModPrefix.."close-button"] = close_gui,
	[ModPrefix.."prev-button"] = guiClick_nav,
	[ModPrefix.."next-button"] = guiClick_nav,
	[ModPrefix.."all-button"] = guiClick_paste,
	[ModPrefix.."match-button"] = guiClick_paste,
	[ModPrefix.."behavior-button"] = guiClick_paste_behavior,
	[ModPrefix.."circuitry-button"] = guiClick_circuitry,
	[ModPrefix.."save-button"] = guiClick_save,
	[ModPrefix.."copy-button"] = guiClick_copy,
	[ModPrefix..OffMode.."-button"] = guiClick_mode,
	[ModPrefix..SendContentsMode.."-button"] = guiClick_mode,
	[ModPrefix..SetRequestsMode.."-button"] = guiClick_mode,
	[ModPrefix.."red-button"] = guiClick_wire,
	[ModPrefix.."green-button"] = guiClick_wire
}

local function onGuiClick(event) --Perform GUI functions
	local element = event.element
	if element == nil or not element.valid then
		return
	end
	local name = element.name
	if starts_with(name, ModPrefix) then
		local id = event.player_index
		local player = get_player(id)
		if player == nil then
			return
		end
		local gui = player.gui
		if name ~= ModPrefix.."edit-field" and gui.center[ModPrefix.."gui"][ModPrefix.."logistics-flow"][ModPrefix.."turret-frame"][ModPrefix.."turret-label"][ModPrefix.."edit-field"] ~= nil then
			gui_rename_turret(id, gui) --Close the label editor whenever anything else is clicked
		end
		if name == ModPrefix.."turret-label" then
			guiClick_rename(id, gui)
		elseif element.type == "sprite-button" then
			if guiButtons[name] ~= nil then
				guiButtons[name](id, gui, name)
			elseif name == ModPrefix.."item-button" then
				guiClick_item(id, gui, element.caption)
			elseif ends_with(name, "-ammo-button") then
				guiClick_ammo(id, gui, string.sub(name, #ModPrefix + 1, -13))
			elseif ends_with(name, "-turret-button") then
				guiClick_turret(id, gui, string.sub(name, #ModPrefix + 1, -15))
			end
		end
	end
end

local function onSelectedArea(event) --Use the logistic turret remote to open the turret GUI
	if event.item ~= TurretRemote then
		return
	end
	local id = event.player_index
	local player = get_player(id)
	if player == nil then
		return
	end
	close_gui(id) --Close any open GUI before proceeding
	local force = player.force
	if not is_remote_enabled(force) then --Logistic system is not researched
		player.print({"MMT.message.remote-fail"})
		return
	end
	local entities = event.entities
	local turretList = {}
	for i = 1, #entities do
		local entity = entities[i]
		if entity ~= nil and entity.valid then
			local turret = entity.name
			if globalCall("LogicTurretConfig")[turret] ~= nil and entity.operable and not entity.to_be_deconstructed(force) then
				local logicTurret = lookup_turret(entity)
				if logicTurret ~= nil then
					if turretList[turret] == nil then
						turretList[turret] = {}
					end
					turretList[turret][#turretList[turret] + 1] = logicTurret --Sort turrets into lists by name
				end
			end
		end
	end
	if next(turretList) ~= nil then
		local logicTurrets = {}
		local counter = 0
		for turret, data in spairs(turretList, function(t, a, b) return #t[a] > #t[b] end) do --Sort turret lists by length
			logicTurrets[turret] = data
			counter = counter + 1
			if counter >= 5 then --Limit to five types
				break
			end
		end
		globalCall("TurretGUI")[id] = {logicTurrets = logicTurrets, index = {}, cache = {}} --GUI metadata
		open_gui(id)
	end
end

local function onAltSelectedArea(event) --Quick-paste mode
	if event.item ~= TurretRemote then
		return
	end
	local id = event.player_index
	local player = get_player(id)
	if player == nil then
		return
	end
	close_gui(id) --Close any open GUI before proceeding
	local force = player.force
	if not is_remote_enabled(force) then --Logistic system is not researched
		player.print({"MMT.message.remote-fail"}) --Display a message
		return
	end
	local clipboard = globalCall("Clipboard")[id]
	if clipboard == nil then --Clipboard is empty
		player.print({"MMT.message.paste-nil"}) --Display a message
		return
	end
	local pasteMode = QuickpasteMode
	if not (pasteMode == "match-ammo-category" or pasteMode == "match-turret-name") then
		pasteMode = "match-ammo-category"
	end
	local copiedTurret, category, ammo, count, circuitry = clipboard.turret, clipboard.category, clipboard.ammo, clipboard.count, clipboard.circuitry --Clipboard contents
	local is_compatible = nil
	if pasteMode == "match-ammo-category" then
		is_compatible = function(turret)
			if globalCall("TurretAmmoSets", turret)[0] == category then return true end
		end
	elseif pasteMode == "match-turret-name" then
		is_compatible = function(turret)
			if turret == copiedTurret then return true end
		end
	end
	local pasteData =
	{
		rCount = 0,
		bCount = 0,
		oCount = 0,
		rUnit = nil,
		bUnit = nil,
		oUnit = nil
	}
	local entities = event.entities
	for i = 1, #entities do
		local entity = entities[i]
		if entity ~= nil and entity.valid then
			local turret = entity.name
			if globalCall("LogicTurretConfig")[turret] ~= nil and is_compatible(turret) and entity.operable and not entity.to_be_deconstructed(force) then
				local logicTurret = lookup_turret(entity)
				if logicTurret ~= nil then
					close_turret_gui(entity) --Close this turret's GUI for all players
					if circuitry ~= nil and QuickpasteBehavior then
						set_circuitry(logicTurret, circuitry.mode, circuitry.wires)
						if pasteData.bUnit == nil then
							pasteData.bUnit = logicTurret.label[id] or {"MMT.gui.turret-label", logicTurret.turret.localised_name, logicTurret.turret.unit_number}
						end
						pasteData.bCount = pasteData.bCount + 1
					end
					if logicTurret.circuitry.mode == SetRequestsMode then --Request slot is overridden by a circuit network
						if pasteData.oUnit == nil then
							pasteData.oUnit = logicTurret.label[id] or {"MMT.gui.turret-label", logicTurret.turret.localised_name, logicTurret.turret.unit_number}
						end
						pasteData.oCount = pasteData.oCount + 1
					else
						if ammo == BlankInGUI then
							set_request(logicTurret, "empty")
						else
							set_request(logicTurret, {ammo = ammo, count = count})
						end
						if pasteData.rUnit == nil then
							pasteData.rUnit = logicTurret.label[id] or {"MMT.gui.turret-label", logicTurret.turret.localised_name, logicTurret.turret.unit_number}
						end
						pasteData.rCount = pasteData.rCount + 1
					end
				end
			end
		end
	end
	player.print(gui_compose_message(pasteData, clipboard)) --Display a message based on the result
end

local function onPlayerDied(event) --Close GUI when player dies
	close_gui(event.player_index)
end

local function onPlayerConnection(event) --Close GUI and clear clipboard
	local id = event.player_index
	destroy_gui(id)
	globalCall("Clipboard")[id] = nil --Delete clipboard data
end

local function onCustomInput(event) --Custom keybinds
	local hotkey = event.input_name
	if hotkey == ModPrefix.."close-gui" then
		close_gui(event.player_index)
	elseif hotkey == ModPrefix.."select-remote" then
		local player = get_player(event.player_index)
		if player == nil then
			return
		end
		local cursor = player.cursor_stack
		if cursor.valid_for_read and cursor.name == TurretRemote then
			player.clean_cursor()
		elseif player.get_item_count(TurretRemote) > 0 then
			player.clean_cursor()
			player.remove_item({name = TurretRemote, count = 1})
			cursor.set_stack({name = TurretRemote, count = 1})
		end
	end
end

----------------------------------------------------------------------------------------------------
--Loader
----------------------------------------------------------------------------------------------------
--Sanitization--------------------------------------------------------------------------------------
local function validate_config(turret, config) --Sanity checks config entries, detects new and updated entries
	if turret == nil or config == nil then
		return
	end
	local validConfig = nil
	local newTurret = nil
	local updatedTurret = nil
	if type(turret) == "string" then
		local turretData = game.entity_prototypes[turret]
		if turretData ~= nil and turretData.type == "ammo-turret" then
			if config == true or config == "empty" then
				if globalCall("LogicTurretConfig")[turret] ~= nil then --Previous entry exists
					if global.LogicTurretConfig[turret] ~= "empty" then
						updatedTurret = true
					end
				else
					newTurret = true
				end
				validConfig = "empty" --All checks passed
			elseif type(config) == "table" then
				local ammo = config.ammo
				local count = config.count
				if ammo ~= nil and count ~= nil and type(ammo) == "string" and type(count) == "number" and count >= 1 then
					local ammoData = game.item_prototypes[ammo]
					if ammoData ~= nil and ammoData.type == "ammo" then
						if globalCall("LogicTurretConfig")[turret] ~= nil and global.LogicTurretConfig[turret] ~= "empty" and global.LogicTurretConfig[turret].ammo == ammo then --Previous entry exists and ammo type is the same
							if global.LogicTurretConfig[turret].count ~= count then --Ammo count has changed
								count = math.min(math.floor(count), ammoData.stack_size) --Round down to the nearest whole number, maximum one stack
								updatedTurret = true
							end
							validConfig = {ammo = ammo, count = count} --No further checks necessary
						elseif globalCall("AmmoCategories")[ammo] == globalCall("TurretAmmoSets", turret)[0] then --Item's ammo category matches the turret's ammo category
							if global.LogicTurretConfig[turret] ~= nil then --Previous entry exists
								updatedTurret = true
							else
								newTurret = true
							end
							count = math.min(math.floor(count), ammoData.stack_size) --Round down to the nearest whole number, maximum one stack
							validConfig = {ammo = ammo, count = count} --All checks passed
						end
					end
				end
			end
		end
	end
	return validConfig, newTurret, updatedTurret --Return results
end

local function check_config() --Compile a list of all valid config entries
	local newTurrets = {} --New entries will end up here
	local updatedTurrets = {} --Updated entries will end up here
	local turretList = {}
	if LogisticTurret ~= nil and type(LogisticTurret) == "table" then --Gather turrets from the user's config file
		for turret, config in pairs(LogisticTurret) do
			turretList[turret] = config
		end
	end
	if AllowRemoteConfig then --Gather turrets added by remote calls
		for turret, config in pairs(globalCall("RemoteTurretConfig")) do
			if game.entity_prototypes[turret] ~= nil then
				turretList[turret] = turretList[turret] or config
			else
				global.RemoteTurretConfig[turret] = nil
			end
		end
	end
	if UseBobsDefault == true and game.active_mods["bobwarfare"] ~= nil then --Gather Bob's turrets
		local BobsDefault = BobsDefault or true
		for turret, entity in pairs(game.entity_prototypes) do
			if entity.type == "ammo-turret" and starts_with(turret, "bob-") then --Find turrets with names prefixed by "bob-"
				turretList[turret] = turretList[turret] or BobsDefault
			end
		end
	end
	for turret, config in pairs(turretList) do --Screen the list for new, updated, and invalid entries
		turretList[turret], newTurrets[turret], updatedTurrets[turret] = validate_config(turret, config)
	end
	for turret in pairs(globalCall("LogicTurretConfig")) do
		if turretList[turret] == nil then --Previous entry was removed from the config file/became invalid
			updatedTurrets[turret] = true
		end
	end
	save_to_global(turretList, "LogicTurretConfig") --Overwrite the old list with the new
	return newTurrets, updatedTurrets
end

--Application---------------------------------------------------------------------------------------
local function update_requests(updatedTurrets) --Update the request slots of turrets whose entries have changed
	if updatedTurrets == nil or next(updatedTurrets) == nil then --No changes
		return
	end
	for i = 1, #globalCall("LogicTurrets") do
		local logicTurret = is_valid_turret(global.LogicTurrets[i])
		if logicTurret ~= nil and updatedTurrets[logicTurret.turret.name] ~= nil then --Turret's entry has changed
			local config = globalCall("LogicTurretConfig")[logicTurret.turret.name]
			if config == nil then --Turret's entry was removed
				local magazine = turret.get_inventory(defines.inventory.turret_ammo)
				for i = 1, #magazine do
					move_ammo(logicTurret.stash, magazine[i])
					move_ammo(logicTurret.trash, magazine[i])
				end
				spill_stack(logicTurret.turret, logicTurret.stash)
				spill_stack(logicTurret.turret, logicTurret.trash)
				destroy_components(logicTurret)
			elseif logicTurret.override then --Turret's request has been edited in-game, and should therefore ignore the config file
				local request = logicTurret.chest.get_request_slot(1)
				if request == nil then
					if config == "empty" then --Override is the same as the new request
						logicTurret.override = nil --Remove override flag
					end
				elseif config ~= "empty" then
					if request.name == config.ammo and request.count == config.count then --Override is the same as the new request
						logicTurret.override = nil --Remove override flag
					end
				end
			else
				set_request(logicTurret, config)
			end
		end
	end
	for force, turretArray in pairs(globalCall("DormantLogicTurrets")) do
		for i = #turretArray, 1, -1 do
			local logicTurret = is_valid_turret(turretArray[i])
			if logicTurret == nil then
				table.remove(turretArray, i)
			elseif updatedTurrets[logicTurret.turret.name] ~= nil and globalCall("LogicTurretConfig")[logicTurret.turret.name] == nil then --Turret's entry was removed
				local magazine = turret.get_inventory(defines.inventory.turret_ammo)
				for i = 1, #magazine do
					move_ammo(logicTurret.stash, magazine[i])
					move_ammo(logicTurret.trash, magazine[i])
				end
				spill_stack(logicTurret.turret, logicTurret.stash)
				spill_stack(logicTurret.turret, logicTurret.trash)
				destroy_components(logicTurret)
				table.remove(turretArray, i)
			end
		end
		if #turretArray <= 0 then --Force has no dormant turrets
			global.DormantLogicTurrets[force] = nil --Delete list
		end
	end
end

local function find_turrets(newTurrets) --Find the turrets of new entries
	if newTurrets == nil or next(newTurrets) == nil then --No new turrets
		return
	end
	for _, surface in pairs(game.surfaces) do
		for name in pairs(newTurrets) do
			for i, turret in pairs(surface.find_entities_filtered{name = name, type = "ammo-turret"}) do
				if lookup_turret(turret) == nil then
					local logicTurret = add_components(turret) --Add internal components
					if logicTurret ~= nil then
						add_logistic_turret(logicTurret) --Add to logistic turret list
					end
				end
			end
		end
	end
end

local function set_autofill(lists) --Set Autofill profiles for new and updated turrets
	if lists == nil or remote.interfaces["af"] == nil or next(globalCall("LogicTurretConfig")) == nil then --Autofill not installed/user has not configured any logistic turrets
		return
	end
	local turretList = {}
	for i = 1, #lists do
		for turret in pairs(lists[i]) do --Compile a list of turrets and their config settings
			local config = global.LogicTurretConfig[turret]
			if config ~= "empty" then
				turretList[turret] = config.ammo
			end
		end
	end
	if next(turretList) ~= nil then
		local autofillSets = --Get Autofill's item sets
		{
			remote.call("af", "getItemArray", "ammo-bullets"),
			remote.call("af", "getItemArray", "ammo-rockets"),
			remote.call("af", "getItemArray", "ammo-shells"),
			remote.call("af", "getItemArray", "ammo-shotgun"),
			remote.call("af", "getItemArray", "ammo-artillery"),
			remote.call("af", "getItemArray", "ammo-battery"),
			remote.call("af", "getItemArray", "ammo-dytech-capsule"),
			remote.call("af", "getItemArray", "ammo-dytech-laser"),
			remote.call("af", "getItemArray", "ammo-dytech-laser-shotgun"),
			remote.call("af", "getItemArray", "ammo-dytech-laser-tank"),
			remote.call("af", "getItemArray", "ammo-dytech-sniper"),
			remote.call("af", "getItemArray", "ammo-yi-chem"),
			remote.call("af", "getItemArray", "ammo-yi-plasma"),
			remote.call("af", "getItemArray", "combat-units"),
			remote.call("af", "getItemArray", "gi-ammo-artillery"),
			remote.call("af", "getItemArray", "gi-ammo-auto45"),
			remote.call("af", "getItemArray", "gi-ammo-flame"),
			remote.call("af", "getItemArray", "gi-ammo-mine"),
			remote.call("af", "getItemArray", "gi-ammo-rocket"),
			remote.call("af", "getItemArray", "gi-ammo-wmd"),
			remote.call("af", "getItemArray", "mo-ammo-goliath"),
			remote.call("af", "getItemArray", "tw-ammo-belt"),
			remote.call("af", "getItemArray", "tw-ammo-flame"),
			remote.call("af", "getItemArray", "tw-ammo-rocket")
		}
		for turret, ammo in pairs(turretList) do
			local found = false
			for _, itemArray in pairs(autofillSets) do --Check if the requested ammo matches any of Autofill's item sets
				for i, item in pairs(itemArray) do
					if ammo == item then --Match found
						ammo = itemArray --Autofill will use the whole set instead of a single item
						found = true
						break
					end
				end
				if found then
					break
				end
			end
			remote.call("af", "addToDefaultSets", turret, {priority = 1, group = "turrets", limits = {10}, ammo}) --Set the turret's Autofill profile
		end
	end
end

--Testing surface-----------------------------------------------------------------------------------
local function decorate_workshop() --Remove obstructions and pave the workshop in concrete
	local workshop = game.surfaces[ModPrefix.."workshop"]
	if workshop == nil or not workshop.valid then
		return
	end
	local nature = workshop.find_entities()
	for i = 1, #nature do
		if nature[i].valid and nature[i].type ~= "player" then --Players are unnatural
			nature[i].destroy()
		end
	end
	local flooring = {}
	for x = -32, 31 do
		for y = -32, 31 do
			flooring[#flooring + 1] = {name = "concrete", position = {x, y}}
		end
	end
	workshop.set_tiles(flooring)
	for chunk in workshop.get_chunks() do
		workshop.set_chunk_generated_status(chunk, defines.chunk_generated_status.entities)
	end
end

local function build_workshop() --Create a surface to conduct validation checks in
	local workshop = game.surfaces[ModPrefix.."workshop"]
	if workshop == nil or not workshop.valid then
		workshop = game.create_surface(ModPrefix.."workshop",
		{
			terrain_segmentation = "none",
			water = "none",
			starting_area = "none",
			width = 1,
			height = 1,
			peaceful_mode = true
		})
		workshop.always_day = true
		decorate_workshop() --Sterilize the workshop
	end
	return workshop
end

--Prototype analysis--------------------------------------------------------------------------------
local function sort_ammo_types() --Compile lists of ammo categories and the turrets that can use them
	local surface = build_workshop() --Use the workshop, creating it if it doesn't exist
	local ammoTypes = {}
	local turretAmmo = {}
	for ammo, item in pairs(game.item_prototypes) do
		local ammoType = item.ammo_type
		if ammoType ~= nil and not item.has_flag("hidden") then --Skip hidden items
			ammoTypes[ammo] = ammoType.category --Save as dictionary
		end
	end
	for turret, entity in pairs(game.entity_prototypes) do
		if entity.type == "ammo-turret" then
			local position = surface.find_non_colliding_position(turret, {0, 0}, 0, 1) --In case something is in the workshop that shouldn't be
			if position ~= nil then
				local testTurret = surface.create_entity{name = turret, position = position, force = "neutral"} --Create a test turret
				if testTurret ~= nil and testTurret.valid then
					for ammo, category in pairs(ammoTypes) do
						if testTurret.can_insert({name = ammo}) then --Turret's ammo category matches the item's ammo category
							if turretAmmo[turret] == nil then
								turretAmmo[turret] = {[0] = category} --Save category as index zero
							end
							turretAmmo[turret][#turretAmmo[turret] + 1] = ammo --Save as array
						end
					end
					testTurret.destroy() --Destroy test turret
				end
			end
		end
	end
	save_to_global(ammoTypes, "AmmoCategories") --Save lists in the global table
	save_to_global(turretAmmo, "TurretAmmoSets")
end

local function reload_tech() --Reload any technologies that unlock the logistic turret remote and awaken dormant turrets if necessary
	for name, force in pairs(game.forces) do
		for _, tech in pairs(force.technologies) do
			if tech.effects ~= nil then
				for i = 1, #tech.effects do
					if tech.effects[i].recipe == "logistic-chest-requester" then
						tech.reload()
						break
					end
				end
			end
		end
		local remote = force.recipes[TurretRemote]
		remote.enabled = remote.enabled or force.recipes["logistic-chest-requester"].enabled --Enable the remote if the logistic system is researched
		if globalCall("DormantLogicTurrets")[name] ~= nil and remote.enabled then --Logistic system is researched
			awaken_dormant_turrets(name)
		end
	end
end

local function set_minable() --Set interfaces' minable status to that of their parent turret
	for index, exes in pairs(globalCall("LookupTable")) do
		for x, whys in pairs(exes) do
			for y, logicTurret in pairs(whys) do
				if is_valid_turret(logicTurret) then
					logicTurret.interface.minable = (logicTurret.turret.minable and logicTurret.turret.prototype.mineable_properties.minable)
				else
					remove_address(index, x, y)
				end
			end
		end
	end
end

--Main loader---------------------------------------------------------------------------------------
function load_config() --Runs on the first tick after loading a world
	if loaded then
		return
	end
	for id in pairs(globalCall("TurretGUI")) do --Close any open GUIs
		destroy_gui(id)
	end
	for id in pairs(globalCall("Clipboard")) do --Delete any clipboard data
		global.Clipboard[id] = nil
	end
	local newTurrets, updatedTurrets = check_config() --Check config file for any changes
	update_requests(updatedTurrets) --Apply changes
	find_turrets(newTurrets) --Apply new entries
	set_autofill({newTurrets, updatedTurrets}) --Update Autofill profiles
	validate_ghost_data() --Remove expired ghosts from the ghost lookup table
	if next(globalCall("LogicTurretConfig")) ~= nil then --Register event handlers
		script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity}, onEntityBuilt)
		script.on_event(defines.events.on_entity_died, onEntityDied)
		script.on_event({defines.events.on_preplayer_mined_item, defines.events.on_robot_pre_mined}, onEntityMined)
		script.on_event(defines.events.on_marked_for_deconstruction, onEntityMarked)
		script.on_event(defines.events.on_canceled_deconstruction, onEntityUnmarked)
		script.on_event(defines.events.on_research_finished, onResearchFinished)
		script.on_event(defines.events.on_forces_merging, onForcesMerged)
		script.on_event(defines.events.on_pre_entity_settings_pasted, onPreSettingsPasted)
		script.on_event(defines.events.on_entity_settings_pasted, onSettingsPasted)
		script.on_event(defines.events.on_gui_click, onGuiClick)
		script.on_event(defines.events.on_player_selected_area, onSelectedArea)
		script.on_event(defines.events.on_player_alt_selected_area, onAltSelectedArea)
		script.on_event(defines.events.on_pre_player_died, onPlayerDied)
		script.on_event({defines.events.on_player_joined_game, defines.events.on_player_left_game}, onPlayerConnection)
		script.on_event(ModPrefix.."close-gui", onCustomInput)
	end
	loaded = true
end

local function onInit() --Initialize globals
	globalCall("LogicTurretConfig")
	globalCall("RemoteTurretConfig")
	globalCall("LogicTurrets")
	globalCall("ActiveLogicTurrets")
	globalCall("DormantLogicTurrets")
	globalCall("GhostConnections")
	globalCall("LookupTable")
	globalCall("TurretGUI")
	globalCall("Clipboard")
	globalCall().Counter = 1
	globalCall().IdleCounter = 1
	sort_ammo_types() --Create lists of ammo categories
end

local function onConfigurationChanged(data) --Update version
	if data == nil or data.mod_changes == nil then
		return
	end
	if data.mod_changes[ModName] ~= nil then
		local old_version = data.mod_changes[ModName].old_version
		if old_version ~= nil then
			local function older_than(version)
				local oldPart = string.gmatch(old_version, "%d+")
				for newVer in string.gmatch(version, "%d+") do
					local oldVer = oldPart()
					if oldVer < newVer then
						return true
					elseif oldVer > newVer then
						return false
					end
				end
				return false
			end
			if older_than("1.0.3") then
				globalCall().Counter = 1
				globalCall().IdleCounter = 1
			end
			if older_than("1.1.0") then
				globalCall("ActiveLogicTurrets")
				local workshop = game.surfaces[ModPrefix.."workshop"]
				if workshop ~= nil and workshop.valid then
					workshop.always_day = true
					decorate_workshop()
				end
				for _, force in pairs(game.forces) do
					force.recipes[TurretRemote].reload()
				end
				local arrays = {globalCall("LogicTurrets"), global.IdleLogicTurrets}
				for i = 1, #arrays do
					local turretArray = arrays[i]
					for j = #turretArray, 1, -1 do
						local turret = turretArray[j][1]
						local chest = turretArray[j][2]
						table.remove(turretArray, j)
						if chest.valid then
							if turret.valid and globalCall("LogicTurretConfig")[turret.name] ~= nil then
								local logicTurret = add_components(turret)
								if logicTurret ~= nil then
									local request = chest.get_request_slot(1)
									if request ~= nil then
										request = {ammo = request.name, count = request.count}
									end
									logicTurret.chest.get_inventory(defines.inventory.chest)[1].set_stack(chest.get_inventory(defines.inventory.chest)[1])
									set_request(logicTurret, request)
									add_logistic_turret(logicTurret)
								end
							end
							chest.destroy()
						end
					end
				end
				global.IdleLogicTurrets = nil
				global.IconSets = nil
			end
			if older_than("1.1.1") then
				for index in pairs(globalCall("GhostConnections")) do
					global.GhostConnections[index] = nil
				end
			end
		end
	end
	if data.mod_changes["autofill"] ~= nil and data.mod_changes["autofill"].old_version == nil then --Autofill was installed
		set_autofill({globalCall("LogicTurretConfig")})
	end
	sort_ammo_types() --Re-create the ammo lists
	reload_tech() --Reload any technologies that unlock the logistic turret remote and awaken dormant turrets if necessary
	set_minable() --Set interfaces' minable status to that of their parent turret
end

script.on_init(onInit)
script.on_configuration_changed(onConfigurationChanged)
script.on_event(defines.events.on_tick, onTick)
script.on_event(ModPrefix.."select-remote", onCustomInput)

--Remote interface----------------------------------------------------------------------------------
remote.add_interface(ModName,
{
	configure_logistic_turret = function(turret, config) --Configure a logistic turret
		if turret == nil then
			return
		end
		globalCall("RemoteTurretConfig")[turret] = validate_config(turret, config)
		if AllowRemoteConfig then
			loaded = false
			script.on_event(defines.events.on_tick, onTick)
		end
	end,

	change_request_slot = function(turret, ammo, count) --Change a turret's request
		if turret == nil or not AllowRemoteConfig then
			return false
		end
		if type(turret) == "table" and turret.valid and globalCall("LogicTurretConfig")[turret.name] ~= nil then
			local logicTurret = lookup_turret(turret)
			if logicTurret ~= nil and logicTurret.circuitry.mode ~= SetRequestsMode then
				close_turret_gui(turret)
				if ammo == nil or ammo == "empty" then
					set_request(logicTurret, ammo)
					return true
				elseif type(ammo) == "string" then
					local ammoData = game.item_prototypes[ammo]
					if ammoData ~= nil and ammoData.type == "ammo" and globalCall("AmmoCategories")[ammo] == globalCall("TurretAmmoSets", turret.name)[0] then
						if count ~= nil and type(count) == "number" and count >= 1 then
							count = math.min(math.floor(count), ammoData.stack_size)
						else
							count = ammoData.stack_size
						end
						set_request(logicTurret, {ammo = ammo, count = count})
						return true
					end
				end
			end
		end
		return false
	end,

	change_circuit_mode = function(turret, mode, wires) --Change a turret's circuit mode
		if turret == nil or not AllowRemoteConfig then
			return false
		end
		if type(turret) == "table" and turret.valid and globalCall("LogicTurretConfig")[turret.name] ~= nil then
			local logicTurret = lookup_turret(turret)
			if logicTurret ~= nil then
				close_turret_gui(turret)
				if type(wires) == "table" then
					wires.red = (wires.red == true)
					wires.green = (wires.green == true)
				else
					wires = {red = false, green = false}
				end
				if mode == nil or mode == OffMode then
					set_circuitry(logicTurret, OffMode, wires)
					return true
				elseif mode == SendContentsMode or mode == SetRequestsMode then
					set_circuitry(logicTurret, mode, wires)
					return true
				end
			end
		end
		return false
	end,

	remote_control = function(force, enable) --Check if the logistic turret remote is enabled
		if type(force) == "string" then
			force = game.forces[force]
		end
		if force == nil or not force.valid then
			return
		end
		if enable == true and AllowRemoteConfig and not is_remote_enabled(force) then
			force.recipes[TurretRemote].enabled = true
			awaken_dormant_turrets(force.name)
		end
		return is_remote_enabled(force)
	end,

	reload_config = function()
		globalCall().Counter = 1
		globalCall().IdleCounter = 1
		decorate_workshop()
		sort_ammo_types()
		reload_tech()
		set_minable()
		loaded = false
		script.on_event(defines.events.on_tick, onTick)
	end
})