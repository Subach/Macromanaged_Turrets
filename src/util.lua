local pairs = pairs
local type = type
local abs = math.abs
local floor = math.floor
local min = math.min
local sort = table.sort

local function get_player(id) --Get a player object
	if id == nil or not (type(id) == "number" or type(id) == "string") then return end
	local player = game.players[id]
	if player ~= nil and player.valid then
		return player
	end
end

local function get_player_inventory(player) --Get all of a player's inventories
	if player == nil or not player.valid then return end
	local inventories = {}
	for _, id in pairs(defines.inventory) do
		if inventories[id] == nil then
			local inventory = player.get_inventory(id)
			if inventory ~= nil and inventory.valid then
				inventories[id] = inventory
			end
		end
	end
	return inventories
end

local function globalCall(...) --Get or create a global table
	local t = global
	local keys = {...}
	for i = 1, #keys do
		local k = keys[i]
		if t[k] == nil then t[k] = {} end
		t = t[k]
	end
	return t
end

local function is_older_than(new_version, old_version) --Copied from the Reactors mod by GotLag
	local _ver = new_version:gmatch("%d+")
	for old_ver in old_version:gmatch("%d+") do
		local new_ver = _ver()
		if new_ver > old_ver then
			return true
		elseif new_ver < old_ver then
			return false
		end
	end
	return false
end

local function position_to_area(pos, radius) --Copied from the Factorio Standard Library by Afforess
	radius = radius or 0.03125
	if #pos >= 2 then
		return {left_top = {x = pos[1] - radius, y = pos[2] - radius}, right_bottom = {x = pos[1] + radius, y = pos[2] + radius}}
	else
		return {left_top = {x = pos.x - radius, y = pos.y - radius}, right_bottom = {x = pos.x + radius, y = pos.y + radius}}
	end
end

local function raise_event(id, data) --Copied from the Creative Mode mod by Mooncat
	data = data or {}
	data.name = id
	data.tick = game.tick
	game.raise_event(id, data)
end

local function save_to_global(t, ...) --Overwrite a global table without breaking references
	local g = globalCall(...)
	for k, v in pairs(t) do
		g[k] = v
	end
	for k in pairs(g) do
		if t[k] == nil then
			g[k] = nil
		end
	end
end

local sort_by = { --Sorting functions for spairs
	value = function(t, a, b) return t[a] > t[b] end,
	length = function(t, a, b) return #t[a] > #t[b] end,
	count = function(t, a, b) return t[a].count > t[b].count end }

local function sort_by_distance(t, p) --Sort an array of entities by distance from a position (standalone function; not suitable for use in table.sort or spairs)
	local function f(q)
		local x = p.x - q.x
		local y = p.y - q.y
		return ((x * x) + (y * y))^0.5
	end
	for i = 1, #t do
		local o = t[i]
		t[i] = {o = o, p = f(o.position)}
	end
	sort(t, function(a, b) return a.p > b.p end) --Sorted from farthest to nearest; iterate backward to get closest entities
	for i = 1, #t do
		t[i] = t[i].o
	end
	return t
end

local function spairs(t, f) --Copied from the Advanced Logistics System mod by anoutsider
	local keys = {}
	for k in pairs(t) do
		keys[#keys + 1] = k
	end
	if type(f) == "function" then
		sort(keys, function(a, b) return f(t, a, b) end)
	else
		sort(keys)
	end
	local i = 0
	return function()
		i = i + 1
		local k = keys[i]
		if k ~= nil then
			return k, t[k]
		end
	end
end

local function spill_stack(entity, stack) --Spill items around an entity and mark them for deconstruction
	if entity == nil or stack == nil or not (entity.valid and stack.valid_for_read) then return end
	local surface, pos, force = entity.surface, entity.position, entity.force
	local name, count = stack.name, stack.count
	surface.spill_item_stack(pos, stack, true) --Items can also be looted
	stack.clear()
	local radius = 3
	local collision = entity.prototype.collision_box or {left_top = {x = 0, y = 0}, right_bottom = {x = 0, y = 0}}
	local items = surface.find_entities_filtered{type = "item-entity", name = "item-on-ground", area = { --Note: the "limit" parameter causes issues with deconstruction when spilling multiple stacks
		left_top = {x = pos.x - abs(collision.left_top.x) - radius, y = pos.y - abs(collision.left_top.y) - radius},
		right_bottom = {x = pos.x + abs(collision.right_bottom.x) + radius, y = pos.y + abs(collision.right_bottom.y) + radius}}}
	sort_by_distance(items, pos)
	count = min(count, #items)
	for i = #items, 1, -1 do
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

local function string_starts_with(s, st) --Copied from the Factorio Standard Library by Afforess
	return (s:find(st, 1, true) == 1)
end

local function string_ends_with(s, nd) --Copied from the Factorio Standard Library by Afforess
	return ((#s >= #nd) and (s:find(nd, (#s - #nd) + 1, true) ~= nil))
end

local function string_trim(s) --Copied from the Factorio Standard Library by Afforess
	return s:gsub("^%s*(.-)%s*$", "%1")
end

local function table_compact(t, z, n) --Remove nil entries from an array
	n = n or 1 --Starting index
	local j = n - 1
	for i = n, z do
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

local function table_deepcopy(object) --Copied from Factorio\data\core\lualib\util.lua
	local lookup_table = {}
	local function _copy(_object)
		if type(_object) ~= "table" or _object.__self ~= nil then
			return _object
		elseif lookup_table[_object] ~= nil then
			return lookup_table[_object]
		end
		local new_table = {}
		lookup_table[_object] = new_table
		for key, value in pairs(_object) do
			new_table[_copy(key)] = _copy(value)
		end
		return setmetatable(new_table, getmetatable(_object))
	end
	return _copy(object)
end

return
{
	get_player = get_player,
	get_player_inventory = get_player_inventory,
	globalCall = globalCall,
	is_older_than = is_older_than,
	position_to_area = position_to_area,
	raise_event = raise_event,
	save_to_global = save_to_global,
	sort_by = sort_by,
	sort_by_distance = sort_by_distance,
	spairs = spairs,
	spill_stack = spill_stack,
	string_starts_with = string_starts_with,
	string_ends_with = string_ends_with,
	string_trim = string_trim,
	table_compact = table_compact,
	table_deepcopy = table_deepcopy
}