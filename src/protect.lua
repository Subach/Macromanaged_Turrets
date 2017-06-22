-- Protect module
--   Written by Macros (a.k.a. Subach)
--   Version 1.0.0
-- 
-- Runs a function in protected mode.
-- In the event of an error, the error message
-- will be printed to all connected players
-- instead of crashing the game.
--
-- If no player recieves the message (i.e., there
-- are no connected players), then a real error
-- will be thrown.
-- 
-- Usage: Same as the standard pcall; calls function 'f' with the given arguments
--   local protect = require("protect")
--   protect(f [, arg1, ...])
-- 

local pcall = pcall
local xpcall = xpcall

local function correct(status, ...)
	if status then
		return ...
	else
		error((...), 4)
	end
end

local function dispatch(f, ...)
	return correct(pcall(f, ...))
end

local function raise(err)
	local delivered = false
	if game ~= nil then
		local message = tostring(err)
		for _, player in pairs(game.connected_players) do
			if player.valid then
				player.print(message)
				delivered = true
			end
		end
	end
	if not delivered then
		error(err)
	end
end

local function ret(status, ...)
	if status then
		return ...
	end
end

local function protect(f, ...)
	return ret(xpcall(dispatch, raise, f, ...))
end

return protect