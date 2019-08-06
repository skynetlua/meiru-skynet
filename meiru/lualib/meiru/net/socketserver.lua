---------------------------------------------------------------------
---------------------------------------------------------------------
local skynet       = require "skynet"
local netpack      = require "skynet.netpack"
local socketdriver = require "skynet.socketdriver"


local buffer_pool = {}
local fds_servers = {}
local fds_clients = {}

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

local function send_package(socket, data)
    local fd = socket.fd
    if not fd or not fds_clients[fd] then
        skynet.error("客户端已断网，推送消息失败")
        return
    end
    -- local len = #data
    -- if len>65535 then
    --     assert(false, "data is too big. divide it")
    -- end
    local buffer, len = netpack.pack(data)
    socketdriver.send(fd, buffer, len)
    return true
end

local mtable = {}
mtable.__index = mtable

function mtable:send(...)
    return send_package(self.socket, ...)
end

function mtable:pop(size)
    return socketdriver.pop(self.socket.buffer, buffer_pool, size)
end

function mtable:packsend(data)
    skynet.error("[socketserver]==>> 【",data.cmd,"】")
    data = skynet.packstring(data)
    return self:send(data)
end

function mtable:popunpack()
    local data = self:popdata()
    if data then
        data = skynet.unpack(data)
        skynet.error("[socketserver]==<< 【",data.cmd,"】")
        return data
    end
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

function mtable:start()
    local fd = self.socket.fd
    local client = fds_clients[fd]
    if not client then
        skynet.error("客户端已关闭,无法启动接收数据 fd =",fd,"addr =",client.addr)
        socketdriver.close(fd)
        return
    end
    if self.socket ~= client then
        skynet.error("参数出错,client不一致 fd =",fd)
        skynet.error("client.addr =",client.addr)
        skynet.error("self.socket.addr =",self.socket.addr)
        socketdriver.close(fd)
        socketdriver.close(client.fd)
        return
    end
    if client.fd ~= fd then
        skynet.error("参数出错,client不一致 fd =",fd)
        skynet.error("client.fd =",client.fd)
        skynet.error("client.addr =",client.addr)
        socketdriver.close(fd)
        socketdriver.close(client.fd)
        return
    end
    -- skynet.error("启动客户端addr：", self.socket.addr)
    return socketdriver.start(fd)
end

function mtable:close()
    local fd = self.socket.fd
    local client = fds_clients[fd]
    if not client then
        socketdriver.close(fd)
        skynet.error("客户端已关闭,无需再关闭 fd =",fd,"addr =",client.addr)
        return
    end
    if self.socket ~= client then
        skynet.error("参数出错,client不一致 fd =",fd)
        skynet.error("client.addr =",client.addr)
        skynet.error("self.socket.addr =",self.socket.addr)
        socketdriver.close(fd)
        socketdriver.close(client.fd)
        return
    end

    if client.fd ~= fd then
        skynet.error("参数出错,client不一致 fd =",fd)
        skynet.error("client.fd =",client.fd)
        skynet.error("client.addr =",client.addr)
        socketdriver.close(fd)
        socketdriver.close(client.fd)
        return
    end
    skynet.error("启动客户端addr：", self.socket.addr)
    return socketdriver.close(fd)
end

local function create_client(serverfd, fd, addr)
    local client = {
        serverfd = serverfd,
        fd = fd,
        addr = addr,
        queue_run = create_queue(),
    }
    client.session = {socket=client}
    setmetatable(client.session, mtable)
    return client
end


local handles = {}
--data
handles[1] = function(fd, socket, data, size)
    assert(socket.buffer)
    socketdriver.push(socket.buffer, buffer_pool, data, size)
    -- local message = socketdriver.readall(socket.buffer, buffer_pool)
    if socket.callback then
        socket.callback(socket.session, "data", fd)
    end
end

--connect
handles[2] = function(fd, socket, data, size)
    assert(data == "start")
    if socket.serverfd then
        socket.buffer = socketdriver.buffer()
        local server = fds_servers[socket.serverfd]
        socket.callback = server.callback
        if socket.callback then
            socket.callback(socket.session, "start", fd)
        end
    else
        if socket.callback then
            socket.callback(socket.session, "listen", fd)
        end
    end
