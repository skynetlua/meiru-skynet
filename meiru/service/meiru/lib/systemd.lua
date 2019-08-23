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
--system
-------------------------------------------------
local function excute_cmd(cmd)
    local file = io.popen(cmd)
    local ret = file:read("*all")
    return ret
end

local function get_system_info()
    local cmd = "top -bn 2 -i -c -d 0.1"        
    local output = excute_cmd(cmd)
    if type(output) ~= "string" or #output == 0 then
        return
    end
    local i, j = output:find("%s\ntop.*" )
    local ret = output:sub(i, j)
    return ret
end

local function match_num(str, patten)
    local num = str:match(patten)
    assert(num)
    num = num:match("[0-9]+%.*[0-9]*")
    num = tonumber(num)
    assert(num)
    return num
end

local function get_cpu_usage(info)
    local cpu_user = match_num(info, "[0-9]+%.?[0-9]*%sus,")
    local cpu_system = match_num(info, "[0-9]+%.?[0-9]*%ssy,")
    local cpu_nice = match_num(info, "[0-9]+%.?[0-9]*%sni,")
    local cpu_idle = match_num(info, "[0-9]+%.?[0-9]*%sid,")
    local cpu_wait = match_num(info, "[0-9]+%.?[0-9]*%swa,")
    local cpu_hardware_interrupt = match_num(info, "[0-9]+%.?[0-9]*%shi,")
    local cpu_software_interrupt = match_num(info, "[0-9]+%.?[0-9]*%ssi,")
    local cpu_steal_time = match_num(info, "[0-9]+%.?[0-9]*%sst")

    local cpu_total = cpu_user + cpu_nice + cpu_system + cpu_wait + cpu_hardware_interrupt + cpu_software_interrupt + cpu_steal_time + cpu_idle 
    local cpu_cost = cpu_user + cpu_nice + cpu_system + cpu_wait + cpu_hardware_interrupt + cpu_software_interrupt + cpu_steal_time
    local cpu_usage = cpu_cost / cpu_total
    return cpu_usage
end

local function get_mem_usage(info)
    local mem_total = match_num(info, "Mem[%d%p%s]*[0-9]+%stotal")
    local mem_used = match_num(info, "free[%d%p%s]*[0-9]+%sused")
    local mem_usage = mem_used / mem_total
    return mem_usage
end


local system_stats = {}

local function do_system_record()
    local info = get_system_info()
    local cpu_usage = get_cpu_usage(info)
    local mem_usage = get_mem_usage(info)

    local system_stat = {
        time = os.date("%x %H:%M"),
        cpu_usage = cpu_usage,
        mem_usage = mem_usage
    }
    table.insert(system_stats, system_stat)
    if #system_stats > 60 then
        table.remove(system_stats, 1)
    end

    local delta_time = 60*3
    skynet.timeout(delta_time*100, function() 
        do_system_record()
    end)
end

local function start_system_record()
    local info = get_system_info()
    if not info then
        skynet.error("很抱歉，该系统不支持命令:top -bn 2 -i -c -d 0.1")
        return
    end
    do_system_record()
end


-------------------------------------------------
-------------------------------------------------
local command = {}

function command.system_stat()
    return system_stats
end

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
    local total_records = {}
    for _,serverd in ipairs(serverds) do
        local server_records = skynet.call(serverd, "lua", "server_records")
        for minute,record in pairs(server_records) do
            local tt_record = total_records[minute]
            if not tt_record then
                tt_record = record
                total_records[minute] = tt_record
            else
                assert(tt_record.time == minute)
                tt_record.ip_times = tt_record.ip_times+record.ip_times
                tt_record.visit_times = tt_record.visit_times+record.visit_times
            end
        end
    end

    local minutes = {}
    for minute,record in pairs(total_records) do
        record.time = os.date("%x %H:%M", minute*1800)
        table.insert(minutes, minute)
    end
    table.sort(minutes)
    
    local rets = {}
    for i,v in ipairs(minutes) do
        table.insert(rets, total_records[v])
    end
    return rets
end

skynet.start(function()
    start_system_record()
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
