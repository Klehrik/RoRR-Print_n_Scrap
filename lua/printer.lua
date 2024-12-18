-- Printer

local sPrinter = Resources.sprite_load("printNScrap", "printer", PATH.."sprites/printer.png", 23, 36, 48)

local spawn_tiers     = {Item.TIER.common, Item.TIER.uncommon, Item.TIER.rare, Item.TIER.boss}
local spawn_costs     = {65, 75, 140, 140}    -- Small chest is 50, large chest is 110, and basic shrine is 65
local spawn_weights   = {6, 3, 1, 1}          -- Small/large chests and basic shrines are 8
local spawn_rarities  = {1, 1, 4, 4}          -- Small/large chests are 1, and drone upgraders/recyclers are 4

local item_colors = {Color.ITEM_WHITE, Color.ITEM_GREEN, Color.ITEM_RED, 0, Color.ITEM_YELLOW}
local text_colors = {"", "<g>", "<r>", "", "<y>"}
local tier_tokens = {"common", "uncommon", "rare", "", "boss"}
local scrap_names = {"White", "Green", "Red", "", "Yellow"}

local animation_held_time   = 80
local animation_print_time  = 32
local box_x_offset          = -18   -- Location of the input box of the printer relative to the origin
local box_y_offset          = -22
local box_input_scale       = 0.4   -- Item scale when it enters the input box

local blacklist = {
    "printNScrap-scrapWhite",
    "printNScrap-scrapGreen",
    "printNScrap-scrapRed",
    "printNScrap-scrapYellow"
}

local stage_blacklist = {
    "ror-riskOfRain",
    "ror-boarBeach"
}


-- Packets
local packetCreate = Packet.new()
packetCreate:onReceived(function(message, player)
    local inst = message:read_instance()
    local item = Item.wrap(message:read_ushort())

    local instData = inst:get_data()
    instData.item = item

    -- Set prompt text
    inst.translation_key = "interactable.printer"
    inst.text = Language.translate_token(inst.translation_key..".text")
    inst.text = inst.text:gsub("ITEM", text_colors[item.tier + 1]..Language.translate_token(item.token_name))
    inst.text = inst.text:gsub("TIER", Language.translate_token("tier."..tier_tokens[item.tier + 1]))

    instData.setup = true
end)


local packetUse = Packet.new()
packetUse:onReceived(function(message, player)
    local inst = message:read_instance()
    local taken = Item.wrap(message:read_ushort())

    local instData = inst:get_data()
    instData.taken = taken

    -- Start printer animation
    instData.animation_time = 0
    inst:sound_play_at(gm.constants.wDroneRecycler_Activate, 1.0, 1.0, inst.x, inst.y)
    inst.active = 3
end)


