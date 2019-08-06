local cached      = include(".db.cached", ...)
local modelsd = include(".db.modelsd", ...)


local platform = {}

local ok, skynet = pcall(require, "skynet")
if ok then

local lfs   = require "lfs"
local md5   = require "md5"
-- local cjson = require "cjson"
local mysqldbd = include(".db.mysqldbd", ...)
-- local mysqldbd = require "meiru.db.mysqldbd"

local database = {
	select  = mysqldbd.select,
	query   = mysqldbd.query,
	gets    = modelsd.gets,
	get     = modelsd.get,
	fields  = modelsd.fields,
	insert  = modelsd.insert,
	update  = modelsd.update,
	updates = modelsd.updates,
	clear   = modelsd.clear,
	remove  = modelsd.remove,
	removes = modelsd.removes,
	delete  = modelsd.delete,
	deletes = modelsd.deletes,
}

function platform.database()
	return database
end

--file
function platform.file_attr(file_path)
	return lfs.attributes(file_path)
end

function platform.file_modify_time(file_path)
	local attr = lfs.attributes(file_path)
	if not attr then
		return
	end
	return attr.change
end

function platform.md5(data)
	return md5.sumhexa(data)
end

function platform.hmacmd5(data, key)
	return md5.hmacmd5(data, key)
end

function platform.time()
	return skynet.hpc()/1000000000
end

--
else

local json = include(".3rd.json", ...)
local md5  = include(".3rd.md5", ...)

local database = {
	select  = function(...) log("[platform]database.select", ...) end,
	query   = function(...) log("[platform]database.query", ...) end,
	gets    = modelsd.gets,
	get     = modelsd.get,
	fields  = modelsd.fields,
	insert  = modelsd.insert,
	update  = modelsd.update,
	updates = modelsd.updates,
	clear   = modelsd.clear,
	remove  = modelsd.remove,
	removes = modelsd.removes,
	delete  = modelsd.delete,
	deletes = modelsd.deletes,
}

function platform.get_database()
	return database
end

function platform.file_modify_time(file_path)
	return 1560495220
end

function platform.md5(data)
	return md5.sumhexa(data)
end

local function get_ipad(c)
	return string.char(c:byte() ~ 0x36)
end

local function get_opad(c)
	return string.char(c:byte() ~ 0x5c)
end

function platform.hmacmd5(data,key)
	if #key>64 then
		key = platform.md5(key)
		key = key:sub(1,16)
	end
	local ipad_s = key:gsub(".", get_ipad)..string.rep("6",64-#key)
	local opad_s = key:gsub(".", get_opad)..string.rep("\\",64-#key)
	local istr = platform.md5(ipad_s..data)
	local ostr = platform.md5(opad_s..istr)
	return ostr
end

function platform.time()
	return os.time()
end

end

return platform