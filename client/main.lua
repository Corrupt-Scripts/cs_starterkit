-- Corrupt Scripts | Starter Kit (client)

local isOpen = false
local kitPed, blip
local lastAuto = -100000

local function started(res)
    return GetResourceState(res) == 'started'
end

local function requestOpen(auto)
    if isOpen then return end
    TriggerServerEvent('cs_starterkit:server:open', auto)
end

local function closeUI()
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

---------------------------------------------------------------------
-- NUI
---------------------------------------------------------------------
RegisterNetEvent('cs_starterkit:client:open', function(data)
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end)

RegisterNetEvent('cs_starterkit:client:result', function(success, message, extra)
    SendNUIMessage({ action = 'result', success = success, message = message, extra = extra })
end)

RegisterNUICallback('close', function(_, cb)
    closeUI()
    cb('ok')
end)

RegisterNUICallback('claim', function(_, cb)
    TriggerServerEvent('cs_starterkit:server:claim')
    cb('ok')
end)

if Config.Command then
    RegisterCommand(Config.Command, function() requestOpen(false) end, false)
end

---------------------------------------------------------------------
-- Auto prompt on first load (qbx_core also fires the QBCore event)
---------------------------------------------------------------------
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    if not Config.AutoPromptOnFirstLoad then return end
    if GetGameTimer() - lastAuto < 15000 then return end
    lastAuto = GetGameTimer()
    SetTimeout(Config.AutoPromptDelay or 6000, function()
        requestOpen(true)
    end)
end)

---------------------------------------------------------------------
-- NPC
---------------------------------------------------------------------
local function targetSystem()
    if Config.Target ~= 'auto' then return Config.Target end
    if started('ox_target') then return 'ox' end
    if started('qb-target') then return 'qb' end
    return 'none'
end

local function spawnPed()
    local p = Config.Ped
    local hash = joaat(p.model)
    RequestModel(hash)
    local tries = 0
    while not HasModelLoaded(hash) and tries < 100 do
        Wait(50)
        tries = tries + 1
    end
    if not HasModelLoaded(hash) then return end

    kitPed = CreatePed(4, hash, p.coords.x, p.coords.y, p.coords.z - 1.0, p.coords.w, false, true)
    SetEntityInvincible(kitPed, true)
    FreezeEntityPosition(kitPed, true)
    SetBlockingOfNonTemporaryEvents(kitPed, true)
    if p.scenario then TaskStartScenarioInPlace(kitPed, p.scenario, 0, true) end
    SetModelAsNoLongerNeeded(hash)

    local ts = targetSystem()
    if ts == 'ox' then
        exports.ox_target:addLocalEntity(kitPed, {{
            name = 'cs_starterkit',
            icon = 'fa-solid fa-gift',
            label = Config.Locale.targetLabel,
            distance = p.interactDistance,
            onSelect = function() requestOpen(false) end,
        }})
    elseif ts == 'qb' then
        exports['qb-target']:AddTargetEntity(kitPed, {
            options = {{
                icon = 'fas fa-gift',
                label = Config.Locale.targetLabel,
                action = function() requestOpen(false) end,
            }},
            distance = p.interactDistance,
        })
    end
end

local function deletePed()
    if kitPed and DoesEntityExist(kitPed) then
        if targetSystem() == 'ox' then pcall(function() exports.ox_target:removeLocalEntity(kitPed, 'cs_starterkit') end) end
        DeleteEntity(kitPed)
    end
    kitPed = nil
end

if Config.Ped.enabled then
    CreateThread(function()
        local b = Config.Ped.blip
        if b and b.enabled then
            blip = AddBlipForCoord(Config.Ped.coords.x, Config.Ped.coords.y, Config.Ped.coords.z)
            SetBlipSprite(blip, b.sprite)
            SetBlipColour(blip, b.colour)
            SetBlipScale(blip, b.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(b.label)
            EndTextCommandSetBlipName(blip)
        end

        local useKeyPrompt = targetSystem() == 'none'
        local pedCoords = vec3(Config.Ped.coords.x, Config.Ped.coords.y, Config.Ped.coords.z)

        while true do
            local sleep = 1000
            local dist = #(GetEntityCoords(PlayerPedId()) - pedCoords)

            if dist < 60.0 and not kitPed then
                spawnPed()
            elseif dist >= 60.0 and kitPed then
                deletePed()
            end

            if useKeyPrompt and kitPed and dist < Config.Ped.interactDistance and not isOpen then
                sleep = 0
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName(Config.Locale.pressToOpen)
                EndTextCommandDisplayHelp(0, false, true, -1)
                if IsControlJustReleased(0, 38) then requestOpen(false) end
            end

            Wait(sleep)
        end
    end)
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    deletePed()
    if blip then RemoveBlip(blip) end
    if isOpen then SetNuiFocus(false, false) end
end)
