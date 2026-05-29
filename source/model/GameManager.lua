-- =============================================================
-- model/GameManager.lua
-- Máquina de estados global — Versión 3.0
-- Cambios: fix math.random, 3 fondos por nivel, título animado,
--          panel level clear estilizado, obstáculos sobre inodoro
-- =============================================================

GameManager = {}

-- ── Estados ──────────────────────────────────────────────────
local STATE_TITLE      <const> = 1
local STATE_GAMEPLAY   <const> = 2
local STATE_LEVELCLEAR <const> = 3
local STATE_GAMEOVER   <const> = 4

-- Sub-estados de gameplay
local SUB_RUNNING    <const> = 1
local SUB_CALISTENIA <const> = 2
local SUB_PANIC      <const> = 3

-- ── Variables de estado ───────────────────────────────────────
local state    = STATE_TITLE
local subState = SUB_RUNNING
local level    = 1

local panicTimer      = 0
local levelClearTimer = 0
local titleFrame      = 0
local gameoverFrame   = 0

-- Animación de flush
local flushTable = nil
local flushFrame = 1
local flushTimer = 0
local FLUSH_FRAMES    <const> = 5
local FLUSH_FRAME_DUR <const> = 6

-- ── Screen Shake ─────────────────────────────────────────────
local shakeIntensity = 0
local shakeDuration  = 0

local function triggerShake(intensity, duration)
    if intensity > shakeIntensity then
        shakeIntensity = intensity
        shakeDuration  = duration
    end
end

local function updateShake()
    if shakeDuration > 0 then
        shakeDuration -= 1
        -- BUGFIX: math.floor garantiza enteros para math.random
        local iInt = math.floor(shakeIntensity)
        if iInt < 1 then iInt = 1 end
        local ox = math.random(-iInt, iInt)
        local oy = math.random(-iInt, iInt)
        playdate.display.setOffset(ox, oy)
        shakeIntensity = shakeIntensity * 0.85
        if shakeDuration <= 0 then
            playdate.display.setOffset(0, 0)
            shakeIntensity = 0
        end
    end
end

-- ── Imágenes y fuentes ────────────────────────────────────────
local bgImgs   = {}   -- tabla de 3 fondos: bgImgs[1], [2], [3]
local bgImg    = nil  -- fondo activo (apunta a bgImgs[...])

-- Sprites del título
local titleDiazImgs   = {}   -- idle, calistenia, work1
local titleDiazFrame  = 1
local titleDiazTimer  = 0
local TITLE_DIAZ_DUR  <const> = 40  -- frames por pose

-- Obstáculos flotantes del título
local titleObs = {}
local obsImagesTitle = {}

-- Fuente personalizada
local titleFont = nil

local function loadAssets()
    -- Flush animation
    if not flushTable then
        flushTable = playdate.graphics.imagetable.new("assets/images/flush")
    end

    -- 3 fondos de baño
    for i = 1, 3 do
        if not bgImgs[i] then
            -- Intenta cargar bg_bathroom_1, _2, _3; si no existe usa el base
            local img = playdate.graphics.image.new("assets/images/bg_bathroom_" .. i)
            if not img then
                img = playdate.graphics.image.new("assets/images/bg_bathroom")
            end
            bgImgs[i] = img
        end
    end

    -- Sprites del personaje para el título
    if #titleDiazImgs == 0 then
        titleDiazImgs[1] = playdate.graphics.image.new("assets/images/diaz_idle")
        titleDiazImgs[2] = playdate.graphics.image.new("assets/images/diaz_calistenia")
        titleDiazImgs[3] = playdate.graphics.imagetable.new("assets/images/diaz_work")
    end

    -- Sprites de obstáculos para el título
    local obsNames = { "obs_normal", "obs_pelo", "obs_banana", "obs_car_red" }
    if #obsImagesTitle == 0 then
        for _, name in ipairs(obsNames) do
            local img = playdate.graphics.image.new("assets/images/" .. name)
            if img then
                table.insert(obsImagesTitle, img)
            end
        end
    end

    -- Fuente personalizada (Roobert si existe, si no usa la del sistema)
    if not titleFont then
        titleFont = playdate.graphics.font.new("assets/fonts/font-Roobert-24-Bold")
        -- Si no existe, setFont falla silenciosamente y se usa la de sistema
    end
end

