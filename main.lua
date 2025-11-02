-- Print 'n' Scrap

mods["LuaENVY-ENVY"].auto()
envy = mods["LuaENVY-ENVY"]

mods["ReturnsAPI-ReturnsAPI"].auto{
    namespace   = "printNScrap",
    mp          = true
}

PnS = {}

-- Require core files
Initialize.add(Callback.Priority.BEFORE, function()
    require("./core/helper")
    require("./core/printer")
    require("./core/scrapper")
    require("./core/wrapper")
    require("./core/content")
    require("./core/settings")
end)

-- ENVY public setup
function public.setup()
    return Util.table_shallow_copy(PnS)
end