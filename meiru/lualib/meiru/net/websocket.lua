local skynet = require "skynet"
local crypt  = require "skynet.crypt"
local socket = require "skynet.socket"

local string = string

local MAX_FRAME_SIZE = 256 * 1024 -- max frame is 256K

local op_code = {
    ["frame"]  = 0x00,
    ["text"]   = 0x01,
    ["binary"] = 0x02,
    ["close"]  = 0x08,
    ["ping"]   = 0x09,
    ["pong"]   = 0x0A,
    [0x00]     = "frame",
    [0x01]     = "text",
    [0x02]     = "binary",
    [0x08]     = "close",
    [0x09]     = "ping",
    [0x0A]     = "pong",
}

local function read_close(payload_data)
    local code, reason
    local payload_len = #payload_data
    if payload_len > 2 then
        local fmt = string.format(">I2c%d", payload_len - 2)
        code, reason = string.unpack(fmt, payload_data)
    end
    return code, reason
end

local WebSocket = class("WebSocket")

function WebSocket:ctor(id, handle, interface)
    self.id = id
    self.handle = handle
    self.interface = interface
end

function WebSocket:try_handle(method, ...)
    local handle = self.handle
    local f = handle and handle[method]
    if f then
        f(self, ...)
    end
end

function WebSocket:__raw_write(data)
    if self.interface then
        return self.interface.write(data)
    end
    return socket.write(self.id, data)
end

function WebSocket:__raw_read(sz)
    local ret, err
    if self.interface then
        ret, err = self.interface.read(sz)
    else
        ret, err = socket.read(self.id, sz)
    end
    if ret == false then
        self.client_terminated = true
    end
    return ret, err
end

function WebSocket:read_frame()
    local s = self:__raw_read(2)
    local v1, v2 = string.unpack("I1I1", s)
    local fin  = (v1 & 0x80) ~= 0
    -- unused flag
    -- local rsv1 = (v1 & 0x40) ~= 0
    -- local rsv2 = (v1 & 0x20) ~= 0
    -- local rsv3 = (v1 & 0x10) ~= 0
    local op   =  v1 & 0x0f
    local mask = (v2 & 0x80) ~= 0
    local payload_len = (v2 & 0x7f)
    if payload_len == 126 then
        s = self:__raw_read(2)
        payload_len = string.unpack(">I2", s)
    elseif payload_len == 127 then
        s = self:__raw_read(8)
        payload_len = string.unpack(">I8", s)
    end

    if payload_len > MAX_FRAME_SIZE then
        error("payload_len is too large")
    end

    -- print(string.format("fin:%s, op:%s, mask:%s, payload_len:%s", fin, op_code[op], mask, payload_len))
    local masking_key = mask and self:__raw_read(4) or false
    local payload_data = payload_len>0 and self:__raw_read(payload_len) or ""
    payload_data = masking_key and crypt.xor_str(payload_data, masking_key) or payload_data
    return fin, assert(op_code[op]), payload_data
end

function WebSocket:write_frame(op, payload_data, masking_key)
    payload_data = payload_data or ""
    local payload_len = #payload_data
    local op_v = assert(op_code[op])
    local v1 = 0x80 | op_v -- fin is 1 with opcode
    local s
    local mask = masking_key and 0x80 or 0x00
    -- mask set to 0
    if payload_len < 126 then
        s = string.pack("I1I1", v1, mask | payload_len)
    elseif payload_len < 0xffff then
        s = string.pack("I1I1>I2", v1, mask | 126, payload_len)
    else
        s = string.pack("I1I1>I8", v1, mask | 127, payload_len)
    end
    self:__raw_write(s)
    -- write masking_key
    if masking_key then
        s = string.pack(">I4", masking_key)
        self:__raw_write(s)
        payload_data = crypt.xor_str(payload_data, s)
    end
    if payload_len > 0 then
        self:__raw_write(payload_data)
    end
end

