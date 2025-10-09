-- Scrap (Items)

local names = {"White", "Green", "Red", "Yellow"}
local tiers = {ItemTier.COMMON, ItemTier.UNCOMMON, ItemTier.RARE, ItemTier.BOSS}

for i = 1, 4 do
    local item = Item.new("scrap"..names[i], true)
    item:set_sprite(Sprite.new("scrap"..names[i], "~/sprites/scrap"..names[i]..".png", 1, 13, 13))
    item:set_tier(tiers[i])

    -- Remove from loot pool
    LootPool.wrap(ItemTier.wrap(tiers[i]).item_pool_for_reroll):remove_item(item)
end