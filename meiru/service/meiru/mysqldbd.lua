local skynet = require "skynet"
local mysql  = require "skynet.db.mysql"
local cjson  = require "cjson"

local assert = assert
local string = string
local table = table

local mysql_config = load(string.format("return %s", skynet.getenv("mysql")))()

local db_config = {
    host = mysql_config.host,
    port = mysql_config.port,
    user = mysql_config.username,
    password = mysql_config.password,
    database = mysql_config.database
}

local db 
local table_descs

local ValueType = {
    integer = 1,
    varchar = 2,
    blob    = 3,
    text    = 4
}

local function decode_value(field_info, value)
    local vtype = field_info.vtype
    if vtype == ValueType.integer then
        return value
    elseif vtype == ValueType.varchar or vtype == ValueType.text then
        return value
    elseif vtype == ValueType.blob then
        if type(value) == "string" and #value > 0 then
            value = skynet.unpack(value)
            return value
        else
            return value
        end
    else
        skynet.log("decode_value field_info =", field_info, "value =", value)
        assert(false)
    end
end

local function encode_value(field_info, value)
    local vtype = field_info.vtype
    if vtype == ValueType.integer then
        if type(value) == "number" then
            if value >= 0 and value <= field_info.vlimit then
                return value
            end
        else
            skynet.log("encode_value value =", value)
            skynet.log("encode_value field_info =", field_info)
            skynet.error("[mysqldbd]WARN: value must be number")
            assert(false)
        end
    elseif vtype == ValueType.varchar then
        if type(value) == "string" then
            -- value = dataEncode(value)
            value = string.quote_sql_str(value)
            if utf8.len(value) > field_info.vlimit then
                skynet.error("[mysqldbd]WARN: string length is too many")
                skynet.error("[mysqldbd]WARN: value =", value)
                skynet.log("[mysqldbd]WARN: field_info =", field_info)
                assert(false)
            end
            return value
        else
            skynet.log("encode_value value =", value)
            skynet.log("encode_value field_info =", field_info)
            skynet.error("[mysqldbd]WARN: value must be string")
            assert(false)
        end
    elseif vtype == ValueType.text then
        if type(value) == "string" then
            -- return dataEncode(value)
            return string.quote_sql_str(value)
        else
            skynet.log("encode_value value =", value)
            skynet.log("encode_value field_info =", field_info)
            skynet.error("[mysqldbd]WARN: value must be string")
            assert(false)
        end
    elseif vtype == ValueType.blob then
        value = skynet.packstring(value)
        -- value = dataEncode(value)
        return string.quote_sql_str(value)
        -- return value
    else
        skynet.log("encode_value value =", value)
        skynet.log("encode_value field_info =", field_info)
        skynet.error("[mysqldbd]WARN:  no support type")
        assert(false)
    end
    skynet.log("encode_value value =", value)
    skynet.log("encode_value field_info =", field_info)
    assert(false)
end

------------------------------------------------
------------------------------------------------
local command = {}

