local Com = include("com", ...)

local ComHandle = class("ComHandle", Com)

function ComHandle:ctor(handle)
    assert(handle)
    self.handle = handle
end

function ComHandle:match(req, res)
	return self.handle(req, res)
end

return ComHandle
