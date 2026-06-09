// ==========================================
// SEERPG FUTÁR - NUI JAVASCRIPT
// Kattintható ikon interakciós rendszer
// ==========================================

// Globális változók
let overlayElement = null;
let activeIcons = [];          // Aktuálisan megjelenített ikonok
let isCursorActive = false;    // Kurzor mód aktív-e

// DOM elemek cache
const interactionLayer = document.getElementById('interaction-layer');
const altHint = document.getElementById('alt-hint');

// ==========================================
// NUI MESSAGE LISTENER
// ==========================================
window.addEventListener('message', function(event) {
    const data = event.data;

    switch(data.action) {
        // Panelek
        case 'showSkillPanel':
            showSkillPanel(data.data);
            break;
        case 'showRoundComplete':
            showRoundComplete(data.data);
            break;
        case 'showVehicleSelector':
            showVehicleSelector(data.data);
            break;
        case 'showJobSelector':
            showJobSelector(data.data);
            break;
        case 'updateHUD':
            updateHUD(data.data);
            break;
        case 'hideAll':
            hideAll();
            break;

        // Törékeny és Expressz
        case 'updateFragileIndicator':
            updateFragileIndicator(data.data);
            break;
        case 'updateExpressTimer':
            updateExpressTimer(data.data);
            break;

        // Bolt
        case 'showShopPanel':
            showShopPanel(data.data);
            break;

        // Interakciós ikon rendszer
        case 'showInteractionIcons':
            showInteractionIcons(data.data);
            break;
        case 'hideInteractionIcons':
            hideInteractionIcons();
            break;
        case 'updateIconPositions':
            updateIconPositions(data.data);
            break;
        case 'showAltHint':
            showAltHint();
            break;
        case 'hideAltHint':
            hideAltHint();
            break;
        case 'setCursorActive':
            setCursorActive(data.data.active);
            break;
    }
});

// ==========================================
// INTERAKCIÓS IKON RENDSZER
// ==========================================

/**
 * Ikonok megjelenítése
 * @param {Object} data - { icons: [{id, type, icon, tooltip, color, screenX, screenY}] }
 */
function showInteractionIcons(data) {
    // Előző ikonok törlése
    clearIcons();

    if (!data.icons || data.icons.length === 0) return;

    activeIcons = data.icons;

    // Minden ikonhoz DOM elem létrehozása
    for (const iconData of data.icons) {
        createIconElement(iconData);
    }

    interactionLayer.classList.remove('hidden');
}

/**
 * Ikonok elrejtése
 */
function hideInteractionIcons() {
    clearIcons();
    interactionLayer.classList.add('hidden');
    interactionLayer.classList.remove('active');
}

/**
 * Ikon pozíciók frissítése (frame-enként hívódik Lua-ból)
 * @param {Object} data - { icons: [{id, screenX, screenY, visible}] }
 */
function updateIconPositions(data) {
    if (!data.icons) return;

    for (const update of data.icons) {
        const el = document.getElementById('icon-' + update.id);
        if (!el) continue;

        if (!update.visible) {
            el.style.display = 'none';
            continue;
        }

        el.style.display = 'flex';
        el.style.left = (update.screenX * 100) + '%';
        el.style.top = (update.screenY * 100) + '%';

        // Távolság alapú méretezés (opcionális, közelebb = nagyobb)
        if (update.scale) {
            el.style.transform = `translate(-50%, -50%) scale(${update.scale})`;
        }
    }
}

/**
 * Kurzor aktiválás/deaktiválás
 */
function setCursorActive(active) {
    isCursorActive = active;
    if (active) {
        interactionLayer.classList.add('active');
    } else {
        interactionLayer.classList.remove('active');
    }
}

/**
 * Egyedi ikon DOM elem létrehozása
 */
