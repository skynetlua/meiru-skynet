
include("com.index", ...)

local Request  = include("util.request", ...)
local Response = include("util.response", ...)
local Node     = include("node.node", ...)
local Root     = include("node.root", ...)
local Router   = include("node.router", ...)
local Static   = include("node.static", ...)
local platform = include("util.platform", ...)

----------------------------------------------
--Meiru
----------------------------------------------
local Meiru = class("Meiru")

function Meiru:ctor()
	self.viewdatas = {}
	self.settings  = {}
end

function Meiru:data(key, value)
	if type(key) == "string" then
		self.viewdatas[key] = value
	elseif type(key) == "table" then
		assert(not value)
		for k,v in pairs(key) do
			self.viewdatas[k] = v
		end
	else
		assert(false)
	end
end

function Meiru:set(key, value)
	self.settings[key] = value
end

function Meiru:get(key)
	return self.settings[key]
end

function Meiru:get_node(name, depth)
	if not name or self.node_root.name == name then
		return self.node_root
	end
	depth = depth or 2
	local node = self.node_root:search_child_byname(name, depth)
	return node
end

function Meiru:add_node(name, node)
	local parent = self:get_node(name)
	assert(parent)
	parent:add_child(node)
end

function Meiru:get_or_create_node(name, parent_name)
	local node = self:get_node(name)
	if not node then
		node = Node.new(name, self)
		assert(node)
		if parent_name then
			local parent_node = type(parent_name) == "string" and self:get_node(parent_name) or self.node_res
			parent_node:add_child(node)
		else
			self.node_req:add_child(node)
		end
	end
	return node
end

function Meiru:add_com(name, com, parent_name, ...)
	if not com then
		com = name
		name = self.node_req.name
	end
	local node = self:get_or_create_node(name, parent_name)
	node:add_com(com, ...)
	return node
end

function Meiru:use(...)
	local args = {...}
	local path = args[1]
	local node = self:get_or_create_node("node_start")
	if type(path) == "string" then
		if path:byte(1) == string.byte("/") then
			node = Node.new("node_use", self)
			self:add_node("node_req", node)
		else
			node = self:get_or_create_node(path)
		end
		assert(node)
		table.remove(args, 1)
	end
	for _,field in ipairs(args) do
		node:add(field)
	end
end

function Meiru:run()
	self:add_com("node_finish", "ComFinish")
	-- self.node_root:print()
end

if os.mode == 'dev' then
local LineChars = "\n--------------------------------------\n"
function Meiru:dispatch(req, res)
	self.is_working = true
	local start_time = platform.time()
	local ok, ret = pcall(self.node_req.dispatch, self.node_req, req, res)
	if ok then
		res.req_ret = res.is_end or ret
		res.is_end = nil
		ok, ret = pcall(self.node_res.dispatch, self.node_res, req, res)
	end
	if ok then
		if self.enable_footprint then
			log("dispatch url:"..req.rawurl)
			log("dispatch cost_time:" .. (platform.time() - start_time))
			log(LineChars.."FOOTPRINT"..LineChars..(self.node_req:footprint() or 'nothing'))
		end
		if ret == nil or ret == false then
			self:response(res, 404, "Forbidden")
		else
			assert(ret == true)
		end
	else
		local logmsg = "Meiru req:"..table.tostring(req.rawreq)
		if self.enable_footprint then
			logmsg = logmsg.."\ndispatch url:"..req.rawurl
			logmsg = logmsg .."\ndispatch cost_time:" .. (platform.time() - start_time)
			logmsg = logmsg ..LineChars.."FOOTPRINT"..LineChars..(self.node_req:footprint() or 'nothing')
		end
		local errmsg = LineChars.."ERROR"..LineChars..(ret or "").."\n"..debug.traceback()
		if req.app.__render_error then
			local renerror = req.app.__render_error
			req.app.__render_error = nil
			errmsg = errmsg..LineChars.."RENDER_ERROR"..LineChars
			errmsg = errmsg.."Render error:"..renerror.error
			if renerror.path then
				errmsg = errmsg.."\nRender path:"..renerror.path
				errmsg = errmsg.."\nRender chunk:\n"..renerror.chunk
			end
		end

		self:response(res, 404, logmsg.."\n"..errmsg, {['content-type'] = "text/plain;charset=utf-8"})
	end
end
end

if os.mode ~= 'dev' then

