
local string = string
local table = table
local os  = os

local function urlencodechar(char)
    return "%" .. ("%02X"):format(char:byte())
end
function string.urlencode(input)
    input = tostring(input):gsub("\n", "\r\n")
    input = input:gsub("([^%w%.%- ])", urlencodechar)
    return input:gsub(" ", "+")
end
function string.urldecode(input)
    input = input:gsub("+", " ")
    input = input:gsub("%%(%x%x)", function(h) return string.char(tonumber(h,16) or 0) end)
    input = input:gsub("\r\n", "\n")
    return input
end

local escape_map = {
    ['\0'] = "\\0",
    ['\b'] = "\\b",
    ['\n'] = "\\n",
    ['\r'] = "\\r",
    ['\t'] = "\\t",
    ['\26'] = "\\Z",
    ['\\'] = "\\\\",
    ["'"] = "\\'",
    ['"'] = '\\"',
}

function string.quote_sql_str(str)
    local ret = str:gsub("[\0\b\n\r\t\26\\\'\"]", escape_map)
    return ret
end

function string.ltrim(input)
    return input:gsub("^[ \t\n\r]+", "")
end

function string.rtrim(input)
    return input:gsub("[ \t\n\r]+$", "")
end

function string.trim(input)
    input = input:gsub("^[ \t\n\r]+", "")
    return input:gsub("[ \t\n\r]+$", "")
end

function string.split(input, sep)
    local retval = {}
    sep = sep and "([^"..sep.."]+)" or "([^\t]+)"
    input:gsub(sep , function(c)
        table.insert(retval, c)
    end)
    return retval
end

function table.nums(t)
    local count = 0
    for _, _ in pairs(t) do
        count = count + 1
    end
    return count
end

