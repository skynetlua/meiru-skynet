local skynet = require "skynet"

local string = string
local table = table

local have_mysql= skynet.getenv("mysql") and true


local _mysqldbd

if have_mysql then
    skynet.init(function()
        _mysqldbd = skynet.newservice("meiru/mysqldbd")
    end)
end

--执行
local kMDoSaveInterval = 10
--缓存时间低于给定时间，不写入数据库
local kMTmpSaveIntervel = 60*10
--最大缓存容量
local kMMaxCacheCap = 10000*50
--缓存最大时间
local kMMaxSaveIntervel = 24*3600*365*1

--Cache--------------------------------
local Cache = class("Cache")

function Cache:ctor()
    self.mname = "Cache"
    self.datas = {}

    self.from_idx = 1
    self.to_idx = 1
    self.queue = {}

    self.save_queue = {}
    self.save_map  = {}

    self:clear_time_out()
end

function Cache:run_save_timer()
    if #self.save_queue > 0 then
        local ckey = self.save_queue[1]
        local save_time = self.save_map[ckey]
        if not save_time then
            table.remove(self.save_queue, 1)
            self:run_save_timer()
            return
        end
        local cur_time  = os.time()
        if self.timer_running then
            if cur_time-save_time >= kMDoSaveInterval then
                self.timer_running = nil
            end
        end
        if not self.timer_running then
            self.timer_running = true
            local delta_time = save_time-cur_time
            if delta_time < 0 then
                delta_time = 0
            end
            skynet.timeout(delta_time*100, function()
                self.timer_running = nil
                local cur_time = os.time()
                while #self.save_queue > 0 do
                    local ckey = self.save_queue[1]
                    local save_time = self.save_map[ckey]
                    if save_time then
                        if cur_time >= save_time then
                            self.save_map[ckey] = nil
                            self:save(ckey)
                        else
                            break
                        end
                    end
                    table.remove(self.save_queue, 1)
                end
                self:run_save_timer()
            end)
        end
    end
end

function Cache:add_savequeue(ckey)
    if not self.save_map[ckey] then
        self.save_map[ckey] = os.time()+kMDoSaveInterval
        table.insert(self.save_queue, ckey)
    end
    self:run_save_timer()
end

function Cache:add_data(data)
    local ckey = data.ckey
    self.datas[ckey] = data

    self.queue[self.to_idx] = ckey
    self.to_idx = self.to_idx+1
    if self.to_idx - self.from_idx > kMMaxCacheCap then
        local ockey = self.queue[self.from_idx]
        self.queue[self.from_idx] = nil
        if ockey ~= nil and ockey ~= ckey then
            self.datas[ockey] = nil
        end
        self.from_idx = self.from_idx+1
    end
end

function Cache:set(ckey, val, timeout)
    local data = self:get_data(ckey)
    if not data then
        data = {
            ckey  = ckey,
            vdata = val,
        }
        self:add_data(data)
    else
        assert(data.ckey == ckey)
        data.vdata = val
    end
    if not timeout or timeout == 0 then
        timeout = kMMaxSaveIntervel
    end
    data.deadline = os.time()+timeout
    data.timeout = timeout
    if timeout < kMTmpSaveIntervel then
        return
    end
    if have_mysql then
        self:add_savequeue(ckey)
    end
end

function Cache:get_data(ckey)
    local data = self.datas[ckey]
    if data == false then
        return
    end
    if data then
        if os.time() >= data.deadline then
            self:remove(ckey)
            data = nil
        else
            return data
        end
    end
    if have_mysql then
        local cond = string.format("WHERE `ckey` = '%s'", ckey:quote_sql_str())
        local ret = skynet.call(_mysqldbd, "lua", "select", self.mname, cond)
        assert(#ret < 2)
        if #ret == 1 then
            data = ret[1]
            assert(data.ckey == ckey)
            self:add_data(data)
        else
            self.datas[ckey] = false
        end
    end
    return data
end

function Cache:get(ckey)
    local data = self:get_data(ckey)
    if data then
        return data.vdata, data.deadline
    end
end

function Cache:save(ckey)
    local data = self.datas[ckey]
    if data then
        local ret
        if data.id then
            local cond = string.format("WHERE `id` = %s", data.id)
            ret = skynet.call(_mysqldbd, "lua", "update", self.mname, data, cond)
        else
            ret = skynet.call(_mysqldbd, "lua", "insert", self.mname, data, "ckey")
            -- skynet.log("Cache:save ret2 =", ret)
            if ret and ret.insert_id then
                if not data.id then
                    data.id = ret.insert_id
                else
                    assert(data.id == ret.insert_id)
                end
            end
        end
        assert(ret.affected_rows == 1)
    end
end

function Cache:remove(ckey)
    assert(type(ckey) == 'string' and #ckey > 0)
    self.save_map[ckey] = nil
    local data = self.datas[ckey]
    self.datas[ckey] = false

    if have_mysql then
        local sql = string.format("DELETE FROM `%s` WHERE `ckey` = '%s'", self.mname, ckey:quote_sql_str())
        skynet.send(_mysqldbd, "lua", "query", sql)
    end

    return data
end

function Cache:clear_time_out()
    if have_mysql then
        local sql = string.format("DELETE FROM `%s` WHERE `deadline` != 0 and `deadline` < %s", self.mname, os.time())
        skynet.send(_mysqldbd, "lua", "query", sql)
    end

    local cur_time = os.time()
    local datas = self.datas
    for k,data in pairs(datas) do
        if cur_time > data.deadline then
            datas[k] = nil
        end
    end
    self:time_out()
end

function Cache:time_out()
    skynet.timeout(3600*24*100, function()
        self:clear_time_out()
    end)
end

-------------------------------------------------------
--command
-------------------------------------------------------
local _cache
local function init()
    _cache = Cache.new()
end

local command = {}

function command.get(ckey)
    assert(ckey)
    local vdata, deadline = _cache:get(ckey)
    return vdata, deadline
end

function command.remove(ckey)
    assert(ckey)
    return _cache:remove(ckey)
end

function command.set(ckey, vdata, timeout)
    assert(ckey)
    assert(type(vdata) == "string", "need vdata = skynet.packstring(vdata)")
    return _cache:set(ckey, vdata, timeout)
end

skynet.start(function()
    init()
    skynet.dispatch("lua", function(_,_,cmd,...)
        local f = command[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            assert(false, "error no support cmd"..cmd)
        end
    end)
end)

