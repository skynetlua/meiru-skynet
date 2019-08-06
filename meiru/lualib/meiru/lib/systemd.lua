local skynet = require "skynet"

local _systemd

local thread_queue = {}

skynet.fork(function()
    _systemd = skynet.uniqueservice("meiru/lib/systemd")
    for _,thread in ipairs(thread_queue) do
        skynet.wakeup(thread)
    end
    thread_queue = nil
end)


local systemd = {}

setmetatable(systemd, {__index = function(t, cmd)
	if not _systemd then
		local thread = coroutine.running()
        table.insert(thread_queue, thread)
        skynet.wait(thread)
	end
    local f = function(...)
    	return skynet.call(_systemd, "lua", cmd, ...)
    end
    t[cmd] = f
    return f
end})


return systemd 