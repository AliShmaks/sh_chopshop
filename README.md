<h1 align="center">sh_chopshop</h1>
<p align="center">
  An advanced chop shop for FiveM (Qbox / QBCore + ox_inventory).<br>
  <b>By Shararah Scripts</b>
</p>

---

## Features

- Configurable chop shop location, NPCs and vehicle drop-off.
- Step-by-step part removal: doors, hood, trunk, wheels, then battery, radiator, exhaust and gearbox.
- Shared **impact driver** and **angle grinder** — one tool per player, drop it, pick it up again.
- Grinder sparks and light effects, tool-holding and grinding animations, sound effects.
- Separate payouts and damage penalties for cars and motorcycles.
- Material rewards for every internal part, plus a bonus when the car is fully stripped.
- Server-side claim, sequence, distance and reward checks.
- **Protected vehicles:** police, sheriff, FBI, ambulance, fire trucks, taxis, buses and other
  job / emergency / service vehicles can **not** be chopped. Player-owned vehicles are protected too.

## Configuration highlights (`config.lua`)

| Option | What it does |
|---|---|
| `Config.ChopCooldown` | Cooldown between chop jobs (30 min default). Players who press E during it see the time left. `bypassAce` lets admins skip it. |
| `Config.ChopReach` | How close a player must stand to the specific part they chop. |
| `Config.PickupDistance` | How close you must be to pick up a drill / grinder. |
| `Config.WheelDebris` | `mode = 'real'` drops the car's own wheel; `'prop'` spawns a wheel prop instead. |
| `Config.SportClasses` | Vehicle classes that use the sport radiator / exhaust models. |
| `Config.AntiCheat` | Minimum part counts the server accepts when a car is opened. |
| `Config.Reward` | Sale payouts, damage penalties and material rewards. |

## Tools

Drills and grinders are shared. A player can drop the tool they hold (**X**) and any other player in the
shop can pick it up. Dropped tools stay on the floor for 2 minutes.

## Requirements

| Resource | Notes |
|---|---|
| `qb-core` (or `qbx_core`) | framework |
| `ox_lib` | required |
| `ox_inventory` | required (rewards are given through it) |
| `oxmysql` | required |
| `ox_target` | required |

## Installation

1. Put the folder `sh_chopshop` in your `resources` folder.
2. Make sure the items below exist in `ox_inventory/data/items.lua`.
3. Add to `server.cfg` **after** all the requirements:
   ```cfg
   ensure sh_chopshop
   ```
4. Restart the server and check the console for errors.

### Required items

The default config uses these item names. They must exist in your inventory:

`black_money`, `metalscrap`, `copper`, `steel`, `rubber`, `glass`, `plastic`

You can change them in `config.lua` → `Config.Reward`.

## Protected (non-choppable) vehicles

In `config.lua`:

```lua
-- by class (also covers addon vehicles that use a normal class)
Config.BlacklistedClasses = {
    [17] = true,  -- Service   (taxi, bus, tow truck, trash truck ...)
    [18] = true,  -- Emergency (police, ambulance, fire truck, FBI ...)
    [19] = true,  -- Military
    [21] = true,  -- Trains
}

-- by spawn name — add your addon police / ambulance / taxi cars here
Config.BlacklistedVehicles = { "police", "ambulance", "taxi", ... }
```

Remove a class line to allow it again. If one of your addon job vehicles can still be chopped,
add its spawn name to `Config.BlacklistedVehicles`.

## Configuration

Everything is in `config.lua`, commented: shop location and NPCs, tool pickup spots and props,
hold/grind animations, sparks, payouts, penalties, material rewards, part list and times,
motorcycle options and notification texts.

## Security note

The visual removal of parts happens on the client. A modified client could fake visual actions,
so server-side checks reduce — but cannot fully eliminate — abuse. Keep your server's
anti-cheat up to date.

## License

See [LICENSE](LICENSE). Free to use on your own server; do not resell or re-upload as your own.

## Credits

Made by **Shararah Scripts**.
