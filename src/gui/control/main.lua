local _control = require("src/gui/control/event")

function _control:handler(event, ...)
	return self.dispatch[event](...)
end

return _control