function Meiru:dispatch(req, res)
	self.is_working = true
	local start_time = platform.time()
	local ok, ret = pcall(self.node_req.dispatch, self.node_req, req, res)
	if ok then
		res.req_ret = res.is_end or ret
		res.is_end = nil
		ok, ret = pcall(self.node_res.dispatch, self.node_res, req, res)
	end
	if not ok then
		log("Meiru req:", req.rawreq)
		log(ret.."\n"..debug.traceback())
	end

	if self.enable_footprint then
		log("Meiru url:", req.rawurl)
		log("Meiru cost_time:", platform.time() - start_time)
		log("Meiru footprint:\n", self.node_req:footprint())
	end
	if not ok then
		self:response(res, 404, "Forbidden")
	else
		if ret == nil or ret == false then
			self:response(res, 404, "Forbidden")
		else
			assert(ret == true)
		end
	end
end
end

-- function Meiru:dispatch(req, res)
-- 	self.is_working = true

-- 	local start_time = platform.time()

-- 	local ret = self.node_req:dispatch(req, res)
-- 	res.req_ret = res.is_end or ret
-- 	res.is_end = nil
-- 	ret = self.node_res:dispatch(req, res)

-- 	if self.enable_footprint then
-- 		log("Meiru url:", req.rawurl)
-- 		log("Meiru cost_time:", platform.time() - start_time)
-- 		log("\n", self.node_req:footprint())
-- 	end

-- 	if ret == nil then
-- 		assert(self.is_working)
-- 		self:response(res, 404, "HelloWorld404")
-- 	else
-- 		assert(not self.is_working)
-- 	end
-- end

function Meiru:open_footprint(enable)
	enable = type(enable) ~= 'nil' and enable or true
	self.enable_footprint = enable
	log("开启打印访问足迹")
end

function Meiru:response(res, code, body, header)
	res.__response(code, body, header)
	self.is_working = nil
end

function Meiru:default_config()
	self.node_root = Root.new("node_root", self)

	self.node_req = Node.new("node_req", self)
	self.node_res = Node.new("node_res", self)
	self.node_root:add_child(self.node_req)
	self.node_root:add_child(self.node_res)

	self:set('x-powered-by', true)

	self:add_com("node_start", "ComInit")
	self:add_com("node_start", "ComPath")
	self:add_com("node_start", "ComHeader")
	self:add_com("node_start", "ComCors")
	self:add_com("node_start", "ComCookie")
	self:add_com("node_start", "ComSession")

	self:add_com("node_res", "ComRender")
	self:add_com("node_res", "ComResponse")
end

function Meiru:footprint()
	return self.node_root:footprint()
end

function Meiru:treeprint()
	return self.node_root:treeprint()
end

-----------------------------------------------
--exports
-----------------------------------------------
local exports = {}

function exports.router()
	return Router()
end

function exports.static(path, static_dir)
	return Static(path, static_dir)
end

-----------------------------------------
---create_app
-----------------------------------------
function exports.create_app()
	local meiru = Meiru.new()

	local app = {}
	function app.data(...)
		meiru:data(...)
	end

	function app.get_viewdatas()
		return meiru.viewdatas
	end

	function app.set(...)
		meiru:set(...)
	end

	function app.get(...)
		return meiru:get(...)
	end

	function app.add_node(...)
		meiru:add_node(...)
	end

	function app.get_node(...)
		return meiru:get_node(...)
	end

	function app.get_or_create_node(...)
		return meiru:get_or_create_node(...)
	end

	function app.add_com(...)
		return meiru:add_com(...)
	end

	function app.use(...)
		meiru:use(...)
	end

	function app.run(...)
		meiru:run(...)
	end

	function app.dispatch(raw_req, raw_res)
		local req = Request(app, raw_req)
		local res = Response(app, raw_res)
		meiru:dispatch(req, res)
	end

	function app.response(...)
		meiru:response(...)
	end

	function app.open_footprint(enable)
		meiru:open_footprint(enable)
	end
	
	function app.footprint()
		return meiru:footprint()
	end

	function app.treeprint()
		return meiru:treeprint()
	end

	function app.chunkprint()
		assert(false, "discard")
		-- assert(os.mode == 'dev', "Please open development mode.just setting os.mode = 'dev'")
		-- local chunk = ""
		-- if app.__chunks then
		-- 	for _,v in ipairs(app.__chunks) do
		-- 		chunk = chunk .."ejs:[["..v[1].."]]\n"..v[2].."\n"
		-- 	end
		-- end
		-- return chunk
	end
	------------------------------
	-----------------------------
	meiru:default_config()
	return app
end

return exports