
local skynet = require "skynet"
local stm    = require "skynet.stm"
local md5   = require "md5"
local QueueMap = require "meiru.lib.queuemap"

local _filebox

---------------------------------------------
--command
---------------------------------------------
local FileBox = class("FileBox")

function FileBox:ctor()
    self.map = {}

    local queuemaps = {}
    queuemaps[1] = QueueMap(500, self.map)
    queuemaps[2] = QueueMap(100, self.map)
    queuemaps[3] = QueueMap(20, self.map)
    queuemaps[4] = QueueMap(10, self.map)
    queuemaps[5] = QueueMap(1, self.map)
    self.queuemaps = queuemaps

    self.file_md5s = {}
end

function FileBox:set_data(key, data)
    if os.mode == 'dev' then
        return
    end
    if data == false then
        self.map[key] = false
    else
        --10*1024
        if data.len < 10240 then
            self.queuemaps[1].set(key, data)
        --100*1024
        elseif data.len < 102400 then
            self.queuemaps[2].set(key, data)
        --500*1024
        elseif data.len < 51200 then
            self.queuemaps[3].set(key, data)
        --1024*1024
        elseif data.len < 1048576 then
            self.queuemaps[4].set(key, data)
        --5*1024*1024
        else
            self.queuemaps[4].set(key, data)
        end
    end
end

function FileBox:get_data(key)
    return self.map[key]
end

function FileBox:get_file_content(path)
    local data = self:get_data(path)
    if data == false then
        return
    end
    if not data then
        local content = io.readfile(path)
        if content then
            local obj = stm.new(skynet.pack(content))
            data = {
                path = path,
                obj  = obj,
                len = #content
            }
            if data.len < 5242880 then
                if os.mode ~= 'dev' then
                    self:set_data(path, data)
                end
            end
        else
            if os.mode ~= 'dev' then
                self:set_data(path, false)
                self.file_md5s[path] = false
            end
            return
        end
    end
    local copy_obj = stm.copy(data.obj)
    return copy_obj
end

function FileBox:get_file_md5(path)
    local file_md5 = self.file_md5s[path]
    if file_md5 == false then
        return
    end
    if file_md5 then
        return file_md5
    end

    local data = self:get_data(path)
    if data then
        local copy_obj = stm.copy(data.obj)
        local ref_obj = stm.newcopy(copy_obj)
        local ok, content = ref_obj(skynet.unpack)
        if ok then
            file_md5 = md5.sumhexa(content)
            self.file_md5s[path] = file_md5
            return file_md5
        end
    end
    local content = io.readfile(path)
    if content then
        file_md5 = md5.sumhexa(content)
        if os.mode ~= 'dev' then
            self.file_md5s[path] = file_md5
        end
        return file_md5
    else
        if os.mode ~= 'dev' then
            self.file_md5s[path] = false
        end
    end
end

---------------------------------------------
--command
---------------------------------------------
local command = {}

function command.file_read(path)
    return _filebox:get_file_content(path)
end

function command.file_md5(path)
    return _filebox:get_file_md5(path)
end


skynet.start(function()
    _filebox = FileBox.new()

    skynet.dispatch("lua", function(_,_,cmd,...)
        local f = command[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            assert(false,"error no support cmd"..cmd)
        end
    end)
end)


