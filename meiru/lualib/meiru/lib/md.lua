-- local widget = require "meiru.widget"
local widget = include("widget", ...)

local HeaderNodes = {
	{"ul", "- "},{"ul", "+ "},{"ul", "* "},{"hr", "---"},{"hr", "***"},
	{"h6", "###### "},{"h5", "##### "},{"h4", "#### "},{"h3", "### "},{"h2", "## "},
	{"h1", "# "},{"pre", "```", "```"},{"blockquote", ">"}
}
local InlineNodes = {
	{"a", false, "[", "](", ")"},
	{"img", false, "![", "](", ")"},
	{"strong", "em", "***", "***"},
	{"strong", false, "**", "**"},
	{"code", false, "`", "`"},
	{"em", false, "*", "*"},
	{"mark", false, "==", "=="},
	{"del", false, "~~", "~~"}
}
local Nodes = {
	["txt"] = {"txt"}, ["p"] = {"p"}, ["br"] = {"br"}, ["ol"] = {"ol"}, ["pre"] = {"pre"},
	["table"] = {"table"}, ["caption"] = {"caption"}, ["thead"] = {"thead"}, ["th"] = {"th"},
	["tbody"] = {"tbody"}, ["tr"] = {"tr"}, ["td"] = {"td"}, ["li"] = {"li"}, ["div"] = {"div"}
}

local string = string
local table  = table

local function class(cname, super)
    local clazz = {}
    clazz.__cname = cname
    clazz.__index = clazz
    if type(super) == "table" then
        setmetatable(clazz, {__index = super})
    else
        clazz.ctor = function() end
    end
    function clazz.new(...)
        local instance = setmetatable({}, clazz)
        instance:ctor(...)
        return instance
    end
    return clazz
end

local function string_split(str, sep)
	local retval = {}
	local idx = 1
	local s, e
	while true do
		s, e = str:find(sep, idx, true)
		if not s then
			table.insert(retval, str:sub(idx))
			break
		end
		table.insert(retval, str:sub(idx, s-1))
		idx = e+1
	end
    -- 	string.gsub(str, string.format("([^%s]+)", (sep or "\t")), function(c)
    --     	table.insert(retval, c)
    -- 	end)
    return retval
end

local function string_multi_split(str, sep)
	local retval = {}
    str:gsub("([^"..(sep or "\t").."]+)", function(c)
        table.insert(retval, c)
    end)
    return retval
end

local function is_empty_txt(txt)
    for i=1,#txt do
        if string.byte(txt, i) ~= string.byte(" ") then
            return
        end
    end
    return true
end

----------------------------------------
----------------------------------------
local Piece = class("Piece")

function Piece:searchNode(txt, idx, len, nodes)
	local pattern
	for _,node in ipairs(nodes) do
		pattern = node[3]
		if string.byte(pattern, 1) == string.byte(txt, idx) then
			for j=1,#pattern do
				if string.byte(pattern, j) ~= string.byte(txt, idx + j-1) then
					node = nil
					break
				end
			end
			if node then
				local tpattern = node[4]
				if tpattern then
					for i=idx + #pattern+1,len do
						if string.byte(tpattern, 1) == string.byte(txt, i) then
							for j=1,#tpattern do
								if string.byte(tpattern, j) ~= string.byte(txt, i+j-1) then
									node = nil
									break
								end
							end
							if node then
								self.startIdx = idx + #pattern
								return node
							end
						end
					end
				else
					self.startIdx = idx + #pattern
					return node
				end
			end
		end
	end
end

function Piece:searchPattern(txt, idx, len, pattern)
	if string.byte(pattern, 1) ~= string.byte(txt, idx) then
		return
	end
	local k
	local plen = #pattern
	for i=1,plen do
		k = idx + i-1
		if k > len or string.byte(pattern, i) ~= string.byte(txt, k) then
			return
		end
	end
	return true
end

function Piece:isCheckChar(txt, idx)
	local charCode = string.byte(txt, idx)
	if charCode >= 128 then 
		return
	end
	if charCode < 48 or (charCode > 57 and charCode < 65) or
		(charCode > 90 and charCode < 97) or charCode > 122 then
		return true
	end