function createIconElement(iconData) {
    const wrapper = document.createElement('div');
    wrapper.className = 'interact-icon';
    wrapper.id = 'icon-' + iconData.id;
    wrapper.style.left = (iconData.screenX * 100) + '%';
    wrapper.style.top = (iconData.screenY * 100) + '%';
    wrapper.style.setProperty('--icon-color', iconData.color || '#44aaff');
    wrapper.style.setProperty('--icon-glow', hexToGlow(iconData.color || '#44aaff'));

    // Pulzáló gyűrű
    const pulse = document.createElement('div');
    pulse.className = 'interact-icon-pulse';
    pulse.style.borderColor = iconData.color || '#44aaff';

    // Ikon kör
    const circle = document.createElement('div');
    circle.className = 'interact-icon-circle';
    circle.textContent = iconData.icon || '❓';

    // Tooltip
    const tooltip = document.createElement('div');
    tooltip.className = 'interact-icon-tooltip';
    tooltip.textContent = iconData.tooltip || '';

    // Összeállítás
    wrapper.appendChild(pulse);
    wrapper.appendChild(circle);
    wrapper.appendChild(tooltip);

    // Kattintás kezelés
    wrapper.addEventListener('click', function(e) {
        e.stopPropagation();
        onIconClicked(iconData.id, iconData.type);
    });

    interactionLayer.appendChild(wrapper);
}

/**
 * Ikon kattintás kezelés - NUI callback küldése Lua felé
 */
function onIconClicked(iconId, iconType) {
    // Vizuális feedback - rövid scale animáció
    const el = document.getElementById('icon-' + iconId);
    if (el) {
        el.style.transform = 'translate(-50%, -50%) scale(0.8)';
        setTimeout(() => {
            el.style.transform = 'translate(-50%, -50%) scale(1)';
        }, 150);
    }

    // Lua callback
    postNUI('iconClicked', {
        id: iconId,
        type: iconType
    });
}

/**
 * Összes ikon törlése
 */
function clearIcons() {
    interactionLayer.innerHTML = '';
    activeIcons = [];
}

// ==========================================
// ALT HINT KEZELÉS
// ==========================================
function showAltHint() {
    altHint.classList.remove('hidden');
}

function hideAltHint() {
    altHint.classList.add('hidden');
}

// ==========================================
// BILLENTYŰ KEZELÉS
// ==========================================
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        hideAll();
        postNUI('closeUI', {});
    }
});

// Close gombok
document.getElementById('round-close-btn').addEventListener('click', function() {
    hideAll();
    postNUI('closeUI', {});
});

document.getElementById('skill-close-btn').addEventListener('click', function() {
    hideAll();
    postNUI('closeUI', {});
});

document.getElementById('vehicle-close-btn').addEventListener('click', function() {
    hideAll();
    postNUI('closeUI', {});
});

document.getElementById('shop-close-btn').addEventListener('click', function() {
    hideAll();
    postNUI('closeShop', {});
});

// ==========================================
// SKILL PANEL
// ==========================================
function showSkillPanel(data) {
    hideAll();
    showOverlay();

    const panel = document.getElementById('skill-panel');
    const jobLabel = document.getElementById('skill-job-label');
    const starsContainer = document.getElementById('stars-container');
    const currentPoints = document.getElementById('current-points');
    const nextLevelPoints = document.getElementById('next-level-points');
    const rankEl = document.getElementById('skill-rank');

    jobLabel.textContent = data.jobLabel || 'Futár';

    // Rang megjelenítés
    if (data.rankName) {
        rankEl.textContent = data.rankName;
        rankEl.style.color = data.rankColor || '#ffffff';
    } else {
        rankEl.textContent = '';
    }

    // Csillagok
    starsContainer.innerHTML = '';
    const maxStars = data.maxStars || 12;
    const currentLevel = data.skillLevel || 1;

    for (let i = 1; i <= maxStars; i++) {
        const star = document.createElement('span');
        star.className = 'star ' + (i <= currentLevel ? 'filled' : 'empty');
        star.textContent = '★';
        starsContainer.appendChild(star);
    }

    currentPoints.textContent = formatNumber(data.skillPoints || 0);
    nextLevelPoints.textContent = formatNumber(data.nextLevelPoints || 0);

    panel.classList.remove('hidden');

    setTimeout(function() {
        if (!panel.classList.contains('hidden')) {
            hideAll();
            postNUI('closeUI', {});
        }
    }, 6000);
}

