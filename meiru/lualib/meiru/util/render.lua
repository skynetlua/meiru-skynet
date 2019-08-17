local Markdown = include(".lib.md", ...)
local widget   = include(".lib.widget", ...)
local QueueMap = include(".lib.queuemap", ...)


local table = table

local white_char = string.byte(" ")
local escape_char = string.byte("=")
local unescape_char = string.byte("-")

local function is_empty_txt(txt)
    if type(txt) ~= "string" or #txt == 0 then 
        return true 
    end
    for i=1,#txt do
        if txt:byte(i) ~= white_char then 
            return 
        end
    end
    return true
end

local function markdown(text)
    return '<div class="markdown-text">' .. Markdown(text or '') .. '</div>'
end

local function load_chunk(content)
    local ssidx, seidx, esidx, eeidx, element, txt
    local elements = {}
    local search, strlen = 1, #content
    while search <= strlen do
        ssidx,seidx = content:find("<%", search, true)
        if ssidx then
            esidx,eeidx = content:find("%>", search, true)
            if esidx then
                table.insert(elements, {what = 0, txt = content:sub(search, ssidx-1)})
                txt = content:sub(ssidx, eeidx)
                element = {what = 1}
                local char = txt:byte(3)
                if char == escape_char then
                    element.what = 3
                    element.code = txt:sub(4, #txt-3)
                elseif char == unescape_char then
                    element.what = 4
                    element.code = txt:sub(4, #txt-3)
                else
                    element.what = 2
                    element.code = txt:sub(3, #txt-3)
                end
                table.insert(elements, element)
                search = eeidx+1
                if element.what == 2 then
                    esidx = content:find("\n", search, true)
                    if esidx then
                        if esidx-search <= 2 then
                            search = esidx+1
                        end
                    end
                end
            end
        end
        if not ssidx or not esidx then
            table.insert(elements, {what = 0, txt = content:sub(search)})
            break
        end
    end
    local codes = {}
    local __args = {}
    local chunk = ""
    for i,element in ipairs(elements) do
        if element.what == 2 then
            chunk = chunk.. element.code.."\n"
        elseif element.what == 3 then
            chunk = chunk.. "escape(echo("..element.code.."))\n"
        elseif element.what == 4 then
            chunk = chunk.. "echo("..element.code..")\n"
        else
            if not is_empty_txt(element.txt) then
                __args[i] = element.txt
                chunk = chunk.. "echo(__args["..i.."])\n"
            end
        end
    end
    return {chunk = chunk, __args = __args}
end

local queue_map = QueueMap(300)
local function get_chunk(path, get_res, mode)
    if mode then
        local file_txt = get_res(path)
        return load_chunk(file_txt)
    end
    local chunk = queue_map.get(path)
    if not chunk then
        local file_txt = get_res(path)
        chunk = load_chunk(file_txt)
        queue_map.set(path, chunk)
    end
    return chunk
end

local function conv_realpath(cur_path, path)
    local sidx, eidx = path:find("../", 1, true)
    if sidx == 1 then
        path = path:sub(eidx+1)
        local dirs = cur_path:split("/")
        table.remove(dirs)
        table.remove(dirs)
        path = table.concat(dirs, "/ ").."/"..path
    else
        sidx, eidx = path:find("./", 1, true)
        if sidx == 1 then
            path = path:sub(eidx+1)
            local cur_dir = cur_path:match("(.*)[.*^/]")
            if cur_dir then
                path = cur_dir.."/"..path
            end
        end
    end
    return path
end

----------------------------------------
--mode == nil, open cache
--mode == 1, just closest cache
return function(get_res, options, mode)
    local _GEnv = {print = print,type = type,table = table,ipairs = ipairs,log = log,
        pairs = pairs,math = math,string = string,markdown = markdown,widget = widget}
    for k,v in pairs(options) do
        _GEnv[k] = v
    end
    local last_chunk
    local chunk_path
    local Render = false
    Render = function(path, data)
        local chunk = get_chunk(path, get_res, mode)
        if not chunk then
            error("Render no find the chunk:"..path)
            return ""
        end
        chunk_path = path
        last_chunk = chunk
        local env = {}
        if data then
            for k,v in pairs(data) do
                env[k] = v
            end
        end
        for k,v in pairs(_GEnv) do
            env[k] = v
        end
        env.__args = chunk.__args
        local ret = ""
        env.echo = function(str)
            ret = ret..tostring(str)
        end
        env.escape = function(txt)
            if type(txt) ~= "string" then
               return txt 
            end
            return txt:gsub("&", '&amp;'):gsub("<", '&lt;'):gsub(">", '&gt;'):gsub("'", '&#39;'):gsub('"', '&quot;')
        end
        env.partial = function(path1, env1)
            env1 = env1 or {}
            path1 = conv_realpath(path, path1)
            if env1.collection and env1.as then
                local env2 = {}
                for k,v in pairs(env) do
                    env2[k] = v
                end
                local items = ""
                for idx,item in ipairs(env1.collection) do
                    env2[env1.as] = item
                    env2['indexInCollection'] = idx
                    items = items.. Render(path1, env2)
                end
                return items
            end
            for k,v in pairs(env) do
                env1[k] = v
            end
            return Render(path1, env1)
        end
        local cname = "["..path.."]"
        local f = load(chunk.chunk, cname, "bt", env)
        assert(f, "load chunk error:"..cname)
        f()
        return ret
    end

    return function(...)
        last_chunk = nil
        local ok, ret = pcall(Render, ...)
        if not ok then
            if last_chunk then
                log("*********Error chunk info***********")
                log("[Render]error:", ret)
                log("[Render]path:", chunk_path)
                log("[Render]chunk:\n", last_chunk.chunk)
                return ok, {error = ret, path = chunk_path, chunk = last_chunk.chunk}
            else
                return ok, {error = ret}
            end
            assert(false)
        end
        return true, ret
    end
end
