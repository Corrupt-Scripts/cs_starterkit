-- Corrupt Scripts | Starter Kit (server)

local Framework, Inventory, QBCore

local function started(res)
    return GetResourceState(res) == 'started'
end

local function dbg(...)
    if Config.Debug then print('[cs_starterkit]', ...) end
end

---------------------------------------------------------------------
-- Framework / inventory bridge
---------------------------------------------------------------------
if Config.Framework ~= 'auto' then
    Framework = Config.Framework
elseif started('qbx_core') then
    Framework = 'qbox'
elseif started('qb-core') then
    Framework = 'qbcore'
else
    error('[cs_starterkit] No supported framework found. Ensure qbx_core or qb-core starts BEFORE cs_starterkit.')
end

if Framework == 'qbcore' then
    QBCore = exports['qb-core']:GetCoreObject()
end

if Config.Inventory ~= 'auto' then
    Inventory = Config.Inventory
elseif started('ox_inventory') then
    Inventory = 'ox'
else
    Inventory = 'qb'
end

print(('[cs_starterkit] Framework: %s | Inventory: %s | Claim mode: %s'):format(Framework, Inventory, Config.ClaimMode))

local function GetPlayer(src)
    if Framework == 'qbox' then return exports.qbx_core:GetPlayer(src) end
    return QBCore.Functions.GetPlayer(src)
end

local function Notify(src, msg, typ)
    if src == 0 then return print('[cs_starterkit] ' .. msg) end
    if Framework == 'qbox' then
        exports.qbx_core:Notify(src, msg, typ)
    else
        TriggerClientEvent('QBCore:Notify', src, msg, typ)
    end
end