-- ── Seleccionar fondo según nivel ────────────────────────────
local function getBgForLevel(lvl)
    local idx = ((lvl - 1) % 3) + 1
    return bgImgs[idx] or bgImgs[1]
end

-- ── Obstáculos flotantes del título ──────────────────────────
local function initTitleObs()
    titleObs = {}
    local count = 5
    for i = 1, count do
        table.insert(titleObs, {
            x     = math.random(0, 380),
            y     = math.random(50, 200),
            phase = math.random(0, 628) / 100.0,   -- fase inicial aleatoria
            speed = 0.4 + math.random() * 0.4,      -- velocidad horizontal
            amp   = 10 + math.random() * 12,         -- amplitud vertical
            img   = obsImagesTitle[math.random(#obsImagesTitle)] or nil,
        })
    end
end

local function updateTitleObs(ms)
    local t = ms / 1000.0
    for _, o in ipairs(titleObs) do
        o.x = o.x + o.speed
        if o.x > 420 then o.x = -30 end
        -- Movimiento vertical suave con sin
        o.drawY = o.y + math.floor(math.sin(t * 1.5 + o.phase) * o.amp)
    end
end

local function drawTitleObs(gfx)
    for _, o in ipairs(titleObs) do
        if o.img then
            o.img:draw(math.floor(o.x), math.floor(o.drawY or o.y))
        end
    end
end

-- ── Funciones internas ────────────────────────────────────────
local function resetForLevel(lvl)
    subState   = SUB_RUNNING
    panicTimer = 0
    bgImg      = getBgForLevel(lvl)
    Player.init()
    Toilet.init(lvl)
    QTEManager.init(lvl)
    ComboSystem.init()
end

-- ── API pública ───────────────────────────────────────────────

function GameManager.init()
    level      = 1
    state      = STATE_TITLE
    titleFrame = 0
    loadAssets()
    bgImg = getBgForLevel(1)
    ComboSystem.init()
    ScoreManager.init()
    Player.init()
    Toilet.init(level)
    QTEManager.init(level)
    HUD.init()
    initTitleObs()
end

function GameManager.getLevel()    return level    end
function GameManager.getState()    return state    end
function GameManager.getSubState() return subState end

-- ── Bucle principal ───────────────────────────────────────────
function GameManager.update()
    if     state == STATE_TITLE      then GameManager._updateTitle()
    elseif state == STATE_GAMEPLAY   then GameManager._updateGameplay()
    elseif state == STATE_LEVELCLEAR then GameManager._updateLevelClear()
    elseif state == STATE_GAMEOVER   then GameManager._updateGameOver()
    end

    -- HUD encima de todo durante gameplay
    HUD.draw(state, subState, level)

    -- Screen shake al final del frame
    updateShake()
end

-- ── Pantalla de Título (Versión 3.0 — rediseñada) ─────────────
function GameManager._updateTitle()
    local gfx = playdate.graphics
    local ms  = playdate.getCurrentTimeMilliseconds()
    titleFrame += 1

    -- ── Fondo del primer nivel ────────────────────────────────
    if bgImg then
        bgImg:draw(Layout.BG_X, Layout.BG_Y)
    else
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(0, 0, 400, 240)
    end

    -- ── Obstáculos flotantes en el fondo ──────────────────────
    updateTitleObs(ms)
    drawTitleObs(gfx)

    -- ── Díaz animado al centro ────────────────────────────────
    -- Cicla entre idle → calistenia → work (cambia cada TITLE_DIAZ_DUR frames)
    titleDiazTimer += 1
    if titleDiazTimer >= TITLE_DIAZ_DUR then
        titleDiazTimer = 0
        titleDiazFrame = (titleDiazFrame % 3) + 1
    end
    local diazX = 185
    local diazY = 110
    local diazImg = nil
    if titleDiazFrame == 1 then
        diazImg = titleDiazImgs[1]   -- idle
    elseif titleDiazFrame == 2 then
        diazImg = titleDiazImgs[2]   -- calistenia
    elseif titleDiazFrame == 3 then
        -- work: usar imagetable (frame 1 o 2 alternando)
        local wt = titleDiazImgs[3]
        if wt then
            local wf = (math.floor(ms / 200) % 3) + 1
            diazImg = wt:getImage(wf)
        end
    end
    if diazImg then
        diazImg:draw(diazX, diazY)
    end

    -- ── Panel superior con título del juego ───────────────────
    local px, py, pw, ph = 50, 12, 300, 95
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(px, py, pw, ph, 10)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRoundRect(px + 2, py + 2, pw - 4, ph - 4, 8)
    gfx.drawRoundRect(px + 4, py + 4, pw - 8, ph - 6, 6)

    -- Texto del título (fuente personalizada si cargó)
    if titleFont then
        gfx.setFont(titleFont)
    end
    gfx.drawTextAligned("*PLOMERO DÍAZ*", 200, py + 10, kTextAlignment.center)
    -- Restaurar fuente del sistema para el resto
    gfx.setFont(playdate.graphics.font.new("font/Roobert-10-Bold") or playdate.graphics.getSystemFont())

    gfx.drawTextAligned("¡Salva la facultad del diluvio!", 200, py + 34, kTextAlignment.center)

    gfx.setColor(gfx.kColorWhite)
    gfx.drawLine(70, py + 50, 330, py + 50)

    -- Instrucciones compactas
    gfx.drawTextAligned("Manivela=Bombear | Flechas=QTE | B=Calistenia", 200, py + 58, kTextAlignment.center)
    gfx.drawTextAligned("Sube el agua para ganar cada nivel", 200, py + 74, kTextAlignment.center)

    -- ── Parpadeo "PRESS A" en la parte inferior ───────────────
    if (math.floor(titleFrame / 18) % 2) == 0 then
        local bx, by2, bw2, bh2 = 110, 205, 180, 22
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRoundRect(bx, by2, bw2, bh2, 6)
        gfx.setColor(gfx.kColorWhite)
        gfx.drawRoundRect(bx + 1, by2 + 1, bw2 - 2, bh2 - 2, 5)
        gfx.drawTextAligned("[ Presiona A para jugar ]", 200, by2 + 5, kTextAlignment.center)
    end

    if playdate.buttonJustPressed(playdate.kButtonA) then
        level = 1
        ScoreManager.init()
        resetForLevel(level)
        state = STATE_GAMEPLAY
    end
end

-- ── Gameplay ──────────────────────────────────────────────────
function GameManager._updateGameplay()
    local gfx   = playdate.graphics
    local water = Toilet.getWaterLevel()

    -- ── Gestión de sub-estados ──────────────────────────────
    if playdate.buttonIsPressed(playdate.kButtonB) then
        if subState ~= SUB_CALISTENIA then
            if QTEManager.isActive() then
                QTEManager.cancel()
                ComboSystem.resetCombo()
            end
            subState = SUB_CALISTENIA
        end
    else
        if subState == SUB_CALISTENIA then
            subState = SUB_RUNNING
        end
    end

    -- Transición a/desde PANIC
    if subState == SUB_RUNNING and water >= 80 then
        subState   = SUB_PANIC
        panicTimer = 150
        ComboSystem.resetCombo()
        triggerShake(4, 20)
    end
    if subState == SUB_PANIC then
        panicTimer -= 1
        if panicTimer <= 0 and water < 80 then
            subState = SUB_RUNNING
        end
    end

    -- ── Actualizar sistemas ─────────────────────────────────
    local panicMult = (subState == SUB_PANIC) and 1.5 or 1.0

    if subState == SUB_CALISTENIA then
        Player.updateCalistenia()
    else
        Player.update(level)
    end

    local drain = Player.getDrainAmount()
    Toilet.update(level, drain, panicMult)

    if subState ~= SUB_CALISTENIA then
        QTEManager.update(level)
    end

    if ComboSystem.isInFlow() then
        Player.addStamina(0.017)
    end

    -- ── Dibujar escena ──────────────────────────────────────
    -- 1. Fondo (nivel actual → ciclo módulo 3)
    if bgImg then
        bgImg:draw(Layout.BG_X, Layout.BG_Y)
    end

    -- 2. Inodoro (agua + olas)
    Toilet.draw()

    -- 3. Personaje
    Player.draw()

    -- 4. QTE (encima)
    QTEManager.draw()

    -- ── Condiciones de victoria / derrota ───────────────────
    water = Toilet.getWaterLevel()
    if water <= 0 then
        ScoreManager.addLevelBonus(level, ComboSystem.getMaxCombo())
        level           += 1
        state            = STATE_LEVELCLEAR
        levelClearTimer  = 90
        flushFrame       = 1
        flushTimer       = 0
    elseif water >= 100 then
        state         = STATE_GAMEOVER
        gameoverFrame = 0
        triggerShake(6, 30)
    end
end

-- ── Nivel Completado (Versión 3.0 — sin rectángulo negro gigante) ──
function GameManager._updateLevelClear()
    local gfx = playdate.graphics
    levelClearTimer -= 1

    -- Fondo (nivel recién completado)
    if bgImg then bgImg:draw(Layout.BG_X, Layout.BG_Y) end

    -- Estado del juego de fondo
    Toilet.draw()
    Player.draw()

    -- Animación de flush (siempre visible)
    flushTimer += 1
    if flushTimer >= FLUSH_FRAME_DUR then
        flushTimer = 0
        flushFrame = (flushFrame % FLUSH_FRAMES) + 1
    end
    if flushTable then
        local img = flushTable:getImage(flushFrame)
        if img then img:draw(175, 85) end
    end

    -- ── Panel estilizado centrado (blanco con bordes redondeados gruesos) ──
    local pw, ph = 270, 120
    local px = math.floor((400 - pw) / 2)
    local py = math.floor((240 - ph) / 2) - 10

    -- Sombra / borde exterior negro
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(px - 3, py - 3, pw + 6, ph + 6, 14)

    -- Panel blanco principal
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(px, py, pw, ph, 12)

    -- Borde interior negro (decorativo, grosor doble)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRoundRect(px + 2, py + 2, pw - 4, ph - 4, 10)
    gfx.drawRoundRect(px + 4, py + 4, pw - 8, ph - 8, 8)

    -- Texto en negro sobre blanco → perfectamente legible
    gfx.drawTextAligned("★ NIVEL " .. (level - 1) .. " COMPLETADO ★", 200, py + 14, kTextAlignment.center)

    gfx.drawLine(px + 20, py + 34, px + pw - 20, py + 34)

    gfx.drawTextAligned("Score:  " .. ScoreManager.getScore(), 200, py + 42, kTextAlignment.center)
    gfx.drawTextAligned("Coins:  " .. ScoreManager.getCoins(), 200, py + 60, kTextAlignment.center)

    local countdown = math.ceil(levelClearTimer / 30)
    gfx.drawTextAligned("Nivel " .. level .. " en " .. countdown .. "...", 200, py + 82, kTextAlignment.center)

    if levelClearTimer <= 0 then
        resetForLevel(level)
        state = STATE_GAMEPLAY
    end
end

-- ── Game Over ─────────────────────────────────────────────────
function GameManager._updateGameOver()
    local gfx = playdate.graphics
    gameoverFrame += 1

    -- Fondo
    if bgImg then
        bgImg:draw(Layout.BG_X, Layout.BG_Y)
    end

    -- Overlay negro completo
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, 400, 240)

    -- Panel principal
    local px, py, pw, ph = 60, 40, 280, 160
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(px, py, pw, ph, 10)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRoundRect(px + 1, py + 1, pw - 2, ph - 2, 9)
    gfx.drawRoundRect(px + 3, py + 3, pw - 6, ph - 6, 7)

    gfx.drawTextAligned("*GAME OVER*", 200, py + 14, kTextAlignment.center)
    gfx.drawTextAligned("La facultad se inundo...", 200, py + 34, kTextAlignment.center)

    gfx.setColor(gfx.kColorWhite)
    gfx.drawLine(80, py + 52, 320, py + 52)

    gfx.drawTextAligned("Score:           " .. ScoreManager.getScore(), 200, py + 62, kTextAlignment.center)
    gfx.drawTextAligned("Diaz-Coins:      " .. ScoreManager.getCoins(), 200, py + 80, kTextAlignment.center)
    gfx.drawTextAligned("Nivel alcanzado: " .. level, 200, py + 98, kTextAlignment.center)

    -- Parpadeo "PRESS A"
    if (math.floor(gameoverFrame / 20) % 2) == 0 then
        gfx.drawRoundRect(95, py + 122, 210, 20, 5)
        gfx.drawTextAligned("[ Presiona A para reintentar ]", 200, py + 126, kTextAlignment.center)
    end

    if playdate.buttonJustPressed(playdate.kButtonA) then
        level = 1
        ScoreManager.init()
        resetForLevel(level)
        state = STATE_GAMEPLAY
    end
end
