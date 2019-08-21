local skynet = require "skynet"
local ip2region = require "ip2region"

local command = {}

function command.start(db_file)
    local result = ip2region.init(db_file)
    if not result then
        error("载入 ip 地址库错误！", db_file)
        return false
    end
end

function command.ip2region(ip)
    return ip2region.find(ip)
end

function command.ips2region(ips)
    local ret = {}
    for _,ip in ipairs(ips) do
        ret[ip] = ip2region.find(ip)
    end
    return ret
end

skynet.start(function()
    skynet.dispatch("lua", function(_,_,cmd,...)
        local f = command[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            assert(false, "error no support cmd"..cmd)
        end
    end)
end)
