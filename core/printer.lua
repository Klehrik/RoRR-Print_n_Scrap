-- Printer

local sPrinter = Sprite.new("printer", "~/sprites/printer.png", 23, 36, 48)

local spawn_tiers     = {ItemTier.COMMON, ItemTier.UNCOMMON, ItemTier.RARE, ItemTier.BOSS}
local spawn_costs     = {65, 75, 140, 140}    -- Small chest is 50, large chest is 110, and basic shrine is 65
local spawn_weights   = {6, 3, 1, 1}          -- Small/large chests and basic shrines are 8
local spawn_rarities  = {1, 1, 4, 4}          -- Small/large chests are 1, and drone upgraders/recyclers are 4

local item_colors = {Color.Item.WHITE, Color.Item.GREEN, Color.Item.RED, 0, Color.Item.YELLOW}
local text_colors = {"", "<g>", "<r>", "", "<y>"}
local tier_tokens = {"common", "uncommon", "rare", "", "boss"}
local scrap_names = {"White", "Green", "Red", "", "Yellow"}

local animation_held_time   = 80
local animation_print_time  = 32
local box_offset_x          = -18   -- Location of the input box of the printer relative to the origin
local box_offset_y          = -22
local box_input_scale       = 0.4   -- Item scale when it enters the input box
local text_offset_x         = -8    -- Location of the button prompt text
local text_offset_y         = -20

local item_blacklist = {
    "printNScrap-scrapWhite",
    "printNScrap-scrapGreen",
    "printNScrap-scrapRed",
    "printNScrap-scrapYellow"
}



-- ========== Packets ==========

-- Sync printer setup with clients
local packetCreate = Packet.new()
packetCreate:set_serializers(
    function(buffer, inst, item)
        buffer:write_instance(inst)
        buffer:write_ushort(item)
    end,

    function(buffer, player)
        local inst = buffer:read_instance()
        local item = Item.wrap(buffer:read_ushort())

        local inst_data = Instance.get_data(inst)
        inst_data.item = item

        -- Set prompt text
        inst.translation_key = "interactable.printer"
        inst.text = gm.translate(
            inst.translation_key..".text",
            text_colors[item.tier + 1]..gm.translate(item.token_name),
            gm.translate("tier."..tier_tokens[item.tier + 1])
        )

        inst_data.setup = true
    end
)


-- Sync printer use with clients
local packetUse = Packet.new()
packetUse:set_serializers(
    function(buffer, inst, taken)
        buffer:write_instance(inst)
        buffer:write_ushort(taken)
    end,

    function(buffer, player)
        local inst = buffer:read_instance()
        local taken = Item.wrap(buffer:read_ushort())

        local inst_data = Instance.get_data(inst)
        inst_data.taken = taken

        -- Start printer animation
        inst_data.animation_time = 0
        inst:sound_play_at(gm.constants.wDroneRecycler_Activate, 1, 1, inst.x, inst.y)
        inst.active = 3
    end
)



-- ========== Objects ==========

