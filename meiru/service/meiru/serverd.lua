
local skynet = require "skynet"
local socket = require "skynet.socket"

local table  = table
local string = string

--每个IP，每秒钟，可以访问次数
local kMCountPerIpPerSecond = 30

local listen_fd 
local slaves  = {}
local balance = 1

local clientsmap = {}
local blacklists = {}

---------------------------------------------
--slave
---------------------------------------------
local function create_slaves(config)
    local instance = config.instance or 1
    for i = 1, instance do
        local slaveid = skynet.newservice("meiru/agentd", i)
        skynet.call(slaveid, "lua", "start", {config = config, master = skynet.self()})
        local slave = {
            slaveid = slaveid,
            instance = i,
            users = {},
        }
        table.insert(slaves, slave)
    end
end

local function get_slave()
    local slave = slaves[balance]
    balance = balance + 1
    if balance > #slaves then
        balance = 1
    end
    return slave
end

---------------------------------------------
--Client
---------------------------------------------
local Client = class("Client")

function Client:ctor(ip)
    self.ip = ip
    local slave = get_slave()
    self.slave = slave
    self.visit_times = 0
    self.per_times = 0
    self.time_anchor = os.time()
end

function Client:is_invalid()
    local curtime = os.time()
    if curtime == self.time_anchor then
        if self.per_times > kMCountPerIpPerSecond then
            return true
        end
        self.per_times = self.per_times+1
    else
        self.per_times = 0
    end
end

function Client:record_visit_times()
    self.visit_times = self.visit_times+1
    self.last_visit_time = os.time()
    skynet.error("Client:ip =", self.ip, "visit_times =", self.visit_times)
end

-----------------------------------------
-----------------------------------------
local function get_client(ip)
    local client = clientsmap[ip]
    if not client then
        client = Client.new(ip)
        clientsmap[ip] = client
    end
    return client
end

local function client_enter(fd, addr)
    local ip = addr:match("([^:]+)")
    if blacklists[ip] then
        return
    end
    local client = get_client(ip)
    if client:is_invalid() then
        return
    end
    client:record_visit_times()
    return client
end

---------------------------------------------------------------------------
---------------------------------------------------------------------------
local function check_services(services)
    if not services or not next(services) then
        services = {
            ['http'] = "web", 
            ['ws'] = "ws",
        }
        services.protocol = 'http'
    else
        if services['http'] or services['ws'] then
            assert(not services['https'] and not services['wss'])
            services.protocol = 'http'
        elseif services['https'] or services['wss'] then
            assert(not services['http'] and not services['ws'])
            services.protocol = 'https'
        else
            assert(false)
        end
    end
    return services
end 

local command = {}
function command.start(config)
    assert(not listen_fd)
    config.services = check_services(config.services)
    local host = config.host or "0.0.0.0"
    local port = tonumber(config.port)
    local protocol = config.services.protocol
    if not port then
        port = (protocol == 'http' and 80) or (protocol == 'https' and 443)
        assert(port, "[serverd] need port")
    end
    create_slaves(config)

    listen_fd = socket.listen(host, port)
    skynet.error(string.format("Listening %s://%s:%s", protocol, host, port))
    socket.start(listen_fd, function(fd, addr)
        local client = client_enter(fd, addr)
        if client then
            skynet.send(client.slave.slaveid, "lua", "enter", fd, addr)
        else
            socket.close(fd)
        end
    end)
end

function command.add_blacklist(ip)
    blacklists[ip] = true
end

function command.remove_blacklist(ip)
    blacklists[ip] = nil
end

function command.client_infos()
    local infos = {}
    for _,client in pairs(clientsmap) do
        infos[client.ip] = client.visit_times
    end
    return infos
end

function command.exit()
    for _, slave in pairs(slaves) do
        skynet.call(slave.slaveid, "lua", "exit")
    end
end

function command.stop()
    socket.close(listen_fd)
    listen_fd = nil
    for _, slave in pairs(slaves) do
        skynet.call(slave.slaveid, "lua", "stop")
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(_,_,cmd,...)
        local f = command[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            assert(false,"error no support cmd"..cmd)
        end
    end)
end)