// ==========================================
// KÖR TELJESÍTVE PANEL
// ==========================================
function showRoundComplete(data) {
    hideAll();
    showOverlay();

    const panel = document.getElementById('round-panel');

    // Időbónusz megjelenítés
    const timeBonusHeader = document.getElementById('round-time-bonus');
    if (data.timeBonusLabel && data.timeBonus > 0) {
        timeBonusHeader.textContent = data.timeBonusLabel + ' (x' + data.timeBonusMultiplier + ')';
        timeBonusHeader.style.display = 'block';
    } else {
        timeBonusHeader.textContent = '';
        timeBonusHeader.style.display = 'none';
    }

    // Időbónusz sor
    const timeBonusRow = document.getElementById('time-bonus-row');
    const timeBonusValue = document.getElementById('time-bonus-value');
    if (data.timeBonus > 0) {
        timeBonusRow.style.display = 'flex';
        timeBonusValue.textContent = '+' + formatNumber(data.timeBonus) + ' Ft';
    } else {
        timeBonusRow.style.display = 'none';
    }

    document.getElementById('skill-bonus').textContent = formatNumber(data.skillBonus || 0) + ' Ft';
    document.getElementById('club-bonus').textContent = formatNumber(data.clubBonus || 0) + ' Ft';

    const boostValue = data.payBoost || 1.0;
    const basePay = data.boostedPay || 0;
    const totalPay = data.totalPay || 0;
    const skillMult = data.skillMultiplier || 1.0;

    document.getElementById('pay-boost').textContent = boostValue + 'x';
    document.getElementById('boosted-pay').textContent = formatNumber(basePay) + ' Ft (' + formatNumber(totalPay) + ' Ft)';
    document.getElementById('earned-skill').textContent = formatNumber(data.earnedSkillPoints || 0) + ' pont';

    // Skill bónusz sorban a szorzó is megjelenik
    const skillBonusEl = document.getElementById('skill-bonus');
    if (skillMult > 1.0) {
        skillBonusEl.textContent = formatNumber(data.skillBonus || 0) + ' Ft (' + skillMult + 'x)';
    } else {
        skillBonusEl.textContent = formatNumber(data.skillBonus || 0) + ' Ft';
    }

    // Törékeny büntetés sor
    const fragileRow = document.getElementById('fragile-penalty-row');
    if (fragileRow) {
        if (data.fragilePenalty && data.fragilePenalty > 0) {
            fragileRow.style.display = 'flex';
            document.getElementById('fragile-penalty-value').textContent = '-' + formatNumber(data.fragilePenalty) + ' Ft';
        } else {
            fragileRow.style.display = 'none';
        }
    }

    // Expressz bónusz sor
    const expressRow = document.getElementById('express-bonus-row');
    if (expressRow) {
        if (data.expressBonus && data.expressBonus !== 0) {
            expressRow.style.display = 'flex';
            const expressVal = document.getElementById('express-bonus-value');
            if (data.expressBonus > 0) {
                expressVal.textContent = '+' + formatNumber(data.expressBonus) + ' Ft';
                expressVal.className = 'detail-value green';
            } else {
                expressVal.textContent = formatNumber(data.expressBonus) + ' Ft';
                expressVal.className = 'detail-value red';
            }
        } else {
            expressRow.style.display = 'none';
        }
    }

    // Szezonális esemény sor
    const seasonalRow = document.getElementById('seasonal-bonus-row');
    if (seasonalRow) {
        if (data.seasonalEvent && data.seasonalBonus > 0) {
            seasonalRow.style.display = 'flex';
            document.getElementById('seasonal-bonus-value').textContent = '+' + formatNumber(data.seasonalBonus) + ' Ft (' + data.seasonalEvent.name + ')';
        } else {
            seasonalRow.style.display = 'none';
        }
    }

    // Leszállított küldemények
    const deliveriesList = document.getElementById('deliveries-list');
    deliveriesList.innerHTML = '';
    const counts = data.deliveryCounts || {};

    const deliveryLabels = {
        'small': 'Csomag (S)',
        'level': 'Levél',
        'medium': 'Csomag (M)',
        'large': 'Csomag (L)'
    };

    const displayOrder = ['small', 'level', 'medium', 'large'];

    for (const type of displayOrder) {
        const count = counts[type] || 0;
        if (count > 0) {
            const li = document.createElement('li');
            li.innerHTML = deliveryLabels[type] + ': <span>' + count + ' db</span>';
            deliveriesList.appendChild(li);
        }
    }

    panel.classList.remove('hidden');
}

