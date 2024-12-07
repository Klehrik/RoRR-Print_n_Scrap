-- Printer

local sPrinter = Resources.sprite_load("printNScrap", "printer", PATH.."sprites/printer.png", 23, 36, 48)

local spawn_tiers     = {Item.TIER.common, Item.TIER.uncommon, Item.TIER.rare, Item.TIER.boss}
local spawn_costs     = {65, 75, 140, 140}    -- Small chest is 50, large chest is 110, and basic shrine is 65
local spawn_weights   = {6, 3, 1, 1}          -- Small/large chests and basic shrines are 8
local spawn_rarities  = {1, 1, 4, 4}          -- Small/large chests are 1, and drone upgraders/recyclers are 4

local item_colors = {Color.ITEM_WHITE, Color.ITEM_GREEN, Color.ITEM_RED, 0, Color.ITEM_YELLOW}
local text_colors = {"", "<g>", "<r>", "", "<y>"}
local tier_names = {"common", "uncommon", "rare", "", "boss"}
local scrap_names = {"White", "Green", "Red", "", "Yellow"}

local animation_held_time   = 80
local animation_print_time  = 32
local box_x_offset          = -18   -- Location of the input box of the printer relative to the origin
local box_y_offset          = -22
local box_input_scale       = 0.4   -- Item scale when it enters the input box

local ban_list = {
    "printNScrap-scrapWhite",
    "printNScrap-scrapGreen",
    "printNScrap-scrapRed",
    "printNScrap-scrapYellow"
}


for printer_type = 1, #spawn_tiers do

    -- Create Object
    local obj = Object.new("printNScrap", "printer"..printer_type, Object.PARENT.interactable)
    obj.obj_sprite  = sPrinter
    obj.obj_depth   = 1

    -- Create Interactable Card
    local card = Interactable_Card.new("printNScrap", "printer"..printer_type)
    card.object_id = obj
    card.required_tile_space            = 2.0
    card.spawn_with_sacrifice           = true
    card.spawn_cost                     = spawn_costs[printer_type]
    card.spawn_weight                   = spawn_weights[printer_type]
    card.default_spawn_rarity_override  = spawn_rarities[printer_type]

    -- Add Interactable Card to stages
    Stage.find("ror-desolateForest"     ):add_interactable(card)
    Stage.find("ror-driedLake"          ):add_interactable(card)
    Stage.find("ror-dampCaverns"        ):add_interactable(card)
    Stage.find("ror-skyMeadow"          ):add_interactable(card)
    Stage.find("ror-ancientValley"      ):add_interactable(card)
    Stage.find("ror-sunkenTombs"        ):add_interactable(card)
    Stage.find("ror-magmaBarracks"      ):add_interactable(card)
    Stage.find("ror-hiveCluster"        ):add_interactable(card)
    Stage.find("ror-templeOfTheElders"  ):add_interactable(card)

    local printer_tier = spawn_tiers[printer_type]


    -- Callbacks

    obj:onCreate(function(inst)
        local instData = inst:get_data()

        -- Item entry location
        instData.box_x = inst.x + box_x_offset
        instData.box_y = inst.y + box_y_offset

        -- Pick printer item
        -- Make sure that the item is:
        --      of the same rarity
        --      not in the item ban list
        --      is actually unlocked (if applicable)
        local items, item = Item.find_all(printer_tier), nil
        while #items > 0 do
            local pos = gm.irandom_range(1, #items)
            item = items[pos]

            if  item.tier == printer_tier
                and item.namespace and item.identifier
                and (not Helper.table_has(ban_list, item.namespace.."-"..item.identifier))
                and item:is_unlocked()
            then break end

            table.remove(items, pos)
        end
        instData.item = item

        -- Set prompt text
        inst.text = "Print "..text_colors[item.tier + 1]..Language.translate_token(item.token_name).." <y>(1 "..tier_names[item.tier + 1].." item)"
        inst.text_offset_x = -8
        inst.text_offset_y = -20
    end)


    obj:onDraw(function(inst)
        local instData = inst:get_data()
        local actor = inst.activator

        -- Draw hovering item
        local frame = gm.variable_global_get("_current_frame")
        draw_item_sprite(instData.item.sprite_id,
                        inst.x + 10,
                        inst.y - 33 + gm.dsin(frame * 1.333) * 3,
                        0.8,
                        0.8 + gm.dsin(frame * 4) * 0.25)

        -- Prevent backwards animation looping (after printer reset)
        if inst.image_speed < 0.0 and inst.image_index <= 0 then
            inst.image_speed = 0.0
        end


        -- Initial activation
        if inst.active == 2 then
            -- Check if the user has scrap for this tier
            local item = Item.find("printNScrap-scrap"..scrap_names[instData.item.tier + 1])
            if item and actor:item_stack_count(item, Item.STACK_KIND.normal) > 0 then
                instData.taken = item
                
            -- Check if the user has a valid item to print with
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
                        if actor:item_stack_count(item, Item.STACK_KIND.normal) > 0 then
                            if  item.tier == instData.item.tier
                            and item.value ~= instData.item.value then
                                table.insert(items, item)
                            end
                        end
                    end
                end

                -- Stop printer operation if no valid items
                if #items <= 0 then
                    inst.value:sound_play_at(gm.constants.wError, 1.0, 1.0, inst.x, inst.y, 1.0)
                    inst:set_active(0)
                    return
                end
    
                -- Pick a random valid item
                instData.taken = items[gm.irandom_range(1, #items)]
            end
        
            -- Remove item from inventory
            actor:item_remove(instData.taken)
        
            -- Start printer animation
            instData.animation_time = 0
            inst.value:sound_play_at(gm.constants.wDroneRecycler_Activate, 1.0, 1.0, inst.x, inst.y, 1.0)
            inst:set_active(3)

        
        -- Draw item above player
        elseif inst.active == 3 then
            draw_item_sprite(instData.taken.sprite_id,
                            actor.x,
                            actor.y - 48)

            if instData.animation_time < animation_held_time then instData.animation_time = instData.animation_time + 1
            else
                instData.taken_x = actor.x
                instData.taken_y = actor.y - 48
                instData.taken_scale = 1.0
                inst:set_active(4)
            end


        -- Slide item towards input box
        elseif inst.active == 4 then
            draw_item_sprite(instData.taken.sprite_id,
                            instData.taken_x,
                            instData.taken_y,
                            instData.taken_scale)
        
            instData.taken_x = gm.lerp(instData.taken_x, instData.box_x, 0.1)
            instData.taken_y = gm.lerp(instData.taken_y, instData.box_y, 0.1)
            instData.taken_scale = gm.lerp(instData.taken_scale, box_input_scale, 0.1)

            if gm.point_distance(instData.taken_x, instData.taken_y, instData.box_x, instData.box_y) < 1 then
                instData.animation_time = 0
                inst:set_active(5)
            end


        -- Close box for a bit
        elseif inst.active == 5 then
            inst.image_speed = 1.0

            if inst.image_index == 10 then inst.value:sound_play_at(gm.constants.wDroneRecycler_Recycling, 1.0, 1.0, inst.x, inst.y, 1.0)
            elseif inst.image_index >= 21 then
                if instData.animation_time < animation_print_time then instData.animation_time = instData.animation_time + 1
                else inst:set_active(6)
                end
            end


        -- Create item drop and reset
        elseif inst.active == 6 then
            inst.image_speed = -1.0

            local created = instData.item:create(instData.box_x, instData.box_y, inst)
            created.is_printed = true

            inst:set_active(0)

        end
    end)

end