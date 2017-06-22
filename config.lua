local MMT = {LogisticTurrets = {}}; local LogisticTurret = MMT.LogisticTurrets -- Do not edit or remove this line

--[[--------------------------------------------------------------------------------------------[[--
  Macromanaged Turrets
----------------------------------------------------------------------------------------------------
The table below determines which types of turrets will be turned into logistic (requester) turrets. 
Any turret that uses ammo may be added to the list, even those from other mods. Turrets can be 
configured with or without a default request; turrets with a default request will request that ammo 
as soon as they are built.

To configure a turret without a default request, copy this line and paste it below:
  LogisticTurret["turret-name"] = true  -- "empty" is also a valid parameter

Alternatively, to configure a turret with a default request, copy this line and paste it below:
  LogisticTurret["turret-name"] = {ammo = "ammo-name", count = #}
--------------------------------------------------
  "turret-name" is the turret class you want to upgrade.
  "ammo-name" is the ammo you want the turret class to request by default.
  Names are found in the base game's/mod's prototype files, and must include quotation marks.

  'count' is the amount of ammo you want the turret to request. Upgraded robots may add slightly 
  more than this, due to their increased cargo size.

  These examples would turn the vanilla gun turrets into logistic turrets:
    LogisticTurret["gun-turret"] = true
    LogisticTurret["gun-turret"] = "empty"
    LogisticTurret["gun-turret"] = {ammo = "piercing-rounds-magazine", count = 10}

  The third example would cause the turrets to immediately request ten piercing rounds magazines 
  after being built.
--------------------------------------------------

You may change the request slot of turrets in-game by using the logistic turret remote. The remote 
is unlocked by researching the logistic system, and only works on turrets that have been configured 
as logistic turrets.

--]]--------------------------------Add entries below this line---------------------------------]]--







--[[--------------------------------------------------------------------------------------------[[--
  GUI settings
----------------------------------------------------------------------------------------------------
The logistic turret remote can temporarily store a turret's settings and copy them to other turrets.
By using the remote's alternate selection mode, you can quickly paste these settings onto compatible
turrets. Which turrets are compatible is determined by the 'QuickPasteMode' setting:
--------------------------------------------------
  "match-ammo-category"  -- Will paste to any turret that has the same ammo category as
                            the original (e.g., bullets)

  "match-turret-name"    -- Will only paste to turrets of the same type as the original
--------------------------------------------------

If 'QuickPasteCircuitry' is 'true', then quick-paste mode will also copy a turret's circuit network 
settings onto any turrets that match the 'QuickPasteMode' setting.

Connecting a wire to a logistic turret's circuit network interface will cause a circuit connector 
sprite to appear. Changing 'ShowCircuitConnector' to 'false' will disable the sprite graphic. This 
setting is purely cosmetic.

--]]--------------------------------------------------------------------------------------------]]--
MMT.QuickPasteMode = "match-ammo-category"
MMT.QuickPasteCircuitry = true
MMT.ShowCircuitConnector = true


--[[--------------------------------------------------------------------------------------------[[--
  Bob's Warfare
----------------------------------------------------------------------------------------------------
If Bob's Warfare is installed and 'UseBobsDefault' is 'true', Bob's turrets will be added to the 
logistic turret table with pre-configured settings.

You may change the default settings for Bob's turrets by editing 'BobsDefault'.
You may override these settings on a per-turret basis by adding the turret to the table above.

Changing 'UseBobsDefault' to 'false' will disable default logistic functionality, but any overrides 
will still apply.

--]]--------------------------------------------------------------------------------------------]]--
MMT.UseBobsDefault = true
MMT.BobsDefault = {ammo = "piercing-rounds-magazine", count = 10}


--[[--------------------------------------------------------------------------------------------[[--
  Other mods
----------------------------------------------------------------------------------------------------
Mod authors can use this mod to turn their turrets into logistic turrets, with no configuration 
necessary on the part of the user.

You may override any mod-added turret by adding it to the table as per usual, or disallow mods from 
configuring logistic turrets altogether by changing 'AllowRemoteConfig' to 'false'.

--]]--------------------------------------------------------------------------------------------]]--
MMT.AllowRemoteConfig = true


--[[--------------------------------------------------------------------------------------------[[--
  Update frequency
----------------------------------------------------------------------------------------------------
These settings controls how often the script checks each logistic turret. Intervals are measured in 
ticks; there are 60 ticks per second.

Setting 'TickInterval' to a lower number will update turrets more frequently, while setting it to a 
higher number will improve performance. The default TickInterval is 30; the minimum is 10.

If you are experiencing desyncs, setting 'TimeFactor' to a higher number may help. However, setting 
it too high may cause noticeable lag spikes. The default TimeFactor is 5; the minimum is 5; the 
maximum is (TickInterval / 2).

--]]--------------------------------------------------------------------------------------------]]--
MMT.TickInterval = 30
MMT.TimeFactor = 5


--[[--------------------------------------------------------------------------------------------[[--
  Uninstallation
----------------------------------------------------------------------------------------------------
If you no longer wish to use this mod, do not simply disable it in the mod list. To properly remove 
this mod, save and exit your game, change 'UninstallMod' to 'true', then load and re-save your game.
You will then be able to safely remove or disable this mod. Failure to do so will probably delete a 
lot of ammo from your world.

--]]--------------------------------------------------------------------------------------------]]--
MMT.UninstallMod = false


----------------------------------------------------------------------------------------------------
return MMT -- Do not edit or remove this line