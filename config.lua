Config = {}

-- ==========================================
-- ALAP BEÁLLÍTÁSOK
-- ==========================================
Config.JobName = 'futar'
Config.JobLabel = 'Futár'
Config.Framework = 'esx' -- 'esx' vagy 'qbcore'

-- ==========================================
-- FUTÁR DEPO (Munkaadó NPC helyszín)
-- ==========================================
Config.Depot = {
    coords = vector3(1139.87, -3199.82, 5.85),  -- Post OP Los Santos
    heading = 270.0,
    blip = {
        enabled = true,
        sprite = 478,
        color = 5,
        scale = 0.8,
        label = 'Futár Depó'
    }
}

-- ==========================================
-- NPC BEÁLLÍTÁSOK
-- ==========================================
Config.NPC = {
    model = 's_m_m_postal_02',  -- Postás modell
    coords = vector4(1139.87, -3199.82, 5.85, 270.0),
    scenario = 'WORLD_HUMAN_CLIPBOARD'
}

-- ==========================================
-- JÁRMŰ BEÁLLÍTÁSOK
-- ==========================================
Config.Vehicle = {
    model = 'boxville4',  -- Post OP furgon
    spawnPoint = vector4(1137.25, -3203.41, 5.85, 90.0),
    color = { primary = 111, secondary = 111 },  -- Fehér
    fuel = 100,
    locked = true,  -- Csak a futár nyithatja
    deleteOnFinish = true,  -- Törlés munka végén
}

-- Elérhető járművek (skill szint alapján feloldhatók)
Config.VehicleUpgrades = {
    [1] = { model = 'boxville4', label = 'Post OP Furgon', minLevel = 1, speed = 'Lassú', capacity = 'Nagy', desc = 'Megbízható furgon, sok hely.' },
    [2] = { model = 'speedo',    label = 'Speedo',         minLevel = 4, speed = 'Közepes', capacity = 'Közepes', desc = 'Gyorsabb, de kevesebb hely.' },
    [3] = { model = 'rumpo',     label = 'Rumpo',          minLevel = 7, speed = 'Gyors', capacity = 'Közepes', desc = 'Jó egyensúly sebesség és hely között.' },
    [4] = { model = 'surfer2',   label = 'Surfer',         minLevel = 10, speed = 'Nagyon gyors', capacity = 'Kicsi', desc = 'A leggyorsabb, de kevés csomag fér bele.' },
}

-- ==========================================
-- SKILL RENDSZER
-- ==========================================
Config.MaxStars = 12

Config.SkillLevels = {
    [1]  = 0,
    [2]  = 500,
    [3]  = 1200,
    [4]  = 2100,
    [5]  = 3500,
    [6]  = 5200,
    [7]  = 7125,
    [8]  = 9500,
    [9]  = 11650,
    [10] = 14500,
    [11] = 18000,
    [12] = 22000
}

-- Skill pont amit körenként kapsz típusonként
Config.SkillPointsPerDelivery = {
    ['level']  = 25,
    ['small']  = 35,
    ['medium'] = 50,
    ['large']  = 70
}

-- ==========================================
-- FIZETÉS BEÁLLÍTÁSOK (Forint - Ft)
-- ==========================================

-- Alap fizetés csomag típusonként (1. szinten ennyit kapsz)
Config.BasePayPerDelivery = {
    ['level']  = 7200,    -- Levél
    ['small']  = 10500,   -- Csomag (S)
    ['medium'] = 16000,   -- Csomag (M)
    ['large']  = 22000,   -- Csomag (L)
}

-- ==========================================
-- SKILL ALAPÚ PROGRESSZÍV FIZETÉS
-- Minél magasabb a szinted, annál többet kapsz!
-- A szorzó NÖVEKVŐ mértékben emelkedik szintenként.
-- ==========================================
Config.SkillPayMultiplier = {
    [1]  = 1.0,     -- 1★  = x1.0  (alap)
    [2]  = 1.06,    -- 2★  = x1.06 (+6%)
    [3]  = 1.14,    -- 3★  = x1.14 (+14%)
    [4]  = 1.24,    -- 4★  = x1.24 (+24%)
    [5]  = 1.36,    -- 5★  = x1.36 (+36%)
    [6]  = 1.50,    -- 6★  = x1.50 (+50%)
    [7]  = 1.66,    -- 7★  = x1.66 (+66%)
    [8]  = 1.84,    -- 8★  = x1.84 (+84%)
    [9]  = 2.05,    -- 9★  = x2.05 (+105%)
    [10] = 2.30,    -- 10★ = x2.30 (+130%)
    [11] = 2.60,    -- 11★ = x2.60 (+160%)
    [12] = 2.95,    -- 12★ = x2.95 (+195%)
}

-- Skill bónusz: a szorzó feletti rész Ft-ben kiírva az eredmény panelen
-- Példa: 10★ szint, 100.000 Ft alap → 100.000 * 2.65 = 265.000 Ft
-- A "Munka skill bónusz" sor: 165.000 Ft (ami a szorzóból jön)

-- Club tagsági bónusz (külön a skill szorzó tetejére)
Config.ClubBonus = {
    enabled = true,
    multiplier = 1.35,   -- +35% a VÉGSŐ összegre club tagoknak
}

-- Fizetés boost szorzó (alap játékosnak, club tagnak)
-- Ez a skill szorzó UTÁN még hozzáadódik
Config.PayBoost = {
    default = 1.0,       -- Alap: nincs extra boost
    club = 1.3           -- Club: x1.3 boost
}

