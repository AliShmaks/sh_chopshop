Config = {}

Config.Framework = 'qbx'
Config.MenuType = 'ox_lib'
Config.TargetSystem = 'ox_target'
Config.Debug = false

-- Chop Shop Location
Config.ChopShop = {
    coords = vector3(735.56, -1083.62, 21.17),
    radius = 12.0,
    npc = {
        model = "s_m_y_construct_01",
        coords = vector4(735.56, -1083.62, 21.17, 131.57),
        scenario = "WORLD_HUMAN_CLIPBOARD"
    }
}

-- Sell NPC (upstairs from chop zone)
Config.SellNPC = {
    model = "s_m_m_autoshop_02",
    coords = vector4(726.22, -1068.23, 28.31, 180.0),
    scenario = "WORLD_HUMAN_CLIPBOARD"
}

-- Drop-off spot for battery / radiator / exhaust / gearbox
Config.PartDropoff = {
    coords = vector3(728.73, -1072.21, 21.38),
    radius = 2.0,
    label = 'Place Part',
    icon = 'fas fa-box',
}

-- Shared drill pickup locations
Config.ToolPickups = {
    {
        coords = vector3(732.50, -1078.00, 21.20),
        label = 'Pick up Drill',
        icon = 'fas fa-screwdriver-wrench',
        prop = 'imp_prop_impact_driver_01a',
    },
    {
        coords = vector3(738.00, -1078.00, 21.20),
        label = 'Pick up Drill',
        icon = 'fas fa-screwdriver-wrench',
        prop = 'imp_prop_impact_driver_01a',
    },
    {
        coords = vector3(735.33, -1076.33, 21.17),
        label = 'Pick up Drill',
        icon = 'fas fa-screwdriver-wrench',
        prop = 'imp_prop_impact_driver_01a',
    },
}

-- Shared ANGLE GRINDER pickup locations (2 on the floor).
Config.GrinderPickups = {
    {
        coords = vector3(730.50, -1079.50, 21.20),
        label = 'Pick up Grinder',
        icon = 'fas fa-bolt',
        prop = 'prop_tool_consaw',
    },
    {
        coords = vector3(729.34, -1077.17, 21.17),
        label = 'Pick up Grinder',
        icon = 'fas fa-bolt',
        prop = 'prop_tool_consaw',
    },
}

-- How each tool looks in the player's hand.
Config.Tools = {
    drill = {
        label  = 'Impact Driver',
        prop   = 'imp_prop_impact_driver_01a',
        bone   = 28422,
        offset = vector3(0.0700, -0.0600, -0.0300),
        rot    = vector3(80.0, -80.0, 160.0),
    },
    grinder = {
        label  = 'Angle Grinder',
        prop   = 'prop_tool_consaw',
        bone   = 28422,
        offset = vector3(-0.1500, 0.1000, 0.1000),
        rot    = vector3(0.0, 0.0, 180.0),
    },
}

-- Hold animation while a tool is in your hands.
Config.ToolHold = {
    anims = {
        { dict = 'amb@world_human_const_drill@male@drill@base', clip = 'base' },
    },
}

-- Animation used while grinding doors / hood / trunk.
Config.GrindAnims = {
    { dict = 'amb@world_human_hammering@male@base', clip = 'base' },
}

-- Sparks + flickering light while grinding.
Config.Sparks = {
    enabled     = true,
    bodyParts   = true,
    wheels      = false,
    asset       = 'core',
    effects     = { 'ent_brk_sparking_wires' },
    scale       = 0.9,
    burstMinMs  = 70,
    burstMaxMs  = 150,
    spread      = 0.12,
    blendToPart = 0.6,
    light       = true,
}

Config.EZoneDistance = 6.0

-- Rewards
Config.Reward = {
    dirtyMoney = {
        item = 'black_money',
        amount = 10000
    },
    damagePenaltyPerPart = 2000,
    motorcycle = {
        amount = 3000,
        damagePenaltyPerPart = 750,
    },
    materials = {
        pool = { 'metalscrap', 'copper', 'steel', 'rubber', 'glass', 'plastic' },
        pickCount = 3,
        amountMin = 14,
        amountMax = 20
    },
    perPart = {
        enabled = true,
        amountMin = 15,
        amountMax = 23,
        pool = { 'metalscrap', 'copper', 'steel', 'rubber', 'glass', 'plastic' },
    },
}

function Config.GetSaleValue(isBike, damagedCount)
    local r = Config.Reward or {}
    local base = tonumber(r.dirtyMoney and r.dirtyMoney.amount) or 10000
    local penalty = tonumber(r.damagePenaltyPerPart) or 2000
    if isBike and r.motorcycle then
        base = tonumber(r.motorcycle.amount) or base
        penalty = tonumber(r.motorcycle.damagePenaltyPerPart) or penalty
    end
    damagedCount = math.max(0, math.floor(tonumber(damagedCount) or 0))
    local totalPenalty = math.min(base, damagedCount * penalty)
    return math.max(0, base - totalPenalty), totalPenalty, base
end

Config.SportClasses = { [5] = true, [7] = true }

