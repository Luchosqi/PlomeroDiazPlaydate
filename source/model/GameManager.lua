-- =============================================================
-- model/GameManager.lua  — Versión 4.0
-- CAMBIOS v4.0:
--   [FIX]  setOffset siempre vuelve a (0,0) al terminar el shake
--   [NEW]  3 fondos distintos que rotan en el título cada 4 s
--   [NEW]  Título: Díaz animado + obstáculos flotantes + fondo rotando
--   [NEW]  Título: texto "Presiona [btn_A] para empezar" con sprite A
--   [NEW]  Game Over / Level Clear: textos siempre blancos sobre negro
--   [FIX]  Se eliminan rectángulos negros vacíos fantasma
-- =============================================================

GameManager = {}

-- ── Estados ──────────────────────────────────────────────────
local STATE_TITLE      <const> = 1
local STATE_GAMEPLAY   <const> = 2
local STATE_LEVELCLEAR <const> = 3
local STATE_GAMEOVER   <const> = 4

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

-- ── Flush ─────────────────────────────────────────────────────
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
    -- [FIX] Siempre llamamos setOffset(0,0) cuando termina el shake
    -- para evitar el "cuadrado misterioso" que aparece por un offset residual
    if shakeDuration > 0 then
        shakeDuration -= 1
        local iInt = math.max(1, math.floor(shakeIntensity))
        playdate.display.setOffset(math.random(-iInt, iInt), math.random(-iInt, iInt))
        shakeIntensity = shakeIntensity * 0.85
    else
        -- Siempre resetear aunque no haya shake activo (garantiza posición cero)
        playdate.display.setOffset(0, 0)
        shakeIntensity = 0
    end
end

-- ── Assets ────────────────────────────────────────────────────
local bgImgs = {}           -- 3 fondos: bgImgs[1..3]
local bgImg  = nil          -- fondo activo durante gameplay

-- Para el título: fondo rota cada BG_TITLE_SWITCH_SECS segundos
local titleBgIdx        = 1
local titleBgTimer      = 0
local BG_TITLE_SWITCH   <const> = 30 * 4   -- 4 segundos a 30fps

-- Sprites de Díaz usados en el título
local titleDiazImgs  = {}
local titleDiazFrame = 1
local titleDiazTimer = 0
local TITLE_DIAZ_DUR <const> = 40   -- frames por pose

-- Obstáculos flotantes del título
local titleObs       = {}
local obsImagesTitle = {}

-- Sprite del botón A (para "Presiona [A] para empezar")
local btnAImg = nil

local function loadAssets()
    -- Animación de flush
    if not flushTable then
        flushTable = playdate.graphics.imagetable.new("assets/images/flush")
    end

    -- [NEW] 3 fondos distintos. bg_bathroom_1 = ladrillos, _2 = azulejos, _3 = grafitis
    for i = 1, 3 do
        if not bgImgs[i] then
            local img = playdate.graphics.image.new("assets/images/bg_bathroom_" .. i)
            if not img then
                -- Fallback: usar el fondo genérico si el numerado no existe
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
            if img then table.insert(obsImagesTitle, img) end
        end
    end

    -- [NEW] Sprite del botón A para incrustarlo en el texto "Presiona [A]"
    if not btnAImg then
        btnAImg = playdate.graphics.image.new("assets/images/ui_button_a")
    end
end

-- ── Seleccionar fondo por nivel (ciclo módulo 3) ──────────────
local function getBgForLevel(lvl)
    local idx = ((lvl - 1) % 3) + 1
    return bgImgs[idx] or bgImgs[1]
end