function command.select(tblname, cond, ...)
    local table_desc = table_descs[tblname]
    assert(table_desc, "tblname:"..tblname)
    assert(type(cond) == 'string' and #cond>0)
    local fields
    local len = select('#', ...)
    if len == 0 then
        fields = "*"
    else
        local arg
        fields = ""
        for i = 1, len do
            arg = select(i, ...)
            if type(arg) == 'string' and #arg > 0 then
                fields = fields .. "`"..arg .. "`,"
            else
                assert(false)
            end
        end
        fields = fields:sub(1, -2)
    end
    local sql = string.format("SELECT %s FROM `%s` %s;", fields, tblname, cond)
    -- skynet.error("[mysqldbd]command.select sql:",sql)
    local retval = db:query(sql)
    if retval.errno then
        skynet.error("[MYSQLDBD]select sql:",sql)
        skynet.error("[MYSQLDBD]发生错误 errno:",retval.errno,",err:",retval.err)
        assert(false)
    else
        if #retval>0 then
            local field_info
            for _,data in ipairs(retval) do
                for key, value in pairs(data) do
                    field_info = table_desc[key]
                    data[key] = decode_value(field_info, value)
                end
            end
        end
    end
    return retval
end

function command.rawselect(...)
    local retval = command.select(...)
    if #retval>0 then
        for idx,data in ipairs(retval) do
            retval[idx] = skynet.packstring(data)
        end
    end
    return retval
end

function command.jsonselect(...)
    local retval = command.select(...)
    if #retval>0 then
        for idx,data in ipairs(retval) do
            retval[idx] = cjson.encode(data)
        end
    end
    return retval
end

function command.update(tblname, data, cond)
    assert(cond and #cond>0)
    local table_desc = table_descs[tblname]
    assert(table_desc, "tblname:"..tblname)
    assert(not data['key'], "marailDB keyword cause error")

    local field_info
    local tblkv = ""
    for key, value in pairs(data) do
        field_info = table_desc[key]
        if field_info then
            value = encode_value(field_info, value)
            if field_info.vtype == ValueType.integer then
                tblkv = tblkv .."`"..key.."`="..value..","
            else
                tblkv = tblkv .."`"..key.."`='"..value.."',"
            end
        end
    end
    tblkv = tblkv:sub(1, -2)
    local sql = string.format("UPDATE `%s` SET %s %s;", tblname, tblkv, cond)
    -- skynet.error("[mysqldbd]command.update sql:",sql)
    local retval = db:query(sql)
    if retval.errno then
        skynet.error("[MYSQLDBD]update sql:",sql)
        skynet.error("[MYSQLDBD]发生错误 errno:",retval.errno,",err:",retval.err)
    end
    return retval
end

function command.insert(tblname, data, fupdate)
    local table_desc = table_descs[tblname]
    assert(table_desc, "tblname:"..tblname)
    assert(not data['key'], "marailDB keyword cause error")
    local tblkey = ""
    local tblvalue = ""
    local field_info
    for key, value in pairs(data) do
        field_info = table_desc[key]
        if field_info then
            tblkey = tblkey .."`"..key.. "`,"
            value = encode_value(field_info, value)
            if field_info.vtype == ValueType.integer then
                tblvalue = tblvalue .. value.. ","
            else
                tblvalue = tblvalue .. "'"..value.. "',"
            end
        end
    end
    tblkey = tblkey:sub(1, -2)
    tblvalue = tblvalue:sub(1, -2)
    local sql = string.format("INSERT INTO `%s`(%s) VALUES(%s);", tblname, tblkey, tblvalue)
    -- skynet.error("[mysqldbd]command.insert sql:",sql)
    local retval = db:query(sql)
    if retval.errno then
        skynet.error("[MYSQLDBD]insert sql:",sql)
        skynet.error("[MYSQLDBD]发生错误 errno:",retval.errno,",err:",retval.err)
        if retval.errno == 1062 and fupdate and table_desc[fupdate] then
            skynet.error("[MYSQLDBD]改为update 数据")
            local key = fupdate
            local field_info = table_desc[key]
            local value = data[key]
            value = encode_value(field_info, value)
            local cond
            if field_info.vtype == ValueType.integer then
                cond = "WHERE `".. key.. "`=".. value
            else
                cond = "WHERE `".. key.. "`='".. value.. "'"
            end
            return command.update(tblname, data, cond)
        end
    end
    return retval
end

function command.delete(tblname, id)
    local sql = string.format("DELETE FROM `%s` WHERE `id` = %s;",tblname, id)
    local retval = db:query(sql)
    -- skynet.error("[mysqldbd]command.delete sql:",sql)    
    if retval.errno then
        skynet.error("[MYSQLDBD]insert sql:",sql)
        skynet.error("[MYSQLDBD]发生错误 errno:",retval.errno,",err:",retval.err)
    end
    return retval
end

function command.distinct(tblname, field)
    local sql = string.format("SELECT DISTINCT %s FROM %s;", field, tblname)
    local retval = db:query(sql)
    if retval.errno then
        skynet.error("[MYSQL]select sql:",sql)
        skynet.error("[MYSQL]发生错误 errno:",retval.errno,",err:",retval.err)
    else
        if #retval>0 then
            local table_desc = table_descs[tblname]
            assert(table_desc, "tblname:"..tblname)
            local field_info
            local values = {}
            for _,data in ipairs(retval) do
                for key, value in pairs(data) do
                    field_info = table_desc[key]
                    value = decode_value(field_info, value)
                    table.insert(values, value)
                end
            end
            return values
        end
    end
    return retval
end

function command.table_desc(tblname)
    return table_descs[tblname]
end

function command.query(sql)
    -- skynet.error("[mysqldbd]command.query sql:", sql)
    local retval = db:query(sql)
    if retval.errno then
        skynet.error("[MYSQLDBD]query sql:",sql)
        skynet.error("[MYSQLDBD]发生错误 errno:",retval.errno,",err:",retval.err)
        assert(false)
    end
    return retval
end

local function dbquery(db, sql)
    local retval = db:query(sql)
    if retval.errno then
        skynet.error("[MYSQLDBD]dbquery sql:",sql)
        skynet.error("[MYSQLDBD]发生错误 errno:",retval.errno,",err:",retval.err)
        assert(false)
    end
    return retval
end

local function get_all_tablenames(db, db_name)
    local sql = string.format("SELECT table_name FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='%s';",db_name)
    local retval = dbquery(db, sql)
    return retval
end

local function is_exist_table(db, db_name, table_name)
    local sql = string.format("SELECT table_name FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='%s' AND TABLE_NAME='%s';",db_name,table_name)
    local retval = dbquery(db, sql)
    return #retval>0
end

local function load_desc_tables(db, db_name)
    local tableNames = get_all_tablenames(db, db_name)
    table_descs = {}
    for _,v in pairs(tableNames) do
        local table_name = v.table_name or v.TABLE_NAME
        if is_exist_table(db, db_name, table_name) then
            local sql = string.format("desc `%s`;",table_name)
            local retval = dbquery(db, sql)
            table_descs[table_name] = retval
        end
    end

    for table_name,table_desc in pairs(table_descs) do
        local field_infos = {}
        for _,info in ipairs(table_desc) do
            field_infos[info.Field] = info
            info.Type = string.lower(info.Type)
            if string.find(info.Type,"int") then
                info.vtype = ValueType.integer
                if string.find(info.Type,"tinyint") then
                    info.vlimit = 255
                elseif string.find(info.Type,"smallint") then
                    info.vlimit = 65535
                elseif string.find(info.Type,"mediumint") then
                    info.vlimit = 16777215
                elseif string.find(info.Type,"int") then
                    info.vlimit = 4294967295
                elseif string.find(info.Type,"bigint") then
                    info.vlimit = 18446744073709551615
                else
                    skynet.error("table_name:", table_name)
                    skynet.error("field_name:", info.Field)
                    skynet.error("no support type:", info.Type)
                    assert(false)
                end
            elseif string.find(info.Type,"varchar") then
                info.vtype = ValueType.varchar
                local limit = string.match(info.Type, "varchar%((%d+)%)")
                if limit then
                    info.vlimit = tonumber(limit)
                    if not info.vlimit then
                        skynet.error("table_name:", table_name)
                        skynet.error("field_name:", info.Field)
                        skynet.error("no support type:", info.Type)
                        assert(false)
                    end
                else
                    info.vlimit = 65535
                end
            elseif info.Type == "blob" then
                info.vtype = ValueType.blob
            elseif info.Type == "text" then
                info.vtype = ValueType.text
            else
                skynet.error("table_name:", table_name)
                skynet.error("field_name:", info.Field)
                skynet.error("no support type:", info.Type)
                assert(false)
            end
        end
        table_descs[table_name] = field_infos
    end
end

local function init()
    db = mysql.connect(db_config)
    assert(db,"[MYSQLDBD]failed to connect mysql")
    load_desc_tables(db, db_config.database)

    -- local src_data = {
    --     ["area"] = "番禺区",
    --     ["uid"] = "14fc4608f25b0302a6da39ca",
    --     ["name"] = "豆丁谷孕婴童百货连锁",
    --     ["address"] = "广东省广州市番禺区西门南路87附近",
    --     ["city"] = "广州市",
    --     ["location"] = {
    --         ["lat"] = 23.113315,
    --         ["lng"] =113.254713
    --             },
    --     ["province"] = "广东省",
    --     ["detail"] = 1
    -- }
    -- local data = {}
    -- for k,v in pairs(src_data) do
    --     if k == "location" then
    --         data.lat = math.floor(v.lat*10000000)
    --         data.lng = math.floor(v.lng*10000000)
    --     else
    --         data[k] = v
    --     end
    -- end
    -- data.createtime = math.floor(skynet.time())
    -- -- skynet.hooktrace()
    -- local retval = command.insert("infantplace", data)
    -- skynet.log(retval)
    -- -- data.createtime = 12345
    -- local cond = [[WHERE uid = "14fc4608f25b0302a6da39ca"]]
    -- -- command.update("infantplace", data, cond)
    -- local retval = command.select("infantplace", cond)
    -- skynet.log(retval)
    -- skynet.exithooktrace()
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
