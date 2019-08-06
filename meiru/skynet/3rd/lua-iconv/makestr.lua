
local fp = assert(io.open(arg[1], "rb"))
local str = assert(fp:read("*a"))
fp:close()

local i
local c = 0
local ostr = "local xxxxxxxxxxx = \""
for i = 1, string.len(str) do
  ostr = ostr .. "\\" .. string.byte(string.sub(str, i, i+1))
  if string.len(ostr) > 72 then
    io.write(ostr .. "\"\n")
    ostr = ".. \""
  end
end
io.write(ostr .. "\"\n")