end

--close
handles[3] = function(fd, socket, data, size)
    fds_clients[fd] = nil
    local server = fds_servers[socket.serverfd]
    if server then
       local addr = server.clientfds[fd]
       server.clientfds[fd] = nil
        server.clientfds[addr] = nil
    end
    socket.buffer = nil
    if socket.callback then
        socket.callback(socket.session, "close")
        socket.callback = nil
    end
end

--accept
handles[4] = function(fd, server, data, size)
    local serverfd = fd
    assert(serverfd == server.fd)
    local addr = data
    local fd = size

    local oldfd = server.clientfds[addr]
    if oldfd then
        fds_clients[oldfd] = nil
        server.clientfds[oldfd] = nil
        skynet.error("旧连接未断开:oldfd=",oldfd,"addr=",addr)
    end
    server.clientfds[addr] = fd
    server.clientfds[fd] = addr

    local client = create_client(serverfd, fd, addr)
    fds_clients[fd] = client

    if server.callback then
        server.callback(client.session, "accept", fd, addr)
    end
end

--error
handles[5] = function(fd, socket, data, size)
    skynet.error("error:",data)
    if socket.callback then
        socket.callback(socket.session, "error", data)
    end
end

--warning
handles[7] = function(fd, socket, data, size)
    skynet.error("warning:",data)
    if socket.callback then
        socket.callback(socket.session, "warning", data)
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
    -- skynet.error("====>>socket_dispatch[",fd,"]:",MSG_NAMES[msg_type])
    local socket = fds_servers[fd]
    if not socket then
       socket = fds_clients[fd]
        if not socket then
            skynet.error("not socket")
            if msg_type == 1 then
                socketdriver.drop(data, size)
            end
            return
        end
    end

    assert(socket.fd == fd)
    assert(handles[msg_type])
    socket.queue_run(handles[msg_type], fd, socket, data, size)
    -- skynet.error("====<<socket_dispatch[",fd,"]:",MSG_NAMES[msg_type])
    -- skynet.log("检查 fds_clients = ",fds_clients)
    -- skynet.log("检查 fds_servers = ",fds_servers)
end

skynet.register_protocol {
    name = "socket",
    id = skynet.PTYPE_SOCKET,
    unpack = socketdriver.unpack,
    dispatch = socket_dispatch
}



local function close_listen(server)
    if not server then
        return
    end
    local fd = server.fd
    socketdriver.close(fd)
    for fd,_ in pairs(server.clientfds) do
        socketdriver.close(fd)
    end
    local server = fds_servers[fd]
    if server then
        fds_servers[fd] = nil
    end
end

function mtable:close_listen(...)
    return close_listen(self.socket, ...)
end

local function create_server(host, port)
    local server = {
        host = host,
        port = port,
        clientfds = {},
        queue_run = create_queue(),
    }
    -- setmetatable(server, mtable)
    server.session = {socket=server}
    -- setmetatable(server.session, mtable)
    return server
end

local function find_server(host, port)
    for _,server in pairs(fds_servers) do
        if server.host == host and server.port == port then
            return server
        end
    end
end

local function listen_server(config, callback)
    -- skynet.hooktrace(excludes, excludevals)
    local host = config.host
    local port = config.port
    local backlog = config.backlog
    local server = find_server(host, port)
    if server and server.host == host and server.port == port then
        if server.fd then
            server.maxclient = maxclient
            return
        end
    else
        close_listen(server)
        server = create_server(host, port)
    end
    server.maxclient = config.maxclient
    server.nodelay = config.nodelay
    server.callback = callback
    assert(server.fd == nil)
    server.fd = assert(socketdriver.listen(host, port, backlog))
    socketdriver.start(server.fd)
    fds_servers[server.fd] = server
    skynet.error(string.format("Listen on %s:%d", host, port))
    return server.session
end


return listen_server