-- ==========================================
-- KÖR BEÁLLÍTÁSOK
-- ==========================================
Config.Round = {
    maxTime = 900,              -- Maximum idő egy körre (mp) - 15 perc
    cooldownBetweenRounds = 30, -- Várakozás körök között (mp)
}

-- Csomag típus súlyozás (milyen valószínűséggel generálódik)
Config.DeliveryWeights = {
    ['level']  = 35,   -- 35% esély
    ['small']  = 30,   -- 30% esély
    ['medium'] = 20,   -- 20% esély
    ['large']  = 15,   -- 15% esély
}

-- Magasabb szintű típusok feloldása
Config.DeliveryUnlocks = {
    ['level']  = 1,   -- 1. szinttől elérhető
    ['small']  = 1,   -- 1. szinttől elérhető
    ['medium'] = 3,   -- 3. szinttől elérhető
    ['large']  = 5,   -- 5. szinttől elérhető
}

-- ==========================================
-- CSOMAGPONT (LOCKER) HELYSZÍNEK - FIX PONTOK
-- A lockerek MINDIG itt állnak, sosem tűnnek el.
-- Távolság a depótól befolyásolja a fizetést!
-- Egy csomagpontra TÖBB csomag is leadható (S, M, L).
-- ==========================================

-- Távolság szorzó: minél messzebb van a locker, annál többet fizet
Config.DistancePayBonus = {
    near = { maxDistance = 1500, multiplier = 1.0, label = 'Közeli' },
    medium = { maxDistance = 3500, multiplier = 1.25, label = 'Közepes' },
    far = { maxDistance = 6000, multiplier = 1.55, label = 'Távoli' },
    veryFar = { maxDistance = 99999, multiplier = 1.90, label = 'Nagyon távoli' },
}

-- Csomag méret szorzó (nagyobb csomag = több fizetés a távolságra is)
Config.PackageSizeMultiplier = {
    ['level']  = 0.7,    -- Levél: x0.7
    ['small']  = 1.0,    -- Csomag (S): x1.0
    ['medium'] = 1.35,   -- Csomag (M): x1.35
    ['large']  = 1.85,   -- Csomag (L): x1.85
}

-- FIX LOCKER PONTOK (20 helyszín - mindig jelen vannak!)
Config.LockerPoints = {
    -- KÖZELI (depó közelében, ~0-1500m)
    { id = 1,  coords = vector3(1196.45, -3112.77, 5.85), heading = 180.0, label = 'Csomagpont - Kikötő', maxPackages = 3 },
    { id = 2,  coords = vector3(1065.22, -2904.51, 5.90), heading = 0.0, label = 'Csomagpont - Elysian Island', maxPackages = 3 },
    { id = 3,  coords = vector3(811.43, -2979.10, 6.02), heading = 90.0, label = 'Csomagpont - Gyár', maxPackages = 2 },
    { id = 4,  coords = vector3(1137.85, -2641.33, 4.56), heading = 270.0, label = 'Csomagpont - Terminál', maxPackages = 3 },
    { id = 5,  coords = vector3(810.52, -2159.39, 29.87), heading = 0.0, label = 'Csomagpont - Ipari Park', maxPackages = 2 },
    -- KÖZEPES (1500-3500m)
    { id = 6,  coords = vector3(25.72, -1347.27, 29.50), heading = 0.0, label = 'Csomagpont - Strawberry', maxPackages = 3 },
    { id = 7,  coords = vector3(-48.52, -1757.25, 29.42), heading = 180.0, label = 'Csomagpont - Davis', maxPackages = 2 },
    { id = 8,  coords = vector3(340.67, -1750.56, 29.63), heading = 90.0, label = 'Csomagpont - Rancho', maxPackages = 3 },
    { id = 9,  coords = vector3(-706.13, -913.28, 19.22), heading = 270.0, label = 'Csomagpont - Vespucci', maxPackages = 2 },
    { id = 10, coords = vector3(143.26, -1045.85, 29.38), heading = 0.0, label = 'Csomagpont - Pillbox Hill', maxPackages = 3 },
    { id = 11, coords = vector3(-262.76, -965.62, 31.22), heading = 180.0, label = 'Csomagpont - Alta', maxPackages = 2 },
    { id = 12, coords = vector3(-576.83, -654.04, 33.46), heading = 90.0, label = 'Csomagpont - Little Seoul', maxPackages = 3 },
    -- TÁVOLI (3500-6000m)
    { id = 13, coords = vector3(-1222.41, -1079.83, 8.11), heading = 0.0, label = 'Csomagpont - Del Perro', maxPackages = 2 },
    { id = 14, coords = vector3(-1486.78, -378.10, 40.16), heading = 270.0, label = 'Csomagpont - Morningwood', maxPackages = 2 },
    { id = 15, coords = vector3(-78.31, -618.57, 36.27), heading = 180.0, label = 'Csomagpont - Downtown', maxPackages = 3 },
    { id = 16, coords = vector3(373.78, 326.60, 103.57), heading = 0.0, label = 'Csomagpont - Vinewood', maxPackages = 2 },
    { id = 17, coords = vector3(955.26, -622.33, 57.97), heading = 90.0, label = 'Csomagpont - La Mesa', maxPackages = 3 },
    -- NAGYON TÁVOLI (6000m+)
    { id = 18, coords = vector3(1159.52, -314.26, 69.21), heading = 180.0, label = 'Csomagpont - Mirror Park', maxPackages = 2 },
    { id = 19, coords = vector3(2557.45, 380.84, 108.62), heading = 0.0, label = 'Csomagpont - Tataviam', maxPackages = 2 },
    { id = 20, coords = vector3(-1811.69, -617.88, 11.01), heading = 270.0, label = 'Csomagpont - Pacific Bluffs', maxPackages = 3 },
}

