-- =============================================================
-- model/QTEManager.lua  — Versión 3.0
-- CAMBIOS v3.0:
--   [NEW] Obstáculo aparece en el ESPACIO CENTRAL entre Díaz y el inodoro
--         (no en el bowl ni sobre el inodoro)
--   [NEW] Obstáculo dibujado dentro de un círculo blanco con borde negro
--         para que resalte sobre cualquier fondo de muralla
--   [FIX] Tamaño del sprite del obstáculo: 28×28 px (más grande)
-- =============================================================

QTEManager = {}

-- ── Constantes de botones ────────────────────────────────────
local BTN_UP    = playdate.kButtonUp
local BTN_DOWN  = playdate.kButtonDown
local BTN_LEFT  = playdate.kButtonLeft
local BTN_RIGHT = playdate.kButtonRight
local BTN_A     = playdate.kButtonA

-- ── Definición de obstáculos ──────────────────────────────────
local OBSTACLE_DEFS <const> = {
    { name="caquita", img="obs_normal",  seq={BTN_UP, BTN_DOWN},                             penalty=8,  minLevel=1, baseTime=1.4 },
    { name="pelo",    img="obs_pelo",    seq={BTN_UP, BTN_RIGHT, BTN_DOWN, BTN_LEFT},         penalty=10, minLevel=2, baseTime=2.0 },
    { name="banana",  img="obs_banana",  seq={BTN_LEFT, BTN_RIGHT, BTN_LEFT, BTN_RIGHT},       penalty=12, minLevel=3, baseTime=2.2 },
    { name="carro",   img="obs_car_red", seq={BTN_UP, BTN_DOWN, BTN_LEFT, BTN_RIGHT, BTN_A},  penalty=18, minLevel=4, baseTime=2.8 },
}

-- ── Mapa de botón → nombre de imagen UI ──────────────────────
local BTN_IMAGE_NAMES = {
    [BTN_UP]    = "ui_arrow_up",
    [BTN_DOWN]  = "ui_arrow_down",
    [BTN_LEFT]  = "ui_arrow_left",
    [BTN_RIGHT] = "ui_arrow_right",
    [BTN_A]     = "ui_button_a",
}

local BTN_SYMBOLS = {
    [BTN_UP]    = "^",
    [BTN_DOWN]  = "v",
    [BTN_LEFT]  = "<",
    [BTN_RIGHT] = ">",
    [BTN_A]     = "A",
}

-- ── Estado interno ────────────────────────────────────────────
local active         = false
local currentObs     = nil
local seqIndex       = 1
local timeLimit      = 0
local timeElapsed    = 0
local spawnTimer     = 0
local spawnInterval  = 120
local lastWrongFlash = 0

-- ── Imágenes ─────────────────────────────────────────────────
local obsImages = {}
local btnImages = {}
local coinImg   = nil

-- ── Buffer anti-rebote ────────────────────────────────────────
local prevButtons = {}

local function loadImages()
    for _, def in ipairs(OBSTACLE_DEFS) do
        if not obsImages[def.img] then
            obsImages[def.img] = playdate.graphics.image.new("assets/images/" .. def.img)
        end
    end
    for btn, name in pairs(BTN_IMAGE_NAMES) do
        if not btnImages[btn] then
            btnImages[btn] = playdate.graphics.image.new("assets/images/" .. name)
        end
    end
    if not coinImg then
        coinImg = playdate.graphics.image.new("assets/images/coin")
    end
end

-- ── Input ─────────────────────────────────────────────────────
local function justPressed(btn)
    local now  = playdate.buttonIsPressed(btn)
    local prev = prevButtons[btn] or false
    prevButtons[btn] = now
    return now and not prev
end

local function updatePrevButtons()
    prevButtons[BTN_UP]    = playdate.buttonIsPressed(BTN_UP)
    prevButtons[BTN_DOWN]  = playdate.buttonIsPressed(BTN_DOWN)
    prevButtons[BTN_LEFT]  = playdate.buttonIsPressed(BTN_LEFT)
    prevButtons[BTN_RIGHT] = playdate.buttonIsPressed(BTN_RIGHT)
    prevButtons[BTN_A]     = playdate.buttonIsPressed(BTN_A)
end

