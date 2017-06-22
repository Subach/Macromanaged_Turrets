local n, v = "Macromanaged_Turrets", "1.1.4"
local l, p = "MIT License", "MMT-"
local m, s = "Macros", "Subach"
local config = (type(require("config")) == "table") and require("config") or {}
local interval = math.max(math.floor(tonumber(config.TickInterval) or 30), 10)
local time_factor = math.max(math.min(math.floor(tonumber(config.TimeFactor) or 5), math.floor(interval / 2)), 5)
return { _NAME = n, _VERSION = v, _LICENSE = l, _AUTHOR = {name = m, alias = s},
	DEFINES =
	{
		prefix = p,
		events =
		{
			control_event = script.generate_event_name()
		},
		custom_input =
		{
			close_gui = p.."close-gui",
			select_remote = p.."select-remote"
		},
		blank_in_gui = "BIG-MMT", --GIANT ROBO-SCORPION™ not included
		circuit_mode =
		{
			off = "off",
			send_contents = "output",
			set_requests = "input"
		},
		logic_turret =
		{
			bin = p.."logistic-turret-bin",
			chest = p.."logistic-turret-chest",
			combinator = p.."logistic-turret-combinator",
			interface = p.."logistic-turret-interface",
			remote = p.."logistic-turret-remote"
		},
		quickpaste_mode =
		{
			ammo_category = "match-ammo-category",
			turret_name = "match-turret-name"
		},
		request_flag =
		{
			full = p.."request-limit-full",
			half = p.."request-limit-half",
			override = p.."request-override",
			circuitry =
			{
				input = p.."request-circuit-input",
				output = p.."request-circuit-output",
				wires =
				{
					red = p.."request-wire-red",
					green = p.."request-wire-green"
				}
			}
		},
		request_slot = {main = 1, limit = 2, mode = 3, red = 4, green = 5, override = 6},
		workshop = p.."workshop"
	},
	ACTIVE_INTERVAL = math.max(math.floor(interval / time_factor), 1),
	ACTIVE_TIMER = math.max(math.floor(900 / interval), 1),
	IDLE_INTERVAL = math.max(math.floor(interval / time_factor), 1) * 5,
	UPDATE_INTERVAL = time_factor,
	UPDATE_TICK = time_factor - 1,
	QUICKPASTE_MODE = (tostring(config.QuickPasteMode) == "match-turret-name") and tostring(config.QuickPasteMode) or "match-ammo-category",
	QUICKPASTE_BEHAVIOR = config.QuickPasteCircuitry ~= false,
	ALLOW_REMOTE_CONFIG = config.AllowRemoteConfig ~= false,
	USE_BOBS_DEFAULT = config.UseBobsDefault == true,
	BOBS_DEFAULT = config.BobsDefault or "empty",
	UNINSTALL = config.UninstallMod == true,
	LOGISTIC_TURRETS = (type(config.LogisticTurrets) == "table") and config.LogisticTurrets or {} }