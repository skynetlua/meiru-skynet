local skynet = require "skynet"

local systemd = require "meiru.lib.systemd"

local _ip2regiond
local function get_ip2regiond()
    if not _ip2regiond then
        local list = skynet.call(".launcher", "lua", "LIST")
        for address,param in pairs(list) do
            if param:find("meiru/ip2regiond", 1, true) then
                _ip2regiond = address
            end
        end
    end
    return _ip2regiond
end


local exports = {}

local cmds = {
	["network"] = function(req, res, page, limit)
		local data = systemd.net_stat(page, limit)
		local retval = {
			code  = 0,
			msg   = "",
			count = #data,
			data  = data,
		}
		return retval
	end,

	["service"] = function(req, res, page, limit)
		local data = systemd.service_stat(page, limit)
		local stat = systemd.mem_stat()
		local retval = {
			code  = 0,
			msg   = "",
			count = #data,
			data  = data,
			total = stat.total,
			block = stat.block
		}
		return retval
	end,

	["visit"] = function(req, res, page, limit)
		local data = systemd.client_stat()
		local ip2regiond = get_ip2regiond()
		local region = ""
    	if ip2regiond then
        	region = skynet.call(ip2regiond, "lua", "ip2region", req.ip)
        end
		local retval = {
			code  = 0,
			msg   = "",
			count = #data,
			data  = data,
			addr  = req.addr,
			region = region,
		}
		return retval
	end,

	["router"] = function(req, res, page, limit)
		local data = req.app:treeprint()
		local retval = {
			code = 0,
			msg  = "",
			data = data,
		}
		return retval
	end,

	["online"] = function(req, res, page, limit)
		local data = systemd.online_stat()
		local retval = {
			code = 0,
			msg  = "",
			data = data,
		}
		return retval
	end,
}

function exports.index(req, res)
	local what = req.params.what
	local page = req.query.page
	local limit = req.query.limit
	local retval = cmds[what](req, res, page, limit)
	return res.json(retval)
end

return exports

