

local Node = class("Node")

function Node:ctor(name, meiru)
    self.name = assert(name)
    if meiru then
        assert(typeof(meiru) == 'Meiru')
        self.meiru = meiru
    end
end

function Node:set_method(method)
    self.method = method:lower()
end

function Node:set_path(path)
    self.path = path or "/"
    local parts = path:split("/")
    local path_params = {}
    local path_param
    for i,part in ipairs(parts) do
        if part:byte(1) == (":"):byte() then
            path_param = {
                part  = part,
                mask  = true,
                param = part:sub(2) 
            }
        else
            path_param = {
                part = part,
                mask = false
            }
        end
        path_params[i] = path_param
    end
    self.path_params = path_params
end

function Node:open_strict()
    self.is_strict = true
end

function Node:open_terminal()
    self.is_terminal = true
end

function Node:dispatch(req, res)
    self.pass_mask = true
    if self.method then
        if self.method ~= req.method then
            return
        end
    end
    if self.path_params and #self.path_params>0 then
        if self.is_strict then
            if #self.path_params ~= #req.path_params then
                return
            end
        else
            if #self.path_params > #req.path_params then
                return
            end
        end
        local params
        for i,nparam in ipairs(self.path_params) do
            local rparam = req.path_params[i]
            if nparam.mask then
                params = params or {}
                params[nparam.param] = rparam
            else
                if nparam.part ~= rparam then
                    return
                end
            end
        end
        req.params = params
    else
        if self.is_strict then
            if self.path ~= req.path then
                return
            end
        end
    end

    local ret
    if self.coms then
        for _,com in ipairs(self.coms) do
            ret = com:match(req, res)
            com.pass_mask = true
            if ret ~= nil then
                break
            end
            if res.is_end then
                return true
            end
        end
    end
    if ret == nil and self.children then
        for _,node in ipairs(self.children) do
            ret = node:dispatch(req, res)
            if ret ~= nil then
                break
            end
            if res.is_end then
                return true
            end
        end
    end
    if ret == nil and self.is_terminal then
        ret = false
    end
    return ret
end

function Node:add(obj, ...)
    if type(obj) == "string" or type(obj) == "function" then
        self:add_com(obj, ...)
    else
        assert(type(obj) == "table")
        if obj.typeof("Com") then
            self:add_com(obj)
        elseif obj.typeof("Node") then
            self:add_child(obj)
        else
            assert(false, obj.__cname)
        end
    end
end

function Node:add_com(com, ...)
    if type(com) == "string" or type(com) == "function" then
        if type(com) == "string" then
            com = instance(com, ...)
        elseif type(com) == "function" then
            com = instance("ComHandle", com, ...)
        end
    else
        assert(type(com) == "table")
        assert(com.typeof("Com"))
    end
    assert(com:get_node() == nil)
    self.coms = self.coms or {}
    for _,_com in ipairs(self.coms) do
        if _com == com then
            assert(false)
        end
    end
    table.insert(self.coms, com)
    com:set_node(self)
end

function Node:remove_com(com)
    assert(com:get_node() == self)
    if not self.coms then
        return
    end
    for idx,_com in ipairs(self.coms) do
        if _com == com then
            table.remove(self.coms, idx)
            return
        end
    end
end

function Node:get_meiru()
    return self.meiru
end

function Node:set_meiru(meiru)
    self.meiru = meiru
    if self.coms then
        for _,com in ipairs(self.coms) do
            com:set_meiru(meiru)
        end
    end
    if self.children then
        for _,node in ipairs(self.children) do
            node:set_meiru(meiru)
        end
    end
end

function Node:get_children()
    return self.children
end

function Node:add_child(child)
    assert(child:get_parent() == nil)
    self.children = self.children or {}
    for _,_child in ipairs(self.children) do
        if _child == child then
            assert(false)
        end
    end
    table.insert(self.children, child)
    child:set_parent(self)
    if not child:get_meiru() and self.meiru then
        child:set_meiru(self.meiru)
    end
end

function Node:remove_child(child)
    if not self.children then
        return
    end
    for idx,_child in ipairs(self.children) do
        if _child == child then
            child:set_parent(nil)
            table.remove(self.children, idx)
            return
        end
    end
end

function Node:get_child(idx)
    if not self.children then
        return
    end
    return self.children[idx]
end

function Node:get_child_byname(name)
    if not self.children then
        return
    end
    for _,child in ipairs(self.children) do
        if child.name == name then
            return child
        end
    end
end

function Node:search_child_byname(name, depth)
    if not self.children then
        return
    end
    for _,child in ipairs(self.children) do
        if child.name == name then
            return child
        end
    end
    if depth then
        depth = depth-1
        if depth <= 0 then
            return
        end
    end
    local sub_child
    for _,child in ipairs(self.children) do
        sub_child = child:search_child_byname(name, depth)
        if sub_child then
            return sub_child
        end
    end
end

function Node:get_parent()
    return self.parent
end

function Node:set_parent(parent)
    self.parent = parent
end

function Node:get_root()
    local root = self
    while root:get_parent() do
        root = root:get_parent()
    end
    return root
end

function Node:footprint(depth)
    depth = (depth or 0)+1
    if self.pass_mask then
        self.pass_mask = nil
        local rets = {}
        if self.path then
            table.insert(rets, string.rep("++", depth) .. self.name..":"..self.path)
        else
            table.insert(rets, string.rep("++", depth) .. self.name)
        end
        if self.coms then
            for _,com in ipairs(self.coms) do
                if com.pass_mask then
                    table.insert(rets, string.rep("--", depth) .. com.__cname)
                    com.pass_mask = nil
                end
            end
        end
        if self.children then
            for _,child in ipairs(self.children) do
                local ret = child:footprint(depth)
                if ret then
                    table.insert(rets, ret)
                end
            end
        end
        return table.concat(rets, "\n")
    end
end

function Node:treeprint(depth)
    depth = (depth or 0)+1
    local rets = {}
    if self.path then
        table.insert(rets, string.rep("++", depth) .. self.name..":"..self.path)
    else
        table.insert(rets, string.rep("++", depth) .. self.name)
    end
    if self.coms then
        for _,com in ipairs(self.coms) do
            table.insert(rets, string.rep("--", depth) .. com.__cname)
        end
    end
    if self.children then
        for _,child in ipairs(self.children) do
            local ret = child:treeprint(depth)
            if ret then
                table.insert(rets, ret)
            end
        end
    end
    return table.concat(rets, "\n")
end

return Node
