local desc = "Does nothing. Prioritized when using printers."

return {
    interactable = {
        printer = {
            text = "Print %s <y>(1 %s item)"
        },
        scrapper = {
            text = "Use scrapper"
        }
    },

    item = {
        scrap0 = {
            name        = "Item Scrap (White)",
            pickup      = desc,
            description = desc
        },
        scrap1 = {
            name        = "Item Scrap (Green)",
            pickup      = desc,
            description = desc
        },
        scrap2 = {
            name        = "Item Scrap (Red)",
            pickup      = desc,
            description = desc
        },
        scrap4 = {
            name        = "Item Scrap (Yellow)",
            pickup      = desc,
            description = desc
        }
    },

    tier = {
        common      = "common",
        uncommon    = "uncommon",
        rare        = "rare",
        boss        = "boss"
    },

    ui = {
        options = {
            printNScrap = {
                header                  = "PRINT 'N' SCRAP",

                enablePrinters              = "Enable printers",
                ["enablePrinters.desc"]     = "Allow printers to spawn.\n\n<y>Uses the host's setting.</c>",
                
                enableScrappers             = "Enable scrappers",
                ["enableScrappers.desc"]    = "Allow scrappers to spawn.\n\n<y>Uses the host's setting.</c>",
                
                enableNames                 = "Enable floating names",
                ["enableNames.desc"]        = "Display floating item names above printers.\n\n<y>Client-sided</c>",
            }
        }
    }
}