local _MOD = require("src/constants")
local _util = require("src/util")
local memory_flag = _MOD.DEFINES.memory_flag
local memory_slot = _MOD.DEFINES.memory_slot
local globalCall = _util.globalCall
local ceil = math.ceil
local floor = math.floor
local infinity = math.huge

local function get_ammo_list(turret) --Get a list of all the ammo a turret can use
	return globalCall("AmmoData", "AmmoLists")[turret]
end

local function get_ammo_category(turret) --Get a turret's ammo category
	local ammo_list = get_ammo_list(turret)
	if ammo_list ~= nil then
		return ammo_list[0] -- Turret's ammo category
	end
end

local function turret_can_request(turret, ammo) --Check if a turret can use a type of ammo
	local ammo_category = globalCall("AmmoData", "Categories")[ammo]
	if ammo_category ~= nil then
		local category = get_ammo_category(turret)
		if category ~= nil and category == ammo_category then --Turret's ammo category matches the item's ammo category
			return true
		end
	end
	return false
end

local function get_insert_limit(logicTurret) --Get a turret's insert limit
	local limit = logicTurret.components.memory.get_request_slot(memory_slot.limit)
	if limit ~= nil then
		if limit.name == memory_flag.half then
			return 0.5
		else
			return limit.count
		end
	end
	return infinity
end

local function get_request(logicTurret) --Get a turret's current request
	local request = logicTurret.components.chest.get_request_slot(1)
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
		destination.set_stack({name = source.name, count = 1, ammo = 1})
		destination.add_ammo(source.drain_ammo(ceil(count * source.prototype.magazine_size)) - 1)
	end
end

local function request_override(logicTurret, flag) --Get or change a turret's override flag
	local memory = logicTurret.components.memory
	if flag == true then
		memory.set_request_slot({name = memory_flag.override, count = 1}, memory_slot.override) --Set override flag
	elseif flag == false then
		memory.clear_request_slot(memory_slot.override) --Remove override flag
	end
	return (memory.get_request_slot(memory_slot.override) ~= nil)
end

local function set_request(logicTurret, request) --Set the chest's request slot
	local turret = logicTurret.entity.name
	local chest = logicTurret.components.chest
	local memory = logicTurret.components.memory
	local config = globalCall("LogicTurretConfig")[turret]
	if request == nil or request == _MOD.DEFINES.blank_request then
		if config == _MOD.DEFINES.blank_request then --New request is the same as the default
			request_override(logicTurret, false) --Remove override flag
		else
			request_override(logicTurret, true) --Set override flag
		end
		chest.clear_request_slot(1) --Remove request flag
		memory.clear_request_slot(memory_slot.limit) --Remove insert limit flag
	else
		local ammo = request.ammo
		if turret_can_request(turret, ammo) then
			local count = request.count
			local limit = {name = memory_flag.half, count = 1} --Split single ammo item between the turret and chest
			if count > 1 then
				limit.name = memory_flag.full
				limit.count = ceil(count / 2) --Split ammo between the turret and chest
			end
			if config ~= _MOD.DEFINES.blank_request and ammo == config.ammo and count == config.count then --New request is the same as the default
				request_override(logicTurret, false) --Remove override flag
			else
				request_override(logicTurret, true) --Set override flag
			end
			chest.set_request_slot({name = ammo, count = math.max(count - limit.count, 1)}, 1) --Set request flag
			memory.set_request_slot(limit, memory_slot.limit) --Set insert limit flag
		end
	end
end

return
{
	get_ammo_category = get_ammo_category,
	get_ammo_list = get_ammo_list,
	get_insert_limit = get_insert_limit,
	get_request = get_request,
	move_ammo = move_ammo,
	request_override = request_override,
	set_request = set_request,
	turret_can_request = turret_can_request
}