local skynet     = require "skynet"
local Websocket  = require "meiru.net.websocket"
local Modeler    = require "meiru.role.modeler"
local Moduler    = require "meiru.role.moduler"
local Dispatcher = require "meiru.role.dispatcher"
local Coder      = require "meiru.role.coder"

Coder = Coder("json")
local string = string
local table = table

---------------------------------------------------
--User
---------------------------------------------------
local User = class("User")

function User:ctor(ws, req, res)
    self.req = req
    self.dispatcher = Dispatcher.new(self)
    self.modeler = Modeler.new(self)
    self.ws = ws
end

function User:start(moduler)
    self.dispatcher:add_modules(moduler:get_modules())
    self.ws:start()
end

function User:send(name, proto, errno)
    --main thread
    skynet.fork(function(name, proto, errno)
        assert(type(name) == "string", "User:send name must be string")
        assert(#name<256, "User:send name string too more")
        local data = string.char(errno or 0)..string.char(#name)..name
        if proto then
            data = data..Coder.encode(proto)
        end
        self.ws:write(data)
    end, name, proto, errno)
end

function User:dispatch(data)
    --main thread
    skynet.fork(function(data)
        if #data == 0 then
            return
        end
        local len = data:byte(2)
        local pos = len+2
        if pos <= #data then
            local name = data:sub(3, pos)
            local proto
            if pos < #data then
                proto = Coder.decode(data:sub(pos + 1))
            end
            log("User:dispatch name=", name, "proto =", proto)
            self.dispatcher:request(name, proto or {})
        else
            log("User:dispatch illegal data package!!!")
        end
    end, data)
end

function User:command(...)
    self.dispatcher:command(...)
end

function User:request(name, proto)
    self.dispatcher:request(name, proto)
end

function User:trigger(name, data)
    self.dispatcher:trigger(name, data)
end

-----------------------------------------
--handle
----------------------------------------
local handle = {}

function handle.open(ws)
    ws.user:command("network_open")
end

function handle.message(ws, msg)
    ws.user:command("network_message", msg)
    ws.user:dispatch(msg)
end

function handle.ping(ws)
    ws.user:command("network_ping")
end

function handle.pong(ws)
    ws.user:command("network_pong")
end

function handle.close(ws, code, reason)
    ws.user:command("network_close", code, reason)
end

function handle.error(ws, msg)
    ws.user:command("network_error", msg)
end

function handle.warning(ws, msg)
    ws.user:command("network_warning", msg)
end

---------------------------------------------------
--UserBox
---------------------------------------------------

local UserBox = class("UserBox")

function UserBox:ctor()
    self.users = {}

    self.moduler = Moduler.new()
    local module_path = skynet.getenv("module_path")
    local file_paths = io.tracedir(module_path, "%.lua$")
    for _,file_path in ipairs(file_paths) do
        local mname = file_path:match(".*lualib/(.+)%.lua$")
        mname = string.gsub(mname, "/", ".")
        local _module = require(mname)
        log("UserBox file_path =", file_path)
        self.moduler:add_module(mname, _module)
    end
end

function UserBox:enter(req, res)
    local fd = req.fd
    local ws = Websocket.new(fd, handle, res.interface)
    local user = User.new(ws, req)
    ws.user = user
    self.users[fd] = user
    user:start(self.moduler)
    self.users[fd] = nil
    log("UserBox:enter user exit fd =", fd)
end

---------------------------------------------------
--params
---------------------------------------------------
local user_box = UserBox.new()
---------------------------------------------------
--ws
---------------------------------------------------
local ws = {}

function ws.dispatch(req, res)
    local code, resp = Websocket.handshake(req.headers)
    if code then
        res.response(code, resp)
    else
        res.interface.write(resp)
        user_box:enter(req, res)
        return true
    end
end

return ws