// ==========================================
// JOB HUD
// ==========================================
function updateHUD(data) {
    const hud = document.getElementById('job-hud');

    if (!data.show) {
        hud.classList.add('hidden');
        return;
    }

    hud.classList.remove('hidden');

    const timeEl = document.getElementById('hud-time');
    const timeRemaining = data.timeRemaining || 0;
    timeEl.textContent = formatTime(timeRemaining);

    timeEl.classList.remove('hud-time-warning', 'hud-time-critical');
    if (timeRemaining <= 60) {
        timeEl.classList.add('hud-time-critical');
    } else if (timeRemaining <= 180) {
        timeEl.classList.add('hud-time-warning');
    }

    const deliveriesEl = document.getElementById('hud-deliveries');
    deliveriesEl.textContent = (data.deliveriesCompleted || 0) + '/' + (data.deliveriesTotal || 0);

    const currentEl = document.getElementById('hud-current');
    if (data.currentDeliveryLabel) {
        const typeLabels = { 'level': '✉️', 'small': '📦', 'medium': '📦', 'large': '📦' };
        const icon = typeLabels[data.currentDeliveryType] || '📦';
        currentEl.textContent = icon + ' ' + data.currentDeliveryLabel;
    } else {
        currentEl.textContent = '✅ Mind kézbesítve!';
    }

    const progressEl = document.getElementById('hud-progress');
    const total = data.deliveriesTotal || 0;
    const completed = data.deliveriesCompleted || 0;
    const percent = total > 0 ? (completed / total) * 100 : 0;
    progressEl.style.width = percent + '%';

    if (percent >= 100) {
        progressEl.style.background = 'linear-gradient(90deg, #4cff4c, #00ff88)';
    } else if (percent >= 60) {
        progressEl.style.background = 'linear-gradient(90deg, #4cff4c, #00cc44)';
    } else {
        progressEl.style.background = 'linear-gradient(90deg, #44aaff, #0088ff)';
    }
}

// ==========================================
// OVERLAY KEZELÉS
// ==========================================
function showOverlay() {
    removeOverlay();
    overlayElement = document.createElement('div');
    overlayElement.className = 'overlay';
    overlayElement.addEventListener('click', function() {
        hideAll();
        postNUI('closeUI', {});
    });
    document.body.appendChild(overlayElement);
}

function removeOverlay() {
    if (overlayElement) {
        overlayElement.remove();
        overlayElement = null;
    }
}

// ==========================================
// SEGÉD FUNKCIÓK
// ==========================================
function hideAll() {
    document.getElementById('skill-panel').classList.add('hidden');
    document.getElementById('round-panel').classList.add('hidden');
    document.getElementById('vehicle-panel').classList.add('hidden');
    document.getElementById('shop-panel').classList.add('hidden');
    document.getElementById('job-select-panel').classList.add('hidden');
    removeOverlay();
}

function formatNumber(num) {
    return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
}

function formatTime(seconds) {
    if (seconds < 0) seconds = 0;
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return String(mins).padStart(2, '0') + ':' + String(secs).padStart(2, '0');
}

function postNUI(event, data) {
    fetch('https://' + GetParentResourceName() + '/' + event, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {})
    });
}

/**
 * Hex szín -> rgba glow konvertálás
 */
function hexToGlow(hex) {
    const r = parseInt(hex.slice(1, 3), 16);
    const g = parseInt(hex.slice(3, 5), 16);
    const b = parseInt(hex.slice(5, 7), 16);
    return `rgba(${r}, ${g}, ${b}, 0.4)`;
}

