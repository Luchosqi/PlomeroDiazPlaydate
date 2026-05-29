-- =============================================================
-- model/GameManager.lua  — Versión 5.0
-- CAMBIOS v5.0:
--   [NEW] Tipografía "Nontendo Bold" cargada y aplicada en todos los textos.
--   [NEW] Título: fondos rotan cíclicamente cada 3 s (3 fondos distintos).
--   [NEW] Título: Díaz animado al centro alternando idle→work→calistenia.
--   [NEW] Título: obstáculos flotantes con sin/cos; texto con sprite [A].
--   [NEW] Game Over + Level Clear: overlay dithered + panel blanco limpio.
--   [NEW] AudioManager integrado: música en loop con rate dinámico.
--   [FIX] setOffset(0,0) garantizado en cada frame (fin del cuadro misterioso).
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
local flushTable    = nil
local flushFrame    = 1
local flushTimer    = 0
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
        local iInt = math.max(1, math.floor(shakeIntensity))
        playdate.display.setOffset(math.random(-iInt, iInt), math.random(-iInt, iInt))
        shakeIntensity = shakeIntensity * 0.85
    else
        -- [FIX] Siempre resetear para evitar el cuadro misterioso
        playdate.display.setOffset(0, 0)
        shakeIntensity = 0
    end
end

-- ── Patrón de dithering para overlays semitransparentes ──────
local DITHER_75 = { 0xBB, 0xEE, 0xBB, 0xEE, 0xBB, 0xEE, 0xBB, 0xEE }

-- ── Assets ────────────────────────────────────────────────────
local bgImgs       = {}       -- bgImgs[1..3]
local bgImg        = nil      -- fondo activo en gameplay

-- [NEW v5.0] Fuente Nontendo Bold (cargada una sola vez en loadAssets)
local boldFont     = nil
local systemFont   = nil      -- fuente del sistema como fallback

-- Título: rotación de fondo
local titleBgIdx     = 1
local titleBgTimer   = 0
local BG_TITLE_SWITCH <const> = 30 * 3   -- 3 segundos a 30 fps

-- Título: animación de Díaz
local titleDiazImgs  = {}
local titleDiazFrame = 1
local titleDiazTimer = 0
local TITLE_DIAZ_DUR <const> = 45

-- Título: obstáculos flotantes
local titleObs       = {}
local obsImagesTitle = {}

-- Sprite del botón A (para "Presiona [A]")
local btnAImg = nil

-- ── Carga de assets ───────────────────────────────────────────
local function loadAssets()
    local gfx = playdate.graphics

    -- [NEW v5.0] Cargar fuente Nontendo Bold
    if not boldFont then
        boldFont   = gfx.font.new("assets/font/nontendo-bold/Nontendo-Bold")
        systemFont = gfx.getSystemFont()
        -- Establecer la fuente globalmente; cada draw la aplica antes de usar texto
        if boldFont then
            gfx.setFont(boldFont)
        end
    end

    -- Animación de flush
    if not flushTable then
        flushTable = gfx.imagetable.new("assets/images/flush")
    end

    -- 3 fondos distintos
    for i = 1, 3 do
        if not bgImgs[i] then
            local img = gfx.image.new("assets/images/bg_bathroom_" .. i)
            if not img then
                img = gfx.image.new("assets/images/bg_bathroom")
            end
            bgImgs[i] = img
        end
    end

    -- Sprites del personaje para el título
    if #titleDiazImgs == 0 then
        titleDiazImgs[1] = gfx.image.new("assets/images/diaz_idle")
        titleDiazImgs[2] = gfx.image.new("assets/images/diaz_calistenia")
        titleDiazImgs[3] = gfx.imagetable.new("assets/images/diaz_work")
    end

    -- Sprites de obstáculos para el título
    local obsNames = { "obs_normal", "obs_pelo", "obs_banana", "obs_car_red" }
    if #obsImagesTitle == 0 then
        for _, name in ipairs(obsNames) do
            local img = gfx.image.new("assets/images/" .. name)
            if img then table.insert(obsImagesTitle, img) end
        end
    end

    -- Sprite del botón A
    if not btnAImg then
        btnAImg = gfx.image.new("assets/images/ui_button_a")
    end
end

-- ── Helpers de tipografía ─────────────────────────────────────
-- Llamar antes de dibujar texto; restaurar con useSystemFont()
local function useBoldFont()
    if boldFont then
        playdate.graphics.setFont(boldFont)
    end
end

local function useSystemFont()
    if systemFont then
        playdate.graphics.setFont(systemFont)
    end
end

