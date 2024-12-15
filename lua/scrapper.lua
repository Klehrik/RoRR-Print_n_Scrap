-- Scrapper

local sScrapper = Resources.sprite_load("printNScrap", "scrapper", PATH.."sprites/scrapper.png", 1, 10, 25)

local animation_held_time   = 80
local animation_print_time  = 38
local hole_x_offset         = 0     -- Location of the hole of the scrapper relative to the origin
local hole_y_offset         = -26
local hole_input_scale      = 0     -- Item scale when it enters the scrapper

local max_stack = 10    -- Amount of stacks that can be scrapped at once

local scrap_items = {
    "printNScrap-scrapWhite",
    "printNScrap-scrapGreen",
    "printNScrap-scrapRed",
    "",
    "printNScrap-scrapYellow"
}


-- Create Object
local obj = Object.new("printNScrap", "scrapper", Object.PARENT.interactableCrate)
obj.obj_sprite  = sScrapper
obj.obj_depth   = 1

-- Create Interactable Card
local card = Interactable_Card.new("printNScrap", "scrapper")
card.object_id = obj
card.required_tile_space            = 1
card.spawn_with_sacrifice           = true
card.spawn_cost                     = 65
card.spawn_weight                   = 3
card.default_spawn_rarity_override  = 1
card.decrease_weight_on_spawn       = true

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


-- Callbacks

obj:onCreate(function(inst)
    inst.is_scrapper = true     -- Flag for other crate-related mods

    -- Item entry location
    local instData = inst:get_data()
    instData.hole_x = inst.x + hole_x_offset
    instData.hole_y = inst.y + hole_y_offset

    -- Set prompt text
    inst.translation_key = "interactable.scrapper"
    inst.text = Language.translate_token(inst.translation_key..".text")
end)


obj:onCheckCost(function(inst, actor, cost, cost_type, can_activate)
    local instData = inst:get_data()

    -- Check if the actor has any items to scrap
    local size = #actor.inventory_item_order
    if size > 0 then
        for i = 0, size - 1 do
            local item = Item.wrap(actor.inventory_item_order:get(i))

            if not Helper.table_has(scrap_items, item.namespace.."-"..item.identifier) then
                return
            end
        end
    end

    return false
end)


obj:onStep(function(inst)
    local instData = inst:get_data()
    local actor = inst.activator


    if inst.active == 0 then
        instData.populate = false


    -- Initial activation (opened item picker UI)
    elseif inst.active == 1 then
        if not instData.populate then
            instData.populate = true

            -- Add items to contents
            local arr = Array.new()
            instData.contents_data = {} -- Extra information
            local size = #actor.inventory_item_order
            for i = 0, size - 1 do
                local item = Item.wrap(actor.inventory_item_order:get(i))
                if not Helper.table_has(scrap_items, item.namespace.."-"..item.identifier) then
                    arr:push(item.object_id)
                    table.insert(instData.contents_data, {
                        item    = item,
                        count   = actor:item_stack_count(item)
                    })
                end
            end
            inst.contents = arr
        end


    -- Set active to 3 to ignore default behavior
    elseif inst.active == 2 then
        inst.active = 3


    -- Scrapper animation init
    elseif inst.active == 3 then
        -- Get selected item
        local item_data = instData.contents_data[inst.selection + 1]
        instData.taken = item_data.item
        instData.taken_count = math.min(item_data.count, max_stack)

        -- Remove item from inventory
        actor:item_remove(instData.taken, instData.taken_count)
        
        -- Start scrapper animation
        instData.animation_time = 0
        instData.animation_items = {}
        for i = 1, instData.taken_count do
            -- x and y are offsets from the actor's position here
            table.insert(instData.animation_items, {
                sprite  = instData.taken.sprite_id,
                x       = ((instData.taken_count - 1) * -17) + ((i - 1) * 34),
                y       = -48,
                scale   = 1.0
            })
        end
        inst:sound_play_at(gm.constants.wDroneRecycler_Activate, 1.0, 1.0, inst.x, inst.y)
        free_actor(actor)
        inst.last_move_was_mouse = true
        inst.owner = -4
        inst.did_alarm = false
        inst.fade_alpha = 0.0
        inst.active = 4

        
    -- Draw items above player
    elseif inst.active == 4 then
        if instData.animation_time < animation_held_time then instData.animation_time = instData.animation_time + 1
        else
            -- Turn offsets into absolute positions
            for _, item in ipairs(instData.animation_items) do
                item.x = actor.x + item.x
                item.y = actor.y + item.y
            end
            inst.active = 5
        end


    -- Slide items towards hole
    elseif inst.active == 5 then
        local item = instData.animation_items[1]
        if gm.point_distance(item.x, item.y, instData.hole_x, instData.hole_y) < 1 then
            instData.animation_time = 0
            inst.active = 6
        end


    -- Delay for scrapping sfx
    elseif inst.active == 6 then
        if instData.animation_time < animation_print_time then instData.animation_time = instData.animation_time + 1
        else inst.active = 7
        end

        if instData.animation_time == 6 then
            inst:sound_play_at(gm.constants.wDroneRecycler_Recycling, 1.0, 1.0, inst.x, inst.y)
        end


    -- Create scrap drop(s) and reset
    elseif inst.active == 7 then
        local scrap = Item.find(scrap_items[instData.taken.tier + 1])

        for i = 1, instData.taken_count do
            local created = scrap:create(instData.hole_x, instData.hole_y, inst)
            created.is_scrap = true
        end

        inst.active = 0

    end
end)


obj:onDraw(function(inst)
    local instData = inst:get_data()
    local actor = inst.activator


    -- Draw items above player
    if inst.active == 4 then
        for _, item in ipairs(instData.animation_items) do
            draw_item_sprite(item.sprite,
                            actor.x + item.x,
                            actor.y + item.y)
        end


    -- Slide items towards hole
    elseif inst.active == 5 then
        for _, item in ipairs(instData.animation_items) do
            draw_item_sprite(item.sprite,
                            item.x,
                            item.y,
                            Helper.ease_out(item.scale, 3))

            item.x = gm.lerp(item.x, instData.hole_x, 0.1)
            item.y = gm.lerp(item.y, instData.hole_y, 0.1)
            item.scale = gm.lerp(item.scale, hole_input_scale, 0.1)
        end

    end
end)