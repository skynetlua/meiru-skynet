
local __arg = {...}

local function convert_val(v)
	local vtype = type(v)
    if vtype == "nil" then
        return "nil"
    elseif vtype == "string" then
        return '"'.. v .. '"'
    elseif vtype == "number" or vtype == "boolean" then
        return tostring(v)
    else
    	assert(false, "not support value type:"..vtype)
    end
end

local function __dump(t, depth)
    if type(t) ~= "table" then 
        return convert_val(t) 
    end
    depth = (depth or 0) + 1
    if depth > 10 then
        assert(false, "table too depth")
    else
        local retval = {}
        for k, v in pairs(t) do
            table.insert(retval, k .. "=" .. __dump(v, depth))
        end
        return "{"..table.concat(retval, ",").."}"
    end
end

local function lua_encode(obj)
    return __dump(obj, 0)
end

local function lua_decode(str)
    local ret = load("return "..str)()
    return ret
end


-----------------------------------------------------------
--coders
-----------------------------------------------------------
local coders = {}

function coders.json()
	local ok, json = pcall(require, "cjson")
	if not ok then
		json = include(".3rd.json", table.unpack(__arg))
		assert(json)
	end
	local coder = {
		encode = json.encode,
		decode = json.decode
	}
	return coder
end

function coders.lua()
	local coder = {
		encode = lua_encode,
		decode = lua_decode
	}
	return coder
end

function coders.protobuf()
    local protobuf = require "protobuf"
    return protobuf
end

return function(ctype)
	local coder = coders[ctype]()
	assert(coder)
	return coder
end