-- Locker blip beállítás (fix pontoknál mindig látható)
Config.LockerBlip = {
    sprite = 478,
    color = 46,         -- Szürke alapban
    activeColor = 5,    -- Zöld ha oda kell menni
    scale = 0.6,
    label = 'Csomagpont'
}

-- Kör generálás: hány locker pont legyen kiválasztva egy körben
Config.RoundLockerCount = {
    min = 3,
    max = 6,
}

-- Egy lockerre hány csomag kerülhet (az adott locker maxPackages-ig)
Config.PackagesPerLocker = {
    min = 1,
    max = 3,
}

-- ==========================================
-- MARKER ÉS BLIP BEÁLLÍTÁSOK
-- ==========================================
Config.Markers = {
    depot = {
        type = 1,
        color = { r = 50, g = 200, b = 50, a = 150 },
        size = vector3(1.5, 1.5, 1.0),
        drawDistance = 20.0
    },
    pickup = {
        type = 1,
        color = { r = 50, g = 100, b = 255, a = 150 },
        size = vector3(1.0, 1.0, 0.5),
        drawDistance = 15.0
    },
    delivery = {
        type = 1,
        color = { r = 255, g = 165, b = 0, a = 150 },
        size = vector3(1.0, 1.0, 0.5),
        drawDistance = 15.0
    }
}

Config.DeliveryBlip = {
    sprite = 501,
    color = 5,
    scale = 0.7,
    label = 'Kézbesítés'
}

-- Prop-ok (kézben tartott tárgyak) - Custom stream propok
-- Több variáns van minden méretből - random választódik!
Config.Props = {
    letter = 'prop_cs_documents_01',

    -- Csomag (S) variánsok: bzzz_prop_custom_box_1a - 1e
    package_small = {
        'bzzz_prop_custom_box_1a',
        'bzzz_prop_custom_box_1b',
        'bzzz_prop_custom_box_1c',
        'bzzz_prop_custom_box_1d',
        'bzzz_prop_custom_box_1e',
    },

    -- Csomag (M) variánsok: bzzz_prop_custom_box_2a - 2e
    package_medium = {
        'bzzz_prop_custom_box_2a',
        'bzzz_prop_custom_box_2b',
        'bzzz_prop_custom_box_2c',
        'bzzz_prop_custom_box_2d',
        'bzzz_prop_custom_box_2e',
    },

    -- Csomag (L) variánsok: bzzz_prop_custom_box_3a - 3e
    package_large = {
        'bzzz_prop_custom_box_3a',
        'bzzz_prop_custom_box_3b',
        'bzzz_prop_custom_box_3c',
        'bzzz_prop_custom_box_3d',
        'bzzz_prop_custom_box_3e',
    },
}

-- ==========================================
-- RAKLAP RENDSZER (Depó bepakolás)
-- ==========================================
Config.Pallet = {
    -- Raklap prop (alap raklap modell a depóban)
    model = 'prop_boxpile_02b',  -- Doboz halom / raklap
    coords = vector4(1142.50, -3199.82, 5.85, 270.0),  -- Raklap helye a depóban

    -- Csomagok elhelyezése a raklapon (offset-ek a raklaptól)
    -- Soronként és oszloponként rendezve
    packageSlots = {
        -- Első sor (alsó - raklap tetején)
        { offset = vector3(-0.5, -0.4, 0.0), rotation = vector3(0.0, 0.0, 0.0) },
        { offset = vector3(0.0, -0.4, 0.0), rotation = vector3(0.0, 0.0, 5.0) },
        { offset = vector3(0.5, -0.4, 0.0), rotation = vector3(0.0, 0.0, -3.0) },
        { offset = vector3(-0.5, 0.0, 0.0), rotation = vector3(0.0, 0.0, 2.0) },
        { offset = vector3(0.0, 0.0, 0.0), rotation = vector3(0.0, 0.0, -5.0) },
        { offset = vector3(0.5, 0.0, 0.0), rotation = vector3(0.0, 0.0, 0.0) },
        { offset = vector3(-0.5, 0.4, 0.0), rotation = vector3(0.0, 0.0, 4.0) },
        { offset = vector3(0.0, 0.4, 0.0), rotation = vector3(0.0, 0.0, -2.0) },
        -- Második sor (felső)
        { offset = vector3(-0.5, -0.4, 0.35), rotation = vector3(0.0, 0.0, 8.0) },
        { offset = vector3(0.0, -0.4, 0.35), rotation = vector3(0.0, 0.0, -4.0) },
        { offset = vector3(0.5, -0.4, 0.35), rotation = vector3(0.0, 0.0, 3.0) },
        { offset = vector3(-0.5, 0.0, 0.35), rotation = vector3(0.0, 0.0, -6.0) },
        { offset = vector3(0.0, 0.0, 0.35), rotation = vector3(0.0, 0.0, 0.0) },
        { offset = vector3(0.5, 0.0, 0.35), rotation = vector3(0.0, 0.0, 5.0) },
        { offset = vector3(-0.5, 0.4, 0.35), rotation = vector3(0.0, 0.0, -3.0) },
    },

    -- Játékos felvétel távolság a raklaptól
    pickupDistance = 1.8,
}

