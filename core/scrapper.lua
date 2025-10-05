-- Scrapper

local sScrapper = Sprite.new("scrapper", "~/sprites/scrapper.png", 1, 10, 25)

local spawn_cost            = 65
local spawn_weight          = 4
local spawn_rarity          = 1

local animation_held_time   = 80
local animation_print_time  = 38
local hole_x_offset         = 0     -- Location of the hole of the scrapper relative to the origin
local hole_y_offset         = -14
local hole_input_scale      = 0     -- Item scale when it enters the scrapper

local max_stack = 10    -- Amount of stacks that can be scrapped at once

local scrap_items = {
    "printNScrap-scrapWhite",
    "printNScrap-scrapGreen",
    "printNScrap-scrapRed",
    "printNScrap-scrapYellow"
}

local scrap_items_identifiers = {
    "scrapWhite",
    "scrapGreen",
    "scrapRed",
    "",
    "scrapYellow"
}



-- ========== Packets ==========

-- Sync scrapper use with clients
local packetUse = Packet.new()
packetUse:set_serializers(
    function(buffer, inst, taken, count)
        buffer:write_instance(inst)
        buffer:write_ushort(taken)
        buffer:write_ushort(count)
    end,

    function(buffer, player)
        local inst = buffer:read_instance()
        local taken = Item.wrap(buffer:read_ushort())
        local taken_count = buffer:read_ushort()

        local inst_data = Instance.get_data(inst)
        inst_data.taken = taken
        inst_data.taken_count = taken_count

        -- Start scrapper animation
        for i = 1, inst_data.taken_count do
            -- x and y are offsets from the actor's position here
            table.insert(inst_data.animation_items, {
                sprite  = inst_data.taken.sprite_id,
                x       = ((inst_data.taken_count - 1) * -17) + ((i - 1) * 34),
                y       = -48,
                scale   = 1.0
            })
        end
        inst:sound_play_at(gm.constants.wDroneRecycler_Activate, 1, 1, inst.x, inst.y)
        inst.active = 4
    end
)



-- ========== Objects ==========

-- Create Object
local obj = Object.new("scrapper", Object.Parent.INTERACTABLE_CRATE)
obj:set_sprite(sScrapper)
obj:set_depth(1)

-- Create Interactable Card
local card = InteractableCard.new("scrapper")
card.object_id                      = obj
card.required_tile_space            = 0
card.spawn_with_sacrifice           = true
card.spawn_cost                     = spawn_cost
card.spawn_weight                   = spawn_weight
card.default_spawn_rarity_override  = spawn_rarity
card.decrease_weight_on_spawn       = true
table.insert(interactable_cards, card)


-- Callbacks

Callback.add(obj.on_create, function(inst)
    inst.is_scrapper = true     -- Flag for other crate-related mods

    -- Item entry location
    local inst_data = Instance.get_data(inst)
    inst_data.hole_x = inst.x + hole_x_offset
    inst_data.hole_y = inst.y + hole_y_offset

    -- Set prompt text
    inst.translation_key = "interactable.scrapper"
    inst.text = gm.translate(inst.translation_key..".text")
end)


Hook.add_post(gm.constants.interactable_check_cost, function(self, other, result, args)
    if self:get_object_index() ~= obj.value then return end

    local inst_data = Instance.get_data(self)
    local actor = args[3].value

    -- Check if the actor has any items to scrap
    local size = #actor.inventory_item_order
    if size > 0 then
        for i = 0, size - 1 do
            local item = Item.wrap(actor.inventory_item_order:get(i))

            -- Pass check if it is not scrap
            if not Util.table_has(scrap_items, item.namespace.."-"..item.identifier) then
                return
            end
        end
    end

    -- If not, prevent usage
    result.value = false
end)


