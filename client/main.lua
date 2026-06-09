-- ==========================================
-- SEERPG FUTÁR - KLIENS OLDAL
-- Komplett futár munka rendszer
-- Kattintható ikon interakciós rendszer (ALT kurzor)
-- ==========================================

-- ==========================================
-- VÁLTOZÓK
-- ==========================================
local isWorking = false
local isOnRound = false
local isUIOpen = false
local jobVehicle = nil
local jobNPC = nil
local depotBlip = nil
local deliveryBlip = nil
local routeBlip = nil

-- Kör adatok
local currentRound = {
    deliveries = {},
    currentDeliveryIndex = 0,
    pickedUp = false,
    completedDeliveries = {},
    startTime = 0,
    totalDeliveries = 0,
}

-- Cooldown
local lastRoundEnd = 0

-- Prop változók
local currentProp = nil

-- Játékos skill adatok (cache)
local playerSkillData = nil

-- ==========================================
-- BEPAKOLÁS RENDSZER VÁLTOZÓK
-- ==========================================
local loadingPhase = false
local palletProps = {}
local palletBaseObj = nil
local cargoProps = {}
local isCarrying = false
local carryingIndex = 0
local carryingType = nil
local packagesLoaded = 0
local isDoorOpen = false
local isAnimPlaying = false

-- ==========================================
-- INTERAKCIÓS IKON RENDSZER VÁLTOZÓK
-- ==========================================
local isCursorMode = false
local currentInteractions = {}
local altHintShown = false

-- ==========================================
-- LOCKER KÉZBESÍTÉS VÁLTOZÓK
-- ==========================================
local allLockerObjects = {}          -- MINDEN fix locker prop (soha nem törlődnek)
local allLockerBlips = {}            -- Locker blipek
local isLockerDoorOpen = false       -- Fiók nyitva van-e
local openedCompartment = 0          -- Melyik fiók van nyitva (index)
local hasPackageInHand = false       -- Kézbesítés közben van-e csomag kézben
local assignedCompartment = 0        -- Melyik fiókba kell berakni
local currentLockerTarget = nil      -- Aktuálisan aktív locker (ahova most kell vinni)

-- ==========================================
-- TÖRÉKENY CSOMAG RENDSZER VÁLTOZÓK
-- ==========================================
local fragileDamage = {}             -- {deliveryIndex = damagePercent}
local lastVehicleSpeed = 0.0
local lastVehicleHealth = 1000

-- ==========================================
-- EXPRESSZ CSOMAG RENDSZER VÁLTOZÓK
-- ==========================================
local expressTimers = {}             -- {deliveryIndex = {startTime, timeLimit}}

-- ==========================================
-- BOLT RENDSZER VÁLTOZÓK
-- ==========================================
local shopNPC = nil

-- ==========================================
-- INICIALIZÁLÁS
-- ==========================================
CreateThread(function()
    if Config.Depot.blip.enabled then
        depotBlip = AddBlipForCoord(Config.Depot.coords)
        SetBlipSprite(depotBlip, Config.Depot.blip.sprite)
        SetBlipColour(depotBlip, Config.Depot.blip.color)
        SetBlipScale(depotBlip, Config.Depot.blip.scale)
        SetBlipAsShortRange(depotBlip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Config.Depot.blip.label)
        EndTextCommandSetBlipName(depotBlip)
    end

    -- Fix lockerek spawnolása (SOHA nem tűnnek el!)
    SpawnAllLockers()

    SpawnJobNPC()
    SpawnShopNPC()
end)

