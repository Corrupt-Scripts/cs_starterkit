Config = {}

Config.Debug = false

-- 'auto' | 'qbox' | 'qbcore'
Config.Framework = 'auto'

-- 'auto' | 'ox' | 'qb'   (auto = ox_inventory if running, otherwise qb-inventory)
Config.Inventory = 'auto'
Config.QBInventoryResource = 'qb-inventory' -- change if you use a renamed qb-inventory fork (e.g. 'ps-inventory', 'lj-inventory')

-- How "only once" is enforced:
--   'license'   = once per PLAYER (Rockstar license) - new characters can't claim again
--   'citizenid' = once per CHARACTER
Config.ClaimMode = 'license'

-- How male/female is decided:
--   'charinfo' = character's gender from the framework (0 = male, 1 = female), falls back to ped model
--   'model'    = current freemode ped model (mp_m / mp_f), falls back to charinfo
Config.GenderSource = 'charinfo'

-- Ways to open the menu
Config.Command = 'starterkit'          -- set to false to disable the command
Config.AutoPromptOnFirstLoad = true    -- pop the menu automatically when an unclaimed player loads in
Config.AutoPromptDelay = 6000          -- ms after load before it pops (lets spawn selector / clothing finish)

-- Admin: /resetstarterkit [server id | license | citizenid]
-- Needs ace: add_ace group.admin command.resetstarterkit allow
Config.AdminResetCommand = 'resetstarterkit'

-- Existing players who already got a starter pack before this script:
--   starterkitimport                          -> marks EVERY existing player/character as claimed (run once)
--   /markstarterkit [server id | license | citizenid] -> mark one person as claimed
-- Needs ace: add_ace group.admin command.starterkitimport allow / command.markstarterkit allow
Config.ImportCommand = 'starterkitimport'
Config.MarkCommand = 'markstarterkit'

Config.Currency = '$'
Config.PlatePrefix = 'CS'              -- vehicle plates become e.g. CS4K7Q2M (max 8 chars total)
Config.VehicleGarage = 'pillboxgarage' -- garage the starter vehicle is stored in (QBox default: 'motelgarage')

-- NPC to hand out kits
Config.Ped = {
    enabled = true,
    model = 'a_m_y_business_03',
    coords = vec4(-1037.74, -2737.98, 20.17, 330.0), -- LSIA arrivals
    scenario = 'WORLD_HUMAN_CLIPBOARD',
    interactDistance = 2.5,
    blip = { enabled = true, sprite = 280, colour = 27, scale = 0.75, label = 'Starter Kit' },
}

-- 'auto' | 'ox' | 'qb' | 'none'  (none = press E prompt)
Config.Target = 'auto'

-- Item names are written for ox_inventory (QBox default).
-- If you're on qb-inventory, these aliases translate them automatically.
Config.ItemAliases = {
    qb = {
        water  = 'water_bottle',
        burger = 'sandwich',
    },
}

-- Kits. The player's gender picks which one they get.
-- items: { name = 'item', count = 1, label = 'optional override', metadata = { ... optional } }
-- vehicle: set to false to give no vehicle
Config.Kits = {
    male = {
        title = 'Starter Kit',
        subtitle = 'Everything you need to hit the streets of Los Santos.',
        cash = 500,
        bank = 2500,
        items = {
            { name = 'phone',   count = 1 },
            { name = 'radio',   count = 1 },
            { name = 'water',   count = 3 },
            { name = 'burger',  count = 3 },
            { name = 'bandage', count = 2 },
        },
        vehicle = {
            model = 'blista',
            label = 'Dinka Blista',
            image = 'https://docs.fivem.net/vehicles/blista.webp',
        },
    },

    female = {
        title = 'Starter Kit',
        subtitle = 'Everything you need to hit the streets of Los Santos.',
        cash = 500,
        bank = 2500,
        items = {
            { name = 'phone',   count = 1 },
            { name = 'radio',   count = 1 },
            { name = 'water',   count = 3 },
            { name = 'burger',  count = 3 },
            { name = 'bandage', count = 2 },
        },
        vehicle = {
            model = 'issi2',
            label = 'Weeny Issi',
            image = 'https://docs.fivem.net/vehicles/issi2.webp',
        },
    },
}

Config.Locale = {
    targetLabel    = 'Collect Starter Kit',
    pressToOpen    = 'Press ~INPUT_CONTEXT~ to collect your starter kit',
    alreadyClaimed = 'You have already claimed your starter kit.',
    claimed        = 'Starter kit claimed - welcome to the city!',
    vehicleStored  = 'Your %s (%s) is waiting in your garage.',
    cantCarry      = "You can't carry everything (%s). Free up some space and try again.",
    error          = 'Something went wrong, please contact staff.',
    resetDone      = 'Starter kit reset for %s (%d row(s) removed).',
    resetUsage     = 'Usage: /%s [server id | license | citizenid]',
    importDone     = 'Imported %d existing claim(s) (mode: %s).',
    markUsage      = 'Usage: /%s [server id | license | citizenid]',
    markDone       = '%s is now marked as having claimed the starter kit.',
    markAlready    = '%s was already marked as claimed.',
    markNotFound   = 'No character found with citizenid %s.',
}
