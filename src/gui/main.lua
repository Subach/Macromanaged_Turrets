local _gui = require("src/gui/event")

function _gui:handler(event, ...)
	return self.dispatch[event](...)
end

return _gui