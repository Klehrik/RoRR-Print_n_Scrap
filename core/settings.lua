-- Settings

local options = ModOptions.new()
local file = TOML.new()

settings = file:read() or {
    enablePrinters  = true,
    enableScrappers = true,
    enableNames     = false
}

local checkbox = options:add_checkbox("enablePrinters")
checkbox:add_getter(function()
    return settings.enablePrinters
end)
checkbox:add_setter(function(value)
    settings.enablePrinters = value
    file:write(settings)
end)

local checkbox = options:add_checkbox("enableScrappers")
checkbox:add_getter(function()
    return settings.enableScrappers
end)
checkbox:add_setter(function(value)
    settings.enableScrappers = value
    file:write(settings)
end)

-- local checkbox = options:add_checkbox("enableNames")
-- checkbox:add_getter(function()
--     return settings.enableNames
-- end)
-- checkbox:add_setter(function(value)
--     settings.enableNames = value
--     file:write(settings)
-- end)