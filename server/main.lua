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

    if Config.Debug then
        print('[RealRPG-Futar] Adatbázis tábla ellenőrizve/létrehozva.')
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
-- Random lockerek + Útvonal optimalizálás
-- ==========================================
RegisterNetEvent('seerpg-futar:server:requestRound', function()
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
    -- RANDOM LOCKER PONTOK KIVÁLASZTÁSA
    -- ==========================================
    local numLockers = math.random(Config.RoundLockerCount.min, Config.RoundLockerCount.max)
    numLockers = numLockers + math.floor(skillLevel / 4)
    numLockers = math.min(numLockers, #Config.LockerPoints)

    -- Fisher-Yates shuffle a random kiválasztáshoz
    local availableLockers = {}
    for i = 1, #Config.LockerPoints do
        table.insert(availableLockers, i)
    end
    for i = #availableLockers, 2, -1 do
        local j = math.random(1, i)
        availableLockers[i], availableLockers[j] = availableLockers[j], availableLockers[i]
    end

    -- Kiválasztott lockerek (rendezés előtt)
    local selectedLockers = {}
    for i = 1, numLockers do
        local lockerPointIndex = availableLockers[i]
        local lockerPoint = Config.LockerPoints[lockerPointIndex]
        local distance = #(lockerPoint.coords - Config.Depot.coords)
        table.insert(selectedLockers, {
            index = lockerPointIndex,
            locker = lockerPoint,
            distance = distance
        })
    end

    -- ==========================================
    -- ÚTVONAL OPTIMALIZÁLÁS
    -- Legközelebbi → legtávolabbi sorrend
    -- ==========================================
    table.sort(selectedLockers, function(a, b)
        return a.distance < b.distance
    end)

    -- ==========================================
    -- CSOMAGOK GENERÁLÁSA LOCKERENKÉNT
    -- Egy lockerre több csomag (S, M, L) is mehet!
    -- ==========================================
    local deliveries = {}
    local lockerAssignments = {}

    for _, selected in ipairs(selectedLockers) do
        local lockerPoint = selected.locker
        local distance = selected.distance
        local distanceCategory, distanceMultiplier = GetDistanceCategory(distance)

        -- Hány csomag kerüljön erre a lockerre
        local maxPkg = math.min(Config.PackagesPerLocker.max, lockerPoint.maxPackages)
        local numPackages = math.random(Config.PackagesPerLocker.min, maxPkg)

        local lockerPackages = {}

        for p = 1, numPackages do
            local deliveryType = GetRandomDeliveryType(skillLevel)

            local delivery = {
                coords = lockerPoint.coords,
                label = lockerPoint.label,
                type = deliveryType,
                lockerId = lockerPoint.id,
                lockerIndex = selected.index,
                distance = distance,
                distanceCategory = distanceCategory,
                distanceMultiplier = distanceMultiplier,
                packageSizeMultiplier = Config.PackageSizeMultiplier[deliveryType] or 1.0,
            }

            table.insert(deliveries, delivery)
            table.insert(lockerPackages, delivery)
        end

        lockerAssignments[lockerPoint.id] = {
            locker = lockerPoint,
            packages = lockerPackages,
            distance = distance,
            distanceCategory = distanceCategory,
        }
    end

    -- Kör regisztrálása
    playerRounds[source] = {
        deliveries = deliveries,
        lockerAssignments = lockerAssignments,
        startTime = os.time(),
        expectedDeliveries = #deliveries
    }

    -- Küldés kliensnek
    TriggerClientEvent('seerpg-futar:client:roundGenerated', source, {
        deliveries = deliveries,
        lockerAssignments = lockerAssignments
    })

    if Config.Debug then
        print('[RealRPG-Futar] Kör generálva: ' .. GetPlayerName(source) .. ' - ' .. numLockers .. ' locker, ' .. #deliveries .. ' csomag')
        for lockerId, assignment in pairs(lockerAssignments) do
            print('  Locker #' .. lockerId .. ' (' .. assignment.locker.label .. ') - ' .. #assignment.packages .. ' csomag - ' .. assignment.distanceCategory)
        end
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
    if elapsed > Config.Round.maxTime + 30 then -- +30 mp puffer hálózati késleltetésre
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
        local roundMaxTime = Config.Round.maxTime
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