-- ==========================================
-- JÁRMŰ CSOMAGTÉR RENDSZER
-- ==========================================
Config.VehicleCargo = {
    -- Oldalsó ajtó interakció
    doorSide = 'right',                  -- Melyik oldalon van az ajtó ('left', 'right', 'back')
    doorInteractDistance = 2.0,          -- Milyen közel kell lenni a jármű oldalához
    doorOpenDistance = 1.5,              -- Ajtó nyitás gomb távolság

    -- Ajtó index a járműben (GTA V door index)
    -- 0 = bal első, 1 = jobb első, 2 = bal hátsó, 3 = jobb hátsó, 4 = csomagtartó, 5 = motorháztető
    doorIndex = 2,  -- Hátsó bal (boxville oldalső ajtó)

    -- Csomagok pozíciói a csomagtérben (offset-ek a jármű eredetétől)
    cargoSlots = {
        { offset = vector3(-0.3, -1.5, -0.2), rotation = vector3(0.0, 0.0, 0.0) },
        { offset = vector3(0.3, -1.5, -0.2), rotation = vector3(0.0, 0.0, 5.0) },
        { offset = vector3(-0.3, -2.0, -0.2), rotation = vector3(0.0, 0.0, -3.0) },
        { offset = vector3(0.3, -2.0, -0.2), rotation = vector3(0.0, 0.0, 2.0) },
        { offset = vector3(-0.3, -2.5, -0.2), rotation = vector3(0.0, 0.0, 0.0) },
        { offset = vector3(0.3, -2.5, -0.2), rotation = vector3(0.0, 0.0, -5.0) },
        -- Felső réteg
        { offset = vector3(-0.3, -1.5, 0.15), rotation = vector3(0.0, 0.0, 4.0) },
        { offset = vector3(0.3, -1.5, 0.15), rotation = vector3(0.0, 0.0, -2.0) },
        { offset = vector3(-0.3, -2.0, 0.15), rotation = vector3(0.0, 0.0, 0.0) },
        { offset = vector3(0.3, -2.0, 0.15), rotation = vector3(0.0, 0.0, 6.0) },
        { offset = vector3(-0.3, -2.5, 0.15), rotation = vector3(0.0, 0.0, -4.0) },
        { offset = vector3(0.3, -2.5, 0.15), rotation = vector3(0.0, 0.0, 0.0) },
        -- Harmadik réteg (ha sok csomag van)
        { offset = vector3(0.0, -1.7, 0.5), rotation = vector3(0.0, 0.0, 3.0) },
        { offset = vector3(0.0, -2.2, 0.5), rotation = vector3(0.0, 0.0, -3.0) },
        { offset = vector3(0.0, -2.7, 0.5), rotation = vector3(0.0, 0.0, 0.0) },
    },

    -- Berakás interakció pont (a jármű oldalán, ahonnan berakod)
    loadPointOffset = vector3(0.8, -1.8, 0.0),  -- Jobb oldali hátul offset
}

-- ==========================================
-- BEPAKOLÁS ANIMÁCIÓK
-- ==========================================
Config.Animations = {
    -- Csomag felvétel a raklapról
    pickupFromPallet = {
        dict = 'random@domestic',
        name = 'pickup_low',
        flag = 0,
        duration = 2000
    },
    -- Csomag kézben tartás (séta közben)
    carryPackage = {
        dict = 'anim@heists@box_carry@',
        name = 'idle',
        flag = 49,
        duration = -1  -- Folyamatos amíg viszi
    },
    -- Csomag behelyezés autóba
    putInVehicle = {
        dict = 'anim@heists@box_carry@',
        name = 'idle',
        flag = 0,
        duration = 2500
    },
    -- Csomag leadás kézbesítésnél
    deliverPackage = {
        dict = 'mp_common',
        name = 'givetake1_b',
        flag = 0,
        duration = 2000
    },
    -- Ajtó nyitás kézzel
    openDoor = {
        dict = 'mini@repair',
        name = 'fixing_a_ped',
        flag = 0,
        duration = 1500
    },
}

-- ==========================================
-- PROP KÉZBEN TARTÁS POZÍCIÓK (bone offset-ek)
-- ==========================================
Config.PropAttach = {
    -- Csomag a kézben (két kézzel tartva, maga előtt)
    carry = {
        bone = 57005,  -- SKEL_R_Hand
        offset = vector3(0.12, 0.08, 0.03),
        rotation = vector3(-50.0, 0.0, 0.0),
    },
    -- Levél (egy kézben)
    letter = {
        bone = 57005,
        offset = vector3(0.1, 0.02, 0.0),
        rotation = vector3(10.0, 0.0, 0.0),
    },
}

-- ==========================================
-- INTERAKCIÓ BEÁLLÍTÁSOK (Kattintható Ikon Rendszer)
-- ==========================================
Config.Interaction = {
    depotDistance = 2.5,         -- NPC-hez közel mennyire kell menni
    deliveryDistance = 2.0,     -- Kézbesítési ponthoz mennyire kell menni

    -- Kurzor megjelenítés gomb
    cursorKey = 19,             -- ALT gomb (INPUT_CHARACTER_WHEEL)
    cursorKeyLabel = 'ALT',

    -- Ikon megjelenési távolság (ettől távolabb nem jelenik meg)
    iconShowDistance = 5.0,

    -- Ikon méret (px)
    iconSize = 56,

    -- Ikon típusok (feladathoz illeszkedő ikonok)
    icons = {
        -- NPC interakciók
        start_work = { icon = '🚚', tooltip = 'Munka elkezdése', color = '#4cff4c' },
        new_round = { icon = '📋', tooltip = 'Új kör indítása', color = '#4cff4c' },
        end_work = { icon = '🚪', tooltip = 'Munka befejezése', color = '#ff4444' },
        view_skill = { icon = '⭐', tooltip = 'Skill megtekintése', color = '#ffd700' },
        finish_round = { icon = '✅', tooltip = 'Kör lezárása', color = '#4cff4c' },

        -- Bepakolás fázis
        pickup_package = { icon = '📦', tooltip = 'Csomag felvétele', color = '#44aaff' },
        open_door = { icon = '🔓', tooltip = 'Ajtó kinyitása', color = '#ffaa00' },
        close_door = { icon = '🔒', tooltip = 'Ajtó bezárása', color = '#ff8800' },
        load_package = { icon = '📥', tooltip = 'Csomag berakása', color = '#44aaff' },
        finish_loading = { icon = '✅', tooltip = 'Bepakolás kész!', color = '#4cff4c' },

        -- Kézbesítés (Locker rendszer)
        take_from_vehicle = { icon = '📤', tooltip = 'Csomag kivétele', color = '#44aaff' },
        open_locker = { icon = '🔓', tooltip = 'Fiók kinyitása', color = '#ffaa00' },
        deliver = { icon = '📥', tooltip = 'Csomag berakása', color = '#4cff4c' },

        -- Jármű javítás
        repair_vehicle = { icon = '🔧', tooltip = 'Jármű javítása', color = '#ffaa00' },

        -- Futár Bolt
        open_shop = { icon = '🛒', tooltip = 'Futár Bolt', color = '#44ff44' },
    }
}

