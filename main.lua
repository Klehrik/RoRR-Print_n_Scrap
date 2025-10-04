-- Print 'n' Scrap

mods["LuaENVY-ENVY"].auto()
mods["ReturnsAPI-ReturnsAPI"].auto{
    namespace = "printNScrap"
}

interactable_cards = {}

local stage_blacklist = {
    "ror-riskOfRain",
    "ror-boarBeach"
}

local function init()
    hotloaded = true
    require("./core/helper")
    require("./core/printer")
    require("./core/scrapper")
    require("./core/scrap")
end

local function add_to_stages()
    -- Add InteractableCards to stages
    -- Runs with delayed priority to account for custom stages
    for _, card in ipairs(interactable_cards) do
        
        for id = 0, #Class.Stage - 1 do
            local stage = Stage.wrap(id)
            if not Util.table_has(stage_blacklist, stage.namespace.."-"..stage.identifier) then
                stage:add_interactable(card)
                -- print("Added '"..card.identifier.."' to stage '"..stage.identifier.."'")
            end
        end
    end

    -- Add guaranteed printers in the Contact Light's Cabin room
    -- TODO
end

Initialize.add(init)
Initialize.add(Callback.Priority.AFTER, add_to_stages)

if hotloaded then
    init()
    add_to_stages()
end