-- local crypt = require "skynet.crypt"
local platform = include("platform", ...)
local uuid  = include(".lib.uuid", ...)
local Coder = include(".role.coder", ...)
local json  = Coder("json")

local string = string
local table = table

local Cookie = {}


local function cookie_check_signed(str, secret)
	if type(str) ~= "string" then
		return
	end
	if str:sub(1, 2) ~= "s:" then
		return
	end
	local val = str:sub(3)
	local idx = val:find(".", 1, true)
	if not idx then
		return
	end
	local ret = val:sub(1, idx-1)
	local checkmac = val:sub(idx+1)
	local mac = platform.hmacmd5(ret, secret)
	if mac == checkmac then
		return ret
	end
end

function Cookie.cookie_sign(val, secret)
	local mac = platform.hmacmd5(val, secret)
	return "s:".. val.."."..mac
end

local function cookie_signeds(cookies, secret)
	local signcookies = {}
	for key,val in pairs(cookies) do
		val = cookie_check_signed(val, secret)
		if val then
			signcookies[key] = val
			cookies[key] = nil
		end
	end
	return signcookies
end

local function cookie_check_json(str)
	if type(str) ~= "string" then
		return
	end
	if str:sub(1, 2) ~= "j:" then
		return
	end
	local tmp = str:sub(3)
	return json.decode(tmp)
end

local function cookie_jsons(cookies)
	for key,val in pairs(cookies) do
		val = cookie_check_json(val)
		if val then
			cookies[key] = val
		end
	end
	return cookies
end

function Cookie.cookie_decode(txt, secret)
	local kvpairs = txt:split(";")
	local cookies = {}
	local key_val, key, val
	for _,kvpair in ipairs(kvpairs) do
		key_val = kvpair:split("=")
		if #key_val == 2 then
			key = key_val[1]:trim()
			val = key_val[2]:trim()
			val = val:urldecode()
			if not cookies[key] then
				if val:byte(1) == ('"'):byte() then
					val = val:sub(2, #val-1)
				end
				cookies[key] = val
			end
		end
	end
	local signcookies = cookie_signeds(cookies, secret)
	signcookies = cookie_jsons(signcookies)
	cookies = cookie_jsons(cookies)
	return cookies, signcookies
end

function Cookie.cookie_encode(cookie)
	local values = {}
	table.insert(values, cookie.key..'='..(cookie.value or ""))
    local field
    for k,v in pairs(cookie) do
        field = k:lower()
        if field == 'secure' then
            table.insert(values, 'Secure')
        elseif field == 'httponly' then
        	table.insert(values, 'HttpOnly')
        elseif field == 'expires' then
        	if type(v) == "number" then
                table.insert(values, 'Expires=' .. os.gmtdate(v))
            else
                table.insert(values, 'Expires=' .. v)
            end
		elseif field == 'domain' then
			table.insert(values, 'Domain=' .. v)
		elseif field == 'path' then
			table.insert(values, 'Path=' .. v)
		elseif field == 'max-age' then
			table.insert(values, 'max-age=' .. v)
        end
    end
	return table.concat(values, ";")
end

return Cookie

