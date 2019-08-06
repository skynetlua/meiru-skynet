local Com = include("com", ...)
local platform = include(".util.platform", ...)
local filed = include(".lib.filed", ...)

local string = string

local ComStatic = class("ComStatic", Com)

function ComStatic:ctor(static_dir)
	self.file_md5s = {}
	self.max_age = 3600*24*7
	if static_dir then
		if static_dir:byte(#static_dir) == string.byte("/") then
	    	static_dir = static_dir:sub(1, #static_dir-1)
	    end
	    self.static_dir = static_dir
	 end
end

function ComStatic:find_static_dir()
	if self.static_dir then
		return self.static_dir
	end
	local static_dir = req.app.get("static_dir")
	assert(static_dir)
	if static_dir:byte(#static_dir) == string.byte("/") then
	    static_dir = static_dir:sub(1, #static_dir-1)
	end
    self.static_dir = static_dir
end

function ComStatic:get_full_path(path)
	if not self.static_dir then
		self:find_static_dir()
	end
	if path:byte(1) == string.byte("/") then
		return self.static_dir .. path
	else
		return self.static_dir .. '/' .. path
	end
end

function ComStatic:match(req, res)
	-- query = {
	-- 	fv = "f0d1c8f7e4134b6d0d21bc96a86e0bb9",
	-- },
    local headers = req.headers
	local fullpath = self:get_full_path(req.path)
	local modify_date = headers['if-modified-since']
	if type(modify_date) == "string" and #modify_date > 0 then
		local modify_time = os.gmttime(modify_date)
		if modify_time then
			local fmodify_time = platform.file_modify_time(fullpath)
			if fmodify_time == modify_time then
				res.send(304)
				res.set_header('Last-Modified', os.gmtdate(fmodify_time))
				res.set_cache_timeout(self.max_age)
				return true
			end
		end
	end
	
	local file_md5 = filed.file_md5(fullpath)
	if not file_md5 then
		return false
	end
	local etag = headers['if-none-match']
	if type(etag) == "string" and #etag > 0 then
		if etag == file_md5 then
			res.send(304)
			res.set_header('ETag', file_md5)
			res.set_cache_timeout(self.max_age)
			return true
		end
	end
	local content = filed.file_read(fullpath)
	if not content then
		return false
	end

	res.set_type(io.extname(fullpath))
	res.set_header('ETag', file_md5)
	local modify_time = platform.file_modify_time(fullpath)
	res.set_header('Last-Modified', os.gmtdate(modify_time))
	res.set_header('Age', 3600*24)
	res.set_cache_timeout(self.max_age)

	res.send(content)
	return true
end

return ComStatic
