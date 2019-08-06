---------------------------------------------------------------------
---------------------------------------------------------------------
local skynet       = require "skynet"
local netpack      = require "skynet.netpack"
local socketdriver = require "skynet.socketdriver"


local buffer_pool = {}
local fds_clients = {}

local function send_package(client, data, israw)
    if client.isConnecting then
        if not client.delay_send_datas then
            client.delay_send_datas = {}
        end
        table.insert(client.delay_send_datas, {
            data  = data,
            israw = israw
        })
        return true
    end
    if not client.fd then
        return
    end
    -- if size>65535 then
    --     assert(false, "data is too big. divide it:size",size)
    -- end
    if not israw then
        local buffer, len = netpack.pack(data)
        socketdriver.send(client.fd, buffer, len)
    else
        socketdriver.send(client.fd, data, #data)
    end
    return true
end

local mtable = {}
mtable.__index = mtable

function mtable:send(data)
    return send_package(self.socket, data)
end

function mtable:rawsend(data)
    return send_package(self.socket, data, 1)
end

function mtable:packsend(data)
    skynet.error("[socketclient]==>> 【",data.cmd,"】")
    data = skynet.packstring(data)
    return self:send(data)
end

function mtable:popunpack()
    local data = self:popdata()
    if data then
        data = skynet.unpack(data)
        skynet.error("[socketclient]==<< 【",data.cmd,"】")
        return data
    end
end

function mtable:close()
    return close_connect(self.socket)
end

function mtable:pop(size)
    return socketdriver.pop(self.socket.buffer, buffer_pool, size)
end

function mtable:popdata()
    while true do
        if self.datalen then
            local data = self:pop(self.datalen)
            if not data then
                return
            end
            self.datalen = nil
            return data
        else
            local len = self:header(2)
            if not len then
                return
            end
            if len>65535 then
                return
            end
            self.datalen = len
        end
    end
end

function mtable:header(size)
    local len = self:pop(size)
    if len then
        return socketdriver.header(len)
    end
end

function mtable:clear()
    socketdriver.clear(self.socket.buffer, buffer_pool)
end

function mtable:readline(sep)
    sep = sep or "\n"
    return socketdriver.readline(self.socket.buffer, buffer_pool, sep)
end

function mtable:readall()
    return socketdriver.readall(self.socket.buffer, buffer_pool)
end


local handles = {}
--data
handles[1] = function(fd, client, data, size)
    assert(fd == client.fd)
    socketdriver.push(client.buffer, buffer_pool, data, size)
    -- local message = socketdriver.readall(client.buffer, buffer_pool)
    if client.callback then
        client.callback(client.session, "data")
    end
    -- while true do
    --     if not client.data_len then
    --         local header = socketdriver.pop(client.buffer, buffer_pool, 2)
    --         if not header then
    --             break
    --         end
    --         client.data_len = header:byte(1) * 256 + header:byte(2)
    --     else
    --         local message = socketdriver.pop(client.buffer, buffer_pool, client.data_len)
    --         if not message then
    --             break
    --         end
    --         client.data_len = nil
    --         if client.callback then
    --             client.callback(client, "data", message)
    --         end
    --     end
    -- end
end

--connect
handles[2] = function(fd, client, data, size)
    assert(fd == client.fd)
    assert(size == 0)
    client.addr = data
    assert(client.host == client.addr)

    client.buffer = socketdriver.buffer()
    client.isConnecting = nil
    client.connected = true

    if client.delay_send_datas then
        for _,data in ipairs(client.delay_send_datas) do
            send_package(client, data.data, data.israw)
        end
        client.delay_send_datas = nil
    end
    if client.callback then
        client.callback(client.session, "connect")
    end
end

--close
handles[3] = function(fd, client, data, size)
    assert(size == #data)
    if not fds_clients[fd] then
        return
    end
    if client.delay_send_datas then
        skynet.error("连接已关闭，有数据未能发送")
    end
    fds_clients[fd] = nil
    client.fd = nil
    client.buffer = nil
    if client.callback then
        client.callback(client.session, "close")
    end
end

--error
handles[5] = function(fd, client, data, size)
    -- skynet.error("error:",data)
    if client.callback then
        client.callback(client.session, "error", data)
    end
end

--warning
handles[7] = function(fd, client, data, size)
    -- skynet.error("warning:",data)
    if client.callback then
        client.callback(client.session, "warning", data)
    end
end

local MSG_TYPES = {
    SKYNET_SOCKET_TYPE_DATA = 1,
    SKYNET_SOCKET_TYPE_CONNECT = 2,
    SKYNET_SOCKET_TYPE_CLOSE = 3,
    SKYNET_SOCKET_TYPE_ACCEPT = 4,
    SKYNET_SOCKET_TYPE_ERROR = 5,
    SKYNET_SOCKET_TYPE_UDP = 6,
    SKYNET_SOCKET_TYPE_WARNING = 7
}

local MSG_NAMES = {}
for k,v in pairs(MSG_TYPES) do
    MSG_NAMES[v] = k
end

local function socket_dispatch(_, _, msg_type, fd, size, data)
    -- skynet.error("====>>socket_dispatch[",fd,"]:", MSG_NAMES[msg_type])
    local client = fds_clients[fd]
    if not client then
        if msg_type == 1 then
            socketdriver.drop(data, size)
        end
        return
    end
    assert(client.fd == fd)
    assert(handles[msg_type])
    client.queue_run(handles[msg_type], fd, client, data, size)
    -- skynet.error("====<<socket_dispatch[",fd,"]:", MSG_NAMES[msg_type])
    -- skynet.log("检查fds_clients= ",fds_clients)
end

skynet.register_protocol {
    name = "socket",
    id = skynet.PTYPE_SOCKET,
    unpack = socketdriver.unpack,
    dispatch = socket_dispatch
}

local function create_queue()
    local cur_thread = nil
    local thread_queue = {}
    local function xpcall_ret(ok, ...)
        cur_thread = nil
        if thread_queue[1] then
            cur_thread = table.remove(thread_queue, 1)
            skynet.wakeup(cur_thread)
        end
        assert(ok, (...))
        return ...
    end
    return function(f, ...)
        local thread = coroutine.running()
        if cur_thread then
            table.insert(thread_queue, thread)
            skynet.wait(thread)
        end
        cur_thread = thread
        return xpcall_ret(xpcall(f, debug.traceback, ...))
    end
end

local function close_connect(client)
    if not client then
        return
    end
    local fd = client.fd
    local client = fds_clients[fd]
    if client then
        if not client.manual_close then
            client.manual_close = true
            socketdriver.close(fd)
        end
        if not client.connected then
            fds_clients[fd] = nil
        end
    end
end

local function do_connect_server(client)
    client.isConnecting = true
    local fd = assert(socketdriver.connect(client.host, client.port))
    assert(fds_clients[fd] == nil)
    client.fd = fd
    fds_clients[fd] = client
end




local function create_client(host, port)
    local client = {
        host = host,
        port = port,
        queue_run = create_queue(),
    }
    client.session = {socket=client}
    setmetatable(client.session, mtable)
    return client
end

local function find_client(host, port)
    for _,client in pairs(fds_clients) do
        if client.host == host and client.port == port then
            return client
        end
    end
end

local function connect_server(host, port, callback)
    -- skynet.hooktrace(excludes, excludevals)
    local client = create_client(host, port)
    do_connect_server(client)
    client.callback = callback
    return client.session

    -- local client = find_client(host, port)
    -- if client and client.host == host and client.port == port then
    --     if client.fd then
    --         return
    --     end
    --     client.isConnecting = nil
    -- else
    --     close_connect(client)
    --     client = create_client(host, port)
    -- end
    -- assert(client.fd == nil)
    -- if not client.isConnecting then
    --     client.isConnecting = true
    --     do_connect_server(client)
    -- end
    -- client.callback = callback
    -- return client.session
end


local function connect_server_only(host, port, callback)
    -- skynet.hooktrace(excludes, excludevals)
    local client = find_client(host, port)
    if client and client.host == host and client.port == port then
        if client.fd then
            return
        end
        client.isConnecting = nil
    else
        close_connect(client)
        client = create_client(host, port)
    end
    assert(client.fd == nil)
    if not client.isConnecting then
        client.isConnecting = true
        do_connect_server(client)
    end
    if callback then
        client.callback = callback
    end
    return client.session
end

return connect_server

