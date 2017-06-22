local _MOD = require("src/constants")
local _util = require("src/util")
local globalCall = _util.globalCall

local function get_item_arrays() --Get Autofill's item sets
	return
	{
		remote.call("af", "getItemArray", "ammo-bullets"),
		remote.call("af", "getItemArray", "ammo-rockets"),
		remote.call("af", "getItemArray", "ammo-shells"),
		remote.call("af", "getItemArray", "ammo-shotgun"),
		remote.call("af", "getItemArray", "ammo-artillery"),
		remote.call("af", "getItemArray", "ammo-battery"),
		remote.call("af", "getItemArray", "ammo-battery"),
		remote.call("af", "getItemArray", "ammo-dytech-capsule"),
		remote.call("af", "getItemArray", "ammo-dytech-laser"),
		remote.call("af", "getItemArray", "ammo-dytech-laser-shotgun"),
		remote.call("af", "getItemArray", "ammo-dytech-laser-tank"),
		remote.call("af", "getItemArray", "ammo-dytech-sniper"),
		remote.call("af", "getItemArray", "ammo-yi-chem"),
		remote.call("af", "getItemArray", "ammo-yi-plasma"),
		remote.call("af", "getItemArray", "combat-units"),
		remote.call("af", "getItemArray", "at-artillery-mk1-shell"),
		remote.call("af", "getItemArray", "at-artillery-mk2-shell"),
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
end

local function link_to_array(ammo, lists) --Check if the requested ammo matches any of Autofill's item sets
	for _, list in pairs(lists) do
		for i, item in pairs(list) do
			if ammo == item then --Match found
				return list --Autofill will use the whole set instead of a single item
			end
		end
	end
	return ammo --No match found
end

local function set_profiles(lists) --Set Autofill profiles for new and updated turrets
	if lists == nil or remote.interfaces["af"] == nil or next(globalCall("LogicTurretConfig")) == nil then --Autofill not installed/user has not configured any logistic turrets
		return
	end
	local turret_list = {}
	for i = 1, #lists do
		for turret in pairs(lists[i]) do --Compile a list of turrets and their config settings
			local config = global.LogicTurretConfig[turret]
			if config ~= nil and config ~= "empty" then
				turret_list[turret] = config.ammo
			end
		end
	end
	if next(turret_list) ~= nil then
		local item_arrays = get_item_arrays() --Get Autofill's item sets
		for turret, ammo in pairs(turret_list) do
			ammo = link_to_array(ammo, item_arrays) --Check if the requested ammo matches any of Autofill's item sets
			remote.call("af", "addToDefaultSets", turret, {priority = 1, group = "turrets", limits = {10}, ammo}) --Set the turret's Autofill profile
		end
	end
end

return
{
	set_profiles = set_profiles
}