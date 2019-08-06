-- local crypt = require "skynet.crypt"
local platform = include("platform", ...)
local uuid  = include(".lib.uuid", ...)
local Coder = include(".role.coder", ...)
local json  = Coder("json")

local Cookie = {}


function Cookie.generate_sessionid()
	return uuid()
end

local function cookie_check_signed(str, secret)
	if type(str) ~= "string" then
		return
	end
	if string.sub(str, 1, 2) ~= "s:" then
		return
	end
	local val = string.sub(str, 3)
	local idx = string.find(val, "%.", 1, true)
	if not idx then
		return
	end
	local key = string.sub(val, 1, idx-1)
	local checkmac = string.sub(val, idx+1)
	local mac = platform.hmacmd5(key, secret)
	if mac == checkmac then
		return key
	end
end

function Cookie.cookie_sign(val, secret)
	local mac = platform.hmacmd5(val, secret)
	return "s:".. val.."."..mac
end


local function cookie_signeds(cookies, secret)
	local dec
	local signcookies = {}
	for key,val in pairs(cookies) do
		dec = cookie_check_signed(val, secret)
		if dec then
			signcookies[key] = dec
			cookies[key] = nil
		end
	end
	return signcookies
end

local function cookie_check_json(str)
	if type(str) ~= "string" then
		return
	end
	if string.sub(str, 1, 2) ~= "j:" then
		return
	end
	local tmp = string.sub(str, 3)
	return json.decode(tmp)
end

local function cookie_jsons(cookies)
	local dec
	for key,val in pairs(cookies) do
		dec = cookie_check_json(val)
		if dec then
			cookies[key] = dec
		end
	end
	return cookies
end

function Cookie.cookie_decode(txt, secret)
	local kvpairs = string.split(txt, ";")
	local cookies = {}
	for _,kvpair in ipairs(kvpairs) do
		local key_val = string.split(kvpair, "=")
		if #key_val == 2 then
			local key = string.trim(key_val[1])
			local val = string.trim(key_val[2])
			val = string.urldecode(val)
			if not cookies[key] then
				if string.byte(val, 1) == string.byte('"') then
					val = string.sub(val, 2, #val-1)
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

function Cookie.cookie_encode(cookies)
    local values = {}
    local low_key
    for k,v in pairs(cookies) do
        -- Max-Age
        low_key = string.lower(k)
        if low_key == 'secure' then
        elseif low_key == 'httponly' then
        elseif low_key == 'expires' then
		elseif low_key == 'domain' then
		elseif low_key == 'path' then
        else
            table.insert(values, k .. '=' .. string.urlencode(v))
        end
    end
    for k,v in pairs(cookies) do
        low_key = string.lower(k)
        if low_key == 'secure' then
            if v then
                table.insert(values, 'Secure')
            end
        elseif low_key == 'httponly' then
            if v then
                table.insert(values, 'HttpOnly')
            end
        elseif low_key == 'expires'  then
            if type(v) == "number" then
                table.insert(values, 'Expires=' .. os.gmtdate(v))
            else
                table.insert(values, 'Expires=' .. v)
            end
        elseif low_key == 'domain' then
			table.insert(values, 'Domain=' .. v)
		elseif low_key == 'path' then
            table.insert(values, 'Path=' .. v)
        else
        end
    end
	return table.concat(values, ";")
end





return Cookie

