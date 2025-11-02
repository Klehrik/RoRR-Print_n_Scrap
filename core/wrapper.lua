-- Wrapper

printer_cards            = {}
printer_stage_blacklist  = {}
scrapper_stage_blacklist = {}
item_blacklist           = {}


Hook.add_pre(gm.constants.run_create, function(self, other, result, args)
    local command = Artifact.find("command").active

    -- Add/remove InteractableCards to/from stages
    for id = 0, #Class.Stage - 1 do
        local stage = Stage.wrap(id)

        if  settings.enablePrinters
        and (not command)
        and (not printer_stage_blacklist[id]) then
            for _, card in ipairs(printer_cards) do
                stage:add_interactable(card)
            end
        else
            for _, card in ipairs(printer_cards) do
                stage:remove_interactable(card)
            end
        end

        if  settings.enableScrappers
        and (not scrapper_stage_blacklist[id]) then
            stage:add_interactable(InteractableCard.find("scrapper"))
        else
            stage:remove_interactable(InteractableCard.find("scrapper"))
        end
    end
end)


--[[
Returns interactable cards for all printers
]]
PnS.get_printer_cards = function()
    return Util.table_shallow_copy(printer_cards)
end


PnS.ban_printers = function(stage)
    printer_stage_blacklist[Wrap.unwrap(stage)] = true
end


PnS.ban_scrappers = function(stage)
    scrapper_stage_blacklist[Wrap.unwrap(stage)] = true
end


PnS.ban_item = function(item)
    item_blacklist[Wrap.unwrap(item)] = true
end