-- ==========================================
-- FIX LOCKEREK SPAWNOLÁSA (mindig jelen vannak)
-- ==========================================
function SpawnAllLockers()
    local model = GetHashKey(Config.Locker.model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end

    for _, lockerPoint in ipairs(Config.LockerPoints) do
        -- Locker prop
        local obj = CreateObject(model, lockerPoint.coords.x, lockerPoint.coords.y, lockerPoint.coords.z, false, false, false)
        SetEntityHeading(obj, lockerPoint.heading)
        FreezeEntityPosition(obj, true)
        SetEntityAsMissionEntity(obj, true, true)

        allLockerObjects[lockerPoint.id] = obj

        -- Blip
        local blip = AddBlipForCoord(lockerPoint.coords)
        SetBlipSprite(blip, Config.LockerBlip.sprite)
        SetBlipColour(blip, Config.LockerBlip.color)
        SetBlipScale(blip, Config.LockerBlip.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(lockerPoint.label)
        EndTextCommandSetBlipName(blip)

        allLockerBlips[lockerPoint.id] = blip
    end

    SetModelAsNoLongerNeeded(model)

    if Config.Debug then
        print('[RealRPG-Futar] ' .. #Config.LockerPoints .. ' fix locker spawnolva.')
    end
end

-- ==========================================
-- NPC KEZELÉS
-- ==========================================
function SpawnJobNPC()
    local npcConfig = Config.NPC
    local model = GetHashKey(npcConfig.model)

    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end

    jobNPC = CreatePed(4, model, npcConfig.coords.x, npcConfig.coords.y, npcConfig.coords.z, npcConfig.coords.w, false, true)
    SetEntityInvincible(jobNPC, true)
    SetBlockingOfNonTemporaryEvents(jobNPC, true)
    FreezeEntityPosition(jobNPC, true)
    SetEntityHeading(jobNPC, npcConfig.coords.w)

    if npcConfig.scenario then
        TaskStartScenarioInPlace(jobNPC, npcConfig.scenario, 0, true)
    end

    SetModelAsNoLongerNeeded(model)
end

-- ==========================================
-- BOLT NPC KEZELÉS
-- ==========================================
function SpawnShopNPC()
    if not Config.Shop or not Config.Shop.enabled then return end

    local shopConfig = Config.Shop.npc
    local model = GetHashKey(shopConfig.model)

    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end

    shopNPC = CreatePed(4, model, shopConfig.coords.x, shopConfig.coords.y, shopConfig.coords.z, shopConfig.coords.w, false, true)
    SetEntityInvincible(shopNPC, true)
    SetBlockingOfNonTemporaryEvents(shopNPC, true)
    FreezeEntityPosition(shopNPC, true)
    SetEntityHeading(shopNPC, shopConfig.coords.w)

    if shopConfig.scenario then
        TaskStartScenarioInPlace(shopNPC, shopConfig.scenario, 0, true)
    end

    SetModelAsNoLongerNeeded(model)
end

-- ==========================================
-- KURZOR KEZELÉS (ALT GOMB)
-- ==========================================
CreateThread(function()
    while true do
        Wait(0)

        -- ALT gomb lenyomás detektálás
        if IsControlJustPressed(0, Config.Interaction.cursorKey) then
            if #currentInteractions > 0 and not isUIOpen then
                EnableCursorMode()
            end
        end

        -- ALT gomb elengedés
        if isCursorMode and IsControlJustReleased(0, Config.Interaction.cursorKey) then
            DisableCursorMode()
        end

        -- Ha kurzor módban vagyunk, tartjuk a focus-t
        if isCursorMode then
            DisableControlAction(0, 1, true)   -- Look LR
            DisableControlAction(0, 2, true)   -- Look UD
            DisableControlAction(0, 142, true)  -- MeleeAttackAlternate
            DisableControlAction(0, 106, true)  -- VehicleMouseControlOverride
        end
    end
end)

function EnableCursorMode()
    if isCursorMode then return end
    isCursorMode = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)

    SendNUIMessage({
        action = 'setCursorActive',
        data = { active = true }
    })

    -- Ikonok megjelenítése a képernyőn
    RefreshInteractionIcons()
end

function DisableCursorMode()
    if not isCursorMode then return end
    isCursorMode = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    SendNUIMessage({
        action = 'setCursorActive',
        data = { active = false }
    })

    SendNUIMessage({ action = 'hideInteractionIcons' })
end

-- ==========================================
-- INTERAKCIÓ DETEKTÁLÁS LOOP
-- Határozza meg, milyen interakciók elérhetők
-- ==========================================
CreateThread(function()
    while true do
        local sleep = 500
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local newInteractions = {}

        -- ==========================================
        -- DEPÓ / NPC INTERAKCIÓK
        -- ==========================================
        local distToDepot = #(playerCoords - Config.Depot.coords)

        if distToDepot < Config.Interaction.depotDistance then
            if not isWorking then
                -- Munka indítás
                table.insert(newInteractions, {
                    id = 'start_work',
                    type = 'start_work',
                    worldCoords = vector3(Config.Depot.coords.x, Config.Depot.coords.y, Config.Depot.coords.z + 1.0)
                })
            elseif isWorking and not isOnRound then
                local canStart = (GetGameTimer() - lastRoundEnd) > (Config.Round.cooldownBetweenRounds * 1000)

                if canStart then
                    table.insert(newInteractions, {
                        id = 'new_round',
                        type = 'new_round',
                        worldCoords = vector3(Config.Depot.coords.x, Config.Depot.coords.y, Config.Depot.coords.z + 1.2)
                    })
                end

                table.insert(newInteractions, {
                    id = 'end_work',
                    type = 'end_work',
                    worldCoords = vector3(Config.Depot.coords.x - 0.5, Config.Depot.coords.y, Config.Depot.coords.z + 0.7)
                })

                table.insert(newInteractions, {
                    id = 'view_skill',
                    type = 'view_skill',
                    worldCoords = vector3(Config.Depot.coords.x + 0.5, Config.Depot.coords.y, Config.Depot.coords.z + 0.7)
                })
            elseif isWorking and isOnRound and currentRound.pickedUp and currentRound.currentDeliveryIndex > #currentRound.deliveries then
                -- Kör lezárás
                table.insert(newInteractions, {
                    id = 'finish_round',
                    type = 'finish_round',
                    worldCoords = vector3(Config.Depot.coords.x, Config.Depot.coords.y, Config.Depot.coords.z + 1.0)
                })
            end
        end

        -- ==========================================
        -- JÁRMŰ JAVÍTÁS INTERAKCIÓ
        -- ==========================================
        if isWorking and not isOnRound and Config.VehicleRepair.enabled and jobVehicle and DoesEntityExist(jobVehicle) then
            local vehHealth = GetEntityHealth(jobVehicle) - 100 -- Entity health starts at 100 (body) 
            local engineHealth = GetVehicleEngineHealth(jobVehicle)
            local combinedHealth = math.min(vehHealth, engineHealth)

            if combinedHealth < Config.VehicleRepair.minHealthToStart then
                local distToRepair = #(playerCoords - Config.VehicleRepair.repairPoint)
                if distToRepair < Config.VehicleRepair.repairDistance then
                    table.insert(newInteractions, {
                        id = 'repair_vehicle',
                        type = 'repair_vehicle',
                        worldCoords = vector3(Config.VehicleRepair.repairPoint.x, Config.VehicleRepair.repairPoint.y, Config.VehicleRepair.repairPoint.z + 1.0)
                    })
                end
            end
        end

        -- ==========================================
        -- BOLT NPC INTERAKCIÓ
        -- ==========================================
        if isWorking and not isOnRound and Config.Shop.enabled and shopNPC and DoesEntityExist(shopNPC) then
            local shopCoords = GetEntityCoords(shopNPC)
            local distToShop = #(playerCoords - shopCoords)
            if distToShop < Config.Interaction.depotDistance then
                table.insert(newInteractions, {
                    id = 'open_shop',
                    type = 'open_shop',
                    worldCoords = vector3(shopCoords.x, shopCoords.y, shopCoords.z + 1.2)
                })
            end
        end

        -- ==========================================
        -- RAKLAP INTERAKCIÓ (bepakolás fázis)
        -- ==========================================
        if loadingPhase and not isCarrying and not isAnimPlaying then
            local palletCoords = GetPalletWorldCoords()
            local distToPallet = #(playerCoords - palletCoords)

            if distToPallet < Config.Pallet.pickupDistance then
                -- Van még csomag a raklapon?
                local hasPackage = false
                for _, pData in ipairs(palletProps) do
                    if not pData.taken then hasPackage = true break end
                end

                if hasPackage then
                    table.insert(newInteractions, {
                        id = 'pickup_package',
                        type = 'pickup_package',
                        worldCoords = vector3(palletCoords.x, palletCoords.y, palletCoords.z + 1.0)
                    })
                end
            end
        end

        -- ==========================================
        -- JÁRMŰ OLDAL INTERAKCIÓ (bepakolás fázis)
        -- ==========================================
        if loadingPhase and jobVehicle and DoesEntityExist(jobVehicle) and not isAnimPlaying then
            local loadPoint = GetVehicleLoadPoint()
            local distToLoad = #(playerCoords - loadPoint)

            if distToLoad < Config.VehicleCargo.doorInteractDistance then
                if not isDoorOpen then
                    -- Ajtó kinyitás
                    table.insert(newInteractions, {
                        id = 'open_door',
                        type = 'open_door',
                        worldCoords = vector3(loadPoint.x, loadPoint.y, loadPoint.z + 0.5)
                    })
                else
                    if isCarrying then
                        -- Csomag berakás
                        table.insert(newInteractions, {
                            id = 'load_package',
                            type = 'load_package',
                            worldCoords = vector3(loadPoint.x, loadPoint.y, loadPoint.z + 0.5)
                        })
                    else
                        if packagesLoaded >= currentRound.totalDeliveries then
                            -- Bepakolás kész, ajtó zárás
                            table.insert(newInteractions, {
                                id = 'finish_loading',
                                type = 'finish_loading',
                                worldCoords = vector3(loadPoint.x, loadPoint.y, loadPoint.z + 0.5)
                            })
                        else
                            -- Ajtó bezárás
                            table.insert(newInteractions, {
                                id = 'close_door',
                                type = 'close_door',
                                worldCoords = vector3(loadPoint.x, loadPoint.y, loadPoint.z + 0.5)
                            })
                        end
                    end
                end
            end
        end

        -- ==========================================
        -- KÉZBESÍTÉSI PONT INTERAKCIÓ (Locker rendszer)
        -- ==========================================
        if isOnRound and currentRound.pickedUp and currentRound.currentDeliveryIndex <= #currentRound.deliveries and not isAnimPlaying then
            local delivery = currentRound.deliveries[currentRound.currentDeliveryIndex]
            if delivery then
                local distToDelivery = #(playerCoords - delivery.coords)
                if distToDelivery < Config.Interaction.deliveryDistance + 3.0 then

                    -- Target locker beállítása (ha még nincs)
                    if not currentLockerTarget then
                        SetCurrentLockerTarget(delivery)
                    end

                    if not hasPackageInHand then
                        -- 1. Lépés: Csomag kivétele a járműből
                        if jobVehicle and DoesEntityExist(jobVehicle) then
                            local vehLoadPoint = GetVehicleLoadPoint()
                            local distToVeh = #(playerCoords - vehLoadPoint)
                            if distToVeh < Config.VehicleCargo.doorInteractDistance + 1.0 then
                                table.insert(newInteractions, {
                                    id = 'take_from_vehicle',
                                    type = 'take_from_vehicle',
                                    worldCoords = vector3(vehLoadPoint.x, vehLoadPoint.y, vehLoadPoint.z + 0.5)
                                })
                            end
                        end
                    else
                        -- 2. Lépés: Locker fiók kezelés
                        local lockerObj = allLockerObjects[delivery.lockerId]
                        if lockerObj and DoesEntityExist(lockerObj) then
                            local lockerCoords = GetEntityCoords(lockerObj)
                            local distToLocker = #(playerCoords - lockerCoords)

                            if distToLocker < Config.Locker.interactDistance then
                                if not isLockerDoorOpen then
                                    table.insert(newInteractions, {
                                        id = 'open_locker',
                                        type = 'open_locker',
                                        worldCoords = vector3(lockerCoords.x, lockerCoords.y, lockerCoords.z + Config.Locker.compartments[assignedCompartment].offsetZ + 0.2)
                                    })
                                else
                                    table.insert(newInteractions, {
                                        id = 'deliver',
                                        type = 'deliver',
                                        worldCoords = vector3(lockerCoords.x, lockerCoords.y, lockerCoords.z + Config.Locker.compartments[assignedCompartment].offsetZ + 0.2)
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end

        -- ==========================================
        -- INTERAKCIÓ VÁLTOZÁS KEZELÉS
        -- ==========================================
        currentInteractions = newInteractions

        -- ALT hint megjelenítés ha van elérhető interakció
        if #currentInteractions > 0 and not altHintShown and not isUIOpen then
            altHintShown = true
            SendNUIMessage({ action = 'showAltHint' })
        elseif #currentInteractions == 0 and altHintShown then
            altHintShown = false
            SendNUIMessage({ action = 'hideAltHint' })
            if isCursorMode then
                DisableCursorMode()
            end
        end

        -- Ha kurzor módban vagyunk, frissítsük az ikonokat
        if isCursorMode then
            RefreshInteractionIcons()
        end

        Wait(sleep)
    end
end)

-- ==========================================
-- IKON POZÍCIÓ FRISSÍTÉS (GYORS LOOP)
-- ==========================================
CreateThread(function()
    while true do
        Wait(0)

        if isCursorMode and #currentInteractions > 0 then
            local updates = {}

            for _, interaction in ipairs(currentInteractions) do
                local onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(
                    interaction.worldCoords.x,
                    interaction.worldCoords.y,
                    interaction.worldCoords.z
                )

                table.insert(updates, {
                    id = interaction.id,
                    screenX = screenX,
                    screenY = screenY,
                    visible = onScreen
                })
            end

            SendNUIMessage({
                action = 'updateIconPositions',
                data = { icons = updates }
            })
        end

        -- Markerek rajzolása (nem kurzor módban is, vizuális segítség)
        if isWorking then
            DrawActiveMarkers()
        end
    end
end)

-- ==========================================
-- IKONOK NUI-NAK KÜLDÉSE
-- ==========================================
function RefreshInteractionIcons()
    local iconConfigs = Config.Interaction.icons
    local iconsToSend = {}

    for _, interaction in ipairs(currentInteractions) do
        local iconCfg = iconConfigs[interaction.type]
        if iconCfg then
            local onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(
                interaction.worldCoords.x,
                interaction.worldCoords.y,
                interaction.worldCoords.z
            )

            table.insert(iconsToSend, {
                id = interaction.id,
                type = interaction.type,
                icon = iconCfg.icon,
                tooltip = iconCfg.tooltip,
                color = iconCfg.color,
                screenX = screenX,
                screenY = screenY,
                visible = onScreen
            })
        end
    end

    SendNUIMessage({
        action = 'showInteractionIcons',
        data = { icons = iconsToSend }
    })
end

-- ==========================================
-- NUI CALLBACK - IKON KATTINTÁS
-- ==========================================
RegisterNUICallback('iconClicked', function(data, cb)
    local iconType = data.type

    -- Kurzor mód kikapcsolás kattintás után
    DisableCursorMode()

    -- Akció végrehajtás típus alapján
    if iconType == 'start_work' then
        StartJob()
    elseif iconType == 'new_round' then
        StartRound()
    elseif iconType == 'end_work' then
        EndJob()
    elseif iconType == 'view_skill' then
        OpenSkillPanel()
    elseif iconType == 'finish_round' then
        FinishRound()
    elseif iconType == 'pickup_package' then
        PickupFromPallet()
    elseif iconType == 'open_door' then
        OpenVehicleDoor()
    elseif iconType == 'close_door' then
        CloseVehicleDoor()
    elseif iconType == 'load_package' then
        LoadPackageIntoVehicle()
    elseif iconType == 'finish_loading' then
        CloseVehicleDoor()
        FinishLoading()
    elseif iconType == 'take_from_vehicle' then
        TakePackageFromVehicle()
    elseif iconType == 'open_locker' then
        OpenLockerCompartment()
    elseif iconType == 'deliver' then
        DeliverToLocker()
    elseif iconType == 'repair_vehicle' then
        RepairJobVehicle()
    elseif iconType == 'open_shop' then
        OpenShop()
    end

    cb('ok')
end)

RegisterNUICallback('closeUI', function(data, cb)
    SetNuiFocus(false, false)
    isUIOpen = false
    isCursorMode = false
    cb('ok')
end)

-- ==========================================
-- MARKER RAJZOLÁS (vizuális segítség, NEM interakció)
-- ==========================================
function DrawActiveMarkers()
    local playerCoords = GetEntityCoords(PlayerPedId())

    -- Depó marker
    local distToDepot = #(playerCoords - Config.Depot.coords)
    if distToDepot < 30.0 then
        local marker = Config.Markers.depot
        DrawMarker(marker.type,
            Config.Depot.coords.x, Config.Depot.coords.y, Config.Depot.coords.z - 1.0,
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
            marker.size.x, marker.size.y, marker.size.z,
            marker.color.r, marker.color.g, marker.color.b, marker.color.a,
            false, false, 2, false, nil, nil, false)
    end

    -- Raklap marker (bepakolás fázis)
    if loadingPhase and not isCarrying then
        local palletCoords = GetPalletWorldCoords()
        local distToPallet = #(playerCoords - palletCoords)
        if distToPallet < 8.0 then
            local marker = Config.Markers.pickup
            DrawMarker(marker.type,
                palletCoords.x, palletCoords.y, palletCoords.z - 1.0,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                marker.size.x, marker.size.y, marker.size.z,
                marker.color.r, marker.color.g, marker.color.b, marker.color.a,
                false, false, 2, false, nil, nil, false)
        end
    end

    -- Jármű load pont marker (bepakolás fázis)
    if loadingPhase and jobVehicle and DoesEntityExist(jobVehicle) then
        local loadPoint = GetVehicleLoadPoint()
        local distToLoad = #(playerCoords - loadPoint)
        if distToLoad < 5.0 then
            DrawMarker(25,
                loadPoint.x, loadPoint.y, loadPoint.z - 0.95,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                0.8, 0.8, 0.5,
                50, 150, 255, 120,
                false, false, 2, false, nil, nil, false)
        end
    end

    -- Kézbesítési pont marker + Locker
    if isOnRound and currentRound.pickedUp and currentRound.currentDeliveryIndex <= #currentRound.deliveries then
        local delivery = currentRound.deliveries[currentRound.currentDeliveryIndex]
        if delivery then
            local distToDelivery = #(playerCoords - delivery.coords)
            if distToDelivery < 30.0 then
                local marker = Config.Markers.delivery
                DrawMarker(marker.type,
                    delivery.coords.x, delivery.coords.y, delivery.coords.z - 1.0,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    marker.size.x, marker.size.y, marker.size.z,
                    marker.color.r, marker.color.g, marker.color.b, marker.color.a,
                    false, false, 2, false, nil, nil, false)
            end

            -- Locker marker (aktív target locker kiemelés)
            if currentLockerTarget and currentLockerTarget.lockerId then
                local lockerObj = allLockerObjects[currentLockerTarget.lockerId]
                if lockerObj and DoesEntityExist(lockerObj) then
                    local lockerCoords = GetEntityCoords(lockerObj)
                    DrawMarker(25,
                        lockerCoords.x, lockerCoords.y, lockerCoords.z - 0.95,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.6, 0.6, 0.4,
                        255, 165, 0, 120,
                        false, false, 2, false, nil, nil, false)
                end
            end
        end
    end
end

-- ==========================================
-- HUD LOOP
-- ==========================================
CreateThread(function()
    while true do
        if isOnRound then
            local elapsed = math.floor((GetGameTimer() - currentRound.startTime) / 1000)
            local remaining = Config.Round.maxTime - elapsed

            if loadingPhase then
                SendNUIMessage({
                    action = 'updateHUD',
                    data = {
                        show = true,
                        timeRemaining = remaining,
                        deliveriesCompleted = packagesLoaded,
                        deliveriesTotal = currentRound.totalDeliveries,
                        currentDeliveryLabel = 'Bepakolás...',
                        currentDeliveryType = 'loading'
                    }
                })
            elseif currentRound.pickedUp then
                local completed = #currentRound.completedDeliveries
                local currentIdx = currentRound.currentDeliveryIndex
                local currentDelivery = currentRound.deliveries[currentIdx]

                SendNUIMessage({
                    action = 'updateHUD',
                    data = {
                        show = true,
                        timeRemaining = remaining,
                        deliveriesCompleted = completed,
                        deliveriesTotal = currentRound.totalDeliveries,
                        currentDeliveryLabel = currentDelivery and currentDelivery.label or '',
                        currentDeliveryType = currentDelivery and currentDelivery.type or ''
                    }
                })

                -- Expressz timer NUI frissítés
                if currentDelivery and currentDelivery.isExpress and expressTimers[currentIdx] then
                    local timerData = expressTimers[currentIdx]
                    local expressElapsed = (GetGameTimer() - timerData.startTime) / 1000
                    local expressRemaining = timerData.timeLimit - expressElapsed
                    if expressRemaining < 0 then expressRemaining = 0 end

                    local percentRemaining = (expressRemaining / timerData.timeLimit) * 100
                    local timerColor = 'normal'
                    if percentRemaining <= Config.Express.criticalPercent then
                        timerColor = 'critical'
                    elseif percentRemaining <= Config.Express.warningPercent then
                        timerColor = 'warning'
                    end

                    SendNUIMessage({
                        action = 'updateExpressTimer',
                        data = {
                            active = true,
                            timeRemaining = math.floor(expressRemaining),
                            timerColor = timerColor
                        }
                    })
                else
                    SendNUIMessage({
                        action = 'updateExpressTimer',
                        data = { active = false }
                    })
                end

                -- Törékeny csomag indikátor
                if currentDelivery and currentDelivery.isFragile then
                    SendNUIMessage({
                        action = 'updateFragileIndicator',
                        data = {
                            show = true,
                            isFragile = true,
                            damage = fragileDamage[currentIdx] or 0,
                            label = Config.Fragile.label
                        }
                    })
                else
                    SendNUIMessage({
                        action = 'updateFragileIndicator',
                        data = { show = false }
                    })
                end
            else
                SendNUIMessage({ action = 'updateHUD', data = { show = false } })
            end

            -- Időlimit ellenőrzés
            if remaining <= 0 then
                Notify(Config.Locale.time_expired)
                CancelRound()
            end
        else
            SendNUIMessage({ action = 'updateHUD', data = { show = false } })
        end

        Wait(1000)
    end
end)

-- ==========================================
-- JÁRMŰ ELLENŐRZÉS
-- ==========================================
CreateThread(function()
    while true do
        if isWorking and jobVehicle then
            if not DoesEntityExist(jobVehicle) or IsEntityDead(jobVehicle) then
                Notify(Config.Locale.vehicle_destroyed)
                if isOnRound then CancelRound() end
                jobVehicle = nil
            end
        end
        Wait(5000)
    end
end)

-- ==========================================
-- MUNKA INDÍTÁS
-- ==========================================
function StartJob()
    if isWorking then
        Notify(Config.Locale.already_working)
        return
    end
    TriggerServerEvent('seerpg-futar:server:startJob')
end

RegisterNetEvent('seerpg-futar:client:jobStarted', function(skillData)
    isWorking = true
    playerSkillData = skillData

    -- Jármű választó panel megnyitása
    isUIOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showVehicleSelector',
        data = {
            vehicles = Config.VehicleUpgrades,
            skillLevel = skillData.skillLevel
        }
    })

    Notify(Config.Locale.job_started)
end)

-- Jármű kiválasztva (NUI callback)
RegisterNUICallback('vehicleSelected', function(data, cb)
    SetNuiFocus(false, false)
    isUIOpen = false

    local vehicleIndex = data.index or 1
    local vehicle = Config.VehicleUpgrades[vehicleIndex]

    if vehicle and playerSkillData and playerSkillData.skillLevel >= vehicle.minLevel then
        SpawnJobVehicle(playerSkillData.skillLevel, vehicleIndex)
    else
        -- Fallback: első jármű
        SpawnJobVehicle(playerSkillData and playerSkillData.skillLevel or 1, 1)
    end

    -- Első kör indítás
    Wait(2000)
    StartRound()

    cb('ok')
end)

-- ==========================================
-- MUNKA BEFEJEZÉS
-- ==========================================
function EndJob()
    if not isWorking then return end
    if isOnRound then CancelRound() end

    DeleteJobVehicle()
    DeleteCurrentProp()
    CleanupPallet()
    CleanupCargoProps()
    ClearCurrentLockerTarget()

    isWorking = false
    isCarrying = false
    isDoorOpen = false
    loadingPhase = false
    hasPackageInHand = false
    playerSkillData = nil

    RemoveDeliveryBlip()
    RemoveRouteBlip()

    TriggerServerEvent('seerpg-futar:server:endJob')
    Notify(Config.Locale.job_ended)
end

-- ==========================================
-- JÁRMŰ KEZELÉS
-- ==========================================
function SpawnJobVehicle(skillLevel, vehicleIndex)
    local selectedVehicle
    if vehicleIndex and Config.VehicleUpgrades[vehicleIndex] then
        selectedVehicle = Config.VehicleUpgrades[vehicleIndex]
    else
        selectedVehicle = Config.VehicleUpgrades[1]
        for i = #Config.VehicleUpgrades, 1, -1 do
            if skillLevel >= Config.VehicleUpgrades[i].minLevel then
                selectedVehicle = Config.VehicleUpgrades[i]
                break
            end
        end
    end

    local model = GetHashKey(selectedVehicle.model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end

    local spawnPoint = Config.Vehicle.spawnPoint
    jobVehicle = CreateVehicle(model, spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.w, true, false)

    SetVehicleColours(jobVehicle, Config.Vehicle.color.primary, Config.Vehicle.color.secondary)
    SetVehicleNumberPlateText(jobVehicle, 'FUTAR')
    SetEntityAsMissionEntity(jobVehicle, true, true)
    SetVehicleDirtLevel(jobVehicle, 0.0)
    SetVehicleDoorsLocked(jobVehicle, 1)
    SetVehicleDoorShut(jobVehicle, Config.VehicleCargo.doorIndex, false)
    SetModelAsNoLongerNeeded(model)

    local vehBlip = AddBlipForEntity(jobVehicle)
    SetBlipSprite(vehBlip, 67)
    SetBlipColour(vehBlip, 3)
    SetBlipScale(vehBlip, 0.7)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Futár Jármű')
    EndTextCommandSetBlipName(vehBlip)
end

function DeleteJobVehicle()
    if jobVehicle and DoesEntityExist(jobVehicle) then
        DeleteEntity(jobVehicle)
        jobVehicle = nil
    end
end

-- ==========================================
-- KÖR INDÍTÁS
-- ==========================================
function StartRound()
    if isOnRound then return end

    local canStart = (GetGameTimer() - lastRoundEnd) > (Config.Round.cooldownBetweenRounds * 1000)
    if not canStart then
        Notify(Config.Locale.cooldown_active)
        return
    end

    TriggerServerEvent('seerpg-futar:server:requestRound')
end

RegisterNetEvent('seerpg-futar:client:roundGenerated', function(roundData)
    isOnRound = true

    currentRound = {
        deliveries = roundData.deliveries,
        currentDeliveryIndex = 1,
        pickedUp = false,
        completedDeliveries = {},
        startTime = GetGameTimer(),
        totalDeliveries = #roundData.deliveries,
    }

    loadingPhase = true
    packagesLoaded = 0
    isCarrying = false
    carryingIndex = 0
    carryingType = nil
    isDoorOpen = false

    -- Expressz timer inicializálás
    expressTimers = {}
    fragileDamage = {}
    for i, delivery in ipairs(roundData.deliveries) do
        if delivery.isExpress then
            expressTimers[i] = { startTime = GetGameTimer(), timeLimit = delivery.expressTimeLimit }
        end
        if delivery.isFragile then
            fragileDamage[i] = 0
        end
    end

    SpawnPalletWithPackages()
    Notify(Config.Locale.round_started)
end)

-- ==========================================
-- RAKLAP RENDSZER
-- ==========================================
function GetPalletWorldCoords()
    local pallet = Config.Pallet
    return vector3(pallet.coords.x, pallet.coords.y, pallet.coords.z)
end

function SpawnPalletWithPackages()
    CleanupPallet()

    local palletConfig = Config.Pallet
    local palletPos = GetPalletWorldCoords()
    local heading = palletConfig.coords.w

    local palletModel = GetHashKey(palletConfig.model)
    RequestModel(palletModel)
    while not HasModelLoaded(palletModel) do Wait(10) end

    palletBaseObj = CreateObject(palletModel, palletPos.x, palletPos.y, palletPos.z, false, false, false)
    SetEntityHeading(palletBaseObj, heading)
    FreezeEntityPosition(palletBaseObj, true)
    SetEntityAsMissionEntity(palletBaseObj, true, true)
    SetModelAsNoLongerNeeded(palletModel)

    palletProps = {}
    for i = 1, currentRound.totalDeliveries do
        local slotIndex = ((i - 1) % #palletConfig.packageSlots) + 1
        local slot = palletConfig.packageSlots[slotIndex]
        local deliveryType = currentRound.deliveries[i].type

        local propName = GetPropNameForType(deliveryType)
        local propModel = GetHashKey(propName)
        RequestModel(propModel)
        while not HasModelLoaded(propModel) do Wait(10) end

        local rad = math.rad(heading)
        local rotatedX = slot.offset.x * math.cos(rad) - slot.offset.y * math.sin(rad)
        local rotatedY = slot.offset.x * math.sin(rad) + slot.offset.y * math.cos(rad)

        local propX = palletPos.x + rotatedX
        local propY = palletPos.y + rotatedY
        local propZ = palletPos.z + slot.offset.z

        local prop = CreateObject(propModel, propX, propY, propZ, false, false, false)
        SetEntityHeading(prop, heading + slot.rotation.z)
        FreezeEntityPosition(prop, true)
        SetEntityAsMissionEntity(prop, true, true)
        SetModelAsNoLongerNeeded(propModel)

        palletProps[i] = { object = prop, type = deliveryType, taken = false }
    end
end

function PickupFromPallet()
    if isCarrying then Notify(Config.Locale.hands_full) return end
    if isAnimPlaying then return end

    local targetIndex = nil
    for i, pallet in ipairs(palletProps) do
        if not pallet.taken then targetIndex = i break end
    end
    if not targetIndex then return end

    isAnimPlaying = true
    local playerPed = PlayerPedId()
    local palletData = palletProps[targetIndex]

    local propCoords = GetEntityCoords(palletData.object)
    TaskTurnPedToFaceCoord(playerPed, propCoords.x, propCoords.y, propCoords.z, 1000)
    Wait(800)

    local anim = Config.Animations.pickupFromPallet
    RequestAnimDict(anim.dict)
    while not HasAnimDictLoaded(anim.dict) do Wait(10) end
    TaskPlayAnim(playerPed, anim.dict, anim.name, 8.0, -8.0, anim.duration, anim.flag, 0, false, false, false)
    Wait(anim.duration * 0.6)

    if DoesEntityExist(palletData.object) then
        DeleteEntity(palletData.object)
    end
    palletProps[targetIndex].taken = true

    AttachPackageProp(playerPed, palletData.type)
    Wait(anim.duration * 0.4)
    ClearPedTasks(playerPed)

    StartCarryAnimation(playerPed)

    isCarrying = true
    carryingIndex = targetIndex
    carryingType = palletData.type
    isAnimPlaying = false
end

-- ==========================================
-- JÁRMŰ AJTÓ KEZELÉS
-- ==========================================
function OpenVehicleDoor()
    if isDoorOpen then return end
    if not jobVehicle or not DoesEntityExist(jobVehicle) then return end
    if isAnimPlaying then return end

    isAnimPlaying = true
    local playerPed = PlayerPedId()

    if not isCarrying then
        local anim = Config.Animations.openDoor
        RequestAnimDict(anim.dict)
        while not HasAnimDictLoaded(anim.dict) do Wait(10) end
        TaskPlayAnim(playerPed, anim.dict, anim.name, 8.0, -8.0, anim.duration, anim.flag, 0, false, false, false)
        Wait(800)
    end

    SetVehicleDoorOpen(jobVehicle, Config.VehicleCargo.doorIndex, false, false)
    isDoorOpen = true

    if not isCarrying then
        Wait(700)
        ClearPedTasks(playerPed)
    end

    isAnimPlaying = false
end

function CloseVehicleDoor()
    if not isDoorOpen then return end
    if not jobVehicle or not DoesEntityExist(jobVehicle) then return end
    SetVehicleDoorShut(jobVehicle, Config.VehicleCargo.doorIndex, false)
    isDoorOpen = false
end

-- ==========================================
-- CSOMAG BEHELYEZÉS A JÁRMŰBE
-- ==========================================
function LoadPackageIntoVehicle()
    if not isCarrying then Notify(Config.Locale.hands_empty) return end
    if not isDoorOpen then Notify(Config.Locale.door_closed) return end
    if isAnimPlaying then return end

    isAnimPlaying = true
    local playerPed = PlayerPedId()

    local anim = Config.Animations.putInVehicle
    RequestAnimDict(anim.dict)
    while not HasAnimDictLoaded(anim.dict) do Wait(10) end

    StopCarryAnimation(playerPed)
    Wait(200)

    -- Bepakolás idő szorzó a csomag méret alapján
    local loadTimeMult = 1.0
    if carryingType and Config.PackageVisuals and Config.PackageVisuals.loadTimeMultiplier[carryingType] then
        loadTimeMult = Config.PackageVisuals.loadTimeMultiplier[carryingType]
    end
    local adjustedDuration = math.floor(anim.duration * loadTimeMult)

    TaskPlayAnim(playerPed, anim.dict, anim.name, 8.0, -8.0, adjustedDuration, anim.flag, 0, false, false, false)
    Wait(math.floor(adjustedDuration * 0.5))

    DeleteCurrentProp()
    SpawnCargoInVehicle(carryingType)

    Wait(math.floor(adjustedDuration * 0.5))
    ClearPedTasks(playerPed)

    packagesLoaded = packagesLoaded + 1
    isCarrying = false
    carryingIndex = 0
    carryingType = nil
    isAnimPlaying = false

    Notify('~g~Csomag bepakolva! ~w~(' .. packagesLoaded .. '/' .. currentRound.totalDeliveries .. ')')

    if packagesLoaded >= currentRound.totalDeliveries then
        Notify(Config.Locale.all_loaded)
    end
end

function SpawnCargoInVehicle(deliveryType)
    if not jobVehicle or not DoesEntityExist(jobVehicle) then return end

    local slotIndex = packagesLoaded + 1
    if slotIndex > #Config.VehicleCargo.cargoSlots then
        slotIndex = ((slotIndex - 1) % #Config.VehicleCargo.cargoSlots) + 1
    end

    local slot = Config.VehicleCargo.cargoSlots[slotIndex]
    local propName = GetPropNameForType(deliveryType)
    local propModel = GetHashKey(propName)
    RequestModel(propModel)
    while not HasModelLoaded(propModel) do Wait(10) end

    local prop = CreateObject(propModel, 0.0, 0.0, 0.0, true, true, true)
    AttachEntityToEntity(prop, jobVehicle, 0,
        slot.offset.x, slot.offset.y, slot.offset.z,
        slot.rotation.x, slot.rotation.y, slot.rotation.z,
        false, false, false, false, 0, true)
    SetModelAsNoLongerNeeded(propModel)

    table.insert(cargoProps, prop)
end

-- ==========================================
-- BEPAKOLÁS BEFEJEZÉS
-- ==========================================
function FinishLoading()
    loadingPhase = false
    currentRound.pickedUp = true
    CleanupPallet()
    SetDeliveryWaypoint(currentRound.currentDeliveryIndex)
end

-- ==========================================
-- LOCKER KÉZBESÍTÉSI RENDSZER
-- (A lockerek FIX-ek, nem kell spawnolni/törölni)
-- ==========================================

-- Aktuális locker target beállítása (kör közben)
function SetCurrentLockerTarget(delivery)
    currentLockerTarget = delivery
    isLockerDoorOpen = false
    hasPackageInHand = false

    -- Fiók hozzárendelés
    if Config.Locker.assignMode == 'random' then
        assignedCompartment = math.random(1, #Config.Locker.compartments)
    else
        assignedCompartment = ((currentRound.currentDeliveryIndex - 1) % #Config.Locker.compartments) + 1
    end

    -- Aktív locker blip kiemelés
    if delivery.lockerId and allLockerBlips[delivery.lockerId] then
        SetBlipColour(allLockerBlips[delivery.lockerId], Config.LockerBlip.activeColor)
    end
end

-- Locker target reset (kézbesítés után)
function ClearCurrentLockerTarget()
    -- Blip visszaállítás normál színre
    if currentLockerTarget and currentLockerTarget.lockerId and allLockerBlips[currentLockerTarget.lockerId] then
        SetBlipColour(allLockerBlips[currentLockerTarget.lockerId], Config.LockerBlip.color)
    end

    currentLockerTarget = nil
    isLockerDoorOpen = false
    openedCompartment = 0
    hasPackageInHand = false
    assignedCompartment = 0
end

-- Cleanup (resource stop - lockerek törlése)
function CleanupAllLockers()
    for id, obj in pairs(allLockerObjects) do
        if obj and DoesEntityExist(obj) then
            DeleteEntity(obj)
        end
    end
    allLockerObjects = {}

    for id, blip in pairs(allLockerBlips) do
        if blip then RemoveBlip(blip) end
    end
    allLockerBlips = {}
end

-- Csomag kivétel a járműből (kézbesítésnél)
function TakePackageFromVehicle()
    if hasPackageInHand then Notify(Config.Locale.hands_full) return end
    if isAnimPlaying then return end
    if not jobVehicle or not DoesEntityExist(jobVehicle) then return end

    isAnimPlaying = true
    local playerPed = PlayerPedId()
    local delivery = currentRound.deliveries[currentRound.currentDeliveryIndex]

    -- Jármű ajtó nyitás (ha zárva)
    SetVehicleDoorOpen(jobVehicle, Config.VehicleCargo.doorIndex, false, false)
    Wait(500)

    -- Animáció: kinyúl a kocsihoz
    local anim = Config.Animations.pickupFromPallet
    RequestAnimDict(anim.dict)
    while not HasAnimDictLoaded(anim.dict) do Wait(10) end
    TaskPlayAnim(playerPed, anim.dict, anim.name, 8.0, -8.0, anim.duration, anim.flag, 0, false, false, false)
    Wait(anim.duration * 0.6)

    -- Csomag megjelenik a kézben
    AttachPackageProp(playerPed, delivery.type)

    -- Cargo prop eltávolítása a járműből
    RemoveOneCargoFromVehicle()

    Wait(anim.duration * 0.4)
    ClearPedTasks(playerPed)

    -- Carry anim
    StartCarryAnimation(playerPed)

    -- Jármű ajtó bezárás
    Wait(500)
    SetVehicleDoorShut(jobVehicle, Config.VehicleCargo.doorIndex, false)

    hasPackageInHand = true
    isAnimPlaying = false

    Notify(Config.Locale.take_from_vehicle)
end

-- Locker fiók kinyitása
function OpenLockerCompartment()
    if isLockerDoorOpen then return end
    if not currentLockerTarget then return end
    if isAnimPlaying then return end

    local lockerObj = allLockerObjects[currentLockerTarget.lockerId]
    if not lockerObj or not DoesEntityExist(lockerObj) then return end

    isAnimPlaying = true
    local playerPed = PlayerPedId()

    local lockerCoords = GetEntityCoords(lockerObj)
    TaskTurnPedToFaceCoord(playerPed, lockerCoords.x, lockerCoords.y, lockerCoords.z, 800)
    Wait(600)

    if not hasPackageInHand then
        local anim = Config.Animations.openDoor
        RequestAnimDict(anim.dict)
        while not HasAnimDictLoaded(anim.dict) do Wait(10) end
        TaskPlayAnim(playerPed, anim.dict, anim.name, 8.0, -8.0, Config.Locker.doorOpenTime, 0, 0, false, false, false)
        Wait(Config.Locker.doorOpenTime)
        ClearPedTasks(playerPed)
    end

    isLockerDoorOpen = true
    openedCompartment = assignedCompartment
    isAnimPlaying = false

    Notify(Config.Locale.locker_open)
end

-- Csomag behelyezés a locker fiókba
function DeliverToLocker()
    if not hasPackageInHand then Notify(Config.Locale.locker_no_package) return end
    if not isLockerDoorOpen then return end
    if isAnimPlaying then return end

    isAnimPlaying = true
    local playerPed = PlayerPedId()
    local delivery = currentRound.deliveries[currentRound.currentDeliveryIndex]

    -- Carry anim leállítás
    StopCarryAnimation(playerPed)
    Wait(200)

    -- Behelyezés animáció
    local anim = Config.Animations.deliverPackage
    RequestAnimDict(anim.dict)
    while not HasAnimDictLoaded(anim.dict) do Wait(10) end
    TaskPlayAnim(playerPed, anim.dict, anim.name, 8.0, -8.0, anim.duration, anim.flag, 0, false, false, false)
    Wait(anim.duration * 0.7)

    -- Csomag eltűnik a kézből
    DeleteCurrentProp()

    Wait(anim.duration * 0.3)
    ClearPedTasks(playerPed)

    -- Kézbesítés regisztrálás
    hasPackageInHand = false

    local currentIdx = currentRound.currentDeliveryIndex

    -- Expressz siker ellenőrzés
    local expressSuccess = nil
    if delivery.isExpress and expressTimers[currentIdx] then
        local timerData = expressTimers[currentIdx]
        local expressElapsed = (GetGameTimer() - timerData.startTime) / 1000
        local expressRemaining = timerData.timeLimit - expressElapsed
        expressSuccess = expressRemaining > 0
    end

    table.insert(currentRound.completedDeliveries, {
        type = delivery.type,
        time = GetGameTimer(),
        isFragile = delivery.isFragile or false,
        damage = fragileDamage[currentIdx] or 0,
        isExpress = delivery.isExpress or false,
        expressSuccess = expressSuccess,
        distanceMultiplier = delivery.distanceMultiplier or 1.0,
        packageSizeMultiplier = delivery.packageSizeMultiplier or 1.0,
    })

    isAnimPlaying = false

    Notify(Config.Locale.locker_delivered .. ' (' .. #currentRound.completedDeliveries .. '/' .. currentRound.totalDeliveries .. ')')

    -- Következő kézbesítés index
    local nextIndex = currentRound.currentDeliveryIndex + 1

    -- MULTI-CSOMAG LOCKER LOGIKA:
    -- Ellenőrizzük, hogy a következő csomag UGYANARRA a lockerre megy-e
    local nextDelivery = currentRound.deliveries[nextIndex]
    local sameLockerId = currentLockerTarget and currentLockerTarget.lockerId

    if nextDelivery and nextDelivery.lockerId == sameLockerId then
        -- Következő csomag UGYANAZ a locker → fiók nyitva marad, csak a kézbesítés index lép
        currentRound.currentDeliveryIndex = nextIndex

        -- Nem zárjuk be a fiókot, nem töröljük a target-et
        -- A játékos visszamegy a kocsihoz a következő csomagért
        hasPackageInHand = false
        -- A fiók nyitva marad!

        Notify('~y~Még van csomag erre a lockerre! Menj vissza a kocsihoz!')
    else
        -- Nincs több csomag erre a lockerre → fiók bezárás, target reset
        Wait(Config.Locker.doorCloseDelay)
        isLockerDoorOpen = false
        openedCompartment = 0

        Wait(500)
        ClearCurrentLockerTarget()

        currentRound.currentDeliveryIndex = nextIndex

        if nextIndex <= #currentRound.deliveries then
            SetDeliveryWaypoint(nextIndex)
        else
            -- Minden kézbesítve!
            Notify(Config.Locale.return_to_depot)
            RemoveDeliveryBlip()
            RemoveRouteBlip()
            SetNewWaypoint(Config.Depot.coords.x, Config.Depot.coords.y)
            if routeBlip then RemoveBlip(routeBlip) end
            routeBlip = AddBlipForCoord(Config.Depot.coords)
            SetBlipSprite(routeBlip, 478)
            SetBlipColour(routeBlip, 2)
            SetBlipRoute(routeBlip, true)
            SetBlipRouteColour(routeBlip, 2)
        end
    end
end

function RemoveOneCargoFromVehicle()
    if #cargoProps > 0 then
        local lastProp = cargoProps[#cargoProps]
        if lastProp and DoesEntityExist(lastProp) then
            DetachEntity(lastProp, true, true)
            DeleteEntity(lastProp)
        end
        table.remove(cargoProps, #cargoProps)
    end
end

-- ==========================================
-- KÖR BEFEJEZÉS
-- ==========================================
function FinishRound()
    if not isOnRound then return end

    DeleteCurrentProp()
    CleanupPallet()
    CleanupCargoProps()
    ClearCurrentLockerTarget()
    RemoveDeliveryBlip()
    RemoveRouteBlip()

    isOnRound = false
    loadingPhase = false
    isCarrying = false
    isDoorOpen = false
    hasPackageInHand = false
    lastRoundEnd = GetGameTimer()

    TriggerServerEvent('seerpg-futar:server:completeRound', currentRound.completedDeliveries)
end

RegisterNetEvent('seerpg-futar:client:roundCompleted', function(data)
    isUIOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'showRoundComplete', data = data })

    if playerSkillData then
        playerSkillData.skillPoints = data.currentSkillPoints
        playerSkillData.skillLevel = data.skillLevel
    end

    if data.leveledUp then
        Wait(1000)
        Notify(Config.Locale.level_up .. data.skillLevel)
    end
end)

-- ==========================================
-- KÖR MEGSZAKÍTÁS
-- ==========================================
function CancelRound()
    isOnRound = false
    loadingPhase = false
    isCarrying = false
    isDoorOpen = false
    isAnimPlaying = false

    currentRound = { deliveries = {}, currentDeliveryIndex = 0, pickedUp = false, completedDeliveries = {}, startTime = 0, totalDeliveries = 0 }
    packagesLoaded = 0
    carryingIndex = 0
    carryingType = nil
    hasPackageInHand = false
    isLockerDoorOpen = false
    openedCompartment = 0
    fragileDamage = {}
    expressTimers = {}

    DeleteCurrentProp()
    CleanupPallet()
    CleanupCargoProps()
    ClearCurrentLockerTarget()
    RemoveDeliveryBlip()
    RemoveRouteBlip()
    StopCarryAnimation(PlayerPedId())

    lastRoundEnd = GetGameTimer()
    SendNUIMessage({ action = 'updateHUD', data = { show = false } })
    SendNUIMessage({ action = 'updateFragileIndicator', data = { show = false } })
    SendNUIMessage({ action = 'updateExpressTimer', data = { active = false } })
    if isCursorMode then DisableCursorMode() end
end

-- ==========================================
-- SKILL PANEL
-- ==========================================
function OpenSkillPanel()
    if isUIOpen then return end
    TriggerServerEvent('seerpg-futar:server:getSkillData')
end

RegisterNetEvent('seerpg-futar:client:receiveSkillData', function(data)
    isUIOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'showSkillPanel', data = data })
end)

RegisterCommand(Config.SkillCommand, function()
    OpenSkillPanel()
end, false)

-- ==========================================
-- WAYPOINT / BLIP KEZELÉS
-- ==========================================
function SetDeliveryWaypoint(index)
    local delivery = currentRound.deliveries[index]
    if not delivery then return end

    RemoveDeliveryBlip()
    RemoveRouteBlip()

    deliveryBlip = AddBlipForCoord(delivery.coords)
    SetBlipSprite(deliveryBlip, Config.DeliveryBlip.sprite)
    SetBlipColour(deliveryBlip, Config.DeliveryBlip.color)
    SetBlipScale(deliveryBlip, Config.DeliveryBlip.scale)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(delivery.label .. ' (' .. GetDeliveryTypeLabel(delivery.type) .. ')')
    EndTextCommandSetBlipName(deliveryBlip)

    if Config.ShowGPSRoute then
        SetBlipRoute(deliveryBlip, true)
        SetBlipRouteColour(deliveryBlip, Config.DeliveryBlip.color)
    end

    SetNewWaypoint(delivery.coords.x, delivery.coords.y)
end

function RemoveDeliveryBlip() if deliveryBlip then RemoveBlip(deliveryBlip) deliveryBlip = nil end end
function RemoveRouteBlip() if routeBlip then RemoveBlip(routeBlip) routeBlip = nil end end

-- ==========================================
-- ANIMÁCIÓ KEZELÉS
-- ==========================================
function StartCarryAnimation(ped)
    local anim = Config.Animations.carryPackage
    RequestAnimDict(anim.dict)
    while not HasAnimDictLoaded(anim.dict) do Wait(10) end
    TaskPlayAnim(ped, anim.dict, anim.name, 8.0, -8.0, -1, anim.flag, 0, false, false, false)

    -- Mozgás sebesség módosítás a csomag típus alapján (PackageVisuals)
    local deliveryType = carryingType
    if not deliveryType and hasPackageInHand and currentRound.deliveries[currentRound.currentDeliveryIndex] then
        deliveryType = currentRound.deliveries[currentRound.currentDeliveryIndex].type
    end
    if deliveryType and Config.PackageVisuals and Config.PackageVisuals.moveSpeedMultiplier[deliveryType] then
        SetPedMoveRateOverride(ped, Config.PackageVisuals.moveSpeedMultiplier[deliveryType])
    end
end

function StopCarryAnimation(ped)
    ClearPedTasks(ped)
    SetPedMoveRateOverride(ped, 1.0)
end

-- ==========================================
-- PROP KEZELÉS
-- ==========================================
function GetPropNameForType(deliveryType)
    if deliveryType == 'level' then return Config.Props.letter
    elseif deliveryType == 'small' then return Config.Props.package_small
    elseif deliveryType == 'medium' then return Config.Props.package_medium
    elseif deliveryType == 'large' then return Config.Props.package_large
    end
    return Config.Props.package_small
end

function AttachPackageProp(ped, deliveryType)
    DeleteCurrentProp()

    local propName = GetPropNameForType(deliveryType)
    local model = GetHashKey(propName)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end

    local attach = deliveryType == 'level' and Config.PropAttach.letter or Config.PropAttach.carry
    local boneIndex = GetPedBoneIndex(ped, attach.bone)
    currentProp = CreateObject(model, 0.0, 0.0, 0.0, true, true, true)
    AttachEntityToEntity(currentProp, ped, boneIndex,
        attach.offset.x, attach.offset.y, attach.offset.z,
        attach.rotation.x, attach.rotation.y, attach.rotation.z,
        true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(model)
end

function DeleteCurrentProp()
    if currentProp and DoesEntityExist(currentProp) then
        DetachEntity(currentProp, true, true)
        DeleteEntity(currentProp)
        currentProp = nil
    end
end

function CleanupPallet()
    if palletBaseObj and DoesEntityExist(palletBaseObj) then DeleteEntity(palletBaseObj) palletBaseObj = nil end
    for _, data in ipairs(palletProps) do
        if data.object and DoesEntityExist(data.object) then DeleteEntity(data.object) end
    end
    palletProps = {}
end

function CleanupCargoProps()
    for _, prop in ipairs(cargoProps) do
        if prop and DoesEntityExist(prop) then DetachEntity(prop, true, true) DeleteEntity(prop) end
    end
    cargoProps = {}
end

-- ==========================================
-- SEGÉD FUNKCIÓK
-- ==========================================
function GetVehicleLoadPoint()
    if not jobVehicle or not DoesEntityExist(jobVehicle) then return vector3(0, 0, 0) end
    local offset = Config.VehicleCargo.loadPointOffset
    return GetOffsetFromEntityInWorldCoords(jobVehicle, offset.x, offset.y, offset.z)
end

function Notify(msg)
    if Config.UseNotifications == 'native' then
        SetNotificationTextEntry('STRING')
        AddTextComponentString(msg)
        DrawNotification(false, false)
    elseif Config.UseNotifications == 'esx' then
        TriggerEvent('esx:showNotification', msg)
    end
end

function GetDeliveryTypeLabel(dtype)
    local labels = { ['level'] = 'Levél', ['small'] = 'Csomag (S)', ['medium'] = 'Csomag (M)', ['large'] = 'Csomag (L)' }
    return labels[dtype] or dtype
end

-- ==========================================
-- TÖRÉKENY CSOMAG SÉRÜLÉS MONITOROZÁS
-- ==========================================
CreateThread(function()
    while true do
        Wait(100)  -- 10x per second check

        if isOnRound and jobVehicle and DoesEntityExist(jobVehicle) then
            local ped = PlayerPedId()
            local currentIdx = currentRound.currentDeliveryIndex

            -- Járműben ülés közben - ütközés detektálás
            if IsPedInVehicle(ped, jobVehicle, false) then
                local currentSpeed = GetEntitySpeed(jobVehicle) * 3.6  -- m/s to km/h
                local currentHealth = GetVehicleEngineHealth(jobVehicle)

                -- Ütközés detektálás: health csökkent?
                if currentHealth < lastVehicleHealth then
                    local healthDrop = lastVehicleHealth - currentHealth

                    if lastVehicleSpeed > Config.Fragile.damage.collision.minSpeed then
                        -- Sérülés számítás: minden törékeny csomagra
                        local baseDamage = Config.Fragile.damage.collision.damagePerHit
                        local speedBonus = (lastVehicleSpeed - Config.Fragile.damage.collision.minSpeed) * Config.Fragile.damage.collision.speedMultiplier
                        local totalDamage = math.min(baseDamage + speedBonus, Config.Fragile.damage.collision.maxDamagePerHit)

                        for i, delivery in ipairs(currentRound.deliveries) do
                            if delivery.isFragile and fragileDamage[i] ~= nil and fragileDamage[i] < 100 then
                                -- Csak az aktuális és még nem kézbesített csomagokra
                                local alreadyDelivered = false
                                for _, completed in ipairs(currentRound.completedDeliveries) do
                                    if completed.time and i <= #currentRound.completedDeliveries then
                                        -- Skip
                                    end
                                end
                                if i >= currentIdx then
                                    fragileDamage[i] = math.min(100, (fragileDamage[i] or 0) + totalDamage)
                                end
                            end
                        end
                    end
                end

                lastVehicleSpeed = currentSpeed
                lastVehicleHealth = currentHealth
            end

            -- Játékos elesés (csomag kézben)
            if (hasPackageInHand or isCarrying) and Config.Fragile.damage.playerFall.enabled then
                if HasEntityBeenDamagedByAnyPed(ped) or IsPedRagdoll(ped) or IsPedFalling(ped) then
                    if currentIdx and currentRound.deliveries[currentIdx] and currentRound.deliveries[currentIdx].isFragile then
                        if fragileDamage[currentIdx] then
                            fragileDamage[currentIdx] = math.min(100, fragileDamage[currentIdx] + Config.Fragile.damage.playerFall.damagePerFall)
                        end
                    end
                    ClearEntityLastDamageEntity(ped)
                end
            end
        else
            -- Reset tracking ha nincs járműben
            lastVehicleSpeed = 0.0
            lastVehicleHealth = 1000
        end
    end
end)

-- ==========================================
-- JÁRMŰ JAVÍTÁS
-- ==========================================
function RepairJobVehicle()
    if not jobVehicle or not DoesEntityExist(jobVehicle) then return end
    if isAnimPlaying then return end

    local engineHealth = GetVehicleEngineHealth(jobVehicle)
    local damagePts = math.floor(1000 - engineHealth)
    local cost = Config.VehicleRepair.repairCost.base + (damagePts * Config.VehicleRepair.repairCost.perDamagePoint)

    isAnimPlaying = true
    local ped = PlayerPedId()

    -- Animáció
    local anim = Config.VehicleRepair.animation
    RequestAnimDict(anim.dict)
    while not HasAnimDictLoaded(anim.dict) do Wait(10) end
    TaskPlayAnim(ped, anim.dict, anim.name, 8.0, -8.0, Config.VehicleRepair.repairTime, anim.flag, 0, false, false, false)

    Wait(Config.VehicleRepair.repairTime)
    ClearPedTasks(ped)

    -- Javítás végrehajtás
    SetVehicleFixed(jobVehicle)
    SetVehicleEngineHealth(jobVehicle, 1000.0)
    SetVehicleBodyHealth(jobVehicle, 1000.0)
    SetVehicleDirtLevel(jobVehicle, 0.0)
    lastVehicleHealth = 1000

    -- Szerver felé költség
    TriggerServerEvent('seerpg-futar:server:chargeRepair', cost)

    isAnimPlaying = false
    Notify('~g~Jármű megjavítva! ~w~(-' .. cost .. ' Ft)')
end

-- Szerver visszajelzés javítás eredményéről
RegisterNetEvent('seerpg-futar:client:repairSuccess', function(data)
    -- Javítás sikeres, pénz levonva
end)

RegisterNetEvent('seerpg-futar:client:repairFailed', function(data)
    Notify('~r~Nincs elég pénzed a javításra!')
end)

-- ==========================================
-- FUTÁR BOLT
-- ==========================================
function OpenShop()
    if isUIOpen then return end
    TriggerServerEvent('seerpg-futar:server:getShopData')
end

RegisterNetEvent('seerpg-futar:client:shopData', function(data)
    isUIOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showShopPanel',
        data = data
    })
end)

RegisterNetEvent('seerpg-futar:client:shopBuyResult', function(data)
    if data.success then
        Notify('~g~Sikeres vásárlás: ' .. (data.upgradeName or '') .. ' (-' .. (data.price or 0) .. ' Ft)')
        -- Frissítjük a bolt adatokat
        TriggerServerEvent('seerpg-futar:server:getShopData')
    else
        local reasons = {
            already_owned = '~r~Már megvásároltad ezt a fejlesztést!',
            level_low = '~r~Túl alacsony a szinted ehhez!',
            requires_missing = '~r~Előbb meg kell venned az előfeltételt!',
            no_money = '~r~Nincs elég pénzed!',
        }
        Notify(reasons[data.reason] or '~r~Sikertelen vásárlás!')
    end
end)

RegisterNUICallback('buyUpgrade', function(data, cb)
    if data.upgradeId then
        TriggerServerEvent('seerpg-futar:server:buyUpgrade', data.upgradeId)
    end
    cb('ok')
end)

RegisterNUICallback('closeShop', function(data, cb)
    SetNuiFocus(false, false)
    isUIOpen = false
    cb('ok')
end)

-- ==========================================
-- RESOURCE CLEANUP
-- ==========================================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if jobNPC and DoesEntityExist(jobNPC) then DeleteEntity(jobNPC) end
    if shopNPC and DoesEntityExist(shopNPC) then DeleteEntity(shopNPC) end
    DeleteJobVehicle()
    DeleteCurrentProp()
    CleanupPallet()
    CleanupCargoProps()
    CleanupAllLockers()
    if depotBlip then RemoveBlip(depotBlip) end
    RemoveDeliveryBlip()
    RemoveRouteBlip()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'updateFragileIndicator', data = { show = false } })
    SendNUIMessage({ action = 'updateExpressTimer', data = { active = false } })
end)

-- ==========================================
-- EXPORTOK
-- ==========================================
exports('StartFutarJob', function() StartJob() end)
exports('EndFutarJob', function() EndJob() end)
exports('StartFutarRound', function() StartRound() end)
exports('OpenSkillPanel', function() OpenSkillPanel() end)
exports('IsPlayerWorking', function() return isWorking end)
exports('IsPlayerOnRound', function() return isOnRound end)
exports('IsLoadingPhase', function() return loadingPhase end)
