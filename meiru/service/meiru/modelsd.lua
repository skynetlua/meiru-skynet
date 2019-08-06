local skynet    = require "skynet"
local fastcache = require "meiru.lib.fastcache"
local table = table
local string = string

local Cache  = fastcache.Cache
local Loader = fastcache.Loader

local CacheConfig = {
    expire_loading = 3,
    maximum_size   = 5000,
    expire_access  = 24*3600,
}

local _mysqldbd 
local _models

skynet.init(function()
    _mysqldbd = skynet.newservice("meiru/mysqldbd")
end)


--DBLoader--------------------------------
local DBLoader = class("DBLoader", Loader)

function DBLoader:ctor(model)
    assert(model)
    self.mname = model:getMName()
    self.model = model

    self.isMultiThread = true
    self.wakeup = skynet.wakeup
    self.wait   = skynet.wait
end

function DBLoader:getValue(key, method, ...)
    local data = skynet.call(_mysqldbd, "lua", method, self.mname, ...)
    -- skynet.log("DBLoader:getValue data =", data)
    if type(data) == 'table' and #data > 0 then
        assert(#data == 1)
        return data[1]
    end
end

function DBLoader:setValue(key, value, ...)
    assert(false)
    -- redishdbdraw.hset(self.mname, key, value)
end

----------------------------------
--Model
----------------------------------
local Model = class("Model")

function Model:ctor(mname)
    self._mname = assert(mname)
    local fields = skynet.call(_mysqldbd, "lua", 'table_desc', mname)
    assert(fields, "model no fields:"..mname)
    self._fields = fields
    self._cache = Cache.new(DBLoader.new(self), CacheConfig)
end

function Model:getFields()
    return self._fields
end

function Model:getMName()
    return self._mname
end

function Model:get(key)
    assert(type(key) == 'number')
    local cond = "WHERE `id` = " .. key
    return self._cache:get(key, "select", cond)
end

function Model:gets(keys)
    local datas = {}
    local req_keys = {}
    local data
    for _,key in ipairs(keys) do
        data = self._cache:getValid(key)
        if data then
            table.insert(datas, data)
        else
            table.insert(req_keys, key)
        end
    end
    if #req_keys > 0 then
        local cond = string.format("WHERE `id` IN (%s)", table.concat(req_keys, ", "))
        local new_datas = skynet.call(_mysqldbd, "lua", "select", self._mname, cond)
        for _,new_data in ipairs(new_datas) do
            self._cache:setValid(new_data.id, new_data)
            table.insert(datas, new_data)
        end
    end
    return datas
end

function Model:update(key, ndata, cond)
    assert(type(key) == 'number')
    local data = self:get(key)
    for k,v in pairs(ndata) do
        if self._fields[k] then
            data[k] = v
        else
            ndata[k] = nil
            -- skynet.error("多余字段: k =", k, "self._mname =", self._mname)
        end
    end
    if not cond then
        cond = "WHERE `id` = " .. data.id
    end
    local retval = skynet.call(_mysqldbd, "lua", "update", self._mname, ndata, cond)
    return retval
end

function Model:updates(keys, ndata, cond)
    local retvals = {}
    for _,key in ipairs(keys) do
        local retval = self:update(key, ndata, cond)
        table.insert(retvals, retval)
    end
    return retvals
end

function Model:clear()
    self._cache:clear()
end

function Model:remove(key)
    assert(type(key) == 'number')
    self._cache:remove(key)
end

function Model:removes(keys)
    for _,key in ipairs(keys) do
        self._cache:remove(key)
    end
end

function Model:delete(key)
    assert(type(key) == 'number')
    self._cache:remove(key)
    local retval = skynet.call(_mysqldbd, "lua", "delete", self._mname, key)
    return retval
end

function Model:deletes(keys)
    for _,key in ipairs(keys) do
        self:delete(key)
    end
end

--Models--------------------------------
local Models = class("Models")
function Models:ctor()
    self._models = {}
end

function Models:getModel(mname)
    local model = self._models[mname]
    if not model then
        model = Model.new(mname)
        self._models[mname] = model
    end
    return model
end

function Models:gets(mname, keys)
    return self:getModel(mname):gets(keys)
end

function Models:get(mname, key)
    return self:getModel(mname):get(key)
end

function Models:get_fields(mname)
    return self:getModel(mname):getFields()
end

function Models:update(mname, key, data, cond)
    return self:getModel(mname):update(key, data, cond)
end

function Models:updates(mname, keys, data, cond)
    return self:getModel(mname):updates(keys, data, cond)
end

function Models:clear(mname)
    return self:getModel(mname):clear()
end

function Models:remove(mname, key)
    return self:getModel(mname):remove(key)
end

function Models:removes(mname, keys)
    return self:getModel(mname):removes(keys)
end

function Models:delete(mname, key)
    return self:getModel(mname):delete(key)
end

function Models:deletes(mname, keys)
    return self:getModel(mname):deletes(keys)
end

-----------------------------------
------------------------------------
local command = {}

function command.get(mname, key)
    local retval = _models:get(mname, key)
    return retval
end

function command.gets(mname, keys)
    local retval = _models:gets(mname, keys)
    return retval
end

function command.fields(mname)
    local retval = _models:get_fields(mname)
    return retval
end

function command.insert(mname, data, fupdate)
    local retval = skynet.call(_mysqldbd, "lua", "insert", mname, data, fupdate)
    if retval.insert_id and retval.insert_id > 0 then
        local key = retval.insert_id
        _models:remove(mname, key)
    else
        skynet.log("[modelsd]command.insert retval =", retval)
        assert(false)
    end
    return key
end

function command.update(mname, key, data, cond)
    return _models:update(mname, key, data, cond)
end

function command.updates(mname, keys, data, cond)
    return _models:updates(mname, keys, data, cond)
end

function command.clear(mname)
    return _models:clear(mname)
end

function command.remove(mname, key)
    return _models:remove(mname, key)
end

function command.removes(mname, keys)
    return _models:removes(mname, key)
end

function command.delete(mname, key)
    return _models:delete(mname, key)
end

function command.deletes(mname, keys)
    return _models:deletes(mname, keys)
end

------------------------------
------------------------------
local function init()
    assert(_models == nil)
    _models = Models.new()
end

skynet.start(function()
    init()
	skynet.dispatch("lua", function(_,_,cmd,...)
        local f = command[cmd]
        if f then
            local retval = f(...)
            skynet.ret(skynet.pack(retval)) 
        else
            assert(false, "error no support cmd"..cmd)
        end
    end)
end)