end

function Piece:processNext(txt, idx, len)
	local startIdx = idx
	local pattern = self._node[5]
	while idx <= len do
		if self:isCheckChar(txt, idx) then
			if self:searchPattern(txt, idx, len, pattern) then
				self.startIdx1 = startIdx
				self.endIdx1 = idx-1
				self._content1 = string.sub(txt, self.startIdx1, self.endIdx1)
				idx = idx + #pattern
				return idx
			elseif self:searchNode(txt, idx, len, InlineNodes) then
				local piece = Piece.new()
				local _next = piece:process(txt, idx, len)
				if _next == idx then 
					break
				end
				self._childs = self._childs or {}
				table.insert(self._childs, piece)
				idx = _next
			else 
				idx = idx+1
			end
		else
			idx = idx+1
		end
	end
	return idx
end

function Piece:process(txt, idx, len)
	local node
	local startIdx = idx
	if self:isCheckChar(txt, idx) then
		node = self:searchNode(txt, idx, len, InlineNodes)
	end
	if node then
		self._node = node
		idx = self.startIdx
		local pattern = node[4]
		while idx <= len do
			if self:isCheckChar(txt, idx) then
				if self:searchPattern(txt, idx, len, pattern) then
					self.endIdx = idx-1
					idx = idx + #pattern
					self._content = string.sub(txt, self.startIdx, self.endIdx) 
					if node[5] then
						return self:processNext(txt, idx, len)
					end
					return idx
				elseif self:searchNode(txt, idx, len, InlineNodes) then
					local piece = Piece.new()
					local _next = piece:process(txt, idx, len)
					if _next == idx then 
						break
					end
					if piece._node == Nodes["txt"] then
						break
					end
					self._childs = self._childs or {}
					table.insert(self._childs, piece)
					idx = _next
				else 
					idx = idx+1
				end
			else
				idx = idx+1
			end
		end
	else
		while idx <= len do
			if self:isCheckChar(txt, idx) then
				if self:searchNode(txt, idx, len, InlineNodes) then
					self._node = Nodes["txt"]
					self.startIdx = startIdx
					self.endIdx = idx-1
					self._content = string.sub(txt, self.startIdx, self.endIdx)
					return idx
				end
			end
			idx = idx+1
		end
	end
	self._node = Nodes["txt"]
	self.startIdx = startIdx
	self.endIdx = len
	self._content = string.sub(txt, self.startIdx, self.endIdx)
	return startIdx + len
end

