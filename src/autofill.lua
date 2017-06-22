local _MOD = require("src/constants")
local _util = require("src/util")
local _logistics = require("src/logistics")
local globalCall = _util.globalCall

local function get_item_arrays(default_sets) --Get Autofill's item sets
	local item_arrays =
	{
		["ammo-bullets"] = remote.call("af", "getItemArray", "ammo-bullets"),
		["ammo-rockets"] = remote.call("af", "getItemArray", "ammo-rockets"),
		["ammo-shells"] = remote.call("af", "getItemArray", "ammo-shells"),
		["ammo-shotgun"] = remote.call("af", "getItemArray", "ammo-shotgun"),
		["ammo-artillery"] = remote.call("af", "getItemArray", "ammo-artillery"),
		["ammo-battery"] = remote.call("af", "getItemArray", "ammo-battery"),
		["ammo-dytech-capsule"] = remote.call("af", "getItemArray", "ammo-dytech-capsule"),
		["ammo-dytech-laser"] = remote.call("af", "getItemArray", "ammo-dytech-laser"),
		["ammo-dytech-laser-shotgun"] = remote.call("af", "getItemArray", "ammo-dytech-laser-shotgun"),
		["ammo-dytech-laser-tank"] = remote.call("af", "getItemArray", "ammo-dytech-laser-tank"),
		["ammo-dytech-sniper"] = remote.call("af", "getItemArray", "ammo-dytech-sniper"),
		["ammo-yi-chem"] = remote.call("af", "getItemArray", "ammo-yi-chem"),
		["ammo-yi-plasma"] = remote.call("af", "getItemArray", "ammo-yi-plasma"),
		["combat-units"] = remote.call("af", "getItemArray", "combat-units"),
		["at-artillery-mk1-shell"] = remote.call("af", "getItemArray", "at-artillery-mk1-shell"),
		["at-artillery-mk2-shell"] = remote.call("af", "getItemArray", "at-artillery-mk2-shell"),
		["gi-ammo-artillery"] = remote.call("af", "getItemArray", "gi-ammo-artillery"),
		["gi-ammo-auto45"] = remote.call("af", "getItemArray", "gi-ammo-auto45"),
		["gi-ammo-flame"] = remote.call("af", "getItemArray", "gi-ammo-flame"),
		["gi-ammo-mine"] = remote.call("af", "getItemArray", "gi-ammo-mine"),
		["gi-ammo-rocket"] = remote.call("af", "getItemArray", "gi-ammo-rocket"),
		["gi-ammo-wmd"] = remote.call("af", "getItemArray", "gi-ammo-wmd"),
		["mo-ammo-goliath"] = remote.call("af", "getItemArray", "mo-ammo-goliath"),
		["tw-ammo-belt"] = remote.call("af", "getItemArray", "tw-ammo-belt"),
		["tw-ammo-flame"] = remote.call("af", "getItemArray", "tw-ammo-flame"),
		["tw-ammo-rocket"] = remote.call("af", "getItemArray", "tw-ammo-rocket")
	}
	for _, data in pairs(default_sets) do
		for i = 1, #data do
			local set = data[i]
			if type(set) == "string" and item_arrays[set] == nil then
				item_arrays[set] = remote.call("af", "getItemArray", set)
			end
		end
	end
	return item_arrays
end

local function link_to_array(ammo, item_arrays) --Check if the ammo list matches any of Autofill's item sets
	for name, set in pairs(item_arrays) do
		for _, item in pairs(set) do
			for i = 1, #ammo do
				if ammo[i] == item then
					return {priority = 1, group = "turrets", limits = {10}, name} --Match found; Autofill will use the predefined set instead of an unordered list
				end
			end
		end
	end
	return {priority = 3, group = "turrets", limits = {10}, ammo} --No match found; Autofill will use a basic list with no particular order
end

local function set_profiles(list) --Create Autofill profiles for logistic turrets
	if remote.interfaces["af"] == nil then --Autofill not installed
		return
	end
	local default_sets = remote.call("af", "getDefaultSets")
	local turret_list = {}
	for turret in pairs(list) do
		if default_sets[turret] == nil then --Turret does not have an Autofill profile
			turret_list[turret] = _util.table_deepcopy(_logistics.get_ammo_list(turret)) --The list of ammo the turret can use
		end
	end
	if next(turret_list) ~= nil then
		local item_arrays = get_item_arrays(default_sets)
		for turret, ammo in pairs(turret_list) do
			local profile = link_to_array(ammo, item_arrays)
			remote.call("af", "addToDefaultSets", turret, profile) --Set the turret's Autofill profile
		end
	end
end

return
{
	set_profiles = set_profiles
}