// ==========================================
// JÁRMŰ VÁLASZTÓ PANEL
// ==========================================
function showVehicleSelector(data) {
    hideAll();
    showOverlay();

    const panel = document.getElementById('vehicle-panel');
    const list = document.getElementById('vehicle-list');
    list.innerHTML = '';

    const vehicles = data.vehicles || [];
    const currentLevel = data.skillLevel || 1;

    const vehicleIcons = ['🚐', '🚙', '🚗', '🏎️'];

    vehicles.forEach(function(vehicle, index) {
        const isLocked = currentLevel < vehicle.minLevel;
        const card = document.createElement('div');
        card.className = 'vehicle-card' + (isLocked ? ' locked' : '');

        card.innerHTML = `
            <div class="vehicle-card-icon">${vehicleIcons[index] || '🚐'}</div>
            <div class="vehicle-card-info">
                <div class="vehicle-card-name">${vehicle.label}</div>
                <div class="vehicle-card-desc">${vehicle.desc || ''}</div>
                <div class="vehicle-card-stats">
                    <span class="vehicle-stat">⚡ ${vehicle.speed || '-'}</span>
                    <span class="vehicle-stat">📦 ${vehicle.capacity || '-'}</span>
                </div>
            </div>
            ${isLocked ? '<div class="vehicle-card-lock">🔒 ' + vehicle.minLevel + '★</div>' : ''}
        `;

        if (!isLocked) {
            card.addEventListener('click', function() {
                // Kiválasztás vizuális
                list.querySelectorAll('.vehicle-card').forEach(c => c.classList.remove('selected'));
                card.classList.add('selected');

                // Küldés Lua-nak
                postNUI('vehicleSelected', { index: index + 1, model: vehicle.model });

                setTimeout(function() {
                    hideAll();
                    postNUI('closeUI', {});
                }, 500);
            });
        }

        list.appendChild(card);
    });

    panel.classList.remove('hidden');
}



// ==========================================
// TÖRÉKENY CSOMAG INDIKÁTOR
// ==========================================
function updateFragileIndicator(data) {
    const el = document.getElementById('fragile-indicator');
    if (!data.show || !data.isFragile) {
        el.classList.add('hidden');
        return;
    }
    el.classList.remove('hidden');
    const bar = document.getElementById('fragile-bar');
    const percent = document.getElementById('fragile-percent');
    const damage = Math.min(data.damage || 0, 100);
    bar.style.height = damage + '%';
    percent.textContent = Math.floor(damage) + '%';
    // Color based on damage
    if (damage >= 70) {
        bar.style.background = '#ff4444';
    } else if (damage >= 40) {
        bar.style.background = '#ffaa00';
    } else {
        bar.style.background = '#4cff4c';
    }
}

// ==========================================
// EXPRESSZ TIMER
// ==========================================
function updateExpressTimer(data) {
    const el = document.getElementById('express-timer');
    if (!data.active) {
        el.classList.add('hidden');
        return;
    }
    el.classList.remove('hidden');
    const timeEl = document.getElementById('express-time');
    timeEl.textContent = formatTime(data.timeRemaining || 0);
    if (data.timerColor === 'critical') {
        timeEl.style.color = '#ff4444';
    } else if (data.timerColor === 'warning') {
        timeEl.style.color = '#ffaa00';
    } else {
        timeEl.style.color = '#4cff4c';
    }
}

