local _MOD = require("src/constants")
local _util = require("src/util")
local request_flag = _MOD.DEFINES.request_flag
local request_slot = _MOD.DEFINES.request_slot
local globalCall = _util.globalCall
local ceil = math.ceil
local floor = math.floor
local infinity = math.huge

local function get_insert_limit(logicTurret) --Get a turret's insert limit
	local limit = logicTurret.components.chest.get_request_slot(request_slot.limit)
	if limit ~= nil then
		if limit.name == request_flag.half then
			return 0.5
		else
			return limit.count
		end
	end
	return infinity
end

local function get_request(logicTurret) --Get a turret's current request
	local request = logicTurret.components.chest.get_request_slot(request_slot.main)
	if request ~= nil then
		local limit = get_insert_limit(logicTurret)
		if limit < infinity then
			request.count = request.count + floor(limit)
		end
	end
	return request
end

local function move_ammo(source, destination, count) --Move ammo between the turret's internal components, preserving the amount of ammo in each item
	if source == nil or not source.valid_for_read then
		return
	end
	count = count or source.count
	if destination.valid_for_read then
		if destination.name == source.name then
			destination.add_ammo(source.drain_ammo(ceil(count * source.prototype.magazine_size)))
		end
	else
		destination.set_stack({name = source.name, count = 1}) --destination.set_stack({name = source.name, count = 1, ammo = 1}) --TODO: Use new SimpleItemStack in v0.15
		destination.ammo = 1
		destination.add_ammo(source.drain_ammo(ceil(count * source.prototype.magazine_size)) - 1)
	end
end

local function request_override(logicTurret, flag) --Get or change a turret's override flag
	local chest = logicTurret.components.chest
	if flag == true then
		chest.set_request_slot({name = request_flag.override, count = 1}, request_slot.override) --Set override flag
	elseif flag == false then
		chest.clear_request_slot(request_slot.override) --Remove override flag
	end
	return (chest.get_request_slot(request_slot.override) ~= nil)
end

local function set_request(logicTurret, request) --Set the chest's request slot
	local chest = logicTurret.components.chest
	local config = globalCall("LogicTurretConfig")[logicTurret.entity.name]
	if request == nil or request == "empty" then
		if config == "empty" then --New request is the same as the default
			request_override(logicTurret, false) --Remove override flag
		else
			request_override(logicTurret, true) --Set override flag
		end
		chest.clear_request_slot(request_slot.main) --Remove request flag
		chest.clear_request_slot(request_slot.limit) --Remove insert limit flag
	else
		local limit = {name = request_flag.half, count = 1} --Split single ammo item between the turret and chest
		if request.count > 1 then
			limit.name = request_flag.full
			limit.count = ceil(request.count / 2) --Split ammo between the turret and chest
		end
		if config ~= "empty" and request.ammo == config.ammo and request.count == config.count then --New request is the same as the default
			request_override(logicTurret, false) --Remove override flag
		else
			request_override(logicTurret, true) --Set override flag
		end
		chest.set_request_slot({name = request.ammo, count = math.max(request.count - limit.count, 1)}, request_slot.main) --Set request flag
		chest.set_request_slot(limit, request_slot.limit) --Set insert limit flag
	end
end
--[ --TODO: Use new SimpleItemStack in v0.15
local function player_insert_ammo(player, item) --Insert ammo into the player's inventory, preserving the amount of ammo in each item
	if player == nil or item == nil or not (player.valid and item.valid_for_read) then
		return 0
	end
	local inserted = player.insert({name = item.name, count = item.count})
	if inserted > 0 then
		local magazine_size = item.prototype.magazine_size
		if magazine_size > item.ammo then --Find the item just inserted and update its ammo count
			local found = false
			local inventories = _util.get_player_inventory(player)
			for _, inventory in pairs(inventories) do
				for i = #inventory, 1, -1 do
					local stack = inventory[i]
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
--]]
local function transfer_inventory(turret, player, ...) --Transfer a logistic turret's inventory to a player
	if turret == nil or player == nil or not (turret.valid and player.valid) then
		return
	end
	local items = {}
	local stacks = {...} --Component inventories
	local magazine = turret.get_inventory(defines.inventory.turret_ammo)
	if magazine ~= nil and magazine.valid then
		for i = 1, #stacks do
			local stack = stacks[i]
			for j = 1, #magazine do
				move_ammo(stack, magazine[j]) --Compact ammo into as few slots as possible
			end
			if stack.valid_for_read then
				items[#items + 1] = stack
			end
		end
		for i = #magazine, 2, -1 do
			local item = magazine[i]
			for j = 1, i - 1 do
				move_ammo(item, magazine[j]) --Compact ammo into as few slots as possible
			end
			if item.valid_for_read then
				items[#items + 1] = item
			end
		end
		if magazine[1].valid_for_read then
			items[#items + 1] = magazine[1]
		end
	end
	if #items > 0 then --Transfer the ammo to the player and create floating text
		local surface = turret.surface
		local pos = turret.position
		local text = {"MMT.message.player-insert", nil, nil, nil}
		local floater = {name = _MOD.DEFINES.prefix.."flying-text", position = pos, text = text, force = "neutral"}
		for _, item in _util.spairs(items, _util.sort_by.count) do
			local inserted = player_insert_ammo(player, item) --player.insert({name = item.name, count = item.count, ammo = item.ammo}) --TODO: Use new SimpleItemStack in v0.15
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

return
{
	get_insert_limit = get_insert_limit,
	get_request = get_request,
	move_ammo = move_ammo,
	request_override = request_override,
	set_request = set_request,
	transfer_inventory = transfer_inventory
}