function Piece:render(parent)
	local node = self._node
	if node == Nodes["txt"] then
		if is_empty_txt(self._content) then
			return
		end
	end
	local wdt
	if node[5] then
		local strs = string_multi_split(self._content1, " ")
		local props = {}
		local url
		if #strs > 1 then
			local lStr = strs[#strs]
			local len = #lStr
			if (string.byte(lStr, 1) == string.byte("'") or string.byte(lStr, 1) == string.byte('"')) 
				and (string.byte(lStr, len) == string.byte("'") or string.byte(lStr, len) == string.byte('"')) then
				props.title = string.sub(lStr, 1, len - 1)
				url = string.sub(self._content1, 0, #self._content1 - len - 1)
			end
		end
		url = url or self._content1
		if node[1] == 'a' then
			props.href = url
			wdt = widget(node[1], props, self._content or "")
		else
			props.src = url
			props.alt = self._content or ""
			wdt = widget(node[1], props)
		end
	else
		wdt = widget(node[1])
	end
	parent:set(wdt)
	if self._childs then
		for _,child in ipairs(self._childs) do
			child:render(wdt)
		end
	-- elseif node[1] then
	-- 	if node[1] ~= 'a' then
	-- 		wdt:set(widget(node[1], self._content))
	-- 	end
	else
		if not node[5] then
			wdt:set(self._content)
		end
	end
end

-------------------------------------------------
-------------------------------------------------
local Block = class("Block")

function Block:ctor()
	self._childs = {}
end

function Block:searchNode(txt, idx, len, nodes)
	local charCode = string.byte(txt, idx)
	if charCode >= 128 then return end
	if charCode >= 48 and charCode <= 57 then
		idx = idx + 1
		for i=idx,len do
			charCode = string.byte(txt, idx)
			if charCode < 48 or charCode > 57 then
				if string.byte(txt, idx) == string.byte(".") and string.byte(txt, idx + 1) == string.byte(" ") then
					self.startIdx = idx + 2
					return Nodes["ol"]
				end
				return
			end
		end
	elseif charCode < 65 or (charCode > 90 and charCode < 97) or charCode > 122 then
		local pattern
		for _,node in ipairs(nodes) do
			pattern = node[2]
			if string.byte(pattern, 1) == string.byte(txt, idx) then
				for j=1,#pattern do
					if string.byte(pattern, j) ~= string.byte(txt, idx + j - 1) then
						node = nil
						break
					end
				end
				if node then
					-- if node[3] then
					-- 	assert(node[3] == "```")
					-- 	local ret = string.find(txt, node[3], idx + #pattern)
					-- 	if ret then
					-- 		self.startIdx = idx + #pattern
					-- 		return node
					-- 	end
					-- else
					self.startIdx = idx + #pattern
					return node
					-- end
				end
			end
		end
	end
end

function Block:searchPatternTail(txt, idx, len, pattern)
	local charCode = string.byte(txt, idx)
	if charCode >= 128 then return end
	if charCode < 48 or (charCode > 57 and charCode < 65) or
		(charCode > 90 and charCode < 97) or charCode > 122 then
		local k
		local plen = #pattern
		for i=plen,1, -1 do
			k = len - (plen - i)
			if k < idx or string.byte(pattern, i) ~= string.byte(txt, k) then
				return
			end
		end
		return true
	end
end

function Block:quickParse(lines, point)
	local txt = lines[point]
	point = point+1
	self._line = txt
	local idx = 1
	local len = #txt
	for i=idx,len do
		if string.byte(txt, i) ~= " " then
			idx = i
			break
		end
	end
	self._spaceNum = idx
	if self._spaceNum >= 4 then
		self._node = Nodes["pre"]
		self.startIdx = idx
		self.endIdx = len
		return point
	end
	local node = self:searchNode(txt, idx, len, HeaderNodes)
	if node then
		self._node = node
		idx = self.startIdx
		local pattern = node[3]
		if not pattern then
			self.endIdx = len
			return point
		else
			if idx < len then
				if self:searchPatternTail(txt, idx, len, pattern) then
					self.endIdx = len - #pattern
					return point
				end
			end
			local line
			local tmps = {}
			for i=point,#lines do
				line = lines[i]
				if self:searchPatternTail(line, 1, #line, pattern) then
					self.endIdx = len
					self._lines = tmps
					point = i + 1
					return point
				end
				table.insert(tmps, (line .. "\n"))
			end
		end
	end
	self._node = Nodes["txt"]
	self.startIdx = 1
	self.endIdx = len
	return point
end

function Block:searchTable(txt, idx, len)
	local char, tr
	local tbl = {}
	for i=idx,len do
		char = string.byte(txt, i)
		if not tr then
			tr = {}
			table.insert(tbl, tr)
		else
			if char == string.byte("|") then
				if not tr.istr then return end
				if #tr == 1 then
					table.insert(tr, 0)
				end
				tr = {}
				table.insert(tbl, tr)
			end
		end
		if char == string.byte(":") then
			table.insert(tr, 1)
		elseif char == string.byte("-") then
			tr.istr = true
			if #tr == 0 then
				table.insert(tr, 0)
			end
		elseif char == string.byte("|") then
		else
			return
		end
	end
	tr = tbl[#tbl]
	if #tr ~= 2 then
		table.remove(tbl)
	end
	for _,tr in ipairs(tbl) do
		tr.istr = nil
		if #tr ~= 2 then 
			return
		end
	end
	self.tbl = tbl
	self._node = Nodes["table"]
	return true
end

function Block:extraProcess()
	if self._node[1] == "hr" then
		local txt = self._line
		local len = #txt
		local sameChar = string.byte(self._node[2], 1)
		for i=2,len do
			if string.byte(txt, i) ~= sameChar then
				self._node = Nodes["txt"]
				self.startIdx = 1
				self.endIdx = len
				break
			end
		end
	end
	if self._node[1] == "txt" then
		local char = string.byte(self._line, self._spaceNum)
		if char == string.byte("|") or char == string.byte(":") or char == string.byte("-") then
			self:searchTable(self._line, self._spaceNum, self.endIdx)
		end
	end
end

function Block:process(lines, point)
	local line = lines[point]
	if #line > 0 then
		point = self:quickParse(lines, point)
		self:extraProcess()
	else
		point = point+1
		self._node = Nodes["br"]
	end
	return point
end

function Block:searchPieces()
	if self._node[1] == "hr" then
		return
	end
	if self._lines or not self._line then
		return
	end
	if self.startIdx > self.endIdx then
		return
	end
	local txt = self._line
	local idx = self.startIdx
	local endIdx = self.endIdx
	local piece, _next
	while idx <= endIdx do
		piece = Piece.new()
		_next = piece:process(txt, idx, endIdx)
		table.insert(self._childs, piece)
		if _next == idx then break end
		idx = _next
	end
end

function Block:render(parent)
	local wdt = widget(self._node[1])
	if parent then
		parent:set(wdt)
	end
	if self._node[1] == "pre" then
		local codeName = string.sub(self._line, self.startIdx, self.endIdx)
		local codeTxt =  table.concat(self._lines)
		local codes = ""
		local charCode
		for i=1,#codeTxt do
			charCode = string.byte(codeTxt, i)
			if charCode<=255 then
				codes = codes.. "&#"..charCode
			else
				codes = codes.. string.char(charCode)
			end
		end
		codeTxt = codes
		wdt:set(widget("code",  codeTxt))
		wdt:set({class = "prettyprint language-"..codeName})
		return wdt
	end
	local childs = self._childs
	if not childs or #childs == 0 then
		return wdt
	end
	assert(self._node[1] ~= "txt")
	for _,child in ipairs(childs) do
		child:render(wdt)
	end
	return wdt
end

-------------------------------------------------
-------------------------------------------------
local GroupBlock = class("GroupBlock", Block)
function GroupBlock:searchPieces()
	local childs = self._childs
	if not childs then return end
	for _,child in ipairs(childs) do
		child:searchPieces()
	end
end

-------------------------------------------------
-------------------------------------------------
local ComBlock = class("ComBlock", GroupBlock)
function ComBlock:ctor()
	self._childs = {}
end

function ComBlock:process(blocks, point, len, fblock)
	table.insert(self._childs, fblock)
	self._node = fblock._node
	fblock._node = Nodes["li"]
	point = point+1
	local block, _next, continue
	while point <= len do
		block = blocks[point]
		if fblock.level == 1 and block._spaceNum == 3 then
			block.level = 2
			local comBlock = ComBlock.new()
			_next = comBlock:process(blocks, point, len, block)
			if _next ~= point then
				table.insert(self._childs, comBlock)
				point = _next
				continue = true
			end
		end
		if not continue  then
			if block._node ~= self._node then
				return point
			end
			block._node = Nodes["li"]
			table.insert(self._childs, block)
			point = point+1
		else
			continue = nil
		end
	end
	return point
end

-------------------------------------------------
-------------------------------------------------
local TableBlock = class("TableBlock", GroupBlock)
function TableBlock:ctor()
	self._childs = {}
end

function TableBlock:process(blocks, point, len, cbBlocks)
	local originPoint = point
	local ctlBlock = blocks[point]
	local num = #ctlBlock.tbl
	local headBlock = cbBlocks[#cbBlocks]
	if not headBlock or headBlock._node[1] ~= "txt" then
		return originPoint
	end

	local ths = string_multi_split(headBlock._line, "|")
	if #ths ~= num then
		return originPoint
	end
	self._node = ctlBlock._node
	self.headBlock = headBlock
	table.remove(cbBlocks)
	self.ctlBlock = ctlBlock

	local trBlock = TableBlock.new()
	trBlock._node = Nodes["tr"]
	local pBlock
	for _,th in ipairs(ths) do
		pBlock = Block.new()
		pBlock._node = Nodes["th"]
		pBlock._line = th
		pBlock.startIdx = 1
		pBlock.endIdx = #pBlock._line
		table.insert(trBlock._childs, pBlock)
	end
	local capBlock = cbBlocks[#cbBlocks]
	if capBlock and capBlock._node[1] == "txt" then
		local line = capBlock._line
		if string.byte(line, 1) == string.byte("|") and string.byte(line, #line) == string.byte("|") then
			pBlock = Block.new()
			pBlock._node = Nodes["caption"]
			pBlock._line = string.sub(line, 2, #line-1)
			pBlock.startIdx = 1
			pBlock.endIdx = #pBlock._line
			table.insert(self._childs, pBlock)
			self.capBlock = capBlock
			table.remove(cbBlocks)
		end
	end
	local theadBlock = TableBlock.new()
	theadBlock._node = Nodes["thead"]
	table.insert(theadBlock._childs, trBlock)
	table.insert(self._childs, theadBlock)
	local block
	point = point+1
	local tbodyBlock = TableBlock.new()
	tbodyBlock._node = Nodes["tbody"]
	while point <= len do
		block = blocks[point]
		if block._node[1] == "txt" then
			local tds = string_multi_split(block._line, "|")
			if #tds >= 1 then
				self.bodyBlocks = self.bodyBlocks or {}
				table.insert(self.bodyBlocks, block)
				trBlock = TableBlock.new()
				trBlock._node = Nodes["tr"]
				for _,td in ipairs(tds) do
					pBlock = Block.new()
					pBlock._node = Nodes["td"]
					pBlock._line = td
					pBlock.startIdx = 1
					pBlock.endIdx = #pBlock._line
					table.insert(trBlock._childs, pBlock)
				end
				table.insert(tbodyBlock._childs, trBlock)
			else
				break
			end
		else
			break
		end
		point = point+1
	end
	table.insert(self._childs, tbodyBlock)
	return point
end

-------------------------------------------------
-------------------------------------------------
local function combineBlocks(blocks)
	local cbBlocks = {}
	local point = 1
	local len = #blocks
	local block, name, _next, continue
	while point <= len do
		block = blocks[point]
		name = block._node[1]
		if name == "ul" or name == "ol" then
			local comBlock = ComBlock.new()
			block.level = 1
			_next = comBlock:process(blocks, point, len, block)
			if _next ~= point then
				table.insert(cbBlocks, comBlock)
				point = _next
				continue = true
			else
				block._node = Nodes["txt"]
			end
		else
			if name == "table" then
				local tableBlock = TableBlock.new()
				_next = tableBlock:process(blocks, point, len, cbBlocks)
				if _next ~= point then
					table.insert(cbBlocks, tableBlock)
					point = _next
					continue = true
				else
					block._node = Nodes["txt"]
				end
			end
		end
		if not continue then
			table.insert(cbBlocks, block)
			point = point+1
		else
			continue = nil
		end
	end
	for _,block in ipairs(cbBlocks) do
		if block._node == Nodes["txt"] then
			block._node = Nodes["p"]
		end
	end
	return cbBlocks
end

local function processBlock(txt)
	local blocks = {}
	local lines = string_split(txt, "\n")
	local point = 1
	local len = #lines
	local line, block, _next
	while point <= len do
		block = Block.new()
		_next = block:process(lines, point)
		table.insert(blocks, block)
		if _next == point then
			break
		end
		point = _next
	end
	blocks = combineBlocks(blocks)
	for _,block in ipairs(blocks) do
		block:searchPieces()
	end
	return blocks
end

local function setWidgetsProps(wdt, props)
	if not props or not next(props) then
		return
	end
	wdt:set(props)
	if wdt._childs then
		for _,child in ipairs(wdt._childs) do
			setWidgetsProps(child, props)
		end
	end
end

local function showDom(blocks, props)
	local html = ""
	for _,block in ipairs(blocks) do
		html = html.. block:render():echo()
	end
	return html
end

return function(text, props)
	local blocks = processBlock(text)
	return showDom(blocks, props)
end
