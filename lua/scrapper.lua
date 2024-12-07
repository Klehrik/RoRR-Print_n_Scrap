-- Scrapper

local sScrapper = Resources.sprite_load("printNScrap", "scrapper", PATH.."sprites/scrapper.png", 1, 10, 25)

local max_stack = 10    -- Amount of stacks that can be scrapped at once


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
card.spawn_weight                   = 30   -- 3 DEBUG
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


local free_actor = function(actor)
    -- Reset actor activity
    actor.activity = 0.0
    actor.activity_free = true
    actor.activity_move_factor = 1.0
    actor.activity_type = 0.0
end

local free_scrapper = function(inst)
    -- Reset scrapper active
    inst.last_move_was_mouse = true
    inst:set_active(0)
end


-- Callbacks

obj:onCreate(function(inst)
    inst.is_scrapper = true     -- Flag for other crate-related mods
    inst.translation_key = "interactable.scrapper"
    inst.text = Language.translate_token(inst.translation_key..".text")
end)


obj:onDraw(function(inst)
    local instData = inst:get_data()
    local actor = inst.activator


    if inst.active == 0 then
        instData.populate = false


    -- Initial activation (opened item picker UI)
    elseif inst.active == 1 then
        if not instData.populate then
            instData.populate = true

            -- Check if the actor has any items to scrap
            local size = #actor.inventory_item_order
            if size <= 0 then
                inst:sound_play_at(gm.constants.wError, 1.0, 1.0, inst.x, inst.y)
                free_actor(actor)
                free_scrapper(inst)
            end

            -- Add items to contents
            local arr = Array.new()
            instData.contents_data = {} -- Extra information
            for i = 0, size - 1 do
                local item = Item.wrap(actor.inventory_item_order:get(i))
                arr:push(item.object_id)
                table.insert(instData.contents_data, {
                    item    = item,
                    count   = actor:item_stack_count(item)
                })
            end
            inst.contents = arr
        end


    -- Set active to 3 to ignore default behavior
    elseif inst.active == 2 then
        inst:set_active(3)


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
        inst:sound_play_at(gm.constants.wDroneRecycler_Activate, 1.0, 1.0, inst.x, inst.y)

        log.info("Scrapping!")
        free_actor(actor)
        free_scrapper(inst)

    end
end)