# Changelog

## 2.3.0
- New **Exhaust** step: battery -> radiator -> exhaust -> gearbox. Sport vehicles use the sport
  radiator/exhaust models (`Config.SportClasses`).
- **Chop cooldown** (`Config.ChopCooldown`, 30 min default) with a live "you can chop again in X minutes" message.
  Per character, optional admin bypass ACE.
- Closer interaction: you must be near the specific part you chop (`Config.ChopReach`) and pick-ups need
  `Config.PickupDistance`.
- Wheels: `Config.WheelDebris` (`real` = the car's own wheel, or `prop` mode with a wheel prop).
- Security: the server now rejects absurd part lists from the client (`Config.AntiCheat`), the plate
  lookup is rate limited and its cache is capped.
- Fixed: a tool returned when leaving the shop could make a second tool spawn.
- Dropped drills/grinders can be picked up by any player in the shop; they stay on the floor 2 minutes and
  are kept in sync for everyone in the zone.
- Code split into multiple files under `client/` and `server/`.

## 2.2.1
- Job, emergency and service vehicles can no longer be chopped:
  police, sheriff, FBI, riot, ambulance, fire trucks, taxis, buses, tow and trash trucks.
- New `Config.BlacklistedClasses` (vehicle classes 17, 18, 19, 21 blocked by default) so addon
  vehicles are covered too; `Config.BlacklistedVehicles` list expanded.
- Server also checks the reported vehicle class when a claim is requested.
- New README, LICENSE and changelog.
