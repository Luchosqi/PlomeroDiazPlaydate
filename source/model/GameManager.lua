-- =============================================================
-- model/GameManager.lua
-- Máquina de estados global — Versión 2.0
-- Añade: Screen Shake, fondo bg_bathroom.png, usa Layout.lua
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
local shakeIntensity = 0   -- píxeles máx de desplazamiento actual
local shakeDuration  = 0   -- frames restantes de shake

local function triggerShake(intensity, duration)
    -- Solo escalar si el nuevo shake es más fuerte
    if intensity > shakeIntensity then
        shakeIntensity = intensity
        shakeDuration  = duration
    end
end

local function updateShake()
    if shakeDuration > 0 then
        shakeDuration -= 1
        local ox = math.random(-shakeIntensity, shakeIntensity)
        local oy = math.random(-shakeIntensity, shakeIntensity)
        playdate.display.setOffset(ox, oy)
        -- Reducir intensidad suavemente
        shakeIntensity = shakeIntensity * 0.85
        if shakeDuration <= 0 then
            playdate.display.setOffset(0, 0)
            shakeIntensity = 0
        end
    end
end

-- ── Imágenes ─────────────────────────────────────────────────
local bgImg = nil

local function loadAssets()
    if not flushTable then
        flushTable = playdate.graphics.imagetable.new("assets/images/flush")
    end
    if not bgImg then
        bgImg = playdate.graphics.image.new("assets/images/bg_bathroom")
    end
end

-- ── Funciones internas ────────────────────────────────────────
local function resetForLevel(lvl)
    subState   = SUB_RUNNING
    panicTimer = 0
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
    ComboSystem.init()
    ScoreManager.init()
    Player.init()
    Toilet.init(level)
    QTEManager.init(level)
    HUD.init()
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

    -- Aplicar screen shake (al final del frame para afectar todo)
    updateShake()
end

-- ── Pantalla de Título ────────────────────────────────────────
function GameManager._updateTitle()
    local gfx = playdate.graphics
    titleFrame += 1

    -- Fondo de baño como decoración del título
    if bgImg then
        bgImg:draw(Layout.BG_X, Layout.BG_Y)
    else
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(0, 0, 400, 240)
        gfx.setColor(gfx.kColorWhite)
    end

    -- Overlay semitransparente (panel central con fondo negro)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(60, 30, 280, 185, 10)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRoundRect(62, 32, 276, 181, 8)

    -- Título
    gfx.drawTextAligned("*PLOMERO DIAZ*", 200, 45, kTextAlignment.center)
    gfx.drawTextAligned("Salva la facultad del diluvio!", 200, 70, kTextAlignment.center)

    -- Separador
    gfx.setColor(gfx.kColorWhite)
    gfx.drawLine(80, 90, 320, 90)

    -- Instrucciones
    gfx.drawTextAligned("Manivela  =  Bombear agua", 200, 100, kTextAlignment.center)
    gfx.drawTextAligned("Flechas   =  Resolver QTE", 200, 118, kTextAlignment.center)
    gfx.drawTextAligned("Btn B     =  Calistenia", 200, 136, kTextAlignment.center)
    gfx.drawTextAligned("(recuperar energia)", 200, 152, kTextAlignment.center)

    -- Parpadeo "PRESS A"
    if (math.floor(titleFrame / 15) % 2) == 0 then
        gfx.drawRoundRect(100, 192, 200, 18, 5)
        gfx.drawTextAligned("[ Presiona A para jugar ]", 200, 195, kTextAlignment.center)
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
        -- Screen shake al entrar en pánico
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

    -- Flow: regeneración pasiva de stamina
    if ComboSystem.isInFlow() then
        Player.addStamina(0.017)
    end

    -- ── Dibujar escena ──────────────────────────────────────
    -- 1. Fondo (primero, detrás de todo)
    if bgImg then
        bgImg:draw(Layout.BG_X, Layout.BG_Y)
    end

    -- 2. Inodoro (incluye agua con olas)
    Toilet.draw()

    -- 3. Personaje
    Player.draw()

    -- 4. QTE (encima del personaje y el inodoro)
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
        -- Shake fuerte en game over
        triggerShake(6, 30)
    end
end

-- ── Nivel Completado ──────────────────────────────────────────
function GameManager._updateLevelClear()
    local gfx = playdate.graphics
    levelClearTimer -= 1

    -- Fondo
    if bgImg then bgImg:draw(Layout.BG_X, Layout.BG_Y) end

    -- Último estado del juego de fondo
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
        if img then img:draw(175, 90) end
    end

    -- Panel de resultado con estilo mejorado
    local px, py, pw, ph = 70, 55, 260, 115
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(px, py, pw, ph, 8)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRoundRect(px + 2, py + 2, pw - 4, ph - 4, 6)

    gfx.drawTextAligned("★ NIVEL " .. (level - 1) .. " COMPLETADO ★", 200, py + 12, kTextAlignment.center)

    gfx.setColor(gfx.kColorWhite)
    gfx.drawLine(90, py + 32, 330, py + 32)

    gfx.drawTextAligned("Score:  " .. ScoreManager.getScore(), 200, py + 40, kTextAlignment.center)
    gfx.drawTextAligned("Coins:  " .. ScoreManager.getCoins(), 200, py + 58, kTextAlignment.center)

    -- Cuenta regresiva animada
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

    -- Fondo oscuro (baño inundado)
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