-- Create printers
for printer_type = 1, #spawn_tiers do

    -- Create Object
    local obj = Object.new("printNScrap", "printer"..printer_type, Object.PARENT.interactable)
    obj.obj_sprite  = sPrinter
    obj.obj_depth   = 1

    -- Create Interactable Card
    local card = Interactable_Card.new("printNScrap", "printer"..printer_type)
    card.object_id                      = obj
    card.required_tile_space            = 2
    card.spawn_with_sacrifice           = true
    card.spawn_cost                     = spawn_costs[printer_type]
    card.spawn_weight                   = spawn_weights[printer_type]
    card.default_spawn_rarity_override  = spawn_rarities[printer_type]

    -- Add Interactable Card to stages
    local stages = Stage.find_all()
    for _, stage in ipairs(stages) do
        if not Helper.table_has(stage_blacklist, stage.namespace.."-"..stage.identifier) then
            stage:add_interactable(card)
        end
    end

    local printer_tier = spawn_tiers[printer_type]


    -- Callbacks

    obj:onCreate(function(inst)
        local instData = inst:get_data()

        -- Item entry location
        instData.box_x = inst.x + box_x_offset
        instData.box_y = inst.y + box_y_offset

        -- Set prompt text offset
        inst.text_offset_x = -8
        inst.text_offset_y = -20

        if Net.is_client() then return end
        instData.setup = true

        -- Pick printer item
        -- Make sure that the item is:
        --      of the same rarity
        --      not in the item ban list
        --      is actually unlocked (if applicable)
        local item
        local items = Item.find_all(printer_tier, Item.ARRAY.tier)
        while #items > 0 do
            local pos = gm.irandom_range(1, #items)
            item = items[pos]

            if  item.tier == printer_tier
                and item.namespace and item.identifier
                and (not Helper.table_has(blacklist, item.namespace.."-"..item.identifier))
                and item:is_unlocked()
            then break end

            table.remove(items, pos)
        end
        instData.item = item

        -- Set prompt text
        inst.translation_key = "interactable.printer"
        inst.text = Language.translate_token(inst.translation_key..".text")
        inst.text = inst.text:gsub("ITEM", text_colors[item.tier + 1]..Language.translate_token(item.token_name))
        inst.text = inst.text:gsub("TIER", Language.translate_token("tier."..tier_tokens[item.tier + 1]))
    end)


    obj:onCheckCost(function(inst, actor, cost, cost_type, can_activate)
        local instData = inst:get_data()

        -- Check if the actor has at least one valid item
        local size = #actor.inventory_item_order
        if size > 0 then
            for i = 0, size - 1 do
                local item = Item.wrap(actor.inventory_item_order:get(i))

                -- Valid item if:
                --      at least one real stack
                --      the same rarity
                --      NOT the same item as the printer
                if  actor:item_stack_count(item, Item.STACK_KIND.normal) > 0
                and item.tier == instData.item.tier
                and item.value ~= instData.item.value then
                    return
                end
            end
        end

        return false
    end)


    obj:onStep(function(inst)
        local instData = inst:get_data()
        local actor = inst.activator


        -- [Host]  Send sync info to clients
        -- (Instance creation is not yet synced onCreate)
        if not instData.sent_sync and Net.is_host() then
            local message = packetCreate:message_begin()
            message:write_instance(inst)
            message:write_ushort(instData.item)
            message:send_to_all()
        end
        instData.sent_sync = true


        -- Prevent backwards animation looping (after printer reset)
        if inst.image_speed < 0.0 and inst.image_index <= 0 then
            inst.image_speed = 0.0
        end


        -- Initial activation
        if inst.active == 2 then
            -- [Client]  Wait for packet from host
            if Net.is_client() then
                inst.active = waiting_active
                return
            end

            -- Check if the actor has scrap for this tier
            local item = Item.find("printNScrap-scrap"..scrap_names[instData.item.tier + 1])
            if item and actor:item_stack_count(item, Item.STACK_KIND.normal) > 0 then
                instData.taken = item
                
            -- Pick a random valid item
            else
                local items = {}
                local size = #actor.inventory_item_order
                if size > 0 then
                    for i = 0, size - 1 do
                        local item = Item.wrap(actor.inventory_item_order:get(i))
    
                        -- Valid item if:
                        --      at least one real stack
                        --      the same rarity
                        --      NOT the same item as the printer
                        if  actor:item_stack_count(item, Item.STACK_KIND.normal) > 0
                        and item.tier == instData.item.tier
                        and item.value ~= instData.item.value then
                            table.insert(items, item)
                        end
                    end
                end

                instData.taken = items[gm.irandom_range(1, #items)]
            end
        
            -- Remove item from inventory
            actor:item_remove(instData.taken)
        
            -- Start printer animation
            instData.animation_time = 0
            inst:sound_play_at(gm.constants.wDroneRecycler_Activate, 1.0, 1.0, inst.x, inst.y)
            inst.active = 3

            -- [Host]  Send sync info to clients
            if Net.is_host() then
                local message = packetUse:message_begin()
                message:write_instance(inst)
                message:write_ushort(instData.taken)
                message:send_to_all()
            end

        
        -- Draw item above player
        elseif inst.active == 3 then
            if instData.animation_time < animation_held_time then instData.animation_time = instData.animation_time + 1
            else
                instData.taken_x = actor.x
                instData.taken_y = actor.y - 48
                instData.taken_scale = 1.0
                inst.active = 4
            end


        -- Slide item towards input box
        elseif inst.active == 4 then
            instData.taken_x = gm.lerp(instData.taken_x, instData.box_x, 0.1)
            instData.taken_y = gm.lerp(instData.taken_y, instData.box_y, 0.1)
            instData.taken_scale = gm.lerp(instData.taken_scale, box_input_scale, 0.1)

            if gm.point_distance(instData.taken_x, instData.taken_y, instData.box_x, instData.box_y) < 1 then
                instData.animation_time = 0
                inst.active = 5
            end


        -- Close box for a bit
        elseif inst.active == 5 then
            inst.image_speed = 1.0

            if inst.image_index == 10 then inst:sound_play_at(gm.constants.wDroneRecycler_Recycling, 1.0, 1.0, inst.x, inst.y)
            elseif inst.image_index >= 21 then
                if instData.animation_time < animation_print_time then instData.animation_time = instData.animation_time + 1
                else inst.active = 6
                end
            end


        -- Create item drop and reset
        elseif inst.active == 6 then
            inst.image_speed = -1.0

            local created = instData.item:create(instData.box_x, instData.box_y, inst)
            created.is_printed = true

            inst.active = 0

        end
    end)


    obj:onDraw(function(inst)
        local instData = inst:get_data()
        local actor = inst.activator

        if not instData.setup then return end


        -- Draw hovering item
        local frame = gm.variable_global_get("_current_frame")
        draw_item_sprite(instData.item.sprite_id,
                        inst.x + 10,
                        inst.y - 33 + gm.dsin(frame * 1.333) * 3,
                        0.8,
                        0.8 + gm.dsin(frame * 4) * 0.25)

        
        -- Draw item above player
        if inst.active == 3 then
            draw_item_sprite(instData.taken.sprite_id,
                            actor.x,
                            actor.y - 48)


        -- Slide item towards input box
        elseif inst.active == 4 then
            draw_item_sprite(instData.taken.sprite_id,
                            instData.taken_x,
                            instData.taken_y,
                            instData.taken_scale)

        end
    end)

end