function table.keys(hashtable)
    local keys = {}
    for k, v in pairs(hashtable) do
        keys[#keys + 1] = k
    end
    return keys
end

function table.values(hashtable)
    local values = {}
    for k, v in pairs(hashtable) do
        values[#values + 1] = v
    end
    return values
end

function table.merge(dest, src)
    for k, v in pairs(src) do
        dest[k] = v
    end
end

function table.indexof(array, value, begin)
    for i = begin or 1, #array do
        if array[i] == value then return i end
    end
    return false
end

function table.keyof(hashtable, value)
    for k, v in pairs(hashtable) do
        if v == value then return k end
    end
    return nil
end

function table.removebyvalue(array, value, removeall)
    local c, i, max = 0, 1, #array
    while i <= max do
        if array[i] == value then
            table.remove(array, i)
            c = c + 1
            i = i - 1
            max = max - 1
            if not removeall then break end
        end
        i = i + 1
    end
    return c
end

function table.map(t, fn)
    local tmp = {}
    for k, v in pairs(t) do
        tmp[k] = fn(v, k)
    end
    return tmp
end

function table.slice(t,s,e)
    local tmp = {}
    if e >= s then
        for i=s,e do
            if t[i] then
                table.insert(tmp, t[i])
            end
        end
    else
        for i=s,e,-1 do
            if t[i] then
                table.insert(tmp, t[i])
            end
        end
    end
    return tmp
end

function table.walk(t, fn)
    for k,v in pairs(t) do
        fn(v, k)
    end
end

function table.filter(t, fn)
    local tmp = {}
    for k, v in pairs(t) do
        if fn(v, k) then 
            tmp[k] = v
        end
    end
    return tmp
end

function table.unique(t, bArray)
    local check = {}
    local n = {}
    local idx = 1
    for k, v in pairs(t) do
        if not check[v] then
            if bArray then
                n[idx] = v
                idx = idx + 1
            else
                n[k] = v
            end
            check[v] = true
        end
    end
    return n
end

function table.clone(t, meta)
    if type(t) ~= "table" then
        return t
    end
    local copy = {}
    if meta then
        setmetatable(copy, getmetatable(t))
    end
    for k, v in pairs(t) do
        copy[k] = v
    end
    return copy
end

function table.deepclone(t, meta)
    if type(t) ~= "table" then
        return t
    end
    local copy = {}
    if meta then
        setmetatable(copy, getmetatable(t))
    end
    for k, v in pairs(t) do
        if type(v) == "table" then
            copy[k] = table.deepclone(v, meta)
        else
            copy[k] = v
        end
    end
    return copy
end

-------------------------------------------
--os
--------------------------------------------
function os.gmtdate(ts)
    ts = ts or os.time()
    return os.date("!%a, %d %b %Y %X GMT", ts)
end

function os.gmttime(date)
    local day, month, year, hour, min, sec, gmt = date:match("(%d+) (%a+) (%d+) (%d+):(%d+):(%d+) (%a+)")
    local months = {Jan=1, Feb=2, Mar=3, Apr=4, May=5, Jun=6, Jul=7, Aug=8, Sep=9, Oct=10, Nov=11, Dec=12}
    local ts = os.time({year = year, month = months[month], day = day, hour = hour, min = min, sec = sec})
    if gmt:upper() == 'GMT' then
        local zonediff = os.difftime(os.time(), os.time(os.date("!*t", os.time())))
        ts = ts+zonediff
    end
    return os.time(os.date("*t",ts))
end

os.platform = ({...})[2]:match([[\]]) and 'win' or 'unix'

function os.excute_cmd(cmd)
    local file = io.popen(cmd)
    assert(file)
    local ret = file:read("*all")
    file:close()
    return ret
end

-------------------------------------------
--io
--------------------------------------------
function io.exists(path)
    local file = io.open(path, "r")
    if file then
        io.close(file)
        return true
    end
    return false
end

function io.readfile(path)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*a")
        io.close(file)
        return content
    end
    return nil
end

function io.writefile(path, content, mode)
    mode = mode or "w+b"
    local file = io.open(path, mode)
    if file then
        if file:write(content) == nil then return false end
        io.close(file)
        return true
    else
        return false
    end
end

function io.pathinfo(path)
    local pos = #path
    local extpos = pos + 1
    while pos > 0 do
        local b = path:byte(pos)
        if b == 46 then -- 46 = char "."
            extpos = pos
        elseif b == 47 then -- 47 = char "/"
            break
        end
        pos = pos - 1
    end
    local dirname = path:sub(1, pos)
    local filename = path:sub(pos + 1)
    extpos = extpos - pos
    local basename = filename:sub(1, extpos - 1)
    local extname = filename:sub(extpos)
    return {
        dirname = dirname,
        filename = filename,
        basename = basename,
        extname = extname
    }
end

function io.dirname(path)
    local pos = #path
    while pos > 0 do
        if path:byte(pos) == 47 then
            break
        end
        pos = pos - 1
    end
    return path:sub(1, pos)
end

function io.filename(path)
    local pos = #path
    while pos > 0 do
        if path:byte(pos) == 47 then
            break
        end
        pos = pos - 1
    end
    return path:sub(pos + 1)
end

function io.extname(path)
    for i=#(path),1,-1 do
         local b = path:byte(i)
         if b == 46 then -- 46 = char "."
            return path:sub(i, #path)
        elseif b == 47 then -- 47 = char "/"
            return
        end
    end
end

function io.filesize(path)
    local size = false
    local file = io.open(path, "r")
    if file then
        local current = file:seek()
        size = file:seek("end")
        file:seek("set", current)
        io.close(file)
    end
    return size
end

function io.dir(path)
    local retval
    if os.platform == "win" then
        path = string.gsub(path, "/", "\\")
        retval = os.excute_cmd("dir "..path)
        local file_list = {}
        retval = retval:split("\n")
        for _,file in ipairs(retval) do
            retval = file:split("%s")
            if #retval == 4 then
                if retval[1]:match("%d+/%d+/%d+") then
                    if retval[3] == "<DIR>" then
                        retval = {name = retval[4], isdir = true}
                    else
                        retval = {name = retval[4]}
                    end
                    table.insert(file_list, retval)
                end
            end
        end
        retval = file_list
    else
        retval = os.excute_cmd("ls -al "..path)
        retval = retval:split("\n")
        local file_list = {}
        for _,file in ipairs(retval) do
            retval = file:split("%s")
            if #retval > 4 then
                if retval[1]:byte(1) == string.byte("d") then
                    retval = {name = table.remove(retval), isdir = true}
                else
                    retval = {name = table.remove(retval)}
                end
                table.insert(file_list, retval)
            end
        end
        retval = file_list
    end
    return retval
end

-- ".+%.(%w+)$"
function io.tracedir(root, suffix, collect)
    collect = collect or {}
    local path
    for _,element in pairs(io.dir(root)) do
        if element.name ~= "." and element.name ~= ".." then
            if string.byte(root, #root) == string.byte("/") then
                path = root .. element.name
            else
                path = root .. "/" .. element.name
            end
            if element.isdir then
                io.tracedir(path, suffix, collect)
            else
                if not suffix or path:match(suffix) then
                    table.insert(collect, path)
                end
            end
        end
    end
    return collect
end

--------------------------------------------------------
--meiru clase and instance
---------------------------------------------------------
local ok, skynet = pcall(require, "skynet")
skynet = ok and skynet
local class_map = {}
local alive_map = {}

local function __tostring(...)
    local len = select('#', ...)
    if len == 0 then
        return ""
    end
    local ret = ""
    for i = 1, len do
        local arg = select(i, ...)
        local vtype = type(arg)
        if vtype == "function" then
            ret = ret .. vtype
        elseif vtype == "userdata" then
            ret = ret .. vtype
        elseif vtype == "thread" then
            ret = ret .. vtype
        elseif vtype == "table" then
            ret = ret .. vtype
        elseif vtype == "string" then
            ret = ret .. '"'..arg..'"'
        else
            ret = ret .. tostring(arg)
        end
        if i ~= len then
            ret = ret .. ", "
        end
    end
    return ret
end

function class(cname, super)
    assert(cname, "cname not nil")
    assert(not class_map[cname], "repeated define class:"..cname)
    local clazz = {}
    clazz.__cname = cname
    class_map[cname] = clazz
    clazz.__index = clazz
    if type(super) == "table" then
        setmetatable(clazz, {__index = super})
    else
        clazz.ctor = function() end
    end

    function clazz.typeof(cname)
        if clazz.__cname == cname then
            return true
        end
        local pclazz = getmetatable(clazz)
        while pclazz do
            if pclazz.__cname == cname then
                return true
            end
            local ppclazz = pclazz.__index
            if not ppclazz then
                ppclazz = getmetatable(pclazz)
            end
            if ppclazz == pclazz then
                break
            end
            pclazz = ppclazz
        end
    end
    function clazz.new(...)
        local inst = {}
        if os.mode == "dev" then
            local date_key = os.date("%x %H:%M")
            local map = alive_map[date_key]
            if not map then
                alive_map[date_key] = {}
                map = alive_map[date_key]
                setmetatable(map, {__mode = "kv"})
            end
            local info = debug.getinfo(2)

            map[inst]  = info.short_src.. ":"..info.currentline ..":" .. clazz.__cname .."(" .. (__tostring(...) or "")..")"
        end
        inst = setmetatable(inst, clazz)
        inst:ctor(...)
        return inst
    end
    return clazz
end

function instance(cname, ...)
    local clazz = class_map[cname]
    assert(clazz, "no define class:"..cname)
    local ret = clazz.new(...)
    return ret
end

function typeof(inst)
    local ltype = type(inst)
    if ltype == "table" and inst.typeof then
        return inst.__cname
    end
    return ltype
end

function include(model, parent)
    if type(parent) == "string" then
        local parts = parent:split(".")
        table.remove(parts)
        local dir_part = table.concat(parts, ".")
        if string.byte(model, 1) == string.byte(".") then
            for i=1,#model do
                if string.byte(model, i) == string.byte(".") then
                    table.remove(parts)
                else
                    dir_part = table.concat(parts, ".")
                    model = string.sub(model, i)
                    break
                end
            end
        end
        model = dir_part.."."..model
    end
    return require(model)
end

function dump_memory()
    local lua_mem1 = collectgarbage("count")
    collectgarbage("collect")
    local lua_mem2 = collectgarbage("count")
    local ret = string.format("lua已用内存:%sKB=>%sKB", lua_mem1, lua_mem2) .. "\n活跃对象实例:"
    local rets = {ret}
    for key, map in pairs(alive_map) do
        table.insert(rets, "创建时间：" .. key)
        for inst, params in pairs(map) do
            table.insert(rets, "instance:".. params) --.. (inst.__traceback or ""))
        end
    end
    return table.concat(rets, "\n")
end

-----------------------------------------------------------
--log
-----------------------------------------------------------
local function convert_val(v)
    if type(v) == "nil" then
        return "nil"
    elseif type(v) == "string" then
        return '"'.. v .. '"'
    elseif type(v) == "number" or type(v) == "boolean" then
        return tostring(v)
    else
        return tostring(v)
    end
end

local function __dump(t, depth, dups)
    if type(t) ~= "table" then 
        return convert_val(t) 
    end
    dups = dups or {}
    if dups[t] then
        return convert_val(t)
    else
        dups[t] = true
    end
    depth = (depth or 0) + 1
    if depth > 10 then
        return "..."
    else
        local retval = {}
        for k, v in pairs(t) do
            table.insert(retval, string.format("%s%s = %s,\n", string.rep("\t", depth), k, __dump(v, depth, dups)))
        end
        return "{\n"..table.concat(retval)..string.format("%s}", string.rep("\t", depth - 1))
    end
end

function log(...)
    local sid = 1
    if type(select(1, ...)) == "boolean" then
        sid = 2
    end
    local logs = {}
    for i = sid, select('#', ...) do
        local v = select(i, ...)
        if type(v) == "table" then
            table.insert(logs, __dump(v, 0))
        else
            table.insert(logs, v and tostring(v) or "nil")
        end
    end
    local output
    if sid == 2 then
        output = table.concat(logs," ") .. "\n" .. debug.traceback()
    else
        output = table.concat(logs," ")
    end
    local info = debug.getinfo(2)
    if info then
        if skynet then
            info = "[".. SERVICE_NAME.."=>"..(info.name or info.what).."]"..os.date("(%y-%m-%d %X)") 
        else
            info = "["..info.short_src.."=>"..(info.name or info.what).."]"..os.date("(%y-%m-%d %X)")
        end
    end
    if skynet then
        skynet.error(info, output)
    else
        print(info, output)
    end
end

-- function string.lua_encode(...)
--     local strs = {}
--     for i = 1, select('#', ...) do
--         local v = select(i, ...)
--         if type(v) == "table" then
--             table.insert(strs, __dump(v, 0))
--         else
--             table.insert(strs, convert_val(v))
--         end
--     end
--     return table.concat(strs," ")
-- end

-- function string.lua_decode(str)
--     local ret = load("return "..str)()
--     return ret
-- end


local function __quick_dump(t, depth)
    if type(t) ~= "table" then 
        return tostring(t) 
    end
    depth = (depth or 0) + 1
    if depth > 8 then
        return "..."
    else
        local retval = {}
        for k, v in pairs(t) do
            table.insert(retval, string.format("%s=%s", k, __quick_dump(v, depth)))
        end
        return "{"..table.concat(retval, ",").."}"
    end
end

function table.tostring(...)
    local strs = ""
    for i = 1, select('#', ...) do
        local v = select(i, ...)
        if type(v) == "table" then
            strs = strs .. __dump(v, 0)
        else
            strs = strs .. (v and tostring(v) or "nil")
        end
    end
    return strs
    -- local strs = {}
    -- for i = 1, select('#', ...) do
    --     local v = select(i, ...)
    --     if type(v) == "table" then
    --         table.insert(strs, __quick_dump(v, 0))
    --     else
    --         table.insert(strs, tostring(v))
    --     end
    -- end
    -- return table.concat(strs,", ")
end


setmetatable(_G, {
    __newindex = function(_, k)
        if k == "lfs" then
            return 
        end
        error("attempt to change undeclared variable " .. k)
    end,
    __index = function(_, k)
        if k == "skynet" then return end
        error("attempt to access undeclared variable " .. k)
    end,
})








