local _MOD = require("src/constants")
local _util = require("src/util")
local _config = require("src/gui/config/main")
local _control = require("src/gui/control/main")
local mod_prefix = _MOD.DEFINES.prefix
local globalCall = _util.globalCall

local function on_gui_click(event) --Perform GUI functions
	local element = event.element
	if element == nil or not element.valid or not _util.string_starts_with(element.name, mod_prefix) then
		return
	end
	_control:handler(event.name, event)
end

local function on_gui_checked_state_changed(event) --Perform GUI functions --TODO:
	local element = event.element
	if element == nil or not element.valid or not _util.string_starts_with(element.name, mod_prefix) then
		return
	end
	
end

local function on_pre_player_died(event) --Close GUI
	_control:handler(event.name, event)
end

local function on_player_left_game(event) --Close GUI and clear clipboard
	_control:handler(event.name, event)
end

local function on_player_selected_area(event) --Use the logistic turret remote to open the turret GUI
	_control:handler(event.name, event)
end

local function on_player_alt_selected_area(event) --Quick-paste mode
	_control:handler(event.name, event)
end

local function on_gui_selection_state_changed(event) --Perform GUI functions --TODO:
	local element = event.element
	if element == nil or not element.valid or not _util.string_starts_with(element.name, mod_prefix) then
		return
	end
	
end

local function on_player_removed(event) --Close all GUIs and clear all clipboard data
	_control:handler(event.name, event)
end

local function on_custom_input_close_gui(event) --Close GUI
	_control:handler(event.input_name, event)
end

return
{
	dispatch =
	{
		[defines.events.on_gui_click] = on_gui_click,
		[defines.events.on_gui_checked_state_changed] = on_gui_checked_state_changed,
		[defines.events.on_pre_player_died] = on_pre_player_died,
		[defines.events.on_player_left_game] = on_player_left_game,
		[defines.events.on_player_selected_area] = on_player_selected_area,
		[defines.events.on_player_alt_selected_area] = on_player_alt_selected_area,
		[defines.events.on_gui_selection_state_changed] = on_gui_selection_state_changed,
		[defines.events.on_player_removed] = on_player_removed,
		[_MOD.DEFINES.custom_input.close_gui] = on_custom_input_close_gui
	},
	config =
	{
		
	},
	control =
	{
		destroy = _control.destroy,
		interrupt = _control.interrupt
	}
}