-- ── Spawn ─────────────────────────────────────────────────────
local function spawnObstacle(level)
    local available = {}
    for _, def in ipairs(OBSTACLE_DEFS) do
        if def.minLevel <= level then
            table.insert(available, def)
        end
    end
    if #available == 0 then return end

    local pick       = available[math.random(#available)]
    local timeFactor = math.max(0.55, 1.0 - (level * 0.04))
    local timeFrames = math.floor(pick.baseTime * timeFactor * 30)

    currentObs  = pick
    seqIndex    = 1
    timeLimit   = timeFrames
    timeElapsed = 0
    active      = true
end

-- ── API pública ───────────────────────────────────────────────

function QTEManager.init(level)
    active        = false
    currentObs    = nil
    seqIndex      = 1
    timeLimit     = 0
    timeElapsed   = 0
    spawnTimer    = 0
    spawnInterval = math.max(50, 130 - level * 10)
    prevButtons   = {}
    lastWrongFlash = 0
    loadImages()
end

function QTEManager.isActive() return active end

function QTEManager.cancel()
    active     = false
    currentObs = nil
end

-- ── Actualización ─────────────────────────────────────────────
function QTEManager.update(level)
    if not active then
        spawnTimer += 1
        if spawnTimer >= spawnInterval then
            spawnTimer = 0
            spawnObstacle(level)
        end
        updatePrevButtons()
        return
    end

    timeElapsed += 1

    if timeElapsed >= timeLimit then
        Toilet.addPenalty(currentObs.penalty)
        ComboSystem.resetCombo()
        lastWrongFlash = playdate.getCurrentTimeMilliseconds()
        active         = false
        currentObs     = nil
        updatePrevButtons()
        return
    end

    local seq      = currentObs.seq
    local expected = seq[seqIndex]
    local pressed  = nil

    if justPressed(BTN_UP)    then pressed = BTN_UP    end
    if justPressed(BTN_DOWN)  then pressed = BTN_DOWN  end
    if justPressed(BTN_LEFT)  then pressed = BTN_LEFT  end
    if justPressed(BTN_RIGHT) then pressed = BTN_RIGHT end
    if justPressed(BTN_A)     then pressed = BTN_A     end

    if pressed ~= nil then
        if pressed == expected then
            seqIndex += 1
            if seqIndex > #seq then
                local timeRemaining = timeLimit - timeElapsed
                local speedBonus    = math.max(1.0, (timeRemaining / timeLimit) * 2.0)
                ScoreManager.addQTEScore(currentObs.penalty * 10, ComboSystem.getCombo(), speedBonus)
                ComboSystem.addCombo()
                active     = false
                currentObs = nil
            end
        else
            Toilet.addPenalty(currentObs.penalty)
            ComboSystem.resetCombo()
            lastWrongFlash = playdate.getCurrentTimeMilliseconds()
            active         = false
            currentObs     = nil
        end
    end

    updatePrevButtons()
end

-- ─────────────────────────────────────────────────────────────
-- ── DIBUJO DEL QTE — Versión 3.0 ─────────────────────────────
-- ─────────────────────────────────────────────────────────────
function QTEManager.draw()
    local gfx = playdate.graphics
    local ms  = playdate.getCurrentTimeMilliseconds()

    -- ── Flash de fallo ────────────────────────────────────────
    if ms - lastWrongFlash < 200 then
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(0, Layout.QTE_PANEL_Y - 4, 400, Layout.QTE_PANEL_H + 8)
        gfx.setColor(gfx.kColorWhite)
        gfx.drawTextAligned("✗ FALLO", 200, Layout.QTE_PANEL_Y + 12, kTextAlignment.center)
        return
    end

    if not active or currentObs == nil then return end

    -- ── [NEW] Obstáculo en el espacio central entre Díaz y el inodoro ──
    -- Díaz termina aprox en X = Layout.PLAYER_X + 120 = 150
    -- Inodoro empieza en X = Layout.TOILET_X = 225
    -- Centro del espacio: X = (150 + 225) / 2 = 187, Y central de la escena ≈ 120
    --
    -- El obstáculo flota verticalmente con math.sin en ese punto central,
    -- NO en el bowl del inodoro.
    local obsImg = obsImages[currentObs.img]
    if obsImg then
        -- [NEW] Usa Layout.OBS_CENTER_X/Y: espacio central entre Díaz y el inodoro
        local midX     = Layout.OBS_CENTER_X
        local midY     = Layout.OBS_CENTER_Y
        local OBS_SIZE = 36   -- tamaño del sprite (ahora 36×36 px)
        local CIRCLE_R = 22   -- radio del círculo de fondo

        -- Animación flotante vertical (suave con sin)
        local floatY = midY + math.floor(math.sin(ms / 400) * 8)
        local obsX   = midX - math.floor(OBS_SIZE / 2)
        local obsY   = floatY - math.floor(OBS_SIZE / 2)

        -- [NEW] Círculo blanco de fondo (el obstáculo NO tiene fondo cuadrado)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillCircleAtPoint(midX, floatY, CIRCLE_R)
        -- Borde negro doble = apariencia "gordita"
        gfx.setColor(gfx.kColorBlack)
        gfx.drawCircleAtPoint(midX, floatY, CIRCLE_R)
        gfx.drawCircleAtPoint(midX, floatY, CIRCLE_R - 1)

        -- Sprite del obstáculo centrado dentro del círculo
        obsImg:draw(obsX, obsY)
    end

    -- ── Barra de tiempo (encima del panel QTE inferior) ───────
    local timerFrac  = 1.0 - (timeElapsed / timeLimit)
    local barFullW   = Layout.QTE_PANEL_W
    local barFilledW = math.floor(barFullW * timerFrac)
    local barX       = Layout.QTE_PANEL_X
    local barY       = Layout.QTE_TIMER_Y

    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(barX, barY, barFullW, 4)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(barX + barFilledW, barY, barFullW - barFilledW, 4)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(barX, barY, barFullW, 4)

    -- ── Panel globo de botones ────────────────────────────────
    local px = Layout.QTE_PANEL_X
    local py = Layout.QTE_PANEL_Y
    local pw = Layout.QTE_PANEL_W
    local ph = Layout.QTE_PANEL_H

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(px, py, pw, ph, 6)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRoundRect(px, py, pw, ph, 6)

    -- Nombre del obstáculo
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText(string.upper(currentObs.name), px + 6, py + 13)

    -- ── Iconos de botón en la secuencia ──────────────────────
    local seq    = currentObs.seq
    local ICON_W = 26
    local ICON_H = 24
    local totalW = #seq * ICON_W
    local startX = px + pw - totalW - 8
    local iconY  = py + math.floor((ph - ICON_H) / 2)

    for i, btn in ipairs(seq) do
        local ix = startX + (i - 1) * ICON_W

        if i < seqIndex then
            -- Completado
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRoundRect(ix, iconY, ICON_H, ICON_H, 4)
            gfx.setColor(gfx.kColorWhite)
            gfx.drawTextAligned("OK", ix + 12, iconY + 6, kTextAlignment.center)

        elseif i == seqIndex then
            -- Actual: parpadeo
            local blink = (math.floor(ms / 133) % 2) == 0
            local img   = btnImages[btn]

            if blink then
                gfx.setColor(gfx.kColorBlack)
                gfx.fillRoundRect(ix - 1, iconY - 1, ICON_H + 2, ICON_H + 2, 4)
                if img then
                    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
                    img:draw(ix, iconY)
                    gfx.setImageDrawMode(gfx.kDrawModeCopy)
                else
                    gfx.setColor(gfx.kColorWhite)
                    gfx.drawTextAligned(BTN_SYMBOLS[btn] or "?", ix + 12, iconY + 6, kTextAlignment.center)
                end
            else
                gfx.setColor(gfx.kColorBlack)
                gfx.drawRoundRect(ix - 2, iconY - 2, ICON_H + 4, ICON_H + 4, 5)
                gfx.setColor(gfx.kColorWhite)
                gfx.fillRoundRect(ix, iconY, ICON_H, ICON_H, 3)
                if img then
                    img:draw(ix, iconY)
                else
                    gfx.setColor(gfx.kColorBlack)
                    gfx.drawTextAligned(BTN_SYMBOLS[btn] or "?", ix + 12, iconY + 6, kTextAlignment.center)
                end
            end

        else
            -- Pendiente
            gfx.setColor(gfx.kColorBlack)
            gfx.drawRoundRect(ix, iconY, ICON_H, ICON_H, 3)
            local img = btnImages[btn]
            if img then
                gfx.setImageDrawMode(gfx.kDrawModeNXOR)
                img:draw(ix, iconY)
                gfx.setImageDrawMode(gfx.kDrawModeCopy)
            else
                gfx.drawTextAligned(BTN_SYMBOLS[btn] or "?", ix + 12, iconY + 6, kTextAlignment.center)
            end
        end
    end
end