Callback.add(obj.on_step, function(inst)
    local inst_data = Instance.get_data(inst)
    local actor = inst.activator


    if inst.active == 0 then
        inst_data.populate = false
        inst_data.animation_time = 0
        inst_data.animation_items = {}


    -- Initial activation (opened item picker UI)
    elseif inst.active == 1 then
        if not inst_data.populate then
            inst_data.populate = true

            -- Add items to contents
            local arr = Array.new()
            local size = #actor.inventory_item_order
            for i = 0, size - 1 do
                local item = Item.wrap(actor.inventory_item_order:get(i))
                if  (not Util.table_has(scrap_items, item.namespace.."-"..item.identifier))
                and actor:item_count(item, Item.StackKind.NORMAL) > 0 then
                    arr:push(item.object_id)
                end
            end
            inst.contents = arr
        end


    -- Item selected
    elseif inst.active == 3 then
        inst.last_move_was_mouse = true
        inst.owner = -4

        -- [Client]  Wait for packet from host
        if Net.client then
            inst.active = 100
            return
        end

        -- Get selected item
        local obj_id = inst.contents:get(inst.selection)
        inst_data.taken = Item.wrap(gm.object_to_item(obj_id))
        inst_data.taken_count = math.min(actor:item_count(inst_data.taken, Item.StackKind.NORMAL), max_stack)

        -- Take item from inventory
        actor:item_take(inst_data.taken, inst_data.taken_count)
        
        -- Start scrapper animation
        for i = 1, inst_data.taken_count do
            -- x and y are offsets from the actor's position here
            table.insert(inst_data.animation_items, {
                sprite  = inst_data.taken.sprite_id,
                x       = ((inst_data.taken_count - 1) * -17) + ((i - 1) * 34),
                y       = -48,
                scale   = 1.0
            })
        end
        inst:sound_play_at(gm.constants.wDroneRecycler_Activate, 1.0, 1.0, inst.x, inst.y)
        inst.active = 4

        -- [Host]  Send sync info to clients
        if Net.host then
            packetUse:send_to_all(inst, inst_data.taken, inst_data.taken_count)
        end

        
    -- Draw items above player
    elseif inst.active == 4 then
        -- Free actor
        GM.actor_activity_set(actor, 0)

        if inst_data.animation_time < animation_held_time then inst_data.animation_time = inst_data.animation_time + 1
        else
            -- Turn offsets into absolute positions
            for _, item in ipairs(inst_data.animation_items) do
                item.x = actor.x + item.x
                item.y = actor.y + item.y
            end
            inst.active = 5
        end


    -- Slide items towards hole
    elseif inst.active == 5 then
        local item = inst_data.animation_items[1]
        if math.distance(item.x, item.y, inst_data.hole_x, inst_data.hole_y) < 1 then
            inst_data.animation_time = 0
            inst.active = 6
        end


    -- Delay for scrapping sfx
    elseif inst.active == 6 then
        if inst_data.animation_time < animation_print_time then inst_data.animation_time = inst_data.animation_time + 1
        else inst.active = 7
        end

        if inst_data.animation_time == 6 then
            inst:sound_play_at(gm.constants.wDroneRecycler_Recycling, 1, 1, inst.x, inst.y)
        end


    -- Create scrap drop(s) and reset
    elseif inst.active == 7 then
        local scrap = Item.find(scrap_items_identifiers[inst_data.taken.tier + 1])

        for i = 1, inst_data.taken_count do
            local created = scrap:create(inst_data.hole_x, inst_data.hole_y, inst)
            created.is_scrap = true
        end

        inst.active = 0

    end
end)


Callback.add(obj.on_draw, function(inst)
    local inst_data = Instance.get_data(inst)
    local actor = inst.activator

    -- Draw items above player
    if inst.active == 4 then
        for _, item in ipairs(inst_data.animation_items) do
            draw_item_sprite(item.sprite,
                            actor.x + item.x,
                            actor.y + item.y)
        end

    -- Slide items towards hole
    elseif inst.active == 5 then
        for _, item in ipairs(inst_data.animation_items) do
            draw_item_sprite(item.sprite,
                            item.x,
                            item.y,
                            math.easeout(item.scale, 3))

            item.x = math.lerp(item.x, inst_data.hole_x, 0.1)
            item.y = math.lerp(item.y, inst_data.hole_y, 0.1)
            item.scale = math.lerp(item.scale, hole_input_scale, 0.1)
        end

    end
end)