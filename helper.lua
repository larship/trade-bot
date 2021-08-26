function log(text)
    local ms = string.sub(tostring(math.floor(os.clock() * 1000)), -3)
    local file = io.open(getScriptPath() .. "\\log.txt", "a");
    file:write(os.date("%d-%m-%Y %X") .. "." .. ms .. ": " .. text .. "\n")
    file:close()
end

function tableToString(val, name, depth)
    depth = depth or 0
    local text = string.rep(" ", depth)

    if name then
        text = text .. name .. " = "
    end

    if type(val) == "table" then
        text = text .. "{\n"

        for key, value in pairs(val) do
            text =  text .. tableToString(value, key, depth + 1) .. ",\n"
        end

        text = text .. string.rep(" ", depth) .. "}"
    elseif type(val) == "number" then
        text = text .. tostring(val)
    elseif type(val) == "string" then
        text = text .. string.format("%q", val)
    elseif type(val) == "boolean" then
        text = text .. (val and "true" or "false")
    else
        text = text .. "\"[unserializable datatype:" .. type(val) .. "]\""
    end

    return text
end

function round(val, fractionCount)
    local multiplier = 10 ^ (fractionCount or 0)
    return math.floor(val * multiplier + 0.5) / multiplier
end

function getTableSum(val, startPos, count)
    local sum = 0
    local counter = 0

    for i = startPos, #val do
        sum = sum + val[i]
        counter = counter + 1

        if counter >= count then
            break
        end
    end

    return sum
end