// ==========================================
// FUTÁR BOLT PANEL
// ==========================================
function showShopPanel(data) {
    hideAll();
    showOverlay();

    const panel = document.getElementById('shop-panel');
    const list = document.getElementById('shop-list');
    const moneyEl = document.getElementById('shop-money');

    list.innerHTML = '';
    moneyEl.textContent = 'Egyenleg: ' + formatNumber(data.playerMoney || 0) + ' Ft';

    const upgrades = data.upgrades || {};
    const purchased = data.purchased || {};
    const skillLevel = data.skillLevel || 1;

    // Kategória rendezés
    const categories = {};
    for (const [id, upgrade] of Object.entries(upgrades)) {
        const cat = upgrade.category || 'other';
        if (!categories[cat]) categories[cat] = [];
        categories[cat].push({ ...upgrade, id: id });
    }

    for (const [catName, items] of Object.entries(categories)) {
        const catDiv = document.createElement('div');
        catDiv.className = 'shop-category';

        items.forEach(function(upgrade) {
            const isOwned = purchased[upgrade.id] === true;
            const isLocked = skillLevel < upgrade.minLevel;
            const requiresMissing = upgrade.requires && !purchased[upgrade.requires];

            const card = document.createElement('div');
            card.className = 'shop-item' + (isOwned ? ' owned' : '') + (isLocked ? ' locked' : '') + (requiresMissing ? ' requires-missing' : '');

            let statusText = '';
            if (isOwned) {
                statusText = '<span class="shop-item-status owned">✅ Megvásárolva</span>';
            } else if (isLocked) {
                statusText = '<span class="shop-item-status locked">🔒 ' + upgrade.minLevel + '★ szint kell</span>';
            } else if (requiresMissing) {
                statusText = '<span class="shop-item-status locked">⚠️ Előfeltétel szükséges</span>';
            } else {
                statusText = '<span class="shop-item-status available">' + formatNumber(upgrade.price) + ' Ft</span>';
            }

            card.innerHTML = `
                <div class="shop-item-icon">${upgrade.icon || '📦'}</div>
                <div class="shop-item-info">
                    <div class="shop-item-name">${upgrade.name}</div>
                    <div class="shop-item-desc">${upgrade.desc || ''}</div>
                </div>
                ${statusText}
            `;

            if (!isOwned && !isLocked && !requiresMissing) {
                card.addEventListener('click', function() {
                    postNUI('buyUpgrade', { upgradeId: upgrade.id });
                    card.classList.add('owned');
                    card.querySelector('.shop-item-status').innerHTML = '⏳ Feldolgozás...';
                });
            }

            catDiv.appendChild(card);
        });

        list.appendChild(catDiv);
    }

    panel.classList.remove('hidden');
}



// ==========================================
// MUNKAVÁLASZTÓ PANEL (csak csomagpont választás)
// ==========================================
let jobSelectState = {
    selectedLocker: null,
    lockers: [],
    basePay: 10500
};

function showJobSelector(data) {
    hideAll();
    showOverlay();

    const panel = document.getElementById('job-select-panel');
    const lockerList = document.getElementById('job-select-lockers');

    jobSelectState.lockers = data.lockers || [];
    jobSelectState.selectedLocker = null;
    jobSelectState.basePay = data.basePay || 10500;

    // Locker opciók generálása
    lockerList.innerHTML = '';
    jobSelectState.lockers.forEach(function(locker) {
        const div = document.createElement('div');
        div.className = 'locker-option';
        div.dataset.lockerId = locker.id;

        const distLabel = locker.distanceCategory || 'near';
        const distLabels = { near: 'Közeli', medium: 'Közepes', far: 'Távoli', veryFar: 'N. távoli' };
        const distMultLabels = { near: 'x1.0', medium: 'x1.25', far: 'x1.55', veryFar: 'x1.9' };

        div.innerHTML = `
            <span class="locker-option-name">${locker.label}</span>
            <span class="locker-option-dist ${distLabel}">${distLabels[distLabel] || distLabel} ${distMultLabels[distLabel] || ''}</span>
        `;

        div.addEventListener('click', function() {
            lockerList.querySelectorAll('.locker-option').forEach(el => el.classList.remove('selected'));
            div.classList.add('selected');
            jobSelectState.selectedLocker = locker;
            updateJobEstimate();
        });

        lockerList.appendChild(div);
    });

    // Indítás gomb
    document.getElementById('job-select-start').onclick = function() {
        if (!jobSelectState.selectedLocker) {
            lockerList.style.border = '2px solid #ff4444';
            setTimeout(() => { lockerList.style.border = 'none'; }, 1500);
            return;
        }

        postNUI('jobOrderSelected', {
            lockerId: jobSelectState.selectedLocker.id
        });

        hideAll();
        postNUI('closeUI', {});
    };

    // Close gomb
    document.getElementById('job-select-close-btn').onclick = function() {
        hideAll();
        postNUI('closeUI', {});
    };

    document.getElementById('job-estimate-pay').textContent = 'Válassz csomagpontot';
    panel.classList.remove('hidden');
}

function updateJobEstimate() {
    const el = document.getElementById('job-estimate-pay');

    if (jobSelectState.selectedLocker) {
        const distMult = jobSelectState.selectedLocker.distanceMultiplier || 1.0;
        const estimate = Math.floor(jobSelectState.basePay * 3 * distMult);
        el.textContent = '~ ' + formatNumber(estimate) + ' Ft';
    } else {
        el.textContent = 'Válassz csomagpontot';
    }
}
