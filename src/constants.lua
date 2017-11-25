local n, v = "Macromanaged_Turrets", "1.1.6"
local l, p = "MIT License", "MMT-"
local m, s = "Macros", "Subach"
local config = (type(require("config")) == "table") and require("config") or {}
local interval = settings.global[p.."tick-interval"].value
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
		blank_request = "empty",
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
			memory = p.."logistic-turret-memory"
		},
		memory_flag =
		{
			full = p.."memory-limit-full",
			half = p.."memory-limit-half",
			override = p.."memory-override",
			circuitry =
			{
				input = p.."memory-circuit-input",
				output = p.."memory-circuit-output",
				wires =
				{
					red = p.."memory-wire-red",
					green = p.."memory-wire-green"
				}
			}
		},
		memory_slot = {limit = 1, mode = 2, red = 3, green = 4, override = 5},
		quickpaste_mode =
		{
			ammo_category = "Match ammo category",
			turret_name = "Match turret name"
		},
		remote_control = p.."logistic-turret-remote"
	},
	ACTIVE_INTERVAL = interval,
	IDLE_INTERVAL = interval * 5,
	ACTIVE_TIMER = math.max(math.floor(900 / interval), 1),
	LOGISTIC_TURRETS = (type(config.LogisticTurrets) == "table") and config.LogisticTurrets or {} }