Config.VehicleParts = {
    -- Doors
    { name = "door_ds", label = "Driver Door",     bone = "door_dside_f", doorIndex = 0, prop = "prop_car_door_01",   chopTime = 3000 },
    { name = "door_ps", label = "Passenger Door",  bone = "door_pside_f", doorIndex = 1, prop = "prop_car_door_01",   chopTime = 3000 },
    { name = "door_lr", label = "Rear Left Door",  bone = "door_dside_r", doorIndex = 2, prop = "prop_car_door_02",   chopTime = 3000 },
    { name = "door_rr", label = "Rear Right Door", bone = "door_pside_r", doorIndex = 3, prop = "prop_car_door_02",   chopTime = 3000 },
    { name = "hood",    label = "Hood",            bone = "bonnet",       doorIndex = 4, prop = "prop_car_bonnet_01", chopTime = 3000 },
    { name = "trunk",   label = "Trunk",           bone = "boot",         doorIndex = 5, prop = "prop_car_bonnet_02", chopTime = 3000 },

    -- Wheels
    { name = "wheel_lf", label = "Front Left Wheel",  bone = "wheel_lf", wheelIndex = 0, prop = "prop_wheel_roller_car", chopTime = 7000 },
    { name = "wheel_rf", label = "Front Right Wheel", bone = "wheel_rf", wheelIndex = 1, prop = "prop_wheel_roller_car", chopTime = 7000 },
    { name = "wheel_lr", label = "Rear Left Wheel",   bone = "wheel_lr", wheelIndex = 2, prop = "prop_wheel_roller_car", chopTime = 7000 },
    { name = "wheel_rr", label = "Rear Right Wheel",  bone = "wheel_rr", wheelIndex = 3, prop = "prop_wheel_roller_car", chopTime = 7000 },

    -- Internal parts (tuned hold positions)
    {
        name = "battery",
        label = "Battery",
        bone = "engine",
        prop = "prop_battery_02",
        internal = true,
        holdBone = 24818,
        holdOffset = vector3(-0.1860, 0.4300, -0.0700),
        holdRot = vector3(0.00, 90.00, 0.00),
        chopTime = 4000,
    },
    {
        name = "radiator",
        label = "Radiator",
        bone = "engine",
        prop = "imp_prop_impexp_radiator_01",
        propSport = "imp_prop_impexp_radiator_02",
        internal = true,
        holdBone = 24818,
        holdOffset = vector3(-0.2640, 0.3280, -0.0400),
        holdRot = vector3(0.00, 90.00, 0.00),
        chopTime = 4000,
    },
    {
        name = "exhaust",
        label = "Exhaust",
        bone = "engine",
        prop = "imp_prop_impexp_exhaust_02",
        propSport = "imp_prop_impexp_exhaust_01",
        internal = true,
        holdBone = 24818,
        holdOffset = vector3(-0.4100, 0.5920, -0.0320),
        holdRot = vector3(27.00, 81.00, 0.00),   -- normalized from 387 → 27
        chopTime = 4000,
    },
    {
        name = "gearbox",
        label = "Gearbox",
        bone = "engine",
        prop = "imp_prop_impexp_gearbox_01",
        internal = true,
        holdBone = 24818,
        holdOffset = vector3(-0.4640, 0.4600, -0.1080),
        holdRot = vector3(0.00, 10.00, 90.00),
        chopTime = 4000,
    },
}

Config.MotorcycleOptionalParts = {
    -- radiator = true,
    -- gearbox = true,
}

Config.MotorcyclePartsByModel = {
}

Config.ChopTime = 7000

Config.AntiCheat = {
    minWheelsCar  = 3,
    minWheelsBike = 2,
    minBodyPanels = 1,
}

Config.WheelDebris = {
    mode = 'real',
    breakFlag = false,
    props = { 'prop_wheel_01', 'prop_wheel_03', 'prop_wheel_roller_car' },
    lifetimeMs = 10000,
}

Config.ChopReach = {
    default = 1.5,
    wheel = 1.4,
    internal = 2.0,
    hood = 2.0,
    trunk = 2.0,
    aimRadius = 1.2,
}

Config.PickupDistance = 1.5

Config.ChopCooldown = {
    enabled = true,
    minutes = 30,
    bypassAce = 'sh_chopshop.bypass',
}

Config.ChopAnimation = {
    dict = "mini@repair",
    anim = "fixing_a_ped"
}

Config.BlacklistedClasses = {
    [17] = true,
    [18] = true,
    [19] = true,
    [21] = true,
}

Config.BlacklistedVehicles = {
    "police", "police2", "police3", "police4", "policeb", "policet",
    "policeold1", "policeold2", "sheriff", "sheriff2", "fbi", "fbi2",
    "riot", "riot2", "pranger", "pbus", "predator",
    "ambulance", "firetruk", "lguard",
    "taxi", "bus", "coach", "rentalbus", "tourbus", "airbus",
    "trash", "trash2", "towtruck", "towtruck2",
}

Config.Notify = {
    enterZone    = "Chop shop zone — Press E near a car to open its parts",
    opened       = "Parts opened — Right-click to chop",
    needGrinder  = "You need an angle grinder — pick one up from the floor first!",
    needDrill    = "You need the impact driver — pick it up from the floor first!",
    partChopped  = "Part removed",
    allChopped   = "Car fully stripped — Bonus materials received!",
    jobFinished  = "Job finished! Go upstairs to sell the car.",
    notChopped   = "This car is not fully chopped yet",
    sold         = "Vehicle sold",
    blacklisted  = "This vehicle cannot be chopped (police, ambulance, taxi and other job vehicles are protected)",
    inVehicle    = "You cannot chop a vehicle while inside it",
    noVehicle    = "No vehicle nearby",
    notInZone    = "You must be in the chop shop zone"
}