-- ── Obstáculos flotantes del título ──────────────────────────
local function initTitleObs()
    titleObs = {}
    -- Necesitamos al menos 1 obstáculo para evitar crash en math.random
    if #obsImagesTitle == 0 then return end
    for i = 1, 5 do
        table.insert(titleObs, {
            x     = math.random(0, 380),
            y     = math.random(50, 190),
            phase = math.random(0, 628) / 100.0,
            speed = 0.5 + math.random() * 0.6,
            amp   = 8 + math.random() * 14,
            img   = obsImagesTitle[math.random(#obsImagesTitle)],
        })
    end
end

local function updateTitleObs(ms)
    local t = ms / 1000.0
    for _, o in ipairs(titleObs) do
        o.x = o.x + o.speed
        if o.x > 430 then o.x = -36 end
        o.drawY = o.y + math.floor(math.sin(t * 1.4 + o.phase) * o.amp)
    end
end

local function drawTitleObs(gfx)
    for _, o in ipairs(titleObs) do
        if o.img then
            -- [NEW] Dibujar obstáculos con un círculo blanco de fondo para
            --       que sean visibles sobre cualquier fondo
            local ox = math.floor(o.x)
            local oy = math.floor(o.drawY or o.y)
            local r  = 18
            gfx.setColor(gfx.kColorWhite)
            gfx.fillCircleAtPoint(ox + 14, oy + 14, r)
            gfx.setColor(gfx.kColorBlack)
            gfx.drawCircleAtPoint(ox + 14, oy + 14, r)
            o.img:draw(ox, oy)
        end
    end
end

-- ── Reset de nivel ────────────────────────────────────────────
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
    titleBgIdx = 1
    titleBgTimer = 0
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
    HUD.draw(state, subState, level)
    updateShake()
end

-- ─────────────────────────────────────────────────────────────
-- ── PANTALLA DE TÍTULO — Versión 4.0 ────────────────────────
-- [NEW] Fondo rota cada 4 s entre los 3 diseños
-- [NEW] Díaz animado al centro (idle→work→calistenia)
-- [NEW] Obstáculos flotan con círculo blanco de fondo
-- [NEW] "Presiona [sprite A] para empezar" — sin panel vacío
-- ─────────────────────────────────────────────────────────────
function GameManager._updateTitle()
    local gfx = playdate.graphics
    local ms  = playdate.getCurrentTimeMilliseconds()
    titleFrame += 1

    -- [NEW] Rotar el fondo entre los 3 diseños cada BG_TITLE_SWITCH frames
    titleBgTimer += 1
    if titleBgTimer >= BG_TITLE_SWITCH then
        titleBgTimer = 0
        titleBgIdx   = (titleBgIdx % 3) + 1
    end
    local currentBg = bgImgs[titleBgIdx]
    if currentBg then
        currentBg:draw(Layout.BG_X, Layout.BG_Y)
    else
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(0, 0, 400, 240)
    end

    -- [NEW] Obstáculos flotantes con círculo blanco de contraste
    updateTitleObs(ms)
    drawTitleObs(gfx)

    -- [NEW] Díaz animado al centro. Cicla idle → work → calistenia
    titleDiazTimer += 1
    if titleDiazTimer >= TITLE_DIAZ_DUR then
        titleDiazTimer = 0
        titleDiazFrame = (titleDiazFrame % 3) + 1
    end
    -- Centrar Díaz: sprite 120×150, centrado horizontalmente
    local diazW, diazH = 120, 150
    local diazX = math.floor((400 - diazW) / 2)
    local diazY = 70
    local diazImg = nil
    if titleDiazFrame == 1 then
        diazImg = titleDiazImgs[1]   -- idle
    elseif titleDiazFrame == 2 then
        -- work: alternar frames de la imagetable
        local wt = titleDiazImgs[3]
        if wt then diazImg = wt:getImage((math.floor(ms / 200) % 3) + 1) end
    elseif titleDiazFrame == 3 then
        diazImg = titleDiazImgs[2]   -- calistenia
    end
    if diazImg then diazImg:draw(diazX, diazY) end

    -- ── Panel superior del título (negro sólido + bordes) ─────
    local px, py, pw, ph = 40, 8, 320, 58
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(px, py, pw, ph, 10)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRoundRect(px + 2, py + 2, pw - 4, ph - 4, 8)

    -- Título grande en blanco (Markdown bold → negrita del sistema)
    gfx.drawTextAligned("*PLOMERO DÍAZ*", 200, py + 8, kTextAlignment.center)

    gfx.setColor(gfx.kColorWhite)
    gfx.drawLine(px + 20, py + 28, px + pw - 20, py + 28)

    -- Subtítulo
    gfx.drawTextAligned("¡Salva la facultad del diluvio!", 200, py + 34, kTextAlignment.center)

    -- ── Instrucciones pequeñas (sin rectángulo extra) ─────────
    -- Panel semitransparente de instrucciones
    local ix, iy, iw, ih = 55, 68, 290, 22
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(ix, iy, iw, ih, 5)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawTextAligned("Manivela=Bombear  |  Flechas=QTE  |  B=Calistenia",
                         200, iy + 4, kTextAlignment.center)

    -- ── [NEW] "Presiona [A] para empezar" con sprite del botón ──
    -- Parpadeo para llamar la atención
    if (math.floor(titleFrame / 18) % 2) == 0 then
        local by2 = 208
        -- Panel negro para contraste
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRoundRect(85, by2 - 2, 230, 24, 6)
        gfx.setColor(gfx.kColorWhite)
        gfx.drawRoundRect(86, by2 - 1, 228, 22, 5)

        -- Texto "Presiona"
        gfx.drawText("Presiona", 95, by2 + 3)
        -- Sprite del botón A incrustado (24×24, pero lo escalamos visualmente a 16px)
        if btnAImg then
            btnAImg:draw(164, by2 + 1)  -- posición justo después del texto
        else
            -- Fallback: rectángulo con letra A
            gfx.setColor(gfx.kColorWhite)
            gfx.fillRect(165, by2 + 2, 14, 14)
            gfx.setColor(gfx.kColorBlack)
            gfx.drawRect(165, by2 + 2, 14, 14)
            gfx.drawTextAligned("A", 172, by2 + 3, kTextAlignment.center)
        end
        -- Texto "para empezar"
        gfx.setColor(gfx.kColorWhite)
        gfx.drawText("para empezar", 192, by2 + 3)
    end

    if playdate.buttonJustPressed(playdate.kButtonA) then
        level = 1
        ScoreManager.init()
        resetForLevel(level)
        state = STATE_GAMEPLAY
    end
end

-- ─────────────────────────────────────────────────────────────
-- ── GAMEPLAY ─────────────────────────────────────────────────
-- ─────────────────────────────────────────────────────────────
function GameManager._updateGameplay()
    local gfx   = playdate.graphics
    local water = Toilet.getWaterLevel()

    if playdate.buttonIsPressed(playdate.kButtonB) then
        if subState ~= SUB_CALISTENIA then
            if QTEManager.isActive() then
                QTEManager.cancel()
                ComboSystem.resetCombo()
            end
            subState = SUB_CALISTENIA
        end
    else
        if subState == SUB_CALISTENIA then subState = SUB_RUNNING end
    end

    if subState == SUB_RUNNING and water >= 80 then
        subState   = SUB_PANIC
        panicTimer = 150
        ComboSystem.resetCombo()
        triggerShake(4, 20)
    end
    if subState == SUB_PANIC then
        panicTimer -= 1
        if panicTimer <= 0 and water < 80 then subState = SUB_RUNNING end
    end

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

    if ComboSystem.isInFlow() then Player.addStamina(0.017) end

    -- Dibujar
    if bgImg then bgImg:draw(Layout.BG_X, Layout.BG_Y) end
    Toilet.draw()
    Player.draw()
    QTEManager.draw()

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

-- ─────────────────────────────────────────────────────────────
-- ── NIVEL COMPLETADO — Versión 4.0 ───────────────────────────
-- [FIX] No hay rect negro fantasma. Panel blanco → texto negro.
-- [NEW] "Presiona [A] para volver" con sprite del botón A.
-- ─────────────────────────────────────────────────────────────
function GameManager._updateLevelClear()
    local gfx = playdate.graphics
    levelClearTimer -= 1

    -- Fondo del nivel recién completado
    if bgImg then bgImg:draw(Layout.BG_X, Layout.BG_Y) end
    Toilet.draw()
    Player.draw()

    -- Animación de flush
    flushTimer += 1
    if flushTimer >= FLUSH_FRAME_DUR then
        flushTimer = 0
        flushFrame = (flushFrame % FLUSH_FRAMES) + 1
    end
    if flushTable then
        local img = flushTable:getImage(flushFrame)
        if img then img:draw(175, 85) end
    end

    -- ── Panel estilizado: negro exterior → blanco interior ───
    local pw, ph = 270, 118
    local px = math.floor((400 - pw) / 2)
    local py = math.floor((240 - ph) / 2) - 8

    -- Sombra exterior negra
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(px - 4, py - 4, pw + 8, ph + 8, 15)

    -- Panel blanco principal
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(px, py, pw, ph, 12)

    -- Bordes interiores decorativos (negros, doble)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRoundRect(px + 2,  py + 2,  pw - 4,  ph - 4,  10)
    gfx.drawRoundRect(px + 4,  py + 4,  pw - 8,  ph - 8,  8)

    -- [FIX] Todo el texto siguiente está en negro sobre panel blanco → siempre legible
    gfx.setColor(gfx.kColorBlack)
    gfx.drawTextAligned("★ NIVEL " .. (level - 1) .. " COMPLETADO ★", 200, py + 12, kTextAlignment.center)

    gfx.drawLine(px + 20, py + 30, px + pw - 20, py + 30)

    gfx.drawTextAligned("Score:  " .. ScoreManager.getScore(), 200, py + 38, kTextAlignment.center)
    gfx.drawTextAligned("Coins:  " .. ScoreManager.getCoins(), 200, py + 54, kTextAlignment.center)

    local countdown = math.ceil(levelClearTimer / 30)
    gfx.drawTextAligned("Nivel " .. level .. " en " .. countdown .. "...", 200, py + 70, kTextAlignment.center)

    -- [NEW] "Presiona [A]" con sprite del botón (si levelClearTimer es par → parpadea)
    if (math.floor(levelClearTimer / 8) % 2) == 0 then
        -- Texto izquierdo
        gfx.drawText("Presiona", px + 30, py + 90)
        if btnAImg then
            btnAImg:draw(px + 100, py + 88)
        end
        gfx.drawText("para continuar", px + 128, py + 90)
    end

    if levelClearTimer <= 0 then
        resetForLevel(level)
        state = STATE_GAMEPLAY
    end
end

-- ─────────────────────────────────────────────────────────────
-- ── GAME OVER — Versión 4.0 ──────────────────────────────────
-- [FIX] Eliminado el fillRect negro que impedía ver el panel.
--       Ahora: fondo → overlay semitransparente → panel blanco → texto negro.
-- [NEW] "Presiona [A] para volver a jugar" con sprite del botón A.
-- ─────────────────────────────────────────────────────────────
function GameManager._updateGameOver()
    local gfx = playdate.graphics
    gameoverFrame += 1

    -- [FIX] Fondo de muralla: visible, da contexto de "baño inundado"
    if bgImg then
        bgImg:draw(Layout.BG_X, Layout.BG_Y)
    end

    -- [FIX] Overlay DITHERED en lugar de fillRect negro completo.
    -- El dithering semitransparente oscurece sin borrar el fondo ni crear el cuadro negro.
    local DITHER_75 = { 0xBB, 0xEE, 0xBB, 0xEE, 0xBB, 0xEE, 0xBB, 0xEE }
    gfx.setPattern(DITHER_75)
    gfx.fillRect(0, 0, 400, 240)
    gfx.setColor(gfx.kColorBlack)  -- restaurar color sólido

    -- ── Panel principal: negro exterior → blanco interior ────
    local px, py, pw, ph = 55, 32, 290, 176
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(px, py, pw, ph, 12)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(px + 3, py + 3, pw - 6, ph - 6, 10)

    -- Bordes decorativos interiores
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRoundRect(px + 4,  py + 4,  pw - 8,  ph - 8,  9)
    gfx.drawRoundRect(px + 6,  py + 6,  pw - 12, ph - 12, 7)

    -- [FIX] Todo el texto en negro sobre panel blanco → siempre visible
    gfx.setColor(gfx.kColorBlack)
    gfx.drawTextAligned("*GAME OVER*", 200, py + 14, kTextAlignment.center)
    gfx.drawTextAligned("La facultad se inundó...", 200, py + 32, kTextAlignment.center)

    gfx.drawLine(px + 20, py + 50, px + pw - 20, py + 50)

    gfx.drawTextAligned("Score:           " .. ScoreManager.getScore(), 200, py + 58, kTextAlignment.center)
    gfx.drawTextAligned("Diaz-Coins:      " .. ScoreManager.getCoins(), 200, py + 76, kTextAlignment.center)
    gfx.drawTextAligned("Nivel alcanzado: " .. level,                   200, py + 94, kTextAlignment.center)

    gfx.drawLine(px + 20, py + 112, px + pw - 20, py + 112)

    -- [NEW] "Presiona [A] para volver a jugar" — con sprite del botón A
    -- Parpadeo cada 20 frames
    if (math.floor(gameoverFrame / 20) % 2) == 0 then
        -- Centrar la composición: "Presiona" + ícono A + "para volver"
        local tyBase = py + 120
        gfx.drawText("Presiona", px + 40, tyBase)
        if btnAImg then
            btnAImg:draw(px + 112, tyBase - 2)
        else
            gfx.drawRoundRect(px + 113, tyBase - 1, 18, 18, 3)
            gfx.drawTextAligned("A", px + 122, tyBase + 1, kTextAlignment.center)
        end
        gfx.drawText("para volver a jugar", px + 138, tyBase)
    end

    if playdate.buttonJustPressed(playdate.kButtonA) then
        level = 1
        ScoreManager.init()
        resetForLevel(level)
        state = STATE_GAMEPLAY
    end
end
