-- Print n Scrap
-- Klehrik

local envy = mods["MGReturns-ENVY"]
envy.auto()
mods["RoRRModdingToolkit-RoRR_Modding_Toolkit"].auto()

PATH = _ENV["!plugins_mod_folder_path"].."/"



-- ========== Main ==========

Initialize(function()
    require("./lua/helper")
    require("./lua/printer")
    require("./lua/scrapper")
    require("./lua/scrap")
end)