-- ==========================================
-- LOCKER (Kézbesítési szekrény) RENDSZER
-- ==========================================
Config.Locker = {
    -- Locker prop modell (custom prop - stream-elni kell!)
    model = 'bzzz_prop_shop_locker',

    -- Fiók ajtók indexei a modellben (ha a prop-nak vannak door bone-jai)
    -- Ha a prop nem támogat door anim-ot, szimulálunk nyitást object-ekkel
    doorCount = 4,    -- Hány fiókja van a lockernek

    -- Locker spawn offset a delivery coords-tól
    spawnOffset = vector3(0.0, 0.0, 0.0),
    heading = 0.0,    -- A szerver generálja delivery-nként

    -- Interakció távolság
    interactDistance = 1.8,

    -- Fiók animáció (fizikai object mozgatás)
    doorOpenOffset = vector3(0.0, 0.35, 0.0),  -- Mennyit nyílik ki a fiók (Y tengely)
    doorOpenTime = 800,     -- Nyitás animáció idő (ms)
    doorCloseDelay = 1500,  -- Csomag behelyezés után ennyi idő múlva záródik (ms)

    -- Fiók magasságok (offset Z a lockertől - melyik fiók milyen magasan van)
    compartments = {
        { offsetZ = 0.1,  label = 'Alsó fiók' },
        { offsetZ = 0.45, label = 'Közép alsó fiók' },
        { offsetZ = 0.8,  label = 'Közép felső fiók' },
        { offsetZ = 1.15, label = 'Felső fiók' },
    },

    -- A kézbesítésnél melyik fiókba kerüljön a csomag (random vagy sorrend)
    assignMode = 'random',  -- 'random' vagy 'sequential'
}

-- ==========================================
-- ÜZENETEK / SZÖVEGEK
-- ==========================================
Config.Locale = {
    -- NPC interakciók
    npc_greeting = 'Üdv futár! Készen állsz a mai műszakra?',
    npc_start_work = '[E] Munka elkezdése',
    npc_end_work = '[X] Munka befejezése',
    npc_open_skill = '[G] Skill megtekintése',
    npc_vehicle_select = 'Válassz járművet:',

    -- Bepakolás fázis
    pallet_pickup = '[E] Csomag felvétele',
    pallet_remaining = ' csomag maradt a raklapon',
    carrying_package = 'Vidd a járműhöz!',
    vehicle_open_door = '[E] Ajtó kinyitása',
    vehicle_close_door = '[E] Ajtó bezárása',
    vehicle_load_package = '[E] Csomag berakása',
    all_loaded = '~g~Minden csomag bepakolva! ~w~Indulj kézbesíteni!',
    loading_progress = 'Bepakolás: ',

    -- Kör közben
    round_started = '~g~Új kör indult! ~w~Pakold be a csomagokat a járműbe!',
    pickup_packages = '[E] Csomagok felvétele',
    deliver_package = '[E] Csomag leadása',
    all_picked_up = '~g~Minden csomag felvéve! ~w~Kezdd el a kézbesítést!',
    delivery_complete = '~g~Sikeresen kézbesítve!',
    round_complete = '~g~Kör teljesítve! Menj vissza a depóba!',
    return_to_depot = '~y~Térj vissza a depóba az eredményeidért!',

    -- Hibák
    already_working = '~r~Már dolgozol!',
    not_working = '~r~Nem dolgozol jelenleg!',
    cooldown_active = '~r~Még várnod kell a következő körig!',
    time_expired = '~r~Lejárt az időd! A kör érvénytelen.',
    too_far = '~r~Túl messze vagy!',
    no_vehicle = '~r~Nincs futárjárműved! Menj vissza a depóba.',
    vehicle_destroyed = '~r~A járműved megsemmisült! A kör véget ért.',
    hands_full = '~r~Már van csomag a kezedben!',
    hands_empty = '~r~Nincs csomag a kezedben!',
    door_closed = '~r~Nyisd ki előbb az ajtót!',

    -- Locker kézbesítés
    take_from_vehicle = 'Csomag kivéve a járműből!',
    locker_open = 'Fiók kinyitva!',
    locker_delivered = '~g~Csomag elhelyezve a fiókban!',
    locker_no_package = '~r~Nincs csomag a kezedben!',

    -- Értesítések
    job_started = '~g~Sikeresen elkezted a futár munkát!',
    job_ended = '~y~Befejezted a futár munkát.',
    level_up = '~p~Szintlépés! Új skill szinted: ',
}

