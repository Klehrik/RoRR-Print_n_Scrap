-- Print n Scrap
-- Klehrik

mods["MGReturns-ENVY"].auto()
mods["RoRRModdingToolkit-RoRR_Modding_Toolkit"].auto(true)

PATH = _ENV["!plugins_mod_folder_path"].."/"

waiting_active = 628    -- random number

-- Note on Alarm usage:
-- Have to delay packet sending by 1 frame because the packet is sometimes
-- instantaneous (at least with self-testing) and runs BEFORE other stuff



-- ========== Main ==========

Initialize(function()
    require("./lua/helper")
    require("./lua/printer")
    require("./lua/scrapper")
    require("./lua/scrap")
end)


Callback.add("onStageStart", "printNScrap-onStageStart", function()
    -- Create guaranteed printers in the Contact Light's Cabin room
    local stage = Stage.wrap(gm.variable_global_get("stage_id"))
    local nsid = stage.namespace.."-"..stage.identifier
    if nsid == "ror-riskOfRain" then
        for r = 0, 2 do
            Object.find("printNScrap-printer"..(r + 1)):create(7650 + (160 * r), 3264)
        end
    end
end, true)