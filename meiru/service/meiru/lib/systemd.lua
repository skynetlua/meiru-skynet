local skynet = require "skynet"
local memory = require "skynet.memory"
local socket = require "skynet.socket"

local _caches = {}
local function get_data(key)
    local cache = _caches[key]
    if cache then
        if os.time() <= cache.deadline then
            return cache.data
        end
        _caches[key] = nil
    end
end

local function set_data(key, data, timeout)
    local cache = {
        data = data,
        deadline = os.time()+(timeout or 3)
    }
    _caches[key] = cache
end


local weak_day_names = {"星期日","星期一","星期二","星期三","星期四","星期五","星期六"}
local function showDate(ts)
    ts = ts or os.time()
    local date = os.date("*t", ts)
    return os.date("%Y/%m/%d %X", ts)..weak_day_names[date.wday]
end


local _ip2regiond
local function get_ip2regiond()
    if not _ip2regiond then
        local list = skynet.call(".launcher", "lua", "LIST")
        for address,param in pairs(list) do
            if param:find("meiru/ip2regiond", 1, true) then
                _ip2regiond = address
            end
        end
    end
    return _ip2regiond
end

local _serverds
local function get_serverds()
    if not _serverds then
        _serverds = {}
        local list = skynet.call(".launcher", "lua", "LIST")
        for address, param in pairs(list) do
            if param:find("meiru/serverd", 1, true) then
                table.insert(_serverds, address)
            end
        end
    end
    return _serverds
end

-------------------------------------------------
-------------------------------------------------
local command = {}

function command.service_stat()
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
    local snames = {}
    for sname in pairs(infos) do
        table.insert(snames, sname)
    end
    table.sort(snames)

    local services = {}
    local service, sname
    local ok, stat, kb
    for _,sname in ipairs(snames) do
        local cmem = infos[sname]
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
    return services
end

function command.mem_stat()
    local stat = {
        total = memory.total(),
        block = memory.block()
    }
    return stat
end

function command.net_stat()
    local list = skynet.call(".launcher", "lua", "LIST")
    local netstats = socket.netstat()
    table.sort(netstats, function(a, b)
        return a.address < b.address
    end)

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
    return netstats
end

function command.client_stat()
    local ips = {}
    local clients = {}
    local ip2client = {}
    local id = 1
    local serverds = get_serverds()
    for _,serverd in ipairs(serverds) do
        local client_infos = skynet.call(serverd, "lua", "client_infos")
        for _,info in ipairs(client_infos) do
            table.insert(clients, info)
            info.slaveid = skynet.address(info.slaveid)
            info.last_visit_time = showDate(info.last_visit_time)
            info.id = id
            if info.ip then
                ip2client[info.ip] = info
                table.insert(ips, info.ip)
            end
            id = id+1
        end
    end

    local ip2regiond = get_ip2regiond()
    if ip2regiond then
        local ips2addrs = skynet.call(ip2regiond, "lua", "ips2region", ips)
        local client
        for ip,addr in pairs(ips2addrs) do
            client = ip2client[ip]
            client.address = addr
        end
    end
    return clients
end

function command.online_stat()
    local serverds = get_serverds()
    local onlines = {}
    for _,serverd in ipairs(serverds) do
        local total_times = skynet.call(serverd, "lua", "total_times")
        for minute,times in pairs(total_times) do
            onlines[minute] = (onlines[minute] or 0)+times
        end
    end
    local minutes = {}
    for minute,_ in pairs(onlines) do
        table.insert(minutes, minute)
    end
    table.sort(minutes)
    local start_idx = 1
    if #minutes > 60 then
        start_idx = #minutes-60
    end
    local rets = {}
    for i=start_idx,#minutes do
        local minute = minutes[i]
        table.insert(rets, {os.date("%x %H:%M", minute*1800), onlines[minute]})
    end
    return rets
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_,cmd,...)
        local data = get_data(cmd)
        if data then
            skynet.ret(skynet.pack(data))
            return
        end
        local f = command[cmd]
        if f then
            data = f(...)
            set_data(cmd, data)
            skynet.ret(skynet.pack(data))
        else
            assert(false, "error no support cmd"..cmd)
        end
    end)
end)