-- ==========================================
-- EGYÉB BEÁLLÍTÁSOK
-- ==========================================
Config.UseNotifications = 'native'  -- 'native', 'esx', 'ox'

-- Debug mód (fejlesztéshez)
Config.Debug = false

-- GPS route kijelzés
Config.ShowGPSRoute = true

-- Skill parancs
Config.SkillCommand = 'munkaskill'

-- Adatbázis tábla
Config.DBTable = 'seerpg_futar_skills'

-- ==========================================
-- IDŐBÓNUSZ RENDSZER
-- Minél gyorsabban teljesíted a kört, annál több extra Ft jár!
-- ==========================================
Config.TimeBonus = {
    enabled = true,

    -- Idő küszöbök (% a maxTime-ból)
    -- Ha a kör maxTime-jának X%-a alatt teljesítesz, bónuszt kapsz
    tiers = {
        { maxPercent = 30, multiplier = 1.50, label = '⚡ Villámgyors!' },  -- 30% alatt = +50%
        { maxPercent = 50, multiplier = 1.30, label = '🏃 Gyors!' },        -- 50% alatt = +30%
        { maxPercent = 70, multiplier = 1.15, label = '👍 Szép tempó!' },   -- 70% alatt = +15%
        { maxPercent = 100, multiplier = 1.0, label = '' },                  -- 100% = nincs bónusz
    },
}

-- ==========================================
-- RANGLÉTRA RENDSZER
-- Szint nevek és előnyök
-- ==========================================
Config.Ranks = {
    [1]  = { name = 'Kezdő Futár',       color = '#888888' },
    [2]  = { name = 'Tanuló Futár',      color = '#aaaaaa' },
    [3]  = { name = 'Futár',             color = '#ffffff' },
    [4]  = { name = 'Gyakorlott Futár',  color = '#44ff44' },
    [5]  = { name = 'Tapasztalt Futár',  color = '#44aaff' },
    [6]  = { name = 'Haladó Futár',      color = '#4488ff' },
    [7]  = { name = 'Szakértő Futár',    color = '#aa44ff' },
    [8]  = { name = 'Veterán Futár',     color = '#ff44aa' },
    [9]  = { name = 'Elit Futár',        color = '#ff8800' },
    [10] = { name = 'Mester Futár',      color = '#ffdd00' },
    [11] = { name = 'Legenda Futár',     color = '#ff4444' },
    [12] = { name = 'Futár Király',      color = '#ffd700' },
}

-- ==========================================
-- NAPI/HETI KIHÍVÁSOK
-- Teljesítésükért extra skill pont és Ft jár
-- ==========================================
Config.Challenges = {
    enabled = true,

    -- Naponta frissülő kihívások (3 random választódik)
    daily = {
        { id = 'deliver_10',      desc = 'Szállíts le 10 csomagot',         target = 10, type = 'deliveries',    reward_money = 42000, reward_skill = 100 },
        { id = 'deliver_large_3', desc = 'Szállíts le 3 db L méretű csomagot', target = 3,  type = 'large_packages', reward_money = 65000, reward_skill = 150 },
        { id = 'complete_3_rounds', desc = 'Teljesíts 3 kört',              target = 3,  type = 'rounds',        reward_money = 52000, reward_skill = 120 },
        { id = 'fast_round',      desc = 'Teljesíts egy kört 5 perc alatt', target = 1,  type = 'fast_round',    reward_money = 70000, reward_skill = 200 },
        { id = 'deliver_far_5',   desc = 'Szállíts 5 csomagot távoli pontra', target = 5,  type = 'far_deliveries', reward_money = 78000, reward_skill = 175 },
        { id = 'no_damage',       desc = 'Sérülés nélkül teljesíts egy kört', target = 1,  type = 'no_damage',    reward_money = 38000, reward_skill = 100 },
        { id = 'deliver_medium_5', desc = 'Szállíts 5 db M méretű csomagot', target = 5, type = 'medium_packages', reward_money = 48000, reward_skill = 100 },
    },

    -- Hetente frissülő kihívások (1 nagy kihívás)
    weekly = {
        { id = 'deliver_50',      desc = 'Szállíts le 50 csomagot ezen a héten', target = 50, type = 'deliveries', reward_money = 210000, reward_skill = 500 },
        { id = 'complete_10_rounds', desc = 'Teljesíts 10 kört ezen a héten', target = 10, type = 'rounds', reward_money = 260000, reward_skill = 600 },
        { id = 'earn_500k',       desc = 'Keress 400 000 Ft-ot futárkodással', target = 400000, type = 'earnings', reward_money = 175000, reward_skill = 400 },
    },

    -- Hány napi kihívás legyen aktív egyszerre
    dailyCount = 3,
    weeklyCount = 1,
}


