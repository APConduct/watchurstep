---
---@param str string
---@param delim string
---@return table
local function split(str, delim)
    local result = {}

    for part in str:gmatch("[^" .. delim .. "]+") do
        table.insert(result, part)
    end

    -- make tostring function like a list ([ 1, 2, 3 ])
    local ts = function()
        local _str = "["
        for i, v in ipairs(result) do
            if i > 1 then
                _str = _str .. ","
            end
            _str = _str .. " " .. v
        end
        return _str .. " ]"
    end
    setmetatable(result, { __tostring = ts })

    return result
end

--test
local str = "hello,world"
local result = split(str, ",")
print(result[1]) -- "hello"
print(result[2]) -- "world"

print(result)    -- "hello,world"
