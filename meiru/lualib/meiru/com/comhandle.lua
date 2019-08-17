local Com = include("com", ...)

----------------------------------------------
--ComHandle
----------------------------------------------
local ComHandle = class("ComHandle", Com)

function ComHandle:ctor(handle)
    assert(handle)
    self.handle = handle
end

function ComHandle:match(req, res)
	return self.handle(req, res)
end

return ComHandle