-- ── Seleccionar fondo por nivel ───────────────────────────────
local function getBgForLevel(lvl)
    local idx = ((lvl - 1) % 3) + 1
    return bgImgs[idx] or bgImgs[1]
end

-- ── Obstáculos flotantes del título ──────────────────────────
local function initTitleObs()
    titleObs = {}
    if #obsImagesTitle == 0 then return end
    for i = 1, 6 do
        table.insert(titleObs, {
            x     = math.random(10, 370),
            y     = math.random(30, 200),
            phase = math.random(0, 628) / 100.0,
            speed = 0.5 + math.random() * 0.7,
            ampY  = 8  + math.random() * 14,
            ampX  = 0,   -- solo movimiento horizontal lineal
            img   = obsImagesTitle[math.random(#obsImagesTitle)],
        })
    end
end

local function updateTitleObs(ms)
    local t = ms / 1000.0
    for _, o in ipairs(titleObs) do
        o.x = o.x + o.speed
        if o.x > 440 then o.x = -40 end
        -- Oscilación vertical suave
        o.drawY = o.y + math.floor(math.sin(t * 1.5 + o.phase) * o.ampY)
    end
end

local function drawTitleObs()
    local gfx = playdate.graphics
    for _, o in ipairs(titleObs) do
        if o.img then
            local ox = math.floor(o.x)
            local oy = math.floor(o.drawY or o.y)
            -- Círculo blanco de fondo para visibilidad
            gfx.setColor(gfx.kColorWhite)
            gfx.fillCircleAtPoint(ox + 18, oy + 18, 20)
            gfx.setColor(gfx.kColorBlack)
            gfx.drawCircleAtPoint(ox + 18, oy + 18, 20)
            gfx.drawCircleAtPoint(ox + 18, oy + 18, 19)
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
    level        = 1
    state        = STATE_TITLE
    titleFrame   = 0
    titleBgIdx   = 1
    titleBgTimer = 0
    loadAssets()
    bgImg = getBgForLevel(1)
    ComboSystem.init()
    ScoreManager.init()
    Player.init()
    Toilet.init(level)
    QTEManager.init(level)
    HUD.init()
    AudioManager.init()
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

-- ═════════════════════════════════════════════════════════════
-- ── PANTALLA DE TÍTULO — v5.0 ────────────────────────────────
-- • Fondo rota entre los 3 diseños cada BG_TITLE_SWITCH frames
-- • Díaz animado al centro (idle → work → calistenia)
-- • Obstáculos flotantes con círculo blanco de contraste
-- • "Bienvenido a Plomero Díaz" en Nontendo Bold
-- • "Presiona [sprite A] para empezar" con ícono incrustado
-- ═════════════════════════════════════════════════════════════
function GameManager._updateTitle()
    local gfx = playdate.graphics
    local ms  = playdate.getCurrentTimeMilliseconds()
    titleFrame += 1

    -- Rotar fondo cada BG_TITLE_SWITCH frames
    titleBgTimer += 1
    if titleBgTimer >= BG_TITLE_SWITCH then
        titleBgTimer = 0
        titleBgIdx   = (titleBgIdx % 3) + 1
    end
    local bg = bgImgs[titleBgIdx]
    if bg then
        bg:draw(Layout.BG_X, Layout.BG_Y)
    else
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(0, 0, 400, 240)
    end

    -- Obstáculos flotantes
    updateTitleObs(ms)
    drawTitleObs()

    -- Díaz animado al centro
    titleDiazTimer += 1
    if titleDiazTimer >= TITLE_DIAZ_DUR then
        titleDiazTimer = 0
        titleDiazFrame = (titleDiazFrame % 3) + 1
    end
    local diazW, diazH = 120, 150
    local diazX = math.floor((400 - diazW) / 2)   -- centrado horizontal
    local diazY = 68
    local diazImg = nil
    if titleDiazFrame == 1 then
        diazImg = titleDiazImgs[1]    -- idle
    elseif titleDiazFrame == 2 then
        local wt = titleDiazImgs[3]   -- work (imagetable)
        if wt then diazImg = wt:getImage((math.floor(ms / 200) % 3) + 1) end
    else
        diazImg = titleDiazImgs[2]    -- calistenia
    end
    if diazImg then diazImg:draw(diazX, diazY) end

    -- ── Panel de título SUPERIOR — solo "Bienvenido a Plomero Diaz" ──
    -- [FIX v5.1] Panel reducido a 1 sola línea de texto.
    -- pw=324 (margen 38px a cada lado), ph=32 (ajustado a 1 línea de Nontendo Bold ~16px + 8px arriba + 8px abajo)
    -- py=6 deja un margen cómodo desde el borde superior.
    local px, py, pw, ph = 38, 6, 324, 32
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(px, py, pw, ph, 8)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(px + 3, py + 3, pw - 6, ph - 6, 6)

    -- Texto centrado verticalmente dentro del panel (py + 8 = margen superior de 8px)
    gfx.setColor(gfx.kColorBlack)
    useBoldFont()
    gfx.drawTextAligned("Bienvenido a Plomero Diaz", 200, py + 8, kTextAlignment.center)
    useSystemFont()

    -- ── Panel INFERIOR parpadeante — "Presiona A para jugar" ──────
    -- [FIX v5.2] Mismo estilo que el panel superior:
    --   * Relleno negro exterior → relleno blanco interior
    --   * Sin sprite incrustado ni division del rectangulo
    --   * gfx.kColorBlack ANTES del texto para evitar conflicto de colores
    -- panY=202 → borde inferior en Y=232 → margen inferior 8px OK
    if (math.floor(titleFrame / 18) % 2) == 0 then
        local panW = 260
        local panH = 30
        local panX = math.floor((400 - panW) / 2)   -- = 70, centrado
        local panY = 202

        -- Borde negro exterior (identico al panel superior)
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRoundRect(panX, panY, panW, panH, 8)
        -- Relleno blanco interior
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRoundRect(panX + 3, panY + 3, panW - 6, panH - 6, 6)

        -- Texto negro sobre blanco, Nontendo Bold, perfectamente centrado
        gfx.setColor(gfx.kColorBlack)
        useBoldFont()
        gfx.drawTextAligned("Presiona A para jugar", 200, panY + 8, kTextAlignment.center)
        useSystemFont()
    end

    if playdate.buttonJustPressed(playdate.kButtonA) then
        level = 1
        ScoreManager.init()
        resetForLevel(level)
        AudioManager.startMusic()
        state = STATE_GAMEPLAY
    end
end

-- ═════════════════════════════════════════════════════════════
-- ── GAMEPLAY ─────────────────────────────────────────────────
-- ═════════════════════════════════════════════════════════════
function GameManager._updateGameplay()
    local gfx   = playdate.graphics
    local water = Toilet.getWaterLevel()

    -- Gestión de sub-estados
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

    -- [NEW v5.0] Actualizar música dinámica según nivel de agua
    AudioManager.update(water, subState == SUB_PANIC)

    -- Dibujo
    if bgImg then bgImg:draw(Layout.BG_X, Layout.BG_Y) end
    Toilet.draw()
    Player.draw()
    QTEManager.draw()

    -- Condiciones de victoria / derrota
    water = Toilet.getWaterLevel()
    if water <= 0 then
        ScoreManager.addLevelBonus(level, ComboSystem.getMaxCombo())
        level           += 1
        state            = STATE_LEVELCLEAR
        levelClearTimer  = 90
        flushFrame       = 1
        flushTimer       = 0
        -- [FIX v5.1] NO detenemos la música al cambiar de nivel;
        -- AudioManager.update() deja de llamarse (STATE_LEVELCLEAR no lo llama)
        -- pero el fileplayer sigue corriendo en segundo plano sin cortes.
    elseif water >= 100 then
        state         = STATE_GAMEOVER
        gameoverFrame = 0
        triggerShake(6, 30)
        -- [FIX v5.1] Tampoco detenemos en Game Over; se corta solo al ir al título.
    end
end

-- ═════════════════════════════════════════════════════════════
-- ── NIVEL COMPLETADO — v5.0 ───────────────────────────────────
-- • Overlay dithered (no fillRect negro puro)
-- • Panel blanco limpio + Nontendo Bold para stats
-- • "Presiona [A] para continuar" con sprite incrustado
-- ═════════════════════════════════════════════════════════════
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

    -- [NEW v5.0] Overlay dithered (semitransparente, sin el cuadro negro feo)
    gfx.setPattern(DITHER_75)
    gfx.fillRect(0, 0, 400, 240)
    gfx.setColor(gfx.kColorBlack)

    -- Panel: borde negro grueso → interior blanco
    local pw, ph = 274, 122
    local px = math.floor((400 - pw) / 2)
    local py = math.floor((240 - ph) / 2) - 6

    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(px - 4, py - 4, pw + 8, ph + 8, 15)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(px, py, pw, ph, 12)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRoundRect(px + 2, py + 2, pw - 4, ph - 4, 10)
    gfx.drawRoundRect(px + 4, py + 4, pw - 8, ph - 8, 8)

    -- [NEW v5.0] Textos en Nontendo Bold sobre fondo blanco → siempre legibles
    useBoldFont()
    gfx.setColor(gfx.kColorBlack)
    gfx.drawTextAligned("Nivel " .. (level - 1) .. " Superado!", 200, py + 10, kTextAlignment.center)
    useSystemFont()

    gfx.drawLine(px + 18, py + 28, px + pw - 18, py + 28)

    gfx.drawTextAligned("Score:  " .. ScoreManager.getScore(), 200, py + 36, kTextAlignment.center)
    gfx.drawTextAligned("Coins:  " .. ScoreManager.getCoins(), 200, py + 52, kTextAlignment.center)

    local countdown = math.ceil(levelClearTimer / 30)
    gfx.drawTextAligned("Nivel " .. level .. " en " .. countdown .. "s...", 200, py + 68, kTextAlignment.center)

    -- [NEW v5.0] "Presiona [A] para continuar" con sprite incrustado
    gfx.drawText("Presiona", px + 28, py + 90)
    if btnAImg then
        btnAImg:draw(px + 96, py + 88)
    end
    gfx.drawText("para continuar", px + 122, py + 90)

    if levelClearTimer <= 0 then
        resetForLevel(level)
        -- [FIX v5.1] startMusic() detecta si ya está sonando y NO la reinicia.
        -- Solo la arranca si por algún motivo se detuvo (primer nivel, etc.)
        AudioManager.startMusic()
        state = STATE_GAMEPLAY
    end
end

-- ═════════════════════════════════════════════════════════════
-- ── GAME OVER — v5.0 ─────────────────────────────────────────
-- • Overlay dithered 75 % (no fillRect negro puro)
-- • Panel blanco limpio + Nontendo Bold para stats
-- • "Presiona [A] para volver a jugar" con sprite incrustado
-- ═════════════════════════════════════════════════════════════
function GameManager._updateGameOver()
    local gfx = playdate.graphics
    gameoverFrame += 1

    -- Fondo con contexto (no pantalla negra vacía)
    if bgImg then bgImg:draw(Layout.BG_X, Layout.BG_Y) end

    -- [NEW v5.0] Overlay dithered en lugar de fillRect negro opaco
    gfx.setPattern(DITHER_75)
    gfx.fillRect(0, 0, 400, 240)
    gfx.setColor(gfx.kColorBlack)

    -- Panel: borde negro → interior blanco
    local px, py, pw, ph = 52, 28, 296, 184
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(px, py, pw, ph, 12)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(px + 3, py + 3, pw - 6, ph - 6, 10)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRoundRect(px + 4, py + 4, pw - 8, ph - 8, 9)
    gfx.drawRoundRect(px + 6, py + 6, pw - 12, ph - 12, 7)

    -- [NEW v5.0] Encabezado en Nontendo Bold
    useBoldFont()
    gfx.setColor(gfx.kColorBlack)
    gfx.drawTextAligned("Game Over", 200, py + 12, kTextAlignment.center)
    useSystemFont()

    gfx.drawTextAligned("La facultad se inundo...", 200, py + 30, kTextAlignment.center)
    gfx.drawLine(px + 18, py + 48, px + pw - 18, py + 48)

    -- Stats
    gfx.drawTextAligned("Score:           " .. ScoreManager.getScore(), 200, py + 56, kTextAlignment.center)
    gfx.drawTextAligned("Diaz-Coins:      " .. ScoreManager.getCoins(), 200, py + 74, kTextAlignment.center)
    gfx.drawTextAligned("Nivel alcanzado: " .. level,                   200, py + 92, kTextAlignment.center)

    gfx.drawLine(px + 18, py + 112, px + pw - 18, py + 112)

    -- [NEW v5.0] "Presiona [A] para volver a jugar" — parpadea
    if (math.floor(gameoverFrame / 20) % 2) == 0 then
        local tyBase = py + 124
        useBoldFont()
        gfx.drawText("Presiona", px + 32, tyBase)
        useSystemFont()
        if btnAImg then
            btnAImg:draw(px + 104, tyBase - 2)
        else
            gfx.drawRoundRect(px + 105, tyBase - 1, 18, 18, 3)
            gfx.drawTextAligned("A", px + 114, tyBase + 1, kTextAlignment.center)
        end
        gfx.drawText("para volver a jugar", px + 130, tyBase)
    end

    -- También mostrar las instrucciones de forma estática
    gfx.drawTextAligned("(se reinicia en el nivel 1)", 200, py + 150, kTextAlignment.center)

    if playdate.buttonJustPressed(playdate.kButtonA) then
        level = 1
        ScoreManager.init()
        resetForLevel(level)
        AudioManager.startMusic()
        state = STATE_GAMEPLAY
    end
end
