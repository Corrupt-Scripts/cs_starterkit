# cs_starterkit — Corrupt Scripts

Gender-aware, one-time starter kit with a NUI menu. Works on **QBox** and **QBCore** (auto-detected),
**ox_inventory** and **qb-inventory** (auto-detected), stored in MySQL via **oxmysql**.

## Install
1. Drop `cs_starterkit` into your resources folder.
2. In `server.cfg`, ensure it **after** your core + inventory:
   ```
   ensure oxmysql
   ensure qbx_core        # or qb-core
   ensure ox_inventory    # or qb-inventory
   ensure cs_starterkit
   ```
3. The DB table is created automatically (or run `install.sql`).
4. Admin reset permission:
   ```
   add_ace group.admin command.resetstarterkit allow
   ```

## How it works
- **Gender**: read from the character (`charinfo.gender`: 0 = male, 1 = female), falling back to the
  freemode ped model. Swap priority with `Config.GenderSource = 'model'`.
- **Once only**: every claim is written to `cs_starterkit_claims` with a PRIMARY KEY lock, so it's
  impossible to double-claim (even by spamming the event). `Config.ClaimMode`:
  `'license'` = once per player across all characters (default), `'citizenid'` = once per character.
- **Opening**: NPC at LSIA (ox_target / qb-target / press E fallback), `/starterkit`, and an automatic
  pop-up on first load for players who haven't claimed.
- **Vehicle**: stored in the configured garage. On QBox uses `qbx_vehicles`, otherwise inserts into `player_vehicles`.

## Importing players from the old starter pack
Run `import_old_claims.sql` once (after the resource has started once). It adds the 132 players who
already received the old pack. Claims are matched on both `license:` and `license2:`, so this works on QBox too.

## Admin
- `/resetstarterkit <server id | license | citizenid>` — lets that player claim again.
- `starterkitimport` (server console) — **run once** to mark every existing player/character in the
  `players` table as already claimed. Safe to re-run; it never duplicates.
- `/markstarterkit <server id | license | citizenid>` — mark one person as claimed (online or offline).

Aces:
```
add_ace group.admin command.resetstarterkit allow
add_ace group.admin command.starterkitimport allow
add_ace group.admin command.markstarterkit allow
```
Imported rows have `name = 'Imported'` so you can tell them apart in the database.

## Config notes
- Item names default to ox_inventory names; `Config.ItemAliases.qb` maps them for qb-inventory.
  A console warning prints if an item doesn't exist.
- Set `Config.VehicleGarage` to a garage that exists on your server
  (QBCore default `pillboxgarage`, QBox default `motelgarage`).
