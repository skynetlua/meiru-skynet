local Node = include("node", ...)


 local function create_node_static(path, static_dir)
	local node = Node.new("node_static")
	node:set_method("get")
    node:set_path(path)
    node:open_terminal()
    node:add_com("ComStatic", static_dir)
    return node
end

return create_node_static