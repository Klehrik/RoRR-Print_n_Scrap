Adds 3D Printers and Scrappers from Risk of Rain 2.  

Online compatible.  

---

### Installation Instructions
Follow the instructions [listed here](https://docs.google.com/document/d/1NgLwb8noRLvlV9keNc_GF2aVzjARvUjpND2rxFgxyfw/edit?usp=sharing).  
Join the [Return of Modding server](https://discord.gg/VjS57cszMq) for support.  

### Credits
* **casey (@invenot)** for printer and scrapper sprite bases.

---

### API

```lua
PnS = mods["Klehrik-Print_n_Scrap"].setup()

-- Add a new printer
-- Passing an existing tier will modify its printer
local interactable_card = PnS.new{
    tier            = ItemTier.COMMON,
    cost            = 65,
    weight          = 6,
    rarity          = 1,
    tier_token      = "tier.common",
    scrap_sprite    = Sprite.new("scrapWhite", "~/sprites/scrapWhite.png", 1, 13, 13)
}

-- Get table of printer interactable cards
local interactable_cards = PnS.get_printer_cards()

-- Ban printers from appearing on this stage
PnS.ban_printers(stage)

-- Ban scrappers from appearing on this stage
PnS.ban_scrappers(stage)

-- Ban an item from appearing in a printer
PnS.ban_item(item)
```