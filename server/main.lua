-- ==========================================
-- SEERPG FUTÁR - SZERVER OLDAL
-- Job kezelés, validáció, fizetés, anticheat
-- ==========================================

-- Framework detektálás
local ESX, QBCore = nil, nil

if Config.Framework == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
elseif Config.Framework == 'qbcore' then
    QBCore = exports['qb-core']:GetCoreObject()
end

-- ==========================================
-- JÁTÉKOS ADATOK
-- ==========================================
local playerSkills = {}       -- Skill adatok
local playerJobs = {}         -- Aktív munkások
local playerRounds = {}       -- Aktív körök
local playerCooldowns = {}    -- Cooldown-ok

-- ==========================================
-- ADATBÁZIS INICIALIZÁLÁS
-- ==========================================
MySQL.ready(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `seerpg_futar_skills` (
            `identifier` VARCHAR(60) NOT NULL,
            `skill_points` INT DEFAULT 0,
            `total_deliveries` INT DEFAULT 0,
            `total_rounds` INT DEFAULT 0,
            `total_earnings` BIGINT DEFAULT 0,
            `best_round_pay` INT DEFAULT 0,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `seerpg_futar_purchases` (
            `id` INT AUTO_INCREMENT,
            `identifier` VARCHAR(60) NOT NULL,
            `upgrade_id` VARCHAR(60) NOT NULL,
            `purchased_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `unique_purchase` (`identifier`, `upgrade_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    if Config.Debug then
        print('[RealRPG-Futar] Adatbázis táblák ellenőrizve/létrehozva.')
    end
end)

-- ==========================================
-- SEGÉD FUNKCIÓK
-- ==========================================

-- Játékos identifier
local function GetPlayerIdentifier(source)
    for _, id in ipairs(GetPlayerIdentifiers(source)) do
        if string.find(id, 'license:') then
            return id
        end
    end
    return nil
end

-- Skill szint kiszámítása
local function GetSkillLevel(points)
    local level = 1
    for i = Config.MaxStars, 1, -1 do
        if Config.SkillLevels[i] and points >= Config.SkillLevels[i] then
            level = i
            break
        end
    end
    return level
end

-- Következő szint ponthatára
local function GetNextLevelPoints(points)
    local currentLevel = GetSkillLevel(points)
    local nextLevel = currentLevel + 1
    if nextLevel > Config.MaxStars then
        return Config.SkillLevels[Config.MaxStars]
    end
    return Config.SkillLevels[nextLevel] or Config.SkillLevels[Config.MaxStars]
end

-- Club tagság ellenőrzés (saját rendszerhez igazítsd)
local function IsClubMember(source)
    -- INTEGRÁCIÓ: Cseréld ki a saját rendszeredre
    -- Példa: return exports['seerpg-club']:IsPlayerMember(source)
    -- Példa QBCore: local Player = QBCore.Functions.GetPlayer(source)
    --               return Player.PlayerData.metadata.club == true
    return false
end

-- Pénz hozzáadása
local function AddMoney(source, amount)
    if Config.Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            xPlayer.addMoney(amount)
            return true
        end
    elseif Config.Framework == 'qbcore' then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            Player.Functions.AddMoney('cash', amount, 'futar-fizetes')
            return true
        end
    end
    return false
end

-- Random kézbesítés típus generálás (súlyozással)
local function GetRandomDeliveryType(skillLevel)
    local availableTypes = {}
    local totalWeight = 0

    for dtype, minLevel in pairs(Config.DeliveryUnlocks) do
        if skillLevel >= minLevel then
            local weight = Config.DeliveryWeights[dtype] or 10
            table.insert(availableTypes, { type = dtype, weight = weight })
            totalWeight = totalWeight + weight
        end
    end

    local roll = math.random(1, totalWeight)
    local cumulative = 0

    for _, entry in ipairs(availableTypes) do
        cumulative = cumulative + entry.weight
        if roll <= cumulative then
            return entry.type
        end
    end

    return 'level' -- Fallback
end

-- Delivery type label
local function GetDeliveryTypeLabel(dtype)
    local labels = {
        ['level'] = 'Levél',
        ['small'] = 'Csomag (S)',
        ['medium'] = 'Csomag (M)',
        ['large'] = 'Csomag (L)'
    }
    return labels[dtype] or dtype
end

-- ==========================================
-- ADATBÁZIS MŰVELETEK
-- ==========================================

local function LoadPlayerSkill(source)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return end

    local result = MySQL.query.await('SELECT * FROM `seerpg_futar_skills` WHERE `identifier` = ?', { identifier })

    if result and result[1] then
        playerSkills[source] = {
            identifier = identifier,
            skill_points = result[1].skill_points,
            total_deliveries = result[1].total_deliveries,
            total_rounds = result[1].total_rounds,
            total_earnings = result[1].total_earnings or 0,
            best_round_pay = result[1].best_round_pay or 0
        }
    else
        MySQL.insert('INSERT INTO `seerpg_futar_skills` (`identifier`) VALUES (?)', { identifier })
        playerSkills[source] = {
            identifier = identifier,
            skill_points = 0,
            total_deliveries = 0,
            total_rounds = 0,
            total_earnings = 0,
            best_round_pay = 0
        }
    end

    if Config.Debug then
        print('[RealRPG-Futar] Skill betöltve: ' .. GetPlayerName(source) .. ' - ' .. playerSkills[source].skill_points .. ' pont')
    end
end

local function SavePlayerSkill(source)
    local data = playerSkills[source]
    if not data then return end

    MySQL.update([[
        UPDATE `seerpg_futar_skills` 
        SET `skill_points` = ?, `total_deliveries` = ?, `total_rounds` = ?, 
            `total_earnings` = ?, `best_round_pay` = ?
        WHERE `identifier` = ?
    ]], {
        data.skill_points,
        data.total_deliveries,
        data.total_rounds,
        data.total_earnings,
        data.best_round_pay,
        data.identifier
    })
end

-- ==========================================
-- JÁTÉKOS CSATLAKOZÁS / KILÉPÉS
-- ==========================================

AddEventHandler('playerConnecting', function()
    local source = source
    Wait(2000)
    LoadPlayerSkill(source)
end)

AddEventHandler('playerDropped', function()
    local source = source
    if playerSkills[source] then
        SavePlayerSkill(source)
        playerSkills[source] = nil
    end
    playerJobs[source] = nil
    playerRounds[source] = nil
    playerCooldowns[source] = nil
    playerPurchases[source] = nil
end)

-- Resource start - online játékosok betöltése
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    Wait(3000)
    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        local src = tonumber(playerId)
        LoadPlayerSkill(src)
    end

    print('[RealRPG-Futar] Resource betöltve. ' .. #players .. ' játékos adatai betöltve.')
end)

-- ==========================================
-- MUNKA INDÍTÁS
-- ==========================================
RegisterNetEvent('seerpg-futar:server:startJob', function()
    local source = source

    -- Anticheat: már dolgozik?
    if playerJobs[source] then
        print('[RealRPG-Futar] ANTICHEAT: ' .. GetPlayerName(source) .. ' dupla munkaindítás kísérlet!')
        return
    end

    -- Skill betöltés ha nincs
    if not playerSkills[source] then
        LoadPlayerSkill(source)
        Wait(500)
    end

    if not playerSkills[source] then
        print('[RealRPG-Futar] HIBA: Nem sikerült betölteni a skill adatokat: ' .. GetPlayerName(source))
        return
    end

    local data = playerSkills[source]
    local skillLevel = GetSkillLevel(data.skill_points)

    -- Regisztrálás aktív munkásnak
    playerJobs[source] = {
        startTime = os.time(),
        roundsCompleted = 0
    }

    -- Küldés kliensnek
    TriggerClientEvent('seerpg-futar:client:jobStarted', source, {
        skillPoints = data.skill_points,
        skillLevel = skillLevel,
        nextLevelPoints = GetNextLevelPoints(data.skill_points),
        maxStars = Config.MaxStars,
        jobLabel = Config.JobLabel
    })

    if Config.Debug then
        print('[RealRPG-Futar] ' .. GetPlayerName(source) .. ' elkezdte a munkát. Skill: ' .. skillLevel)
    end
end)

-- ==========================================
-- MUNKA BEFEJEZÉS
-- ==========================================
RegisterNetEvent('seerpg-futar:server:endJob', function()
    local source = source

    playerJobs[source] = nil
    playerRounds[source] = nil

    if playerSkills[source] then
        SavePlayerSkill(source)
    end

    if Config.Debug then
        print('[RealRPG-Futar] ' .. GetPlayerName(source) .. ' befejezte a munkát.')
    end
end)

-- ==========================================
-- SZEZONÁLIS ESEMÉNYEK
-- ==========================================
function GetActiveSeasonalEvent()
    if not Config.SeasonalEvents or not Config.SeasonalEvents.enabled then return nil end

    local currentDate = os.date('*t')
    local currentMonth = currentDate.month
    local currentDay = currentDate.day
    local currentWday = currentDate.wday  -- 1=Sunday, 7=Saturday

    local activeEvent = nil

    for eventId, event in pairs(Config.SeasonalEvents.events) do
        if event.isWeekendOnly then
            -- Hétvégi boost: szombat (7) vagy vasárnap (1)
            if currentWday == 1 or currentWday == 7 then
                activeEvent = event
                break
            end
        elseif event.startMonth and event.endMonth then
            local isActive = false

            if event.startMonth <= event.endMonth then
                -- Normál tartomány (pl. Ápr 1 - Ápr 20)
                if currentMonth > event.startMonth or (currentMonth == event.startMonth and currentDay >= event.startDay) then
                    if currentMonth < event.endMonth or (currentMonth == event.endMonth and currentDay <= event.endDay) then
                        isActive = true
                    end
                end
            else
                -- Évet átívelő tartomány (pl. Dec 15 - Jan 5)
                if currentMonth > event.startMonth or (currentMonth == event.startMonth and currentDay >= event.startDay) then
                    isActive = true
                elseif currentMonth < event.endMonth or (currentMonth == event.endMonth and currentDay <= event.endDay) then
                    isActive = true
                end
            end

            if isActive then
                activeEvent = event
                break
            end
        end
    end

    return activeEvent
end

-- ==========================================
-- JÁRMŰ JAVÍTÁS FIZETÉS
-- ==========================================
RegisterNetEvent('seerpg-futar:server:chargeRepair', function(cost)
    local source = source

    if not playerJobs[source] then return end
    if not cost or type(cost) ~= 'number' or cost < 0 then return end

    -- Költség levonás
    if Config.Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            if xPlayer.getMoney() >= cost then
                xPlayer.removeMoney(cost)
                TriggerClientEvent('seerpg-futar:client:repairSuccess', source, { cost = cost })
            else
                TriggerClientEvent('seerpg-futar:client:repairFailed', source, { reason = 'no_money' })
            end
        end
    elseif Config.Framework == 'qbcore' then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            if Player.Functions.GetMoney('cash') >= cost then
                Player.Functions.RemoveMoney('cash', cost, 'futar-javitas')
                TriggerClientEvent('seerpg-futar:client:repairSuccess', source, { cost = cost })
            else
                TriggerClientEvent('seerpg-futar:client:repairFailed', source, { reason = 'no_money' })
            end
        end
    end

    if Config.Debug then
        print('[RealRPG-Futar] Jármű javítás: ' .. GetPlayerName(source) .. ' - ' .. cost .. ' Ft')
    end
end)

-- ==========================================
-- FUTÁR BOLT RENDSZER
-- ==========================================
local playerPurchases = {}  -- {source = {upgrade_id = true, ...}}

-- Bolt adatok betöltése
local function LoadPlayerPurchases(source)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return end

    local result = MySQL.query.await('SELECT `upgrade_id` FROM `seerpg_futar_purchases` WHERE `identifier` = ?', { identifier })
    playerPurchases[source] = {}

    if result then
        for _, row in ipairs(result) do
            playerPurchases[source][row.upgrade_id] = true
        end
    end
end

RegisterNetEvent('seerpg-futar:server:getShopData', function()
    local source = source

    if not playerJobs[source] then return end

    -- Betöltjük a vásárlásokat ha még nincs
    if not playerPurchases[source] then
        LoadPlayerPurchases(source)
    end

    local data = playerSkills[source]
    if not data then return end

    local skillLevel = GetSkillLevel(data.skill_points)

    TriggerClientEvent('seerpg-futar:client:shopData', source, {
        upgrades = Config.Shop.upgrades,
        purchased = playerPurchases[source] or {},
        skillLevel = skillLevel,
        playerMoney = GetPlayerMoney(source)
    })
end)

RegisterNetEvent('seerpg-futar:server:buyUpgrade', function(upgradeId)
    local source = source

    if not playerJobs[source] then return end
    if not upgradeId or type(upgradeId) ~= 'string' then return end

    local upgrade = Config.Shop.upgrades[upgradeId]
    if not upgrade then return end

    -- Már megvásárolta?
    if not playerPurchases[source] then LoadPlayerPurchases(source) end
    if playerPurchases[source][upgradeId] then
        TriggerClientEvent('seerpg-futar:client:shopBuyResult', source, { success = false, reason = 'already_owned' })
        return
    end

    -- Szint ellenőrzés
    local data = playerSkills[source]
    if not data then return end
    local skillLevel = GetSkillLevel(data.skill_points)
    if skillLevel < upgrade.minLevel then
        TriggerClientEvent('seerpg-futar:client:shopBuyResult', source, { success = false, reason = 'level_low' })
        return
    end

    -- Előfeltétel ellenőrzés
    if upgrade.requires and not playerPurchases[source][upgrade.requires] then
        TriggerClientEvent('seerpg-futar:client:shopBuyResult', source, { success = false, reason = 'requires_missing' })
        return
    end

    -- Pénz ellenőrzés és levonás
    local price = upgrade.price
    local hasMoney = false

    if Config.Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer and xPlayer.getMoney() >= price then
            xPlayer.removeMoney(price)
            hasMoney = true
        end
    elseif Config.Framework == 'qbcore' then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player and Player.Functions.GetMoney('cash') >= price then
            Player.Functions.RemoveMoney('cash', price, 'futar-bolt-' .. upgradeId)
            hasMoney = true
        end
    end

    if not hasMoney then
        TriggerClientEvent('seerpg-futar:client:shopBuyResult', source, { success = false, reason = 'no_money' })
        return
    end

    -- Vásárlás mentése
    local identifier = GetPlayerIdentifier(source)
    MySQL.insert('INSERT INTO `seerpg_futar_purchases` (`identifier`, `upgrade_id`) VALUES (?, ?)', { identifier, upgradeId })
    playerPurchases[source][upgradeId] = true

    TriggerClientEvent('seerpg-futar:client:shopBuyResult', source, {
        success = true,
        upgradeId = upgradeId,
        upgradeName = upgrade.name,
        price = price
    })

    if Config.Debug then
        print('[RealRPG-Futar] Bolt vásárlás: ' .. GetPlayerName(source) .. ' - ' .. upgrade.name .. ' (' .. price .. ' Ft)')
    end
end)

-- Segéd: játékos pénze
local function GetPlayerMoney(source)
    if Config.Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then return xPlayer.getMoney() end
    elseif Config.Framework == 'qbcore' then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then return Player.Functions.GetMoney('cash') end
    end
    return 0
end

-- ==========================================
-- SEGÉD: Távolság kategória meghatározása
-- ==========================================
local function GetDistanceCategory(distance)
    if distance <= Config.DistancePayBonus.near.maxDistance then
        return 'near', Config.DistancePayBonus.near.multiplier
    elseif distance <= Config.DistancePayBonus.medium.maxDistance then
        return 'medium', Config.DistancePayBonus.medium.multiplier
    elseif distance <= Config.DistancePayBonus.far.maxDistance then
        return 'far', Config.DistancePayBonus.far.multiplier
    else
        return 'veryFar', Config.DistancePayBonus.veryFar.multiplier
    end
end

-- ==========================================
-- KÖR KÉRÉS (Generálás) - Fix Locker Pontok
-- Játékos által választott CSOMAGPONT, script határozza meg a többit
-- ==========================================
RegisterNetEvent('seerpg-futar:server:requestRound', function(orderData)
    local source = source

    -- Validáció
    if not playerJobs[source] then return end
    if playerRounds[source] then return end

    -- Cooldown
    if playerCooldowns[source] then
        local elapsed = os.time() - playerCooldowns[source]
        if elapsed < Config.Round.cooldownBetweenRounds then return end
    end

    -- Skill szint
    local data = playerSkills[source]
    if not data then return end
    local skillLevel = GetSkillLevel(data.skill_points)

    -- ==========================================
    -- JÁTÉKOS CSAK A LOCKERT VÁLASZTJA - A TÖBBI AUTOMATIKUS
    -- ==========================================
    local chosenLockerId = orderData and orderData.lockerId or nil

    -- Keressük meg a választott lockert
    local targetLocker = nil
    for _, locker in ipairs(Config.LockerPoints) do
        if locker.id == chosenLockerId then
            targetLocker = locker
            break
        end
    end

    -- Ha nincs érvényes locker, válasszunk random egyet
    if not targetLocker then
        targetLocker = Config.LockerPoints[math.random(1, #Config.LockerPoints)]
    end

    -- Távolság számítás
    local distance = #(targetLocker.coords - Config.Depot.coords)
    local distanceCategory, distanceMultiplier = GetDistanceCategory(distance)

    -- ==========================================
    -- SCRIPT HATÁROZZA MEG: csomag szám, idő, törékeny
    -- ==========================================

    -- Csomag szám: random (min-max) + skill bónusz
    local packageCount = math.random(Config.PackagesPerLocker.min, math.min(Config.PackagesPerLocker.max, targetLocker.maxPackages))
    packageCount = packageCount + math.floor(skillLevel / 5)
    packageCount = math.min(packageCount, targetLocker.maxPackages)

    -- Időlimit: távolság alapján (távolabb = több idő)
    local timeLimit = math.floor(300 + (distance / 1000) * 60)  -- 5 perc + 1 perc/km
    timeLimit = math.max(300, math.min(900, timeLimit))  -- 5-15 perc között

    -- ==========================================
    -- CSOMAGOK GENERÁLÁSA
    -- ==========================================
    local deliveries = {}
    local lockerAssignments = {}
    local lockerPackages = {}

    for p = 1, packageCount do
        local deliveryType = GetRandomDeliveryType(skillLevel)

        -- Törékeny: random a config chance alapján
        local isFragile = false
        if Config.Fragile.enabled then
            isFragile = math.random(1, 100) <= Config.Fragile.chance
        end

        local delivery = {
            coords = targetLocker.coords,
            label = targetLocker.label,
            type = deliveryType,
            lockerId = targetLocker.id,
            distance = distance,
            distanceCategory = distanceCategory,
            distanceMultiplier = distanceMultiplier,
            packageSizeMultiplier = Config.PackageSizeMultiplier[deliveryType] or 1.0,
            isFragile = isFragile,
        }

        -- Expressz csomag (random)
        if Config.Express.enabled then
            local expressRoll = math.random(1, 100)
            local expressChance = Config.Express.chance
            local seasonalEvent = GetActiveSeasonalEvent()
            if seasonalEvent and seasonalEvent.bonuses and seasonalEvent.bonuses.expressChance then
                expressChance = seasonalEvent.bonuses.expressChance
            end
            if expressRoll <= expressChance then
                delivery.isExpress = true
                local expTime = Config.Express.timeLimit.base + math.floor((distance / 1000) * Config.Express.timeLimit.perKm)
                expTime = math.max(Config.Express.timeLimit.minTime, math.min(Config.Express.timeLimit.maxTime, expTime))
                delivery.expressTimeLimit = expTime
            end
        end

        table.insert(deliveries, delivery)
        table.insert(lockerPackages, delivery)
    end

    lockerAssignments[targetLocker.id] = {
        locker = targetLocker,
        packages = lockerPackages,
        distance = distance,
        distanceCategory = distanceCategory,
    }

    -- Kör regisztrálása
    playerRounds[source] = {
        deliveries = deliveries,
        lockerAssignments = lockerAssignments,
        startTime = os.time(),
        expectedDeliveries = #deliveries,
        customTimeLimit = timeLimit
    }

    -- Küldés kliensnek
    TriggerClientEvent('seerpg-futar:client:roundGenerated', source, {
        deliveries = deliveries,
        lockerAssignments = lockerAssignments,
        customTimeLimit = timeLimit
    })

    if Config.Debug then
        print('[RealRPG-Futar] Kör generálva: ' .. GetPlayerName(source))
        print('  Locker: ' .. targetLocker.label .. ' (' .. distanceCategory .. ')')
        print('  Csomagok: ' .. packageCount .. ' | Idő: ' .. timeLimit .. 'mp')
    end
end)

-- ==========================================
-- KÖR TELJESÍTÉS
-- ==========================================
RegisterNetEvent('seerpg-futar:server:completeRound', function(completedDeliveries)
    local source = source

    -- ==========================================
    -- ANTICHEAT VALIDÁCIÓ
    -- ==========================================

    -- Van aktív munka?
    if not playerJobs[source] then
        print('[RealRPG-Futar] ANTICHEAT: ' .. GetPlayerName(source) .. ' kör teljesítés munka nélkül!')
        return
    end

    -- Van aktív kör?
    if not playerRounds[source] then
        print('[RealRPG-Futar] ANTICHEAT: ' .. GetPlayerName(source) .. ' kör teljesítés aktív kör nélkül!')
        return
    end

    -- Adatok érvényesek?
    if not completedDeliveries or type(completedDeliveries) ~= 'table' then
        print('[RealRPG-Futar] ANTICHEAT: ' .. GetPlayerName(source) .. ' érvénytelen kézbesítés adatok!')
        return
    end

    -- Nem szállított-e le többet mint amennyit kapott?
    local roundData = playerRounds[source]
    if #completedDeliveries > roundData.expectedDeliveries then
        print('[RealRPG-Futar] ANTICHEAT: ' .. GetPlayerName(source) .. ' több kézbesítés mint az elvárható! (' .. #completedDeliveries .. '/' .. roundData.expectedDeliveries .. ')')
        return
    end

    -- Időlimit ellenőrzés (szerver oldali)
    local elapsed = os.time() - roundData.startTime
    local roundTimeLimit = roundData.customTimeLimit or Config.Round.maxTime
    if elapsed > roundTimeLimit + 30 then -- +30 mp puffer hálózati késleltetésre
        print('[RealRPG-Futar] ANTICHEAT: ' .. GetPlayerName(source) .. ' időtúllépés szerver oldalon!')
        playerRounds[source] = nil
        return
    end

    -- Minimum idő ellenőrzés (túl gyors teljesítés = csalás)
    local minTimePerDelivery = 5 -- minimum 5 másodperc/kézbesítés
    if elapsed < (#completedDeliveries * minTimePerDelivery) then
        print('[RealRPG-Futar] ANTICHEAT: ' .. GetPlayerName(source) .. ' gyanúsan gyors teljesítés! (' .. elapsed .. 'mp / ' .. #completedDeliveries .. ' kézbesítés)')
        playerRounds[source] = nil
        return
    end

    -- ==========================================
    -- FIZETÉS SZÁMÍTÁS
    -- ==========================================

    local data = playerSkills[source]
    if not data then return end

    local skillLevel = GetSkillLevel(data.skill_points)
    local isClub = IsClubMember(source)

    local totalBasePay = 0
    local totalSkillPoints = 0
    local deliveryCounts = {
        level = 0,
        small = 0,
        medium = 0,
        large = 0
    }

    for _, delivery in ipairs(completedDeliveries) do
        local dtype = delivery.type
        if Config.BasePayPerDelivery[dtype] then
            -- Alap fizetés * távolság szorzó * csomag méret szorzó
            local basePay = Config.BasePayPerDelivery[dtype]
            local distMult = delivery.distanceMultiplier or 1.0
            local sizeMult = delivery.packageSizeMultiplier or (Config.PackageSizeMultiplier[dtype] or 1.0)

            local deliveryPay = math.floor(basePay * distMult * sizeMult)
            totalBasePay = totalBasePay + deliveryPay

            totalSkillPoints = totalSkillPoints + (Config.SkillPointsPerDelivery[dtype] or 25)
            deliveryCounts[dtype] = (deliveryCounts[dtype] or 0) + 1
        end
    end

    -- ==========================================
    -- PROGRESSZÍV SKILL FIZETÉS SZÁMÍTÁS
    -- Minél magasabb a szinted, annál többet kapsz!
    -- ==========================================

    -- Skill szorzó a szint alapján (progresszíven növekvő)
    local skillMultiplier = Config.SkillPayMultiplier[skillLevel] or 1.0
    local skillBoostedPay = math.floor(totalBasePay * skillMultiplier)
    local skillBonus = skillBoostedPay - totalBasePay  -- A bónusz rész (Ft)

    -- Club tagsági bónusz (a skill-elt összegre számolva)
    local clubBonus = 0
    if isClub and Config.ClubBonus.enabled then
        clubBonus = math.floor(skillBoostedPay * (Config.ClubBonus.multiplier - 1))
    end

    -- Fizetés boost szorzó
    local payBoost = isClub and Config.PayBoost.club or Config.PayBoost.default
    local boostedPay = math.floor(skillBoostedPay * payBoost)

    -- Teljes fizetés = skill-elt alap * boost + club bónusz
    local totalPay = boostedPay + clubBonus

    -- ==========================================
    -- IDŐBÓNUSZ SZÁMÍTÁS
    -- Gyorsabb teljesítés = extra Ft!
    -- ==========================================
    local timeBonus = 0
    local timeBonusMultiplier = 1.0
    local timeBonusLabel = ''

    if Config.TimeBonus.enabled then
        local roundMaxTime = roundData.customTimeLimit or Config.Round.maxTime
        local timePercent = (elapsed / roundMaxTime) * 100

        for _, tier in ipairs(Config.TimeBonus.tiers) do
            if timePercent <= tier.maxPercent then
                timeBonusMultiplier = tier.multiplier
                timeBonusLabel = tier.label
                break
            end
        end

        if timeBonusMultiplier > 1.0 then
            timeBonus = math.floor(totalPay * (timeBonusMultiplier - 1.0))
            totalPay = totalPay + timeBonus
        end
    end

    -- ==========================================
    -- RANGLÉTRA (szint név)
    -- ==========================================
    local rankName = Config.Ranks[skillLevel] and Config.Ranks[skillLevel].name or 'Futár'
    local rankColor = Config.Ranks[skillLevel] and Config.Ranks[skillLevel].color or '#ffffff'

    -- ==========================================
    -- TÖRÉKENY CSOMAG SÉRÜLÉS BÜNTETÉS
    -- ==========================================
    local totalFragilePenalty = 0
    if Config.Fragile.enabled then
        for _, delivery in ipairs(completedDeliveries) do
            if delivery.damage and delivery.damage > 0 and delivery.isFragile then
                local penaltyPercent = delivery.damage * Config.Fragile.payPenalty.penaltyMultiplier / 100
                local thisDeliveryPay = Config.BasePayPerDelivery[delivery.type] or 0
                totalFragilePenalty = totalFragilePenalty + math.floor(thisDeliveryPay * penaltyPercent)
            end
        end
        totalPay = totalPay - totalFragilePenalty
    end

    -- ==========================================
    -- EXPRESSZ CSOMAG BÓNUSZ/BÜNTETÉS
    -- ==========================================
    local totalExpressBonus = 0
    if Config.Express.enabled then
        for _, delivery in ipairs(completedDeliveries) do
            if delivery.isExpress then
                local thisDeliveryPay = Config.BasePayPerDelivery[delivery.type] or 0
                if delivery.expressSuccess then
                    totalExpressBonus = totalExpressBonus + math.floor(thisDeliveryPay * (Config.Express.successMultiplier - 1))
                else
                    totalExpressBonus = totalExpressBonus - math.floor(thisDeliveryPay * (1 - Config.Express.failedMultiplier))
                end
            end
        end
        totalPay = totalPay + totalExpressBonus
    end

    -- ==========================================
    -- SZEZONÁLIS ESEMÉNY
    -- ==========================================
    local seasonalEvent = GetActiveSeasonalEvent()
    local seasonalBonus = 0
    if seasonalEvent then
        local seasonalMult = seasonalEvent.bonuses.payMultiplier or 1.0
        if seasonalMult > 1.0 then
            seasonalBonus = math.floor(totalPay * (seasonalMult - 1.0))
            totalPay = totalPay + seasonalBonus
        end
        totalSkillPoints = math.floor(totalSkillPoints * (seasonalEvent.bonuses.skillMultiplier or 1.0))
    end

    -- Biztosítjuk hogy totalPay nem negatív
    if totalPay < 0 then totalPay = 0 end

    -- ==========================================
    -- SKILL PONTOK FRISSÍTÉS
    -- ==========================================

    local oldLevel = skillLevel
    data.skill_points = data.skill_points + totalSkillPoints
    data.total_deliveries = data.total_deliveries + #completedDeliveries
    data.total_rounds = data.total_rounds + 1
    data.total_earnings = data.total_earnings + totalPay

    -- Legjobb kör frissítés
    if totalPay > data.best_round_pay then
        data.best_round_pay = totalPay
    end

    local newLevel = GetSkillLevel(data.skill_points)
    local leveledUp = newLevel > oldLevel

    -- Mentés
    SavePlayerSkill(source)

    -- ==========================================
    -- PÉNZ HOZZÁADÁS
    -- ==========================================
    local moneyAdded = AddMoney(source, totalPay)

    if not moneyAdded and Config.Debug then
        print('[RealRPG-Futar] FIGYELEM: Nem sikerült pénzt adni: ' .. GetPlayerName(source) .. ' - ' .. totalPay .. ' Ft')
    end

    -- ==========================================
    -- COOLDOWN ÉS CLEANUP
    -- ==========================================
    playerCooldowns[source] = os.time()
    playerRounds[source] = nil
    playerJobs[source].roundsCompleted = (playerJobs[source].roundsCompleted or 0) + 1

    -- ==========================================
    -- EREDMÉNY KÜLDÉSE KLIENSNEK
    -- ==========================================
    TriggerClientEvent('seerpg-futar:client:roundCompleted', source, {
        -- Fizetés részletezés
        basePay = totalBasePay,
        skillBonus = skillBonus,
        skillMultiplier = skillMultiplier,
        clubBonus = clubBonus,
        payBoost = payBoost,
        boostedPay = boostedPay,
        totalPay = totalPay,
        timeBonus = timeBonus,
        timeBonusMultiplier = timeBonusMultiplier,
        timeBonusLabel = timeBonusLabel,
        roundTime = elapsed,

        -- Törékeny és expressz
        fragilePenalty = totalFragilePenalty,
        expressBonus = totalExpressBonus,
        seasonalEvent = seasonalEvent and { name = seasonalEvent.name, payMultiplier = seasonalEvent.bonuses.payMultiplier } or nil,
        seasonalBonus = seasonalBonus,

        -- Skill
        earnedSkillPoints = totalSkillPoints,
        currentSkillPoints = data.skill_points,
        skillLevel = newLevel,
        nextLevelPoints = GetNextLevelPoints(data.skill_points),
        leveledUp = leveledUp,

        -- Rang
        rankName = rankName,
        rankColor = rankColor,

        -- Kézbesítések
        deliveryCounts = deliveryCounts,
        totalDelivered = #completedDeliveries,

        -- Egyéb
        isClubMember = isClub,
        maxStars = Config.MaxStars,
        jobLabel = Config.JobLabel
    })

    if Config.Debug then
        print('[RealRPG-Futar] Kör teljesítve: ' .. GetPlayerName(source))
        print('  - Kézbesítések: ' .. #completedDeliveries)
        print('  - Fizetés: ' .. totalPay .. ' Ft')
        print('  - Skill pontok: +' .. totalSkillPoints .. ' (összesen: ' .. data.skill_points .. ')')
        if leveledUp then
            print('  - SZINTLÉPÉS! ' .. oldLevel .. ' -> ' .. newLevel)
        end
    end
end)

-- ==========================================
-- SKILL ADATOK LEKÉRÉSE
-- ==========================================
RegisterNetEvent('seerpg-futar:server:getSkillData', function()
    local source = source

    if not playerSkills[source] then
        LoadPlayerSkill(source)
        Wait(500)
    end

    local data = playerSkills[source]
    if not data then return end

    local skillLevel = GetSkillLevel(data.skill_points)
    local isClub = IsClubMember(source)

    TriggerClientEvent('seerpg-futar:client:receiveSkillData', source, {
        skillPoints = data.skill_points,
        skillLevel = skillLevel,
        nextLevelPoints = GetNextLevelPoints(data.skill_points),
        totalDeliveries = data.total_deliveries,
        totalRounds = data.total_rounds,
        totalEarnings = data.total_earnings,
        bestRoundPay = data.best_round_pay,
        isClubMember = isClub,
        maxStars = Config.MaxStars,
        jobLabel = Config.JobLabel,
        rankName = Config.Ranks[skillLevel] and Config.Ranks[skillLevel].name or 'Futár',
        rankColor = Config.Ranks[skillLevel] and Config.Ranks[skillLevel].color or '#ffffff'
    })
end)

-- ==========================================
-- ADMIN PARANCSOK
-- ==========================================

-- Skill pontok beállítása
RegisterCommand('setfutarskill', function(source, args)
    if source == 0 or IsPlayerAceAllowed(source, 'command.setfutarskill') then
        local targetId = tonumber(args[1])
        local points = tonumber(args[2])

        if not targetId or not points then
            if source == 0 then
                print('[RealRPG-Futar] Használat: /setfutarskill [id] [pontok]')
            end
            return
        end

        if playerSkills[targetId] then
            playerSkills[targetId].skill_points = points
            SavePlayerSkill(targetId)

            local newLevel = GetSkillLevel(points)
            if source == 0 then
                print('[RealRPG-Futar] ' .. GetPlayerName(targetId) .. ' skill pontjai: ' .. points .. ' (szint: ' .. newLevel .. ')')
            else
                TriggerClientEvent('chat:addMessage', source, {
                    args = { '[RealRPG-Futar]', GetPlayerName(targetId) .. ' skill pontjai beállítva: ' .. points }
                })
            end
        else
            if source == 0 then
                print('[RealRPG-Futar] Játékos nem található: ' .. targetId)
            end
        end
    end
end, true)

-- Futár statisztikák
RegisterCommand('futarstats', function(source, args)
    if source == 0 or IsPlayerAceAllowed(source, 'command.futarstats') then
        local targetId = tonumber(args[1]) or source

        if playerSkills[targetId] then
            local data = playerSkills[targetId]
            local level = GetSkillLevel(data.skill_points)
            local msg = string.format(
                '[RealRPG-Futar] %s - Szint: %d | Pontok: %d | Körök: %d | Kézbesítések: %d | Kereset: %d Ft',
                GetPlayerName(targetId), level, data.skill_points, data.total_rounds, data.total_deliveries, data.total_earnings
            )

            if source == 0 then
                print(msg)
            else
                TriggerClientEvent('chat:addMessage', source, { args = { msg } })
            end
        end
    end
end, true)

-- Skill reset
RegisterCommand('resetfutarskill', function(source, args)
    if source == 0 or IsPlayerAceAllowed(source, 'command.resetfutarskill') then
        local targetId = tonumber(args[1])
        if not targetId then return end

        if playerSkills[targetId] then
            playerSkills[targetId].skill_points = 0
            playerSkills[targetId].total_deliveries = 0
            playerSkills[targetId].total_rounds = 0
            playerSkills[targetId].total_earnings = 0
            playerSkills[targetId].best_round_pay = 0
            SavePlayerSkill(targetId)

            if source == 0 then
                print('[RealRPG-Futar] ' .. GetPlayerName(targetId) .. ' futár adatai resetelve.')
            end
        end
    end
end, true)

-- ==========================================
-- EXPORTOK (más scriptek számára)
-- ==========================================

exports('GetPlayerSkillLevel', function(source)
    if playerSkills[source] then
        return GetSkillLevel(playerSkills[source].skill_points)
    end
    return 0
end)

exports('GetPlayerSkillPoints', function(source)
    if playerSkills[source] then
        return playerSkills[source].skill_points
    end
    return 0
end)

exports('AddSkillPoints', function(source, points)
    if playerSkills[source] then
        playerSkills[source].skill_points = playerSkills[source].skill_points + points
        SavePlayerSkill(source)
        return true
    end
    return false
end)

exports('IsPlayerWorkingFutar', function(source)
    return playerJobs[source] ~= nil
end)
