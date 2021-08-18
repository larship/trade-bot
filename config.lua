local Config = {}

function initConfig()
	Config = {}

	local file = io.open(getScriptPath() .. "\\.env", "r")
    if not file then
        return nil
    end

    local value = file:read("l")

    while value do
        for key, val in string.gmatch(value, "(.+)=(.+)") do
            Config[key:gsub("%s+", "")] = val:gsub("%s+", "")
        end

        value = file:read("l")
    end

    file:close()
end

function getConfigValue(value)
	return Config[value]
end