-- ==========================================
-- TÖRÉKENY CSOMAG RENDSZER
-- Ütközés/gyors kanyar/leejtés sértheti a csomagot
-- A sérülés csökkenti a fizetést!
-- ==========================================
Config.Fragile = {
    enabled = true,

    -- Milyen eséllyel legyen egy csomag törékeny (%)
    chance = 25,  -- 25% esély hogy törékeny lesz

    -- Sérülés források és értékek (0-100 skála, 100 = teljesen tönkrement)
    damage = {
        -- Ütközés (jármű baleset)
        collision = {
            minSpeed = 20.0,       -- Km/h alatti ütközés nem számít
            damagePerHit = 15,     -- Ütközésenként ennyi sérülés
            maxDamagePerHit = 40,  -- Maximum sérülés egyetlen ütközésből
            speedMultiplier = 0.5, -- Sebesség szorzó (gyorsabb = nagyobb sérülés)
        },
        -- Hirtelen fékezés/gyorsulás
        acceleration = {
            threshold = 25.0,      -- G-erő küszöb (ennél erősebb fékezés/gyorsulás számít)
            damagePerEvent = 5,    -- Sérülés eseményenként
        },
        -- Karakter elesik (csomag kézben van)
        playerFall = {
            enabled = true,
            damagePerFall = 20,    -- Eleséskor ennyi sérülés
        },
    },

    -- Sérülés hatása a fizetésre
    payPenalty = {
        -- A sérülés %-ban csökkenti a fizetést
        -- Pl. 30% sérülés = 30% * penaltyMultiplier fizetés csökkenés
        penaltyMultiplier = 0.8,  -- 80%-os hatás (30% sérülés = 24% fizetés csökkenés)
        -- 100% sérülés felett a csomag MEGSEMMISÜL (0 Ft fizetés)
        destroyThreshold = 100,
    },

    -- NUI ikon beállítások
    indicator = {
        showAlways = false,       -- Mindig mutassa vagy csak törékeny csomagnál
        position = 'left',       -- 'left' vagy 'right' - képernyő melyik oldalán
        warningThreshold = 40,   -- Sárga figyelmeztetés ennyi sérülés felett
        criticalThreshold = 70,  -- Piros figyelmeztetés ennyi sérülés felett
    },

    -- Vizuális jelzés a csomagon (csomag prop színe/effekt)
    visual = {
        damagedEffect = true,    -- Sérült csomagnál vizuális jelzés
    },

    -- Jelölés a csomagon (NUI-n "TÖRÉKENY" felirat)
    label = '⚠️ TÖRÉKENY',
    labelColor = '#ff8800',
}

-- ==========================================
-- EXPRESSZ CSOMAG RENDSZER
-- Időkorlátos kézbesítés - dupla fizetés ha időben érsz oda!
-- ==========================================
Config.Express = {
    enabled = true,

    -- Milyen eséllyel legyen expressz csomag (%)
    chance = 15,  -- 15% esély hogy expressz lesz

    -- Időlimit beállítások
    timeLimit = {
        base = 180,            -- Alap időlimit (mp) - 3 perc
        perKm = 15,            -- +15 mp / km távolság (depótól)
        minTime = 120,         -- Minimum időlimit (mp) - 2 perc
        maxTime = 360,         -- Maximum időlimit (mp) - 6 perc
    },

    -- Fizetés szorzó ha időben kézbesítesz
    successMultiplier = 2.0,   -- Dupla fizetés expressznél

    -- Büntetés ha nem érsz oda időben (a csomag NEM vész el, de kevesebb fizetés)
    failedMultiplier = 0.5,    -- Fele fizetés ha lejárt az idő

    -- Vizuális jelzés
    label = '⚡ EXPRESSZ',
    labelColor = '#ff4444',
    timerColor = {
        normal = '#44ff44',    -- Zöld: sok idő van
        warning = '#ffaa00',   -- Sárga: kevés idő
        critical = '#ff4444',  -- Piros: nagyon kevés idő
    },
    warningPercent = 40,       -- Sárga ha ennyi % idő maradt
    criticalPercent = 20,      -- Piros ha ennyi % idő maradt

    -- Extra skill pont expressz teljesítésért
    bonusSkillPoints = 50,
}

-- ==========================================
-- JÁRMŰ JAVÍTÁS RENDSZER
-- Ha balesetezel, javíttatnod kell a depóban!
-- ==========================================
Config.VehicleRepair = {
    enabled = true,

    -- Jármű HP küszöb (ez alatt nem indíthatsz új kört)
    minHealthToStart = 600,    -- 1000 a max HP, 600 alatt javítani kell

    -- Javítás költség
    repairCost = {
        base = 5000,           -- Alap javítási díj (Ft)
        perDamagePoint = 30,   -- +30 Ft / sérülés pont (1000 - aktuális HP)
    },

    -- Javítás idő (ms)
    repairTime = 8000,         -- 8 másodperc

    -- Javítás animáció
    animation = {
        dict = 'mini@repair',
        name = 'fixing_a_ped',
        flag = 0,
    },

    -- Javítás interakciós ikon
    icon = { icon = '🔧', tooltip = 'Jármű javítása', color = '#ffaa00' },

    -- Javítás pont (a depóban)
    repairPoint = vector3(1135.50, -3205.20, 5.85),
    repairDistance = 3.0,

    -- Figyelmeztetés küszöbök
    warningHealth = 750,       -- Sárga figyelmeztetés
    criticalHealth = 500,      -- Piros figyelmeztetés + lassulás
}

