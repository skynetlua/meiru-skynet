local modelsd = include("modelsd", ...)
local mysqldbd = include("mysqldbd", ...)
local database_default = {
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

local table = table
local string = string
local type = type
local ipairs = ipairs
local pairs = pairs
local assert = assert

local tinsert = table.insert

local conditions = {}

conditions["$in"] = function(conds, k, v, opt, args)
	if not next(args) then
		return
	end
	local ttype = type(args[1])
	if ttype == "string" then
		local tmps = {}
		for i,arg in ipairs(args) do
			tmps[i] = '"'.. string.quote_sql_str(arg)..'"'
		end
		args = tmps
	elseif ttype == "number" then
	else
		assert(false, "args[1]="..args[1])
	end
	tinsert(conds, string.format("`%s` IN (%s)",k, table.concat(args, ", ")))
end

conditions["$like"] = function(conds, k, v, opt, args)
	local ttype = type(args)
	if ttype == "string" then
		tinsert(conds, string.format([[`%s` LIKE "%s"]], k, string.quote_sql_str(args)))
	elseif ttype == "number" then
		tinsert(conds, string.format([[`%s` LIKE %s]], k, args))
	else
		assert(false)
	end
end

conditions["$nin"] = function(conds, k, v, opt, args)
	local ttype = type(args[1])
	if ttype == "string" then
		local tmps = {}
		for i,arg in ipairs(args) do
			tmps[i] = '"'.. string.quote_sql_str(arg)..'"'
		end
		args = tmps
	elseif ttype == "number" then
	else
		assert(false)
	end
	tinsert(conds, string.format([[`%s` NOT IN (%s)]],k, table.concat(args, ", ")))
end

conditions["$gte"] = function(conds, k, v, opt, args)
	assert(type(args) == "number")
	tinsert(conds, string.format([[`%s` >= %s]], k, args))
end

conditions["$gt"] = function(conds, k, v, opt, args)
	assert(type(args) == "number")
	tinsert(conds, string.format([[`%s` > %s]], k, args))
end

conditions["$lte"] = function(conds, k, v, opt, args)
	assert(type(args) == "number")
	tinsert(conds, string.format([[`%s` <= %s]], k, args))
end

conditions["$lt"] = function(conds, k, v, opt, args)
	assert(type(args) == "number")
	tinsert(conds, string.format([[`%s` < %s]], k, args))
end

conditions["$or"] = function(conds, k, v)
	local tmps = {}
	for i,arg in ipairs(v) do
		assert(type(arg) == "table")
		for k,v in pairs(arg) do
			local ttype = type(v)
			if ttype == "string" then
				tinsert(tmps, string.format([[`%s` = "%s"]], k, string.quote_sql_str(v)))
			elseif ttype == "number" then
				tinsert(tmps, string.format([[`%s` = %s]], k, v))
			elseif ttype == "boolean" then
				tinsert(tmps, string.format([[`%s` = %d]], k, v and 1 or 0))
			else
				assert(false)
			end
		end
	end
	tinsert(conds, string.format("(%s)", table.concat(tmps, " OR ")))
end


local platform = include(".util.platform", ...)

return function(tblName, db)
	local database = db or database_default
	assert(database)
	local Model = {}
	Model.__index = Model

	function Model.get_fields()
		if not Model._fields then
			Model._fields = database.fields(tblName)
		end
		return Model._fields
	end

	function Model:commit()
		assert(getmetatable(self) == Model)
		if self.id then
			self.update_at = os.time()
		else
			self.create_at = os.time()
			self.update_at = self.create_at
		end
		local fields = Model.get_fields()
		local data = {}
		for k,_ in pairs(fields) do
			data[k] = self[k]
		end
		if self.id then
			database.update(tblName, self.id, data)
		else
			local retval = database.insert(tblName, data)
			if type(retval) == "number" then
				self.id = retval
			else
				log("Model:commit failed retval =", retval)
				assert(false)
			end
		end
	end

	function Model:save(...)
		assert(getmetatable(self) == Model)
		assert(type(self.id) == 'number')
		self.update_at = os.time()
		local fields = {...}
		local data = {}
		if #fields >= 0 then
			for _,field in ipairs(fields) do
				data[field] = self[field]
			end
			assert(next(data), 'Model:save nothing')
		else
			local fields = Model.get_fields()
			for k,_ in pairs(fields) do
				data[k] = self[k]
			end
		end
		database.update(tblName, self.id, data)
	end

	function Model:dusting()
		assert(getmetatable(self) == Model)
		local fields = Model.get_fields()
		for k,v in pairs(self) do
			if type(v) == 'function' then
				if not Model[k] then
					self[k] = nil
				end
			else
				if not fields[k] then
					self[k] = nil
				end
			end
		end
	end

	function Model:snapshot()
		assert(getmetatable(self) == Model)
		local fields = Model.get_fields()
		local data = {}
		for k,v in pairs(self) do
			if type(v) ~= 'function' then
				if fields[k] then
					data[k] = v
				end
			end
		end
		return data
	end

	function Model.makeModel(data)
		assert(type(data) == 'table')
		-- local instance = {}
	    setmetatable(data, Model)
	    -- instance.mdata = data
	    data:dusting()
	    data:ctor()
	    return data
	end

	function Model.get_models(ids)
		if ids and type(ids[1]) == "table" then
			local tmps = {}
			for i,v in ipairs(ids) do
				tmps[i] = v.id
			end
			ids = tmps
		end
	   	local models = database.gets(tblName, ids)
	    for idx,model in ipairs(models) do
	    	models[idx] = Model.makeModel(model)
	    end
	    return models
	end

	function Model.get_model(id)
	 	local model = database.get(tblName, id)
	    if model then
	    	model = Model.makeModel(model)
	    end
	    return model
	end

	local function is_only_id(query)
		local is_find_id = nil
		for k,v in pairs(query) do
			if k == "id" then
				if is_find_id == nil then
					is_find_id = true
				end
			else
				return false
			end
		end
		return is_find_id
	end

	local function make_condition(query, options)
		-- log("make_condition query =", query)
		-- log("make_condition options =", options)
		local conds = {}
		for k,v in pairs(query) do
			if k == "$or" then
				local condition = conditions[k]
				assert(condition, "condition no exist:"..k)
				condition(conds, k, v)
			elseif type(v) == "table" then
				for opt,args in pairs(v) do
					local condition = conditions[opt]
					assert(condition, "condition no exist:"..opt)
					condition(conds, k, v, opt, args)
				end
			else
				if type(v) == "string" then
					tinsert(conds, string.format([[`%s` = "%s"]], k, string.quote_sql_str(v)))
				elseif type(v) == "number" then
					tinsert(conds, string.format("`%s` = %s", k, v))
				elseif type(v) == "boolean" then
					tinsert(conds, string.format("`%s` = %d", k, v and 1 or 0))
				else
					assert(false)
				end
			end
		end
		if #conds == 0 then
			return
		end
		local option_conds
		if options then
			option_conds = {}
			local option = options["sort"]
			if option then
				options["sort"] = nil
				local sort_options = {}
				local fields = string.split(option, " ")
				for _,field in ipairs(fields) do
					local char = string.byte(field, 1)
					if char == string.byte("-") then
						field = string.sub(field, 2)
						tinsert(sort_options, string.format("`%s` DESC", field))
					elseif char == string.byte("+") then
						field = string.sub(field, 2)
						tinsert(sort_options, string.format("`%s` ASC", field))
					else
						tinsert(sort_options, string.format("`%s` ASC", field))
					end
				end
				tinsert(option_conds, string.format("ORDER BY %s", table.concat(sort_options, ",")))
			end
			option = options["limit"]
			if option then
				options["limit"] = nil
				if options["skip"] then
					tinsert(option_conds, string.format("LIMIT %s, %s", options["skip"], option))
					options["skip"] = nil
				else
					tinsert(option_conds, string.format("LIMIT %s", option))
				end
			end
			if next(options) then
				assert(false)
			end
		end
		local sql_cond
		if #conds == 0 then
			if not option_conds then
				sql_cond = ""
			else
				sql_cond = " "..table.concat(option_conds, " ")
			end
		end
		if not option_conds then
			sql_cond = "WHERE "..table.concat(conds, " AND ")
		else
			sql_cond = "WHERE "..table.concat(conds, " AND ") .." ".. table.concat(option_conds, " ")
		end
		return sql_cond
	end

	function Model.get_ids(query, options)
		local sql_cond = make_condition(query, options)
		if not sql_cond then
			return {}
		end
		local ids = database.select(tblName, sql_cond, "id")
		if ids and type(ids[1]) == "table" then
			local tmps = {}
			for i,v in ipairs(ids) do
				tmps[i] = v.id
			end
			ids = tmps
		end
		return ids
	end

	function Model.find(query, options)
		assert(type(query) == 'table' and next(query))
		if is_only_id(query) then
			if type(query.id) == "table" then
				if query.id["$in"] then
					return Model.get_models(query.id["$in"])
				end
			end
			assert(false)
		end
		local ids = Model.get_ids(query, options)
		if #ids == 0 then
			return {}
		end
		return Model.get_models(ids)
	end

	function Model.findOne(query, options)
		assert(type(query) == 'table' and next(query))
		if is_only_id(query) then
			if type(query.id) == "number" then
				return Model.get_model(query.id)
			end
			assert(false)
		end
		local models = Model.find(query, options)
		if models then
			return models[1]
		end
	end

	function Model.countDocuments(query, options)
		assert(type(query) == 'table' and next(query))
		local slq_cond = make_condition(query, options)
		if not slq_cond then
			return 0
		end
		local sql = string.format("SELECT COUNT(*) FROM `%s` %s;", tblName, slq_cond)
		local ret = database.query(sql)
		assert(#ret == 1)
		return ret[1]['COUNT(*)']
	end

	function Model.delete(query)
		assert(type(query) == 'table' and next(query))
		if is_only_id(query) then
			if type(query.id) == "number" then
				database.delete(tblName, query.id)
				return
			end
			assert(false)
		end
		local ids = Model.get_ids(query)
		if #ids == 0 then
			return
		end
		database.deletes(tblName, ids)
	end

	function Model.updateMany(query, data)
		assert(type(query) == 'table' and next(query))
		if is_only_id(query) then
			if type(query.id) == "number" then
				database.update(tblName, query.id, data)
				return
			end
			assert(false)
		end
		local ids = Model.get_ids(query)
		if #ids == 0 then
			return
		end
		database.updates(tblName, ids, data)
	end

	return Model
end
