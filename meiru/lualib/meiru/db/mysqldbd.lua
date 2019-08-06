local skynet = require "skynet"


local _mysqldbd
skynet.fork(function()
    _mysqldbd = skynet.uniqueservice("meiru/mysqldbd")
end)


local mysqldb = {}

setmetatable(mysqldb, { __index = function(t,cmd)
    local f = function(...)
    	return skynet.call(_mysqldbd, "lua", cmd, ...)
    end
    t[cmd] = f
    return f
end})


return mysqldb 