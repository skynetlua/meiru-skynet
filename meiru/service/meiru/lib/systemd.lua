local skynet = require "skynet"
local memory = require "skynet.memory"
local socket = require "skynet.socket"

local _caches = {}

-------------------------------------------------
-------------------------------------------------
local command = {}

function command.service_stat()
    local data = _caches["service_stat"]
    if data then
        if os.time() <= data.deadline then
            return data.data
        end
    end
    local list = skynet.call(".launcher", "lua", "LIST")
    local infos = {}
    local meminfo = memory.info()
    if not next(meminfo) then
        for sname,_ in pairs(list) do
            infos[sname] = 0
        end
    else
        for sid,cmem in pairs(meminfo) do
            infos[skynet.address(sid)] = cmem
        end
    end

    local services = {}
    local service, sname
    local ok, stat, kb
    for sname,cmem in pairs(infos) do
        service = {
            sname = sname,
            cmem  = cmem/1024.0,
            param = list[sname],
        }
        if service.param then
            ok, stat = pcall(skynet.call, sname, "debug", "STAT")
            if ok then
                service.mqlen   = stat.mqlen
                service.cpu     = stat.cpu
                service.message = stat.message
                service.task    = stat.task
            else
                skynet.error("error:", stat)
            end
            ok, kb = pcall(skynet.call, sname,"debug","MEM")
            if ok then
                service.lmem = kb
            else
                skynet.error("error:", kb)
            end
        end
        table.insert(services, service)
    end

    local stat = {
        services = services,
        total    = memory.total(),
        block    = memory.block()
    }
    _caches["service_stat"] = {
        data = stat,
        deadline = os.time()+3
    }
    return stat
end

function command.net_stat()
    local data = _caches["net_stat"]
    if data then
        if os.time() <= data.deadline then
            return data.data
        end
    end

    local list = skynet.call(".launcher", "lua", "LIST")
    local netstats = socket.netstat()
    for _, info in ipairs(netstats) do
        info.sname   = skynet.address(info.address)
        info.read    = info.read and info.read/1024.0
        info.write   = info.write and info.write/1024.0
        info.wbuffer = info.wbuffer and info.wbuffer/1024.0
        info.rtime   = info.rtime and info.rtime/100.0
        info.wtime   = info.wtime and info.wtime/100.0
        info.param   = list[info.sname]
        info.address = nil
    end
    _caches["net_stat"] = {
        data = netstats,
        deadline = os.time()+3
    }
    return netstats
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