function WebSocket:resolve_accept()
    local recv_count = 0
    local recv_buf = ""
    while true do
        if socket.invalid(self.id) then
            log("WebSocket:write 网络已关闭")
           self:try_handle("close")
            return
        end
        local fin, op, payload_data = self:read_frame()
        if op == "close" then
            local code, reason = read_close(payload_data)
            self:write_frame("close")
            self:try_handle("close", code, reason)
            break
        elseif op == "ping" then
            self:write_frame("pong")
            self:try_handle("ping")
        elseif op == "pong" then
            self:try_handle("pong")
        else
            if fin and #recv_buf == 0 then
                self:try_handle("message", payload_data)
            else
                recv_buf = recv_buf .. payload_data
                recv_count = recv_count + #payload_data
                if recv_count > MAX_FRAME_SIZE then
                    error("payload_len is too large")
                end
                if fin then
                    self:try_handle("message", recv_buf)
                    recv_buf = ""
                    recv_count = 0
                end
            end
        end
    end
end

function WebSocket:start()
    self:try_handle("open")
    socket.warning(self.id, function(id, sz)
        self:try_handle("warning", sz)
    end)
    local ok, err = xpcall(WebSocket.resolve_accept, debug.traceback, self)
    if not ok then
        if err == socket_error then
            if closed then
                self:try_handle("close")
            else
                self:try_handle("error")
            end
        else
            error(err)
        end
    end
end

-- function WebSocket:read()
--     local recv_buf
--     while true do
--         if socket.invalid(self.id) then
--             return
--         end
--         local fin, op, payload_data = self:read_frame()
--         if op == "close" then
--             self:__rawclose()
--             return false, payload_data
--         elseif op == "ping" then
--             self:write_frame("pong")
--         elseif op ~= "pong" then  -- op is frame, text binary
--             if fin and not recv_buf then
--                 return payload_data
--             else
--                 recv_buf = recv_buf or ""
--                 recv_buf = recv_buf..payload_data
--                 if fin then
--                     return recv_buf
--                 end
--             end
--         end
--     end
--     assert(false)
-- end

function WebSocket:write(data, fmt, masking_key)
    fmt = fmt or "text"
    assert(fmt == "text" or fmt == "binary")
    self:write_frame(fmt, data, masking_key)
end

function WebSocket:ping()
    self:write_frame("ping")
end

function WebSocket:close(code ,reason)
    -- local ok, err = xpcall(function()
        reason = reason or ""
        local payload_data
        if code then
            local fmt = ">I2c".. #reason
            payload_data = string.pack(fmt, code, reason)
        end
        self:write_frame("close", payload_data)
    -- end, debug.traceback)
    self:__rawclose()
    if not ok then
        skynet.error(err)
    end
end

function WebSocket:__rawclose()
    socket.close(self.id)
    if self.interface then
        if self.interface.close then
            self.interface.close()
        end
    end
end

function WebSocket.handshake(header)
    if not header["upgrade"] or header["upgrade"]:lower() ~= "websocket" then
        return 426, "Upgrade Required"
    end

    if not header["host"] then
        return 400, "host Required"
    end

    if not header["connection"] or header["connection"]:lower() ~= "upgrade" then
        return 400, "Connection must Upgrade"
    end

    local sw_key = header["sec-websocket-key"]
    if not sw_key then
        return 400, "Sec-WebSocket-Key Required"
    else
        local raw_key = crypt.base64decode(sw_key)
        if #raw_key ~= 16 then
            return 400, "Sec-WebSocket-Key invalid"
        end
    end

    if not header["sec-websocket-version"] or header["sec-websocket-version"] ~= "13" then
        return 400, "Sec-WebSocket-Version must 13"
    end

    local sw_protocol = header["sec-websocket-protocol"]
    local sub_pro = ""
    if sw_protocol then
        for sub_protocol in string.gmatch(sw_protocol, "[^%s,]+") do
            if sub_protocol == "chat" then
                sub_pro = "Sec-WebSocket-Protocol: chat\r\n"
                has_chat = true
                break
            end
        end
        if not has_chat then
            return 400, "Sec-WebSocket-Protocol need include chat"
        end
    end

    -- response handshake
    local accept = crypt.base64encode(crypt.sha1(sw_key .. "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
    local resp = "HTTP/1.1 101 Switching Protocols\r\n"..
                 "Upgrade: websocket\r\n"..
                 "Connection: Upgrade\r\n"..
    string.format("Sec-WebSocket-Accept: %s\r\n", accept)..
                  sub_pro ..
                  "\r\n"
    return nil, resp
end

return WebSocket