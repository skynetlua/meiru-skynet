
local skynet = require "skynet"
local socket = require "skynet.socket"

local table  = table
local string = string


local listen_fd 
local slaves  = {}
local balance = 1

local usersmap   = {}
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
--User
---------------------------------------------
local User = class("User")

function User:ctor(ip)
    self.ip = ip
    local slave = get_slave()
    self.slave = slave
    self.visit_times = 0
    self.per_times = 0
    self.time_anchor = os.time()
end

function User:is_invalid()
    local curtime = os.time()
    if curtime == self.time_anchor then
        if self.per_times > 30 then
            return true
        end
        self.per_times = self.per_times+1
    else
        self.per_times = 0
    end
    self.visit_times = self.visit_times+1
    self.last_visit_time = curtime
    skynet.error("ip =", self.ip, "visit_times =", self.visit_times)
end

-----------------------------------------
-----------------------------------------
local function get_user(ip)
    local user = usersmap[ip]
    if not user then
        user = User.new(ip)
        usersmap[ip] = user
    end
    return user
end

local function user_enter(fd, addr)
    local ip = addr:match("([^:]+)")
    if blacklists[ip] then
        return
    end
    local user = get_user(ip)
    if user:is_invalid() then
        return
    end
    -- user:record_visit_times()
    return user
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
        local user = user_enter(fd, addr)
        if user then
            skynet.send(user.slave.slaveid, "lua", "enter", fd, addr)
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

function command.user_infos()
    local infos = {}
    for _,user in pairs(usersmap) do
        infos[user.ip] = user.visit_times
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

