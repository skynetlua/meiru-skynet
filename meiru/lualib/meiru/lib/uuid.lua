

local function num_to_num36(num)
    local num36 = {}
    while num > 0 do
        local remainder = num%36
        if remainder>9 then
            table.insert(num36,1,string.char(remainder-10+97))
        else
            table.insert(num36,1,string.char(remainder+48))
        end
        num = math.floor(num/36)
    end
    return table.concat(num36,"")
end

local __suid = 1
math.randomseed(os.time())
local function generate_uuid()
    local sources = {
        num_to_num36(os.time()),
        num_to_num36(math.random(100000000, 1000000000-1)),
        num_to_num36(__suid),
    }
    __suid = __suid+1
    local id = table.concat(sources)
    return id
end

return generate_uuid
