-- Content

printer_cards = {
    PnS.new{
        tier            = ItemTier.COMMON,
        cost            = 65,
        weight          = 6,
        rarity          = 1,
        tier_token      = "tier.common",
        scrap_sprite    = Sprite.new("scrapWhite", "~/sprites/scrapWhite.png", 1, 13, 13)
    },
    PnS.new{
        tier            = ItemTier.UNCOMMON,
        cost            = 75,
        weight          = 3,
        rarity          = 1,
        tier_token      = "tier.uncommon",
        scrap_sprite    = Sprite.new("scrapGreen", "~/sprites/scrapGreen.png", 1, 13, 13)
    },
    PnS.new{
        tier            = ItemTier.RARE,
        cost            = 140,
        weight          = 1,
        rarity          = 4,
        tier_token      = "tier.rare",
        scrap_sprite    = Sprite.new("scrapRed", "~/sprites/scrapRed.png", 1, 13, 13)
    },
    PnS.new{
        tier            = ItemTier.BOSS,
        cost            = 140,
        weight          = 1,
        rarity          = 4,
        tier_token      = "tier.boss",
        scrap_sprite    = Sprite.new("scrapYellow", "~/sprites/scrapYellow.png", 1, 13, 13)
    }
}

for _, stage in ipairs{
    Stage.find("riskOfRain"),
    Stage.find("boarBeach")
} do
    PnS.ban_printers(stage)
    PnS.ban_scrappers(stage)
end