-- ==========================================
-- FUTÁR BOLT / UPGRADE RENDSZER
-- Vásárolható fejlesztések a futár munkához
-- ==========================================
Config.Shop = {
    enabled = true,

    -- Bolt NPC (a depóban, másik NPC)
    npc = {
        model = 's_m_m_postal_01',
        coords = vector4(1141.50, -3197.20, 5.85, 180.0),
        scenario = 'WORLD_HUMAN_STAND_IMPATIENT'
    },

    -- Elérhető fejlesztések
    upgrades = {
        -- GPS fejlesztések
        gps_basic = {
            id = 'gps_basic',
            category = 'gps',
            name = 'GPS Frissítés',
            desc = 'Gyorsabb útvonal számítás, mini-térkép kiemelés.',
            price = 50000,
            minLevel = 2,
            icon = '🗺️',
        },
        gps_advanced = {
            id = 'gps_advanced',
            category = 'gps',
            name = 'Fejlett GPS',
            desc = 'Több útvonal egyszerre látható a térképen.',
            price = 120000,
            minLevel = 5,
            icon = '📡',
            requires = 'gps_basic',  -- Előfeltétel
        },

        -- Csomagtér fejlesztések
        cargo_expand = {
            id = 'cargo_expand',
            category = 'cargo',
            name = 'Csomagtér Bővítés',
            desc = '+3 extra csomag hely a járműben.',
            price = 85000,
            minLevel = 3,
            icon = '📦',
            effect = { extraSlots = 3 },
        },
        cargo_secure = {
            id = 'cargo_secure',
            category = 'cargo',
            name = 'Csomag Rögzítő',
            desc = 'Törékeny csomagok 30%-kal kevesebb sérülést kapnak.',
            price = 95000,
            minLevel = 4,
            icon = '🛡️',
            effect = { fragileProtection = 0.30 },
        },

        -- Bepakolás fejlesztések
        speed_loader = {
            id = 'speed_loader',
            category = 'speed',
            name = 'Gyors Bepakolás',
            desc = 'Bepakolás animáció 40%-kal gyorsabb.',
            price = 65000,
            minLevel = 3,
            icon = '⚡',
            effect = { loadSpeedMultiplier = 0.6 },
        },

        -- Jármű fejlesztések
        vehicle_armor = {
            id = 'vehicle_armor',
            category = 'vehicle',
            name = 'Jármű Védelem',
            desc = 'A futárjármű 25%-kal kevesebb sérülést kap.',
            price = 110000,
            minLevel = 6,
            icon = '🛡️',
            effect = { vehicleArmorBonus = 0.25 },
        },
        vehicle_speed = {
            id = 'vehicle_speed',
            category = 'vehicle',
            name = 'Motor Tuning',
            desc = 'A futárjármű kicsit gyorsabb.',
            price = 150000,
            minLevel = 8,
            icon = '🏎️',
            effect = { vehicleSpeedBoost = true },
        },

        -- Expressz fejlesztések
        express_time = {
            id = 'express_time',
            category = 'express',
            name = 'Expressz Időbővítés',
            desc = '+30 másodperc extra idő expressz csomagoknál.',
            price = 75000,
            minLevel = 5,
            icon = '⏱️',
            effect = { expressExtraTime = 30 },
        },
    },

    -- Bolt ikon (interakciós rendszerben)
    interactionIcon = { icon = '🛒', tooltip = 'Futár Bolt', color = '#44ff44' },
}

-- ==========================================
-- SZEZONÁLIS ESEMÉNYEK
-- Automatikusan aktiválódnak dátum alapján
-- ==========================================
Config.SeasonalEvents = {
    enabled = true,

    events = {
        -- Karácsonyi esemény (Dec 15 - Jan 5)
        christmas = {
            name = '🎄 Karácsonyi Futár',
            startMonth = 12, startDay = 15,
            endMonth = 1, endDay = 5,
            bonuses = {
                payMultiplier = 1.25,          -- +25% fizetés
                skillMultiplier = 1.50,        -- +50% skill pont
                expressChance = 25,            -- Több expressz csomag
            },
            specialPackage = {
                enabled = true,
                name = 'Ajándék csomag',
                type = 'gift',
                prop = 'prop_cs_gift_01',      -- Ajándék prop
                basePay = 30000,
                chance = 20,                   -- 20% eséllyel generálódik
            },
        },

        -- Húsvéti esemény (Ápr 1 - Ápr 20)
        easter = {
            name = '🐣 Húsvéti Kézbesítés',
            startMonth = 4, startDay = 1,
            endMonth = 4, endDay = 20,
            bonuses = {
                payMultiplier = 1.15,
                skillMultiplier = 1.30,
            },
            specialPackage = {
                enabled = true,
                name = 'Húsvéti kosár',
                type = 'easter_basket',
                prop = 'prop_food_bag1',
                basePay = 18000,
                chance = 25,
            },
        },

        -- Dupla pont hétvége (minden szombat-vasárnap)
        weekend_boost = {
            name = '🔥 Hétvégi Boost',
            isWeekendOnly = true,             -- Csak szombat-vasárnap
            bonuses = {
                payMultiplier = 1.0,           -- Fizetés normál
                skillMultiplier = 2.0,         -- DUPLA skill pont!
            },
        },

        -- Nyári fesztivál (Jún 20 - Aug 31)
        summer = {
            name = '☀️ Nyári Fesztivál',
            startMonth = 6, startDay = 20,
            endMonth = 8, endDay = 31,
            bonuses = {
                payMultiplier = 1.10,
                skillMultiplier = 1.20,
                expressChance = 20,
            },
        },
    },
}

-- ==========================================
-- CSOMAG VIZUÁLIS MÉRET RENDSZER
-- Különböző prop-ok a csomag méretéhez
-- Nagyobb csomag = nagyobb prop + lassabb mozgás
-- ==========================================
Config.PackageVisuals = {
    -- Prop modellek: a Config.Props táblából random választódnak (lásd fent)
    -- Itt csak a méret-specifikus beállítások vannak

    -- Mozgás lassítás méret szerint (1.0 = normál sebesség)
    moveSpeedMultiplier = {
        ['level']  = 1.0,      -- Levél: normál sebesség
        ['small']  = 0.95,     -- S: alig lassabb
        ['medium'] = 0.85,     -- M: érezhetően lassabb
        ['large']  = 0.70,     -- L: jelentősen lassabb
    },

    -- Bepakolás idő szorzó (nagyobb csomag = lassabb bepakolás)
    loadTimeMultiplier = {
        ['level']  = 0.6,      -- Levél: gyors
        ['small']  = 1.0,      -- S: normál
        ['medium'] = 1.3,      -- M: lassabb
        ['large']  = 1.7,      -- L: sokkal lassabb
    },
}
