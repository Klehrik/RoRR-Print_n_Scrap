-- Scrap (Items)

local names = {"White", "Green", "Red", "Yellow"}
local tiers = {Item.TIER.common, Item.TIER.uncommon, Item.TIER.rare, Item.TIER.boss}

for i = 1, 4 do
    local item = Item.new("printNScrap", "scrap"..names[i], true)
    item:set_sprite(Resources.sprite_load("printNScrap", "scrap"..names[i], PATH.."sprites/scrap"..names[i]..".png", 1, 13, 13))
    item:set_tier(tiers[i])
    item:toggle_loot(false)
end