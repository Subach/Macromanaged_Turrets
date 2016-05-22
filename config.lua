LogisticTurret = {} --Do not edit or remove this line

--[[--------------------------------------------------------------------------------------------[[--
--Macromanaged Turrets
----------------------------------------------------------------------------------------------------
The table below determines which types of turrets will be turned into logistic (requester) turrets. 
Any turret that uses ammo may be added to the list, even those from other mods. Turrets must have a 
default request; after being built, turrets will automatically request their default ammo.

To add a table entry, copy this line and paste it below:
LogisticTurret["turret-name"] = {ammo = "ammo-name", count = #}
--------------------------------------------------
	"turret-name" is the turret class you want to upgrade.
	"ammo-name" is the ammo you want that turret class to request by default.
	Names are found in the base game/mod's prototype files, and must include quotation marks.

	'count' is the amount of ammo you want the turret to request. Upgraded robots may add slightly 
	more than this, due to their increased cargo size.

	This example would cause all vanilla gun turrets to request five piercing rounds magazines:
	LogisticTurret["gun-turret"] = {ammo = "piercing-bullet-magazine", count = 5}
--------------------------------------------------
You may change the request slot of an individual turret by using the logistic turret remote in-game.
The logistic turret remote only works on turrets that have been added to the logistic turret table.

Changes to this configuration file require a game reload to take effect.

--]]--------------------------------Add entries below this line---------------------------------]]--







--[[--------------------------------------------------------------------------------------------[[--
--Update frequency
----------------------------------------------------------------------------------------------------
This setting controls how often the script checks each logistic turret. The interval is measured in 
ticks; there are 60 ticks to a second. Setting TimerInterval to a lower number will update turrets 
more frequently, while setting it to a higher number will improve performance. The default setting 
of 30 means each turret will be checked twice a second.

Logistic turrets are automatically marked as idle when certain conditions are met. Idle turrets are 
checked one-fifth as often as non-idle turrets.
--]]--------------------------------------------------------------------------------------------]]--
TimerInterval = 30

--[[--------------------------------------------------------------------------------------------[[--
--Bob's Warfare
----------------------------------------------------------------------------------------------------
If Bob's Warfare is installed and 'UseBobsDefault' is 'true', Bob's turrets will become logistic 
turrets with pre-configured request settings.

You may change the default request settings for Bob's turrets by editing 'BobsDefault'.
You may override these settings on a per-turret basis by adding the turret to the table above.

Changing 'UseBobsDefault' to 'false' will disable default logistic functionality, but any overrides 
will still apply.
--]]--------------------------------------------------------------------------------------------]]--
UseBobsDefault = true
BobsDefault = {ammo = "piercing-bullet-magazine", count = 5}

--[[--------------------------------------------------------------------------------------------[[--
--Other mods
----------------------------------------------------------------------------------------------------
Mod authors can use this mod to turn their turrets into logistic turrets, with no configuration 
necessary on the part of the user.

You may override any mod-added turret by adding it to the table as per usual, or disallow mods from 
configuring logistic turrets altogether by changing 'AllowRemoteCalls' to 'false'.
--]]--------------------------------------------------------------------------------------------]]--
AllowRemoteCalls = true