for printer_index, tier in ipairs(spawn_tiers) do

    -- Create Object
    local obj = Object.new("printer"..printer_index, Object.Parent.INTERACTABLE)
    obj:set_sprite(sPrinter)
    obj:set_depth(1)

    -- Create Interactable Card
    local card = InteractableCard.new("printer"..printer_index)
    card.object_id                      = obj
    card.required_tile_space            = 2
    card.spawn_with_sacrifice           = true
    card.spawn_cost                     = spawn_costs[printer_index]
    card.spawn_weight                   = spawn_weights[printer_index]
    card.default_spawn_rarity_override  = spawn_rarities[printer_index]
    table.insert(interactable_cards, card)


    -- Callbacks

    Callback.add(obj.on_create, function(inst)
        local inst_data = Instance.get_data(inst)

        -- Item entry location
        inst_data.box_x = inst.x + box_offset_x
        inst_data.box_y = inst.y + box_offset_y

        -- Set prompt text offset
        inst.text_offset_x = text_offset_x
        inst.text_offset_y = text_offset_y

        if Net.client then return end
        inst_data.setup = true  -- Set to `true` for clients on packet receive

        -- Pick printer item
        -- Make sure that the item is:
        --      of the same rarity
        --      not in the item ban list
        --      is actually unlocked (if applicable)
        local item
        local items = Item.find_all(tier, Item.Property.TIER)
        while #items > 0 do
            local pos = math.floor(math.randomf(1, #items + 1))
            item = items[pos]

            if  item.namespace and item.identifier
                and (not Util.table_has(item_blacklist, item.namespace.."-"..item.identifier))
                -- TODO
                -- and item:is_unlocked()
            then break end

            table.remove(items, pos)
        end
        inst_data.item = item

        -- Set prompt text
        inst.translation_key = "interactable.printer"
        inst.text = gm.translate(
            inst.translation_key..".text",
            text_colors[item.tier + 1]..gm.translate(item.token_name),
            gm.translate("tier."..tier_tokens[item.tier + 1])
        )
    end)


    Hook.add_post(gm.constants.interactable_check_cost, function(self, other, result, args)
        if self:get_object_index() ~= obj.value then return end

        local inst_data = Instance.get_data(self)
        local actor = args[3].value

        -- Check if the actor has at least one valid item
        local size = #actor.inventory_item_order
        if size > 0 then
            for i = 0, size - 1 do
                local item = Item.wrap(actor.inventory_item_order:get(i))

                -- Valid item if:
                --      at least one real stack
                --      the same rarity
                --      NOT the same item as the printer
                if  actor:item_count(item, Item.StackKind.NORMAL) > 0
                and item.tier == tier
                and item.value ~= inst_data.item.value then
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
        

        -- [Host]  Send sync info to clients
        -- (Instance creation is not yet synced on_create)
        if (not inst_data.sent_sync) and Net.host then
            packetCreate:send_to_all(inst, inst_data.item)
        end
        inst_data.sent_sync = true


        -- Prevent backwards animation looping (after printer reset)
        if inst.image_index <= 0 then
            inst.image_speed = math.max(inst.image_speed, 0)
        end


        -- Initial activation
        if inst.active == 2 then
            -- [Client]  Wait for packet from host
            if Net.client then
                inst.active = 100
                return
            end

            -- Check if the actor has scrap for this tier
            local item = Item.find("scrap"..scrap_names[tier + 1])
            if item and actor:item_count(item, Item.StackKind.NORMAL) > 0 then
                inst_data.taken = item
                
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
                        if  actor:item_count(item, Item.StackKind.NORMAL) > 0
                        and item.tier == tier
                        and item.value ~= inst_data.item.value then
                            table.insert(items, item)
                        end
                    end
                end

                inst_data.taken = items[math.floor(math.randomf(1, #items + 1))]
            end
        
            -- Take item from inventory
            actor:item_take(inst_data.taken)
        
            -- Start printer animation
            inst_data.animation_time = 0
            inst:sound_play_at(gm.constants.wDroneRecycler_Activate, 1.0, 1.0, inst.x, inst.y)
            inst.active = 3

            -- [Host]  Send sync info to clients
            if Net.host then
                packetUse:send_to_all(inst, inst_data.taken)
            end

        
        -- Draw item above player
        elseif inst.active == 3 then
            if inst_data.animation_time < animation_held_time then inst_data.animation_time = inst_data.animation_time + 1
            else
                inst_data.taken_x = actor.x
                inst_data.taken_y = actor.y - 48
                inst_data.taken_scale = 1.0
                inst.active = 4
            end


        -- Slide item towards input box
        elseif inst.active == 4 then
            inst_data.taken_x       = math.lerp(inst_data.taken_x, inst_data.box_x, 0.1)
            inst_data.taken_y       = math.lerp(inst_data.taken_y, inst_data.box_y, 0.1)
            inst_data.taken_scale   = math.lerp(inst_data.taken_scale, box_input_scale, 0.1)

            if math.distance(inst_data.taken_x, inst_data.taken_y, inst_data.box_x, inst_data.box_y) < 1 then
                inst_data.animation_time = 0
                inst.active = 5
            end


        -- Close box for a bit
        elseif inst.active == 5 then
            inst.image_speed = 1.0

            if inst.image_index == 10 then inst:sound_play_at(gm.constants.wDroneRecycler_Recycling, 1, 1, inst.x, inst.y)
            elseif inst.image_index >= 21 then
                if inst_data.animation_time < animation_print_time then inst_data.animation_time = inst_data.animation_time + 1
                else inst.active = 6
                end
            end


        -- Create item drop and reset
        elseif inst.active == 6 then
            inst.image_speed = -1.0

            local created = inst_data.item:create(inst_data.box_x, inst_data.box_y, inst)
            created.is_printed = true

            inst.active = 0

        end
    end)


    Callback.add(obj.on_draw, function(inst)
        local inst_data = Instance.get_data(inst)
        if not inst_data.setup then return end

        local actor = inst.activator

        -- Draw hovering item
        local frame = Global._current_frame
        draw_item_sprite(inst_data.item.sprite_id,
                        inst.x + 10,
                        inst.y - 33 + math.dsin(frame * 1.333) * 3,
                        0.8,
                        0.8 + math.dsin(frame * 4) * 0.25)
        
        -- Draw item above player
        if inst.active == 3 then
            draw_item_sprite(inst_data.taken.sprite_id,
                             actor.x,
                             actor.y - 48)

        -- Slide item towards input box
        elseif inst.active == 4 then
            draw_item_sprite(inst_data.taken.sprite_id,
                             inst_data.taken_x,
                             inst_data.taken_y,
                             inst_data.taken_scale)

        end
    end)

end