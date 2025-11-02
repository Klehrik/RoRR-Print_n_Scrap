-- Printer

local sPrinter = Sprite.new("printer", "~/sprites/printer.png", 23, 36, 48)

local animation_held_time   = 80
local animation_print_time  = 32
local box_offset_x          = -18   -- Location of the input box of the printer relative to the origin
local box_offset_y          = -22
local box_input_scale       = 0.4   -- Item scale when it enters the input box
local text_offset_x         = -8    -- Location of the button prompt text
local text_offset_y         = -20

__properties = {}
__scrap_items = {}
__scrap_items_by_tier = {}



-- ========== Packets ==========

-- Sync printer setup with clients
local packetCreate = Packet.new("printerCreate")
packetCreate:set_serializers(
    function(buffer, inst, item, tier_token)
        buffer:write_instance(inst)
        buffer:write_ushort(item)
        buffer:write_string(tier_token)
    end,

    function(buffer, player)
        local inst = buffer:read_instance()
        local item = Item.wrap(buffer:read_ushort())
        local tier_token = buffer:read_string()

        local inst_data = Instance.get_data(inst)
        inst_data.item = item

        -- Set prompt text
        inst.translation_key = "interactable.printer"
        inst.text = gm.translate(
            inst.translation_key..".text",
            "<"..ItemTier.wrap(item.tier).text_color:sub(2, -2)..">"..gm.translate(item.token_name),
            gm.translate(tier_token)
        )

        inst_data.setup = true
    end
)


-- Sync printer use with clients
local packetUse = Packet.new("printerUse")
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



-- ========== Static Methods ==========

--[[
Property        Default
--------        -------
tier            ItemTier.COMMON
cost            65
weight          6
rarity          1
tier_token      "tier.common"
scrap_sprite    nil
]]
PnS.new = function(properties)
    if not properties               then log.error("No properties table provided", 2) end
    if not Initialize.has_started() then log.error("ReturnsAPI initialization loop has not started yet", 2) end

    local already_added = __properties[tier]

    -- Create stored properties table for tier, or merge with existing
    local tier = Wrap.unwrap(properties.tier) or ItemTier.COMMON

    __properties[tier] = __properties[tier] or {}
    __properties[tier] = {
        tier            = tier,
        cost            = properties.cost           or __properties[tier].cost          or 65,
        weight          = properties.weight         or __properties[tier].weight        or 6,
        rarity          = properties.rarity         or __properties[tier].rarity        or 1,
        tier_token      = properties.tier_token     or __properties[tier].tier_token    or "tier.common",
        scrap_sprite    = properties.scrap_sprite   or __properties[tier].scrap_sprite
    }

    -- Create Object
    local obj = Object.new("printer"..tier, Object.Parent.INTERACTABLE)
    obj:set_sprite(sPrinter)
    obj:set_depth(1)

    -- Create Interactable Card
    local card = InteractableCard.new("printer"..tier)
    card.object_id                      = obj
    card.required_tile_space            = 2
    card.spawn_with_sacrifice           = true
    card.spawn_cost                     = __properties[tier].cost
    card.spawn_weight                   = __properties[tier].weight
    card.default_spawn_rarity_override  = __properties[tier].rarity

    -- Create scrap
    local scrap
    if __properties[tier].scrap_sprite then
        scrap = Item.new("scrap"..tier)
        scrap:set_sprite(__properties[tier].scrap_sprite)
        scrap:set_tier(tier)

        -- Remove from loot pool
        LootPool.wrap(ItemTier.wrap(tier).item_pool_for_reroll):remove_item(scrap)

        __scrap_items[scrap.value]  = scrap
        __scrap_items_by_tier[tier] = scrap
    end

    -- Callbacks
    if already_added then
        return card
    end

    Callback.add(obj.on_create, function(inst)
        local inst_data = Instance.get_data(inst)

        -- Set prompt text offset
        inst.text_offset_x = text_offset_x
        inst.text_offset_y = text_offset_y

        if Net.client then return end
        inst_data.setup = true  -- Set to `true` for clients on packet receive

        -- Pick printer item
        -- Make sure that the item is:
        --      of the same rarity
        --      not in the item ban list
        --      is in a loot pool
        --      is actually unlocked (if applicable)
        local item
        local items = Item.find_all(tier, Item.Property.TIER)
        while #items > 0 do
            local pos = math.floor(math.randomf(1, #items + 1))
            item = items[pos]

            if  item.namespace and item.identifier
            and (not __scrap_items[item.value])
            and (not item_blacklist[item.value])
            and item:is_loot()
            and item:get_achievement():is_unlocked_any()
            then break end

            table.remove(items, pos)
        end
        inst_data.item = item

        -- Set prompt text
        inst.translation_key = "interactable.printer"
        inst.text = gm.translate(
            inst.translation_key..".text",
            "<"..ItemTier.wrap(tier).text_color..">"..gm.translate(item.token_name),
            gm.translate(__properties[tier].tier_token)
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

        -- Set item entry location
        inst_data.box_x = inst.x + box_offset_x
        inst_data.box_y = inst.y + box_offset_y
        

        -- [Host]  Send sync info to clients
        -- (Instance creation is not yet synced on_create)
        if (not inst_data.sent_sync) and Net.host then
            packetCreate:send_to_all(inst, inst_data.item, __properties[tier].tier_token)
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
            if scrap and (actor:item_count(scrap, Item.StackKind.NORMAL) > 0) then
                inst_data.taken = scrap
                
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
            inst:sound_play_at(gm.constants.wDroneRecycler_Activate, 1, 1, inst.x, inst.y)
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
                inst_data.taken_scale = 1
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
            inst.image_speed = 1

            if inst.image_index == 10 then inst:sound_play_at(gm.constants.wDroneRecycler_Recycling, 1, 1, inst.x, inst.y)
            elseif inst.image_index >= 21 then
                if inst_data.animation_time < animation_print_time then inst_data.animation_time = inst_data.animation_time + 1
                else inst.active = 6
                end
            end


        -- Create item drop and reset
        elseif inst.active == 6 then
            inst.image_speed = -1

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
    

    table.insert(printer_cards, card)
    return card
end