local function getIdentifiers(src, Player)
    local pd = Player.PlayerData
    local rockstar = GetPlayerIdentifierByType(src, 'license')   -- license:xxxx (what most old scripts stored)
    local rockstar2 = GetPlayerIdentifierByType(src, 'license2') -- QBox may store this one instead
    local license = rockstar or pd.license
    local cid = pd.citizenid

    if Config.ClaimMode == 'citizenid' then
        local id = 'cid:' .. cid
        return id, license, cid, { id }
    end

    -- Any of these existing in the claims table counts as "already claimed"
    local alts, seen = {}, {}
    for _, v in ipairs({ rockstar, rockstar2, pd.license }) do
        if v and not seen[v] then seen[v] = true; alts[#alts + 1] = v end
    end
    return license, license, cid, alts
end

local MALE_HASH = GetHashKey('mp_m_freemode_01')
local FEMALE_HASH = GetHashKey('mp_f_freemode_01')

local function genderFromModel(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local model = GetEntityModel(ped)
    if model == FEMALE_HASH then return 'female' end
    if model == MALE_HASH then return 'male' end
end

local function genderFromCharinfo(Player)
    local ci = Player.PlayerData.charinfo
    local g = ci and tonumber(ci.gender)
    if g == 1 then return 'female' end
    if g == 0 then return 'male' end
end

local function getGender(src, Player)
    local g
    if Config.GenderSource == 'model' then
        g = genderFromModel(src) or genderFromCharinfo(Player)
    else
        g = genderFromCharinfo(Player) or genderFromModel(src)
    end
    return g or 'male'
end

---------------------------------------------------------------------
-- Items
---------------------------------------------------------------------
local function resolveItemName(name)
    local aliases = Config.ItemAliases and Config.ItemAliases[Inventory]
    return (aliases and aliases[name]) or name
end

local function getItemInfo(name)
    if Inventory == 'ox' then
        local item = exports.ox_inventory:Items(name)
        if item then
            return item.label, ('nui://ox_inventory/web/images/%s.png'):format(name)
        end
    elseif QBCore then
        local item = QBCore.Shared.Items[name]
        if item then
            return item.label, ('nui://%s/html/images/%s'):format(Config.QBInventoryResource, item.image or (name .. '.png'))
        end
    end
end

local function buildKit(gender)
    local kit = Config.Kits[gender] or Config.Kits.male
    local items = {}
    for _, it in ipairs(kit.items or {}) do
        local name = resolveItemName(it.name)
        local label, image = getItemInfo(name)
        if not label then
            print(('[cs_starterkit] ^3WARNING^7: item "%s" does not exist in %s inventory'):format(name, Inventory))
        end
        items[#items + 1] = {
            name = name,
            count = it.count or 1,
            label = it.label or label or name,
            image = it.image or image,
            metadata = it.metadata,
        }
    end
    return {
        title = kit.title,
        subtitle = kit.subtitle,
        cash = kit.cash or 0,
        bank = kit.bank or 0,
        items = items,
        vehicle = kit.vehicle and {
            model = kit.vehicle.model,
            label = kit.vehicle.label or kit.vehicle.model,
            image = kit.vehicle.image,
            garage = kit.vehicle.garage,
        } or nil,
    }
end

local function canCarry(src, items)
    for _, it in ipairs(items) do
        if Inventory == 'ox' then
            if not exports.ox_inventory:CanCarryItem(src, it.name, it.count) then
                return false, it.label
            end
        else
            local ok, res = pcall(function()
                return exports[Config.QBInventoryResource]:CanAddItem(src, it.name, it.count)
            end)
            if ok and res == false then return false, it.label end
        end
    end
    return true
end

local function giveItem(src, Player, it)
    if Inventory == 'ox' then
        return exports.ox_inventory:AddItem(src, it.name, it.count, it.metadata)
    end
    local ok = Player.Functions.AddItem(it.name, it.count, false, it.metadata or {})
    if ok and QBCore and QBCore.Shared.Items[it.name] then
        TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[it.name], 'add', it.count)
    end
    return ok
end

---------------------------------------------------------------------
-- Vehicles
---------------------------------------------------------------------
local PLATE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789'

local function generatePlate()
    local plate
    repeat
        plate = (Config.PlatePrefix or ''):upper():sub(1, 4)
        while #plate < 8 do
            local i = math.random(#PLATE_CHARS)
            plate = plate .. PLATE_CHARS:sub(i, i)
        end
        local exists = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
    until not exists
    return plate
end

local function giveVehicle(license, cid, veh)
    local plate = generatePlate()
    local garage = veh.garage or Config.VehicleGarage

    if Framework == 'qbox' and started('qbx_vehicles') then
        local ok, res = pcall(function()
            return exports.qbx_vehicles:CreatePlayerVehicle({
                model = veh.model,
                citizenid = cid,
                garage = garage,
                props = { plate = plate },
            })
        end)
        if ok and res then return plate end
        dbg('qbx_vehicles:CreatePlayerVehicle failed, falling back to SQL', res)
    end

    local hash = GetHashKey(veh.model)
    MySQL.insert.await(
        'INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { license, cid, veh.model, tostring(hash), json.encode({ plate = plate, model = hash }), plate, garage, 1 }
    )
    return plate
end

---------------------------------------------------------------------
-- Database
---------------------------------------------------------------------
MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `cs_starterkit_claims` (
            `identifier` VARCHAR(100) NOT NULL,
            `license`    VARCHAR(100) DEFAULT NULL,
            `citizenid`  VARCHAR(50)  DEFAULT NULL,
            `name`       VARCHAR(100) DEFAULT NULL,
            `gender`     VARCHAR(10)  DEFAULT NULL,
            `plate`      VARCHAR(8)   DEFAULT NULL,
            `claimed_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`identifier`),
            KEY `license` (`license`),
            KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    dbg('claims table ready')
end)

local function isClaimed(ids)
    if type(ids) ~= 'table' then ids = { ids } end
    local marks = ('?,'):rep(#ids):sub(1, -2)
    return MySQL.scalar.await(('SELECT 1 FROM cs_starterkit_claims WHERE identifier IN (%s) LIMIT 1'):format(marks), ids) ~= nil
end

---------------------------------------------------------------------
-- Events
---------------------------------------------------------------------
local openCooldown, busy = {}, {}

RegisterNetEvent('cs_starterkit:server:open', function(auto)
    local src = source
    local now = GetGameTimer()
    if openCooldown[src] and now - openCooldown[src] < 1500 then return end
    openCooldown[src] = now

    local Player = GetPlayer(src)
    if not Player then return end

    local _, _, _, ids = getIdentifiers(src, Player)
    if isClaimed(ids) then
        if not auto then Notify(src, Config.Locale.alreadyClaimed, 'error') end
        return
    end

    local gender = getGender(src, Player)
    local ci = Player.PlayerData.charinfo or {}

    TriggerClientEvent('cs_starterkit:client:open', src, {
        gender = gender,
        name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''),
        currency = Config.Currency,
        claimMode = Config.ClaimMode,
        kit = buildKit(gender),
    })
end)

local function doClaim(src)
    local Player = GetPlayer(src)
    if not Player then return end

    local id, license, cid, ids = getIdentifiers(src, Player)
    if isClaimed(ids) then
        return TriggerClientEvent('cs_starterkit:client:result', src, false, Config.Locale.alreadyClaimed)
    end

    local gender = getGender(src, Player)
    local kit = buildKit(gender)

    local fits, failedItem = canCarry(src, kit.items)
    if not fits then
        return TriggerClientEvent('cs_starterkit:client:result', src, false, Config.Locale.cantCarry:format(failedItem))
    end

    local ci = Player.PlayerData.charinfo or {}
    local fullName = ('%s %s'):format(ci.firstname or '', ci.lastname or '')

    -- Atomic lock: primary key means only ONE insert can ever succeed per identifier
    local affected = MySQL.update.await(
        'INSERT IGNORE INTO cs_starterkit_claims (identifier, license, citizenid, name, gender) VALUES (?, ?, ?, ?, ?)',
        { id, license, cid, fullName, gender }
    )
    if not affected or affected == 0 then
        return TriggerClientEvent('cs_starterkit:client:result', src, false, Config.Locale.alreadyClaimed)
    end

    for _, it in ipairs(kit.items) do
        if not giveItem(src, Player, it) then
            print(('[cs_starterkit] ^1Failed to give %sx %s to %s (%s)^7'):format(it.count, it.name, GetPlayerName(src), id))
        end
    end

    if kit.cash > 0 then Player.Functions.AddMoney('cash', kit.cash, 'starter-kit') end
    if kit.bank > 0 then Player.Functions.AddMoney('bank', kit.bank, 'starter-kit') end

    local plate
    if kit.vehicle then
        local ok, res = pcall(giveVehicle, license, cid, kit.vehicle)
        if ok then
            plate = res
            MySQL.update('UPDATE cs_starterkit_claims SET plate = ? WHERE identifier = ?', { plate, id })
        else
            print('[cs_starterkit] ^1Vehicle insert failed:^7 ' .. tostring(res))
        end
    end

    print(('[cs_starterkit] %s (%s / %s) claimed the %s kit%s'):format(
        GetPlayerName(src), license, cid, gender, plate and (' - vehicle ' .. plate) or ''))

    local msg = Config.Locale.claimed
    if plate then msg = msg .. ' ' .. Config.Locale.vehicleStored:format(kit.vehicle.label, plate) end

    TriggerClientEvent('cs_starterkit:client:result', src, true, msg, { plate = plate })
    Notify(src, Config.Locale.claimed, 'success')
end

RegisterNetEvent('cs_starterkit:server:claim', function()
    local src = source
    if busy[src] then return end
    busy[src] = true
    local ok, err = pcall(doClaim, src)
    busy[src] = nil
    if not ok then
        print('[cs_starterkit] ^1Claim error:^7 ' .. tostring(err))
        TriggerClientEvent('cs_starterkit:client:result', src, false, Config.Locale.error)
    end
end)

AddEventHandler('playerDropped', function()
    openCooldown[source] = nil
    busy[source] = nil
end)

---------------------------------------------------------------------
-- Admin reset
---------------------------------------------------------------------
if Config.AdminResetCommand then
    RegisterCommand(Config.AdminResetCommand, function(src, args)
        local target = args[1]
        if not target then
            return Notify(src, Config.Locale.resetUsage:format(Config.AdminResetCommand), 'error')
        end

        local affected
        local serverId = tonumber(target)
        if serverId and GetPlayerName(serverId) then
            local P = GetPlayer(serverId)
            if not P then return Notify(src, 'Player not loaded.', 'error') end
            local _, _, _, ids = getIdentifiers(serverId, P)
            local marks = ('?,'):rep(#ids):sub(1, -2)
            affected = MySQL.update.await(('DELETE FROM cs_starterkit_claims WHERE identifier IN (%s)'):format(marks), ids)
            target = GetPlayerName(serverId)
        else
            affected = MySQL.update.await(
                'DELETE FROM cs_starterkit_claims WHERE identifier = ? OR license = ? OR citizenid = ?',
                { target, target, target }
            )
        end

        Notify(src, Config.Locale.resetDone:format(target, affected or 0), 'success')
    end, true)
end

---------------------------------------------------------------------
-- Import existing players / manually mark someone as claimed
---------------------------------------------------------------------

-- One-off: mark EVERY player/character already in the `players` table as claimed.
-- Run from the server console (or as admin):  starterkitimport
if Config.ImportCommand then
    RegisterCommand(Config.ImportCommand, function(src)
        local affected
        if Config.ClaimMode == 'citizenid' then
            affected = MySQL.update.await([[
                INSERT IGNORE INTO cs_starterkit_claims (identifier, license, citizenid, name)
                SELECT CONCAT('cid:', p.citizenid), p.license, p.citizenid, 'Imported'
                FROM players p
                WHERE p.citizenid IS NOT NULL
            ]])
        else
            affected = MySQL.update.await([[
                INSERT IGNORE INTO cs_starterkit_claims (identifier, license, citizenid, name)
                SELECT p.license, p.license, MIN(p.citizenid), 'Imported'
                FROM players p
                WHERE p.license IS NOT NULL
                GROUP BY p.license
            ]])
        end
        Notify(src, Config.Locale.importDone:format(affected or 0, Config.ClaimMode), 'success')
    end, true)
end

local function insertClaim(identifier, license, cid, name)
    return MySQL.update.await(
        'INSERT IGNORE INTO cs_starterkit_claims (identifier, license, citizenid, name) VALUES (?, ?, ?, ?)',
        { identifier, license, cid, name or 'Manually marked' }
    ) or 0
end

-- /markstarterkit <server id | license | citizenid>
if Config.MarkCommand then
    RegisterCommand(Config.MarkCommand, function(src, args)
        local target = args[1]
        if not target then
            return Notify(src, Config.Locale.markUsage:format(Config.MarkCommand), 'error')
        end

        local affected = 0
        local serverId = tonumber(target)

        if serverId and GetPlayerName(serverId) then
            -- Online player
            local P = GetPlayer(serverId)
            if not P then return Notify(src, 'Player not loaded.', 'error') end
            local id, license, cid = getIdentifiers(serverId, P)
            affected = insertClaim(id, license, cid)
            target = GetPlayerName(serverId)

        elseif target:find('^license') then
            -- Offline, by license
            if Config.ClaimMode == 'citizenid' then
                affected = MySQL.update.await([[
                    INSERT IGNORE INTO cs_starterkit_claims (identifier, license, citizenid, name)
                    SELECT CONCAT('cid:', citizenid), license, citizenid, 'Manually marked'
                    FROM players WHERE license = ?
                ]], { target }) or 0
            else
                affected = insertClaim(target, target, nil)
            end

        else
            -- Offline, by citizenid
            local license = MySQL.scalar.await('SELECT license FROM players WHERE citizenid = ? LIMIT 1', { target })
            if not license then
                return Notify(src, Config.Locale.markNotFound:format(target), 'error')
            end
            if Config.ClaimMode == 'citizenid' then
                affected = insertClaim('cid:' .. target, license, target)
            else
                affected = insertClaim(license, license, target)
            end
        end

        if affected > 0 then
            Notify(src, Config.Locale.markDone:format(target), 'success')
        else
            Notify(src, Config.Locale.markAlready:format(target), 'error')